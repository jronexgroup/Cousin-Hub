import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../app_theme.dart';
import '../services/auth_service.dart';
import '../games/charades_words.dart';
import 'charades_result_screen.dart';

class CharadesGameScreen extends StatefulWidget {
  final String roomId;
  const CharadesGameScreen({super.key, required this.roomId});
  @override
  State<CharadesGameScreen> createState() => _CharadesGameScreenState();
}

class _CharadesGameScreenState extends State<CharadesGameScreen> {
  final _db = FirebaseDatabase.instance;
  final _auth = AuthService();
  final _clueCtrl = TextEditingController();
  final _guessCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  Map<String, dynamic> _room = {};
  int _currentRound = 0;
  List<Map<String, dynamic>> _clues = [];
  List<Map<String, dynamic>> _guesses = [];

  String get _myUid => _auth.currentUid!;
  String get _myName => _auth.currentName;
  String? get _secretWord => _room['secretWord'] as String?;
  String? get _actorUid => _room['actorUid'] as String?;
  bool get _isActor => _actorUid == _myUid;
  bool get _roundActive => _room['roundActive'] == true;
  String? get _roundWinner => _room['roundWinner'] as String?;

  @override
  void initState() {
    super.initState();
    _db.ref('charadesRooms/${widget.roomId}').onValue.listen((e) {
      if (!e.snapshot.exists || !mounted) return;
      setState(() => _room = Map<String, dynamic>.from(e.snapshot.value as Map));
      _currentRound = (_room['currentRound'] as num?)?.toInt() ?? 0;
      if (_room['status'] == 'finished' && mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => CharadesResultScreen(roomId: widget.roomId)));
      }
      if (_room['roundActive'] == true && _actorUid == null && _isHost) {
        _startNewRound();
      }
    });
    _db.ref('charadesRooms/${widget.roomId}/clues').onValue.listen((e) {
      if (!e.snapshot.exists || !mounted) { setState(() => _clues = []); return; }
      setState(() => _clues = (e.snapshot.value as Map).entries.map((en) {
        final v = Map<String, dynamic>.from(en.value as Map); v['id'] = en.key; return v;
      }).toList()..sort((a, b) => ((b['timestamp'] as num?) ?? 0).compareTo((a['timestamp'] as num?) ?? 0)));
    });
    _db.ref('charadesRooms/${widget.roomId}/guesses').onValue.listen((e) {
      if (!e.snapshot.exists || !mounted) { setState(() => _guesses = []); return; }
      setState(() => _guesses = (e.snapshot.value as Map).entries.map((en) {
        final v = Map<String, dynamic>.from(en.value as Map); v['id'] = en.key; return v;
      }).toList()..sort((a, b) => ((b['timestamp'] as num?) ?? 0).compareTo((a['timestamp'] as num?) ?? 0)));
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollCtrl.hasClients) _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      });
    });

    Future.delayed(const Duration(seconds: 1), () {
      if (_isHost && _room['roundActive'] != true) _startNewRound();
    });
  }

  bool get _isHost => _room['host'] == _myUid;

  List<Map<String, dynamic>> get _players {
    final p = (_room['players'] as Map?) ?? {};
    return p.entries.map((e) {
      final v = Map<String, dynamic>.from(e.value as Map); v['uid'] = e.key; return v;
    }).toList();
  }

  List<Map<String, dynamic>> get _actorOrder {
    final p = _players;
    final startIdx = (_room['actorIndex'] as num?)?.toInt() ?? 0;
    final ordered = [...p];
    ordered.sort((a, b) {
      final idxA = (a['uid'] as String);
      final idxB = (b['uid'] as String);
      return _players.indexWhere((pp) => pp['uid'] == idxA).compareTo(_players.indexWhere((pp) => pp['uid'] == idxB));
    });
    return ordered;
  }

  Future<void> _startNewRound() async {
    final rng = Random();
    final word = charadesWords[rng.nextInt(charadesWords.length)];
    final players = _players;
    final actorIdx = (_room['actorIndex'] as num?)?.toInt() ?? 0;
    final actor = players[actorIdx % players.length];
    final nextActorIdx = (actorIdx + 1) % players.length;

    await _db.ref('charadesRooms/${widget.roomId}').update({
      'secretWord': word,
      'actorUid': actor['uid'],
      'actorIndex': nextActorIdx,
      'roundActive': true,
      'roundWinner': null,
      'round': _currentRound,
    });
    await _db.ref('charadesRooms/${widget.roomId}/clues').remove();
    await _db.ref('charadesRooms/${widget.roomId}/guesses').remove();
  }

  Future<void> _sendClue() async {
    final text = _clueCtrl.text.trim();
    if (text.isEmpty || !_isActor) return;
    _clueCtrl.clear();
    await _db.ref('charadesRooms/${widget.roomId}/clues').push().set({
      'senderUid': _myUid, 'senderName': _myName, 'text': text, 'timestamp': ServerValue.timestamp,
    });
  }

  Future<void> _sendGuess() async {
    final text = _guessCtrl.text.trim();
    if (text.isEmpty) return;
    _guessCtrl.clear();
    await _db.ref('charadesRooms/${widget.roomId}/guesses').push().set({
      'senderUid': _myUid, 'senderName': _myName, 'text': text, 'timestamp': ServerValue.timestamp,
    });
    await Future.delayed(const Duration(milliseconds: 300));
    await _checkGuess(text);
  }

  Future<void> _checkGuess(String guess) async {
    if (_secretWord == null || _roundWinner != null) return;
    if (_wordMatches(guess, _secretWord!)) {
      await _endRound(_myUid);
    }
  }

  Future<void> _actorSelectWinner(String guesserUid) async {
    if (!_isActor || _roundWinner != null) return;
    await _endRound(guesserUid);
  }

  Future<void> _endRound(String winnerUid) async {
    final scores = Map<String, int>.from((_room['scores'] as Map?)?.map((k, v) => MapEntry(k.toString(), (v as num).toInt())) ?? {});
    scores[winnerUid] = (scores[winnerUid] ?? 0) + 1;
    final totalRounds = (_room['totalRounds'] as num?)?.toInt() ?? 8;
    final nextRound = _currentRound + 1;
    final isFinished = nextRound >= totalRounds;

    await _db.ref('charadesRooms/${widget.roomId}').update({
      'roundWinner': winnerUid,
      'scores': scores,
    });

    Future.delayed(const Duration(seconds: 3), () async {
      if (!mounted) return;
      if (isFinished) {
        await _db.ref('charadesRooms/${widget.roomId}').update({'status': 'finished', 'roundActive': false});
      } else {
        await _db.ref('charadesRooms/${widget.roomId}').update({
          'currentRound': nextRound,
          'roundActive': false,
          'actorUid': null,
          'secretWord': null,
        });
      }
    });
  }

  bool _wordMatches(String guess, String secret) {
    final g = guess.trim().toLowerCase();
    final s = secret.trim().toLowerCase();
    // Exact match
    if (g == s) return true;
    // Multi-word partial match: check if all guess words appear in secret
    final gWords = g.split(RegExp(r'\s+')).where((w) => w.length > 2).toList();
    final sWords = s.split(RegExp(r'\s+'));
    if (gWords.length > 1) {
      return gWords.every((w) => sWords.any((sw) => sw.contains(w) || w.contains(sw)));
    }
    // Single word: check if it's contained in secret or vice versa for words with 4+ chars
    if (g.length >= 4 && (s.contains(g) || g.contains(s))) return true;
    return false;
  }

  @override
  void dispose() {
    _clueCtrl.dispose();
    _guessCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: AppTheme.ink), onPressed: () => Navigator.pop(context)),
        title: Text('Round ${_currentRound + 1}/${_room['totalRounds'] ?? 8}',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.ink)),
      ),
      body: _roundActive ? (_isActor ? _buildActorView() : _buildGuesserView()) : _buildWaitingView(),
    );
  }

  Widget _buildWaitingView() {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Text('🎭', style: TextStyle(fontSize: 64)),
      const SizedBox(height: 16),
      Text(DateTime.now().millisecondsSinceEpoch % 2 == 0 ? 'Loading...' : 'Getting ready...',
        style: const TextStyle(fontSize: 16, color: AppTheme.muted)),
    ]));
  }

  Widget _buildActorView() {
    final players = _players.where((p) => p['uid'] != _myUid).toList();
    return Column(children: [
      // Secret word banner
      Container(padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(gradient: AppTheme.mainGradient),
        child: Column(children: [
          const Text('🤫 You are the ACTOR!', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(_secretWord ?? '', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 1)),
          const Text('Don\'t say this word!', style: TextStyle(color: Colors.white60, fontSize: 11)),
          const SizedBox(height: 12),
          if (_roundWinner != null)
            Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(100)),
              child: Text('🎉 ${_playerName(_roundWinner!)} guessed it!', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
        ])),
      // Clues stream
      Expanded(child: Container(
        color: const Color(0xFFF8F4FF),
        child: ListView.builder(
          controller: _scrollCtrl,
          padding: const EdgeInsets.all(12),
          itemCount: _clues.length + 1,
          itemBuilder: (_, i) {
            if (i == 0) return Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('Your clues:', style: TextStyle(fontSize: 11, color: AppTheme.muted, fontWeight: FontWeight.w600)));
            final clue = _clues[i - 1];
            return Container(margin: const EdgeInsets.only(bottom: 4), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE8D9C5))),
              child: Row(children: [
                const Text('💬 ', style: TextStyle(fontSize: 12)),
                Expanded(child: Text(clue['text'] ?? '', style: const TextStyle(fontSize: 13, color: AppTheme.ink))),
              ]));
          },
        ),
      )),
      // Guesses with select buttons
      Container(
        constraints: const BoxConstraints(maxHeight: 180),
        color: Colors.white,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          children: [
            Text('Guesses:', style: TextStyle(fontSize: 11, color: AppTheme.muted, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            if (_guesses.isEmpty)
              const Text('Waiting for guesses...', style: TextStyle(fontSize: 12, color: AppTheme.soft))
            else
              ..._guesses.map((g) {
                final isCorrect = _roundWinner == g['senderUid'];
                return Container(margin: const EdgeInsets.only(bottom: 4), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isCorrect ? const Color(0xFFE8F5E9) : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isCorrect ? Colors.green : const Color(0xFFE8D9C5))),
                  child: Row(children: [
                    Expanded(child: Text('${g['senderName']}: ${g['text']}',
                      style: TextStyle(fontSize: 12, color: isCorrect ? Colors.green : AppTheme.ink, fontWeight: isCorrect ? FontWeight.w700 : FontWeight.w400))),
                    if (_roundWinner == null && g['senderUid'] != _myUid)
                      GestureDetector(onTap: () => _actorSelectWinner(g['senderUid'] as String),
                        child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(100)),
                          child: const Text('👑 Correct', style: TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w700))),
                      ),
                  ]));
              }),
          ],
        ),
      ),
      // Clue input
      Container(padding: const EdgeInsets.all(12), color: Colors.white, child: Row(children: [
        Expanded(child: TextField(controller: _clueCtrl,
          decoration: InputDecoration(
            hintText: 'Type a clue...', filled: true, fillColor: AppTheme.bg,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
          style: const TextStyle(fontSize: 13), onSubmitted: (_) => _sendClue())),
        const SizedBox(width: 8),
        GestureDetector(onTap: _sendClue,
          child: Container(padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.send, color: Colors.white, size: 18)),
        ),
      ])),
    ]);
  }

  Widget _buildGuesserView() {
    return Column(children: [
      // Actor indicator + scores
      Container(padding: const EdgeInsets.all(12), color: Colors.white,
        child: Row(children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: const Color(0xFFFFF8E1), borderRadius: BorderRadius.circular(100)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Text('🎭 ', style: TextStyle(fontSize: 12)),
              Text(_playerName(_actorUid!), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.orange.shade800)),
            ])),
          const Spacer(),
          Text('is describing...', style: const TextStyle(fontSize: 11, color: AppTheme.muted)),
        ])),
      // Clues stream
      Expanded(child: Container(
        color: const Color(0xFFF8F4FF),
        child: ListView.builder(
          controller: _scrollCtrl,
          padding: const EdgeInsets.all(12),
          itemCount: _clues.length + 1,
          itemBuilder: (_, i) {
            if (i == 0) return Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('Clues:', style: TextStyle(fontSize: 11, color: AppTheme.muted, fontWeight: FontWeight.w600)));
            final clue = _clues[i - 1];
            return Container(margin: const EdgeInsets.only(bottom: 4), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE8D9C5))),
              child: Row(children: [
                Container(width: 24, height: 24,
                  decoration: BoxDecoration(gradient: AppTheme.mainGradient, shape: BoxShape.circle),
                  child: Center(child: Text((clue['senderName'] ?? '?')[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)))),
                const SizedBox(width: 8),
                Expanded(child: Text(clue['text'] ?? '', style: const TextStyle(fontSize: 13, color: AppTheme.ink))),
              ]));
          },
        ),
      )),
      // Guesses
      Container(
        constraints: const BoxConstraints(maxHeight: 150),
        color: Colors.white,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          children: [
            Text('Your guesses:', style: TextStyle(fontSize: 11, color: AppTheme.muted, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            if (_guesses.isEmpty)
              const Text('Type your guess below!', style: TextStyle(fontSize: 12, color: AppTheme.soft))
            else
              ..._guesses.map((g) {
                final isMe = g['senderUid'] == _myUid;
                final isCorrect = _roundWinner == g['senderUid'];
                return Container(margin: const EdgeInsets.only(bottom: 4), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isCorrect ? const Color(0xFFE8F5E9) : isMe ? const Color(0xFFEDE9FE) : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isCorrect ? Colors.green : const Color(0xFFE8D9C5))),
                  child: Text('${g['senderName']}: ${g['text']}${isCorrect ? ' ✅' : ''}',
                    style: TextStyle(fontSize: 12, color: isCorrect ? Colors.green : AppTheme.ink, fontWeight: isCorrect ? FontWeight.w700 : FontWeight.w400)));
              }),
          ],
        ),
      ),
      // Guess input
      Container(padding: const EdgeInsets.all(12), color: Colors.white, child: Row(children: [
        Expanded(child: TextField(controller: _guessCtrl,
          decoration: InputDecoration(
            hintText: 'Type your guess...', filled: true, fillColor: AppTheme.bg,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
          style: const TextStyle(fontSize: 13), onSubmitted: (_) => _sendGuess())),
        const SizedBox(width: 8),
        GestureDetector(onTap: _sendGuess,
          child: Container(padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.send, color: Colors.white, size: 18)),
        ),
      ])),
    ]);
  }

  String _playerName(String uid) {
    final p = _players.where((p) => p['uid'] == uid);
    return p.isEmpty ? '?' : p.first['name'] as String? ?? '?';
  }
}
