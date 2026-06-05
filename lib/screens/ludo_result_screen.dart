import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../app_theme.dart';
import 'home_screen.dart';

class LudoResultScreen extends StatefulWidget {
  final String matchId;
  final String uid;
  const LudoResultScreen({super.key, required this.matchId, required this.uid});
  @override
  State<LudoResultScreen> createState() => _LudoResultScreenState();
}

class _LudoResultScreenState extends State<LudoResultScreen> {
  final _db = FirebaseDatabase.instance;
  Map<String, dynamic> _results = {};
  bool _loading = true;

  static const _xpForRank = [0, 100, 75, 50, 25, 10];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final event = await _db.ref('ludoKingResults/${widget.matchId}').once();
      if (!event.snapshot.exists || !mounted) return;
      final val = event.snapshot.value;
      if (val != null) {
        setState(() {
          _results = Map<String, dynamic>.from(val as Map);
          _loading = false;
        });
      } else if (mounted) {
        setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _goHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final playersData = _results['players'] as Map<String, dynamic>? ?? {};
    final players = playersData.entries.map((e) {
      final d = Map<String, dynamic>.from(e.value as Map);
      return _PlayerInfo(uid: e.key, name: d['name']?.toString() ?? 'Cousin', rank: d['rank'] as int? ?? 0, xp: d['xpEarned'] as int? ?? 0);
    }).toList()..sort((a, b) => a.rank.compareTo(b.rank));

    int myRank = 0;
    for (final p in players) {
      if (p.uid == widget.uid) { myRank = p.rank; break; }
    }
    final medals = ['', '🥇', '🥈', '🥉', '4️⃣', '5️⃣'];

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A1A), elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: _goHome),
        title: const Text('🏆 Match Results', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white))),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF7C3AED)))
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                const Spacer(flex: 1),

                // My rank highlight
                if (myRank > 0)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: myRank == 1
                          ? const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFFA500)])
                          : const LinearGradient(colors: [Color(0xFF1A1A3E), Color(0xFF2D1B69)]),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: myRank == 1
                          ? [BoxShadow(color: const Color(0xFFFFD700).withOpacity(0.4), blurRadius: 20)]
                          : null),
                    child: Column(children: [
                      Text(medals[myRank.clamp(0, 5)], style: const TextStyle(fontSize: 56)),
                      const SizedBox(height: 8),
                      Text('You placed #$myRank!',
                        style: TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w900,
                          color: myRank == 1 ? Colors.black : Colors.white)),
                      if (myRank > 0 && myRank < _xpForRank.length)
                        Text('+${_xpForRank[myRank]} XP',
                          style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800,
                            color: myRank == 1 ? Colors.black87 : Colors.green)),
                    ])),
                const SizedBox(height: 24),
                const Text('Standings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white54)),
                const SizedBox(height: 10),

                // All players
                Expanded(child: ListView(children: [
                  ...players.where((p) => p.rank > 0).map((p) {
                    final isMe = p.uid == widget.uid;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isMe ? AppTheme.primary.withOpacity(0.15) : const Color(0xFF1A1A2E),
                        borderRadius: BorderRadius.circular(14),
                        border: isMe ? Border.all(color: AppTheme.primary, width: 2) : null),
                      child: Row(children: [
                        Text(medals[p.rank.clamp(0, 5)], style: const TextStyle(fontSize: 28)),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${p.name}${isMe ? ' (You)' : ''}',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
                          Text(_rankLabel(p.rank),
                            style: const TextStyle(color: Colors.white54, fontSize: 11)),
                        ])),
                        Text('+${p.xp} XP',
                          style: const TextStyle(color: Colors.green, fontSize: 15, fontWeight: FontWeight.w900)),
                      ]));
                  }),
                ])),

                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: AppTheme.gradientButton(
                    label: '🏠 Back to Home',
                    onTap: _goHome,
                    height: 52),
                ),
                const Spacer(flex: 1),
              ]),
            ),
    );
  }

  String _rankLabel(int r) {
    switch (r) {
      case 1: return 'Champion 🏆';
      case 2: return 'Runner Up 🥈';
      case 3: return 'Second Runner Up 🥉';
      default: return '${r}th Place';
    }
  }
}

class _PlayerInfo {
  final String uid;
  final String name;
  final int rank;
  final int xp;
  _PlayerInfo({required this.uid, required this.name, required this.rank, required this.xp});
}
