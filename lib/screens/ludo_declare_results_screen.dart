import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../app_theme.dart';
import 'ludo_result_screen.dart';

class LudoDeclareResultsScreen extends StatefulWidget {
  final String matchId;
  final String roomCode;
  final String hostUid;
  final String hostName;
  const LudoDeclareResultsScreen({
    super.key, required this.matchId, required this.roomCode,
    required this.hostUid, required this.hostName,
  });
  @override
  State<LudoDeclareResultsScreen> createState() => _LudoDeclareResultsState();
}

class _LudoDeclareResultsState extends State<LudoDeclareResultsScreen> {
  final _db = FirebaseDatabase.instance;
  List<_PlayerResult> _players = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadPlayers();
  }

  void _loadPlayers() {
    _db.ref('ludoKingMatches/${widget.matchId}/players').once().then((e) {
      if (!e.snapshot.exists || !mounted) return;
      final data = Map<String, dynamic>.from(e.snapshot.value as Map);
      final list = data.entries.map((en) => _PlayerResult(
        uid: en.key,
        name: (en.value as Map)['name']?.toString() ?? 'Cousin',
        rank: 0,
      )).toList();
      if (mounted) setState(() => _players = list);
    });
  }

  void _setRank(int index, int rank) {
    setState(() {
      for (final p in _players) {
        if (p.rank == rank) p.rank = 0;
      }
      _players[index].rank = rank;
    });
  }

  static const _xpForRank = [0, 100, 75, 50, 25, 10];

  Future<void> _save() async {
    final assigned = _players.where((p) => p.rank > 0).length;
    if (assigned == 0) return;
    setState(() => _saving = true);

    final resultsMap = <String, dynamic>{};
    for (final p in _players) {
      final xp = p.rank > 0 && p.rank < _xpForRank.length ? _xpForRank[p.rank] : 0;
      resultsMap[p.uid] = {
        'name': p.name,
        'rank': p.rank,
        'xpEarned': xp,
      };
    }

    await _db.ref('ludoKingResults/${widget.matchId}').set({
      'roomCode': widget.roomCode,
      'hostUid': widget.hostUid,
      'hostName': widget.hostName,
      'date': ServerValue.timestamp,
      'players': resultsMap,
    });

    for (final p in _players) {
      if (p.rank <= 0) continue;
      final xp = p.rank < _xpForRank.length ? _xpForRank[p.rank] : 0;
      final statsRef = _db.ref('users/${p.uid}/ludoKingStats');
      final snap = await statsRef.get();
      final cur = snap.exists ? Map<String, dynamic>.from(snap.value as Map) : <String, dynamic>{};
      final newXp = ((cur['xp'] ?? 0) as int) + xp;
      final newWins = ((cur['wins'] ?? 0) as int) + (p.rank == 1 ? 1 : 0);
      final newMatches = ((cur['matches'] ?? 0) as int) + 1;
      final curBest = (cur['bestRank'] ?? 999) as int;
      await statsRef.set({
        'xp': newXp,
        'wins': newWins,
        'matches': newMatches,
        'bestRank': p.rank < curBest ? p.rank : curBest,
      });
    }

    await _db.ref('ludoKingMatches/${widget.matchId}').update({'status': 'finished'});

    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(
      builder: (_) => LudoResultScreen(matchId: widget.matchId, uid: widget.hostUid)));
  }

  @override
  Widget build(BuildContext context) {
    return _editView();
  }

  Widget _editView() {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A1A), elevation: 0,
        title: const Text('🏆 Declare Results', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white))),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(16)),
            child: Column(children: [
              const Text('🎮', style: TextStyle(fontSize: 40)),
              const SizedBox(height: 8),
              Text('Room: ${widget.roomCode}', style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              const Text('Who won? Select rank for each player', style: TextStyle(color: Colors.white54, fontSize: 12)),
            ])),
          const SizedBox(height: 16),
          Expanded(child: ListView.builder(
            itemCount: _players.length,
            itemBuilder: (_, i) {
              final p = _players[i];
              final medals = ['', '🥇', '🥈', '🥉', '4️⃣', '5️⃣'];
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: p.rank > 0 ? AppTheme.primary.withOpacity(0.12) : const Color(0xFF1A1A2E),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: p.rank > 0 ? AppTheme.primary : Colors.grey.shade800,
                    width: p.rank > 0 ? 2 : 1)),
                child: Row(children: [
                  Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.3),
                      shape: BoxShape.circle),
                    child: Center(child: Text(p.name[0].toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)))),
                  const SizedBox(width: 12),
                  Expanded(child: Text(p.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white))),
                  if (p.rank > 0)
                    Text(medals[p.rank.clamp(0, 5)], style: const TextStyle(fontSize: 24))
                  else
                    const SizedBox(width: 60),
                  PopupMenuButton<int>(
                    icon: const Icon(Icons.arrow_drop_down_circle_outlined, color: Colors.white54),
                    onSelected: (rank) => _setRank(i, rank),
                    itemBuilder: (_) => [1, 2, 3, 4, 5].map((r) {
                      final taken = _players.any((x) => x.rank == r);
                      return PopupMenuItem<int>(
                        value: r,
                        enabled: !taken,
                        child: Row(children: [
                          Text('${medals[r]}  ', style: const TextStyle(fontSize: 18)),
                          Text('${r}st Place', style: TextStyle(
                            color: taken ? Colors.grey : Colors.white,
                            fontWeight: FontWeight.w700)),
                          if (taken) const Spacer(),
                          if (taken) const Text('(taken)', style: TextStyle(color: Colors.grey, fontSize: 11)),
                        ]));
                    }).toList()),
                ]));
            },
          )),
          AppTheme.gradientButton(
            label: '💾 Save Results & Award XP',
            loading: _saving,
            onTap: _players.any((p) => p.rank > 0) ? _save : null,
            height: 52),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }

  String rankLabel(int r) {
    switch (r) {
      case 1: return 'Champion 🏆';
      case 2: return 'Runner Up 🥈';
      case 3: return 'Second Runner Up 🥉';
      default: return '${r}th Place';
    }
  }
}

class _PlayerResult {
  final String uid;
  final String name;
  int rank;
  _PlayerResult({required this.uid, required this.name, required this.rank});
}
