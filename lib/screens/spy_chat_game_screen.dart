import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart' as emoji_picker;
import '../app_theme.dart';
import 'spy_chat_models.dart';
import 'spy_chat_result_screen.dart';

class SpyChatGameScreen extends StatefulWidget {
  final String roomId, myUid, myName, myPhoto;
  final bool isHost;

  const SpyChatGameScreen({
    super.key,
    required this.roomId,
    required this.myUid,
    required this.myName,
    required this.myPhoto,
    this.isHost = false,
  });

  @override
  State<SpyChatGameScreen> createState() => _SpyChatGameScreenState();
}

class _SpyChatGameScreenState extends State<SpyChatGameScreen> with SingleTickerProviderStateMixin {
  final _db = FirebaseDatabase.instance;
  StreamSubscription? _roomSub, _chatSub;
  Timer? _countdownTimer;
  late TabController _tabCtrl;

  List<SpyPlayerData> _players = [];
  String _status = 'waiting';
  String? _myWord, _currentClueTurn;
  int? _discussionEndAt, _votingEndAt;
  bool _wordConfirmed = false, _navigated = false;
  bool _showClueInput = false;
  String _clueInputText = '';
  String? _myVote;
  final _chatCtrl = TextEditingController();
  bool _showEmoji = false;
  List<Map<String, dynamic>> _chatMessages = [];
  Map<String, int> _voteTally = {};

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _listenRoom();
    _listenChat();
    _startCountdown();
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  void _listenRoom() {
    _roomSub = _db.ref('spyChatRooms/${widget.roomId}').onValue.listen((e) {
      if (!e.snapshot.exists || !mounted) return;
      final d = Map<String, dynamic>.from(e.snapshot.value as Map);

      final st = d['status'] as String? ?? 'waiting';
      if ((st == 'finished' || st == 'cancelled') && !_navigated) {
        _navigated = true;
        _roomSub?.cancel();
        _chatSub?.cancel();
        _countdownTimer?.cancel();
        Navigator.pushReplacement(context, MaterialPageRoute(
          builder: (_) => SpyChatResultScreen(
            roomId: widget.roomId, myUid: widget.myUid,
            myName: widget.myName, myPhoto: widget.myPhoto)));
        return;
      }

      final pm = d['players'] as Map? ?? {};
      final list = pm.entries.map((e) =>
        SpyPlayerData.fromMap(Map<String, dynamic>.from(e.value as Map), e.key)).toList();

      final myData = pm[widget.myUid] as Map?;
      final myWord = myData?['word'] as String?;

      setState(() {
        _players = list;
        _status = st;
        _currentClueTurn = d['currentClueTurn'] as String?;
        _discussionEndAt = d['discussionEndAt'] as int?;
        _votingEndAt = d['votingEndAt'] as int?;
        if (myWord != null) _myWord = myWord;

        // Vote tally from room data
        final votes = d['votes'] as Map? ?? {};
        final tally = <String, int>{};
        for (final v in votes.values) {
          final target = v as String?;
          if (target != null) tally[target] = (tally[target] ?? 0) + 1;
        }
        _voteTally = tally;
      });
    });
  }

  void _listenChat() {
    _chatSub = _db.ref('chats/spyChat_${widget.roomId}')
        .orderByChild('timestamp').limitToLast(200).onValue.listen((e) {
      if (!e.snapshot.exists || !mounted) return;
      final msgs = <Map<String, dynamic>>[];
      e.snapshot.children.forEach((child) {
        final m = Map<String, dynamic>.from(child.value as Map);
        m['key'] = child.key;
        msgs.add(m);
      });
      msgs.sort((a, b) => ((a['timestamp'] as num?) ?? 0).compareTo((b['timestamp'] as num?) ?? 0));
      if (mounted) setState(() => _chatMessages = msgs);
    });
  }

  int get _aliveCount => _players.where((p) => p.alive).length;
  bool get _myTurn => _currentClueTurn == widget.myUid;
  bool get _isAlive => _players.any((p) => p.uid == widget.myUid && p.alive);
  bool get _isSpy => _players.any((p) => p.uid == widget.myUid && p.role == 'spy');

  int get _discussionRemaining {
    if (_discussionEndAt == null) return 0;
    return ((_discussionEndAt! - DateTime.now().millisecondsSinceEpoch) / 1000).ceil().clamp(0, 999);
  }

