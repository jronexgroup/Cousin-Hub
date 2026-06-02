import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../app_theme.dart';

class LudoLeaderboardScreen extends StatefulWidget {
  const LudoLeaderboardScreen({super.key});
  @override
  State<LudoLeaderboardScreen> createState() => _LudoLeaderboardState();
}

class _LudoLeaderboardState extends State<LudoLeaderboardScreen> {
  final _db = FirebaseDatabase.instance;
  List<_LeaderEntry> _entries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final snap = await _db.ref('users').once();
    if (!snap.snapshot.exists || !mounted) return;
    final data = Map<String, dynamic>.from(snap.snapshot.value as Map);
    final list = <_LeaderEntry>[];
    for (final e in data.entries) {
      final user = e.value is Map ? Map<String, dynamic>.from(e.value as Map) : <String, dynamic>{};
      final stats = user['ludoKingStats'] != null
          ? Map<String, dynamic>.from(user['ludoKingStats'] as Map)
          : <String, dynamic>{};
      if (stats.containsKey('xp') && (stats['xp'] as int) > 0) {
        list.add(_LeaderEntry(
          uid: e.key,
          name: user['name']?.toString() ?? 'Cousin',
          xp: (stats['xp'] as int?) ?? 0,
          wins: (stats['wins'] as int?) ?? 0,
          matches: (stats['matches'] as int?) ?? 0,
          bestRank: (stats['bestRank'] as int?) ?? 999,
        ));
      }
    }
    list.sort((a, b) => b.xp.compareTo(a.xp));
    if (mounted) setState(() { _entries = list; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A1A), elevation: 0,
        title: const Text('🏆 Leaderboard', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _entries.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Text('🎲', style: TextStyle(fontSize: 64)),
                  const SizedBox(height: 12),
                  const Text('No matches played yet', style: TextStyle(color: Colors.white54, fontSize: 15)),
                  const SizedBox(height: 4),
                  const Text('Win your first match to appear here!', style: TextStyle(color: Colors.grey, fontSize: 12)),
                ]))
              : ListView.builder(padding: const EdgeInsets.all(14), itemCount: _entries.length, itemBuilder: (_, i) {
                  final e = _entries[i];
                  final medal = i == 0 ? '🥇' : i == 1 ? '🥈' : i == 2 ? '🥉' : '${i + 1}.';
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: i < 3 ? AppTheme.primary.withOpacity(0.1 + (0.05 * (3 - i))) : const Color(0xFF1A1A2E),
                      borderRadius: BorderRadius.circular(14),
                      border: i < 3 ? Border.all(color: AppTheme.primary.withOpacity(0.4), width: 1.5) : null),
                    child: Row(children: [
                      Text(medal, style: const TextStyle(fontSize: 26)),
                      const SizedBox(width: 12),
                      Container(
                        width: 42, height: 42,
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.3),
                          shape: BoxShape.circle),
                        child: Center(child: Text(e.name[0].toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)))),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(e.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                        Text('${e.wins}W · ${e.matches}M · Best: ${e.bestRank == 999 ? "-" : "${e.bestRank}st"}',
                          style: const TextStyle(color: Colors.white54, fontSize: 11)),
                      ])),
                      Text('${e.xp} XP', style: const TextStyle(color: Colors.green, fontSize: 18, fontWeight: FontWeight.w900)),
                    ]));
                }),
    );
  }
}

class _LeaderEntry {
  final String uid;
  final String name;
  final int xp;
  final int wins;
  final int matches;
  final int bestRank;
  _LeaderEntry({required this.uid, required this.name, required this.xp, required this.wins, required this.matches, required this.bestRank});
}
