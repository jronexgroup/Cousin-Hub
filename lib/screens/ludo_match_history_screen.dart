import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../app_theme.dart';
import '../services/auth_service.dart';

class LudoMatchHistoryScreen extends StatefulWidget {
  const LudoMatchHistoryScreen({super.key});
  @override
  State<LudoMatchHistoryScreen> createState() => _LudoMatchHistoryState();
}

class _LudoMatchHistoryState extends State<LudoMatchHistoryScreen> {
  final _db = FirebaseDatabase.instance;
  final _uid = AuthService().currentUid ?? '';
  List<Map<String, dynamic>> _matches = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final snap = await _db.ref('ludoKingResults').orderByChild('date').once();
    if (!snap.snapshot.exists || !mounted) return;
    final data = Map<String, dynamic>.from(snap.snapshot.value as Map);
    final list = <Map<String, dynamic>>[];
    for (final e in data.entries) {
      final m = Map<String, dynamic>.from(e.value as Map);
      final players = m['players'] != null ? Map<String, dynamic>.from(m['players'] as Map) : <String, dynamic>{};
      if (players.containsKey(_uid)) {
        m['_id'] = e.key;
        m['_date'] = m['date'] as int? ?? 0;
        list.add(m);
      }
    }
    list.sort((a, b) => (b['_date'] as int).compareTo(a['_date'] as int));
    if (mounted) setState(() { _matches = list; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A1A), elevation: 0,
        title: const Text('📜 Match History', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _matches.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Text('📭', style: TextStyle(fontSize: 64)),
                  const SizedBox(height: 12),
                  const Text('No matches played yet', style: TextStyle(color: Colors.white54, fontSize: 15)),
                ]))
              : ListView.builder(padding: const EdgeInsets.all(14), itemCount: _matches.length, itemBuilder: (_, i) {
                  final m = _matches[i];
                  final players = Map<String, dynamic>.from(m['players'] as Map);
                  final myResult = Map<String, dynamic>.from(players[_uid] as Map);
                  final myRank = (myResult['rank'] as int?) ?? 0;
                  final myXp = (myResult['xpEarned'] as int?) ?? 0;
                  final medals = ['', '🥇', '🥈', '🥉', '4th', '5th'];
                  final date = m['_date'] as int? ?? 0;
                  final dt = DateTime.fromMillisecondsSinceEpoch(date);
                  final dateStr = '${dt.month}/${dt.day}/${dt.year}';

                  final sortedPlayers = players.entries.toList()
                    ..sort((a, b) => ((Map.from(a.value as Map))['rank'] as int? ?? 999)
                        .compareTo((Map.from(b.value as Map))['rank'] as int? ?? 999));

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A2E),
                      borderRadius: BorderRadius.circular(14)),
                    child: Column(children: [
                      Row(children: [
                        Text(medals[myRank.clamp(0, 4)], style: const TextStyle(fontSize: 28)),
                        const SizedBox(width: 10),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Room: ${m['roomCode'] ?? '-'}',
                            style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w700)),
                          Text(dateStr, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                        ])),
                        Text('+$myXp XP', style: const TextStyle(color: Colors.green, fontSize: 18, fontWeight: FontWeight.w900)),
                      ]),
                      const SizedBox(height: 8),
                      const Divider(color: Colors.white12, height: 1),
                      const SizedBox(height: 8),
                      ...sortedPlayers.map((en) {
                        final p = Map<String, dynamic>.from(en.value as Map);
                        final rank = (p['rank'] as int?) ?? 0;
                        final xp = (p['xpEarned'] as int?) ?? 0;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(children: [
                            SizedBox(width: 24, child: Text(medals[rank.clamp(0, 4)], style: const TextStyle(fontSize: 14))),
                            const SizedBox(width: 8),
                            Expanded(child: Text(p['name']?.toString() ?? 'Cousin',
                              style: TextStyle(
                                fontSize: 13,
                                color: en.key == _uid ? Colors.white : Colors.white54,
                                fontWeight: en.key == _uid ? FontWeight.w700 : FontWeight.w400))),
                            Text('+$xp XP', style: TextStyle(fontSize: 11, color: Colors.green.shade300)),
                          ]));
                      }),
                    ]));
                }),
    );
  }
}