  int get _votingRemaining {
    if (_votingEndAt == null) return 0;
    return ((_votingEndAt! - DateTime.now().millisecondsSinceEpoch) / 1000).ceil().clamp(0, 999);
  }

  Future<void> _confirmWord() async {
    await _db.ref('spyChatRooms/${widget.roomId}/players/${widget.myUid}/confirmedWord').set(true);
    setState(() => _wordConfirmed = true);
  }

  Future<void> _submitClue() async {
    if (_clueInputText.trim().isEmpty) return;
    await _db.ref('chats/spyChat_${widget.roomId}').push().set({
      'senderUid': widget.myUid, 'senderName': widget.myName,
      'text': _clueInputText.trim(), 'type': 'clue',
      'timestamp': ServerValue.timestamp,
    });
    await _db.ref('spyChatRooms/${widget.roomId}/clueMessages').push().set({
      'senderUid': widget.myUid, 'senderName': widget.myName,
      'text': _clueInputText.trim(), 'timestamp': ServerValue.timestamp,
    });
    setState(() { _showClueInput = false; _clueInputText = ''; });
  }

  Future<void> _sendChat() async {
    if (_chatCtrl.text.trim().isEmpty) return;
    await _db.ref('chats/spyChat_${widget.roomId}').push().set({
      'senderUid': widget.myUid, 'senderName': widget.myName,
      'text': _chatCtrl.text.trim(), 'type': 'text',
      'timestamp': ServerValue.timestamp,
    });
    _chatCtrl.clear();
    setState(() => _showEmoji = false);
  }

  Future<void> _castVote(String targetUid) async {
    if (!_isAlive) return;
    if (_myVote == targetUid) {
      await _db.ref('spyChatRooms/${widget.roomId}/votes/${widget.myUid}').remove();
      setState(() => _myVote = null);
    } else {
      await _db.ref('spyChatRooms/${widget.roomId}/votes/${widget.myUid}').set(targetUid);
      setState(() => _myVote = targetUid);
    }
  }

