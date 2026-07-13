import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../app_theme.dart';
import '../services/auth_service.dart';
import 'rps_result_screen.dart';

class RpsGameScreen extends StatefulWidget {
  final String roomId;
  const RpsGameScreen({super.key, required this.roomId});
  @override
  State<RpsGameScreen> createState() => _RpsGameScreenState();
}

class _RpsGameScreenState extends State<RpsGameScreen> {
  final _db = FirebaseDatabase.instance;
  final _auth = AuthService();
  Map<String, dynamic> _room = {};
  int _round = 0;
  int _phaseTimer = 0;
  String? _myPick;
  bool _submitted = false;

  String get _myUid => _auth.currentUid!;
  String get _myName => _auth.currentName;
  bool get _isHost => _room['host'] == _myUid;

  @override
  void initState() {
    super.initState();
    _db.ref('rpsRooms/${widget.roomId}').onValue.listen((e) {
      if (!e.snapshot.exists || !mounted) return;
      final data = Map<String, dynamic>.from(e.snapshot.value as Map);
      setState(() { _room = data; _round = (data['round'] as num?)?.toInt() ?? 0; });
      if (data['status'] == 'finished' && mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => RpsResultScreen(roomId: widget.roomId)));
      }
    });
    _startPhaseTimer();
  }

  void _startPhaseTimer() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _phaseTimer = _getPhaseTimeLeft());
      final phase = _room['phase'] ?? 'pick';
      if (phase == 'reveal' || phase == 'result') {
        final phaseStart = (_room['phaseStartedAt'] as num?)?.toInt() ?? 0;
        if (DateTime.now().millisecondsSinceEpoch - phaseStart > 4000) return false;
      }
      return true;
    });
  }

  int _getPhaseTimeLeft() {
    final phase = _room['phase'] ?? 'pick';
    if (phase != 'reveal' && phase != 'result') return 0;
    final phaseStart = (_room['phaseStartedAt'] as num?)?.toInt() ?? 0;
    return 4 - (DateTime.now().millisecondsSinceEpoch - phaseStart) ~/ 1000;
  }

  List<Map<String, dynamic>> get _players {
    final p = (_room['players'] as Map?) ?? {};
    return p.entries.map((e) {
      final v = Map<String, dynamic>.from(e.value as Map); v['uid'] = e.key; return v;
    }).toList();
  }

  Map<String, dynamic>? get _currentRound {
    final rounds = _room['rounds'] as Map?;
    if (rounds == null) return null;
    return Map<String, dynamic>.from(rounds['$_round'] as Map? ?? {});
  }

  String get _phase => (_room['phase'] ?? _room['rounds/$_round/phase'] ?? 'pick') as String;

  bool get _allPicked {
    final r = _currentRound;
    if (r == null) return false;
    final picks = r['picks'] as Map? ?? {};
    return _players.every((p) => picks.containsKey(p['uid']));
  }

  Future<void> _pick(String choice) async {
    if (_submitted) return;
    setState(() { _myPick = choice; _submitted = true; });
    await _db.ref('rpsRooms/${widget.roomId}/rounds/$_round/picks/$_myUid').set(choice);

    if (_isHost && _allPicked) {
      await Future.delayed(const Duration(milliseconds: 500));
      _resolveRound();
    }
  }

  void _resolveRound() {
    final r = _currentRound!;
    final picks = Map<String, String>.from((r['picks'] as Map).map((k, v) => MapEntry(k.toString(), v.toString())));
    final mode = _room['mode'] ?? 'bo3';
    final scores = Map<String, int>.from((_room['scores'] as Map?)?.map((k, v) => MapEntry(k.toString(), (v as num).toInt())) ?? {});
    final uids = _players.map((p) => p['uid'] as String).toList();

    Map<String, int> roundWins = {};
    for (final uid in uids) {
      for (final other in uids) {
        if (uid == other) continue;
        final result = _rpsResult(picks[uid]!, picks[other]!);
        if (result == 1) roundWins[uid] = (roundWins[uid] ?? 0) + 1;
      }
    }

    String? winner;
    if (mode == 'ffa') {
      final maxWins = roundWins.values.isEmpty ? 0 : roundWins.values.reduce(max);
      final top = roundWins.entries.where((e) => e.value == maxWins).toList();
      if (top.length == 1) {
        winner = top.first.key;
        scores[winner] = (scores[winner] ?? 0) + 1;
      }
    } else {
      final target = mode == 'bo3' ? 2 : 3;
      for (final uid in uids) {
        for (final other in uids) {
          if (uid == other) continue;
          final result = _rpsResult(picks[uid]!, picks[other]!);
          if (result == 1) {
            scores[uid] = (scores[uid] ?? 0) + 1;
          }
        }
      }
      for (final uid in uids) {
        if ((scores[uid] ?? 0) >= target) {
          winner = uid;
          break;
        }
      }
    }

    final phaseStartedAt = DateTime.now().millisecondsSinceEpoch;
    final updates = <String, dynamic>{};
    updates['rounds/$_round/results'] = roundWins.map((k, v) => MapEntry(k, v));
    updates['phase'] = 'reveal';
    updates['phaseStartedAt'] = phaseStartedAt;

    if (winner != null) {
      updates['winner'] = winner;
      updates['status'] = 'finished';
      _db.ref('rpsRooms/${widget.roomId}').update(updates);
      return;
    }

    _db.ref('rpsRooms/${widget.roomId}').update(updates);

    Future.delayed(const Duration(seconds: 4), () async {
      if (!mounted) return;
      final nextRound = _round + 1;
      await _db.ref('rpsRooms/${widget.roomId}/round/$nextRound').set({
        'phase': 'pick',
        'phaseStartedAt': DateTime.now().millisecondsSinceEpoch,
      });
      await _db.ref('rpsRooms/${widget.roomId}/round').set(nextRound);
      await _db.ref('rpsRooms/${widget.roomId}/phase').set('pick');
      await _db.ref('rpsRooms/${widget.roomId}/phaseStartedAt').set(DateTime.now().millisecondsSinceEpoch);
      setState(() { _submitted = false; _myPick = null; _round = nextRound; });
    });
  }

  int _rpsResult(String a, String b) {
    if (a == b) return 0;
    if ((a == 'rock' && b == 'scissors') || (a == 'scissors' && b == 'paper') || (a == 'paper' && b == 'rock')) return 1;
    return -1;
  }

  Map<String, int> get _scores {
    return Map<String, int>.from((_room['scores'] as Map?)?.map((k, v) => MapEntry(k.toString(), (v as num).toInt())) ?? {});
  }

  @override
  Widget build(BuildContext context) {
    final isPickPhase = _phase == 'pick';
    final isRevealPhase = _phase == 'reveal';
    final currentRound = _currentRound;
    final picks = (currentRound?['picks'] as Map?) ?? {};
    final results = Map<String, int>.from((currentRound?['results'] as Map?)?.map((k, v) => MapEntry(k.toString(), (v as num).toInt())) ?? {});

    String? myResult;
    if (results.isNotEmpty && _myPick != null) {
      final r = results[_myUid];
      if (r != null) myResult = r > 0 ? 'Won' : r < 0 ? 'Lost' : 'Tie';
    }

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        title: Text('Round ${_round + 1}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.ink)),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: AppTheme.ink), onPressed: () => Navigator.pop(context)),
      ),
      body: Column(children: [
        // Score bar
        Container(padding: const EdgeInsets.all(12), color: Colors.white,
          child: SingleChildScrollView(scrollDirection: Axis.horizontal,
            child: Row(children: _players.map((p) {
              final score = _scores[p['uid']] ?? 0;
              final target = _room['mode'] == 'bo3' ? 2 : _room['mode'] == 'bo5' ? 3 : 0;
              return Padding(padding: const EdgeInsets.only(right: 12),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 28, height: 28,
                    decoration: BoxDecoration(gradient: AppTheme.mainGradient, shape: BoxShape.circle),
                    child: Center(child: Text((p['name'] ?? '?')[0].toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)))),
                  const SizedBox(width: 4),
                  Text(p['name'] ?? '', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.ink)),
                  const SizedBox(width: 4),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(100)),
                    child: Text('$score${target > 0 ? '/$target' : ''}',
                      style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
                ]));
            }).toList()),
          ),
        ),
        Expanded(child: isPickPhase ? _buildPickPhase(picks) : _buildRevealPhase(picks, results, myResult)),
      ]),
    );
  }

  Widget _buildPickPhase(Map picks) {
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const SizedBox(height: 20),
      const Text('Pick your move!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.ink)),
      const SizedBox(height: 8),
      Text('${_players.where((p) => picks.containsKey(p['uid'])).length}/${_players.length} picked',
        style: const TextStyle(fontSize: 14, color: AppTheme.muted)),
      const SizedBox(height: 40),
      if (_submitted)
        Column(children: [
          const Text('✅ Waiting for others...', style: TextStyle(fontSize: 16, color: Colors.green, fontWeight: FontWeight.w600)),
          const SizedBox(height: 20),
          Text(_emojiForPick(_myPick!), style: const TextStyle(fontSize: 64)),
        ])
      else
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _pickBtn('rock', '🪨', 'Rock'),
          const SizedBox(width: 16),
          _pickBtn('paper', '📄', 'Paper'),
          const SizedBox(width: 16),
          _pickBtn('scissors', '✂️', 'Scissors'),
        ]),
    ]);
  }

  Widget _pickBtn(String val, String emoji, String label) {
    return GestureDetector(onTap: () => _pick(val),
      child: Column(children: [
        Container(width: 80, height: 80,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: AppTheme.primary.withOpacity(0.2), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: Center(child: Text(emoji, style: const TextStyle(fontSize: 36)))),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.ink, fontSize: 13)),
      ]));
  }

  Widget _buildRevealPhase(Map picks, Map<String, int> results, String? myResult) {
    return SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(children: [
      Text(myResult == 'Won' ? '🎉 You Won!' : myResult == 'Lost' ? '😔 You Lost' : '🤝 Tie',
        style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800,
          color: myResult == 'Won' ? Colors.green : myResult == 'Lost' ? Colors.red : Colors.orange)),
      const SizedBox(height: 24),
      ..._players.map((p) {
        final uid = p['uid'] as String;
        final pick = picks[uid]?.toString() ?? '?';
        final result = results[uid];
        final emoji = _emojiForPick(pick);
        final wl = result == null ? '' : result > 0 ? ' ✅' : result < 0 ? ' ❌' : ' ➖';
        return Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
            border: uid == _myUid ? Border.all(color: AppTheme.primary, width: 2) : null),
          child: Row(children: [
            Text('$emoji  ', style: const TextStyle(fontSize: 28)),
            Expanded(child: Text(p['name'] ?? '', style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.ink, fontSize: 15))),
            Text(pick.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.muted, fontSize: 13)),
            Text('$wl', style: const TextStyle(fontSize: 18)),
          ]));
      }),
    ]));
  }

  String _emojiForPick(String? pick) {
    switch (pick) {
      case 'rock': return '🪨';
      case 'paper': return '📄';
      case 'scissors': return '✂️';
      default: return '❓';
    }
  }
}