  @override
  void dispose() {
    _roomSub?.cancel();
    _chatSub?.cancel();
    _countdownTimer?.cancel();
    _tabCtrl.dispose();
    _chatCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A1A), elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(children: [
          const Text('🕵️', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 6),
          Text('Spy Chat', style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 16)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white12, borderRadius: BorderRadius.circular(10)),
            child: Text('$_aliveCount/${_players.length}',
              style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        ]),
      ),
      body: Stack(children: [
        Column(children: [
          _buildWordBar(),
          if (_status == 'wordReveal' && !_wordConfirmed)
            _buildWordPopup()
          else ...[
            _buildTimerBar(),
            Expanded(child: _buildTabContent()),
          ],
        ]),
        if (_showClueInput && _status == 'clueSubmission')
          _buildClueInputOverlay(),
      ]),
    );
  }

  Widget _buildWordBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF111122),
        border: Border(bottom: BorderSide(color: Colors.white12))),
      child: Column(children: [
        const Text('YOUR WORD', style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(_myWord?.toUpperCase() ?? '???',
          style: TextStyle(
            color: _isSpy ? Colors.redAccent : AppTheme.primary,
            fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1.2)),
      ]),
    );
  }

  Widget _buildWordPopup() {
    return Expanded(
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.primary.withOpacity(0.4), width: 2)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(_isSpy ? 'YOU ARE A SPY!' : 'YOU ARE A CIVILIAN',
              style: TextStyle(
                color: _isSpy ? Colors.redAccent : Colors.greenAccent,
                fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 20),
            const Text('YOUR WORD', style: TextStyle(color: Colors.white38, fontSize: 12)),
            const SizedBox(height: 8),
            Text(_myWord?.toUpperCase() ?? '???',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 28)),
            const SizedBox(height: 20),
            Text(
              _isSpy
                  ? 'The civilians have a similar but different word.\nDo not get caught!'
                  : 'Keep your word secret.\nFind the spies!',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 13, height: 1.5)),
            const SizedBox(height: 24),
            AppTheme.gradientButton(
              label: 'OK', onTap: _confirmWord, height: 48),
          ]),
        ),
      ),
    );
  }

  Widget _buildTimerBar() {
    if (_status == 'discussion' && _discussionRemaining > 0) {
      return _timerRow('💬 Discussion', _discussionRemaining, Colors.blueAccent);
    }
    if (_status == 'voting' && _votingRemaining > 0) {
      return _timerRow('🗳️ Voting', _votingRemaining, Colors.orangeAccent);
    }
    if (_status == 'clueSubmission') {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: const Color(0xFF111122),
        child: Text(
          _myTurn ? '✏️ Your turn to submit a clue!' : '⏳ Waiting for clue...',
          style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w600)),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _timerRow(String label, int remaining, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFF111122),
      child: Row(children: [
        Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: remaining <= 10 ? Colors.red.shade900 : Colors.white12,
            borderRadius: BorderRadius.circular(6)),
          child: Text('${remaining}s',
            style: TextStyle(
              color: remaining <= 10 ? Colors.redAccent : Colors.white70,
              fontWeight: FontWeight.w900, fontSize: 13)),
        ),
      ]),
    );
  }

  Widget _buildTabContent() {
    return Column(children: [
      Container(
        color: const Color(0xFF0A0A1A),
        child: TabBar(
          controller: _tabCtrl,
          indicatorColor: AppTheme.primary,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white38,
          tabs: const [
            Tab(text: 'Clue Room', icon: Icon(Icons.lightbulb_outline, size: 18)),
            Tab(text: 'Voting Room', icon: Icon(Icons.how_to_vote_outlined, size: 18)),
          ]),
      ),
      Expanded(child: TabBarView(controller: _tabCtrl, children: [
        _buildClueRoom(),
        _buildVotingRoom(),
      ])),
    ]);
  }

  Widget _buildClueRoom() {
    return Column(children: [
      // Clue messages
      Expanded(child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: _chatMessages.length + 1,
        itemBuilder: (_, i) {
          if (i == 0) return const SizedBox(height: 4);
          final m = _chatMessages[i - 1];
          final type = m['type'] as String? ?? 'text';
          final text = m['text'] as String? ?? '';
          final name = m['senderName'] as String? ?? '';
          final isMe = m['senderUid'] == widget.myUid;
          if (type == 'system') {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Center(child: Text(text,
                style: const TextStyle(color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic))));
          }
          if (type == 'clue') {
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF1B3A2D),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.greenAccent.withOpacity(0.3))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text('🔍 $name\'s clue',
                    style: const TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: 4),
                Text('"$text"',
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
              ]),
            );
          }
          // text message
          return Container(
            margin: const EdgeInsets.only(bottom: 4),
            child: Row(
              mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
              children: [
                if (!isMe) ...[
                  Container(width: 24, height: 24,
                    decoration: const BoxDecoration(color: Colors.grey, shape: BoxShape.circle),
                    child: ClipOval(child: Text(name[0].toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontSize: 10)))),
                  const SizedBox(width: 6),
                ],
                Container(
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.65),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isMe ? AppTheme.primary.withOpacity(0.3) : const Color(0xFF1A1A2E),
                    borderRadius: BorderRadius.circular(12)),
                  child: Text(text,
                    style: const TextStyle(color: Colors.white, fontSize: 13)),
                ),
              ],
            ),
          );
        },
      )),
      // Chat input
      if (_status == 'discussion')
        _buildChatInput()
      else if (_status == 'clueSubmission')
        _buildClueStatusBar()
      else
        const SizedBox.shrink(),
    ]);
  }

  Widget _buildChatInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      decoration: const BoxDecoration(
        color: Color(0xFF111122),
        border: Border(top: BorderSide(color: Colors.white12))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (_showEmoji)
          SizedBox(
            height: 160,
            child: emoji_picker.EmojiPicker(
              onEmojiSelected: (_, e) => _chatCtrl.text += e.emoji,
              config: const emoji_picker.Config(
                height: 160,
                emojiViewConfig: emoji_picker.EmojiViewConfig(
                  columns: 7, verticalSpacing: 0, horizontalSpacing: 0)),
            ),
          ),
        Row(children: [
          IconButton(
            icon: Icon(_showEmoji ? Icons.keyboard : Icons.emoji_emotions, color: Colors.white54, size: 18),
            onPressed: () => setState(() => _showEmoji = !_showEmoji)),
          Expanded(child: TextField(
            controller: _chatCtrl,
            enabled: _isAlive,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: _isAlive ? 'Chat...' : 'Eliminated',
              hintStyle: TextStyle(color: Colors.white24),
              border: InputBorder.none),
            onSubmitted: (_) => _sendChat())),
          IconButton(
            icon: const Icon(Icons.send_rounded, color: AppTheme.primary, size: 18),
            onPressed: _isAlive ? _sendChat : null),
        ]),
      ]),
    );
  }

  Widget _buildClueStatusBar() {
    final isEliminated = !_isAlive;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: Color(0xFF111122),
        border: Border(top: BorderSide(color: Colors.white12))),
      child: isEliminated
          ? const Text('You are eliminated', style: TextStyle(color: Colors.white24, fontSize: 12))
          : ElevatedButton(
              onPressed: _myTurn ? () => setState(() => _showClueInput = true) : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _myTurn ? AppTheme.primary : Colors.grey.shade800,
                disabledBackgroundColor: Colors.grey.shade800,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              child: Text(
                _myTurn ? '✏️ Submit Your Clue' : '⏳ Waiting for turn...',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
            ),
    );
  }

  Widget _buildClueInputOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black87,
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.primary.withOpacity(0.4))),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('Your Turn', textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20)),
              const SizedBox(height: 8),
              const Text('Enter a clue for others to guess',
                textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 13)),
              const SizedBox(height: 16),
              TextField(
                autofocus: true,
                maxLines: 3,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'Type your clue...',
                  hintStyle: const TextStyle(color: Colors.white24),
                  filled: true, fillColor: const Color(0xFF0A0A1A),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                onChanged: (v) => _clueInputText = v,
                onSubmitted: (_) => _submitClue()),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: OutlinedButton(
                  onPressed: () => setState(() => _showClueInput = false),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white54)))),
                const SizedBox(width: 12),
                Expanded(child: AppTheme.gradientButton(
                  label: 'Submit',
                  onTap: _clueInputText.trim().isNotEmpty ? _submitClue : null,
                  height: 44)),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildVotingRoom() {
    final alive = _players.where((p) => p.alive).toList();
    final eliminated = _players.where((p) => !p.alive).toList();
    final canVote = _status == 'voting' && _isAlive;

    return Column(children: [
      if (_votingRemaining > 0 && _status == 'voting')
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          color: Colors.orange.shade900.withOpacity(0.2),
          child: Text(
            _myVote != null ? '✅ You voted' : '🗳️ Vote for someone',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
        ),
      Expanded(child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          ...alive.map((p) => _voteCard(p, canVote)),
          if (eliminated.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('ELIMINATED', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w900, fontSize: 11))),
            ...eliminated.map((p) => _voteCard(p, false)),
          ],
        ],
      )),
    ]);
  }

  Widget _voteCard(SpyPlayerData p, bool canVote) {
    final votedByMe = _myVote == p.uid;
    final voteCount = _voteTally[p.uid] ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: votedByMe ? Colors.orange.shade900.withOpacity(0.3) : const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: votedByMe ? Colors.orange : !p.alive ? Colors.red.shade900 : Colors.white12,
          width: votedByMe ? 2 : 1)),
      child: Row(children: [
        Container(width: 44, height: 44,
          decoration: BoxDecoration(
            color: Colors.grey.shade700,
            shape: BoxShape.circle,
            border: Border.all(color: p.alive ? Colors.white24 : Colors.red.shade900, width: 2)),
          child: p.photo.isNotEmpty
              ? ClipOval(child: Image.network(p.photo, fit: BoxFit.cover))
              : Center(child: Text(p.name[0].toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(p.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
            if (!p.alive) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.red.shade900, borderRadius: BorderRadius.circular(4)),
                child: const Text('OUT', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900)),
              ),
            ],
          ]),
          const SizedBox(height: 2),
          Text('Votes: $voteCount', style: const TextStyle(color: Colors.white54, fontSize: 11)),
        ])),
        if (canVote && p.alive)
          ElevatedButton(
            onPressed: () => _castVote(p.uid),
            style: ElevatedButton.styleFrom(
              backgroundColor: votedByMe ? Colors.orange.shade700 : Colors.grey.shade700,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: Text(votedByMe ? 'VOTED' : 'VOTE',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11)),
          ),
      ]),
    );
  }
}
