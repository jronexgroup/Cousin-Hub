import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app_theme.dart';
import '../services/auth_service.dart';
import 'ludo_king_invite_screen.dart';
import 'ludo_leaderboard_screen.dart';
import 'ludo_match_history_screen.dart';

class LudoKingMatchScreen extends StatefulWidget {
  const LudoKingMatchScreen({super.key});
  @override
  State<LudoKingMatchScreen> createState() => _LudoKingMatchState();
}

class _LudoKingMatchState extends State<LudoKingMatchScreen> {
  final _db = FirebaseDatabase.instance;
  final _uid = AuthService().currentUid ?? '';
  String _name = 'Cousin', _photo = '';
  int _xp = 0, _wins = 0, _matches = 0;
  List<Map<String, dynamic>> _recentMatches = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final p = await AuthService().getProfile(_uid);
    if (p != null && mounted) setState(() {
      _name = p['nickname'] ?? p['name'] ?? 'Cousin';
      _photo = p['photoUrl'] ?? '';
    });
    _loadStats();
    _loadRecent();
  }

  void _loadStats() {
    _db.ref('users/$_uid/ludoKingStats').onValue.listen((e) {
      if (!e.snapshot.exists || !mounted) return;
      final s = Map<String, dynamic>.from(e.snapshot.value as Map);
      setState(() {
        _xp = (s['xp'] ?? 0) as int;
        _wins = (s['wins'] ?? 0) as int;
        _matches = (s['matches'] ?? 0) as int;
      });
    });
  }

  void _loadRecent() {
    _db.ref('ludoKingResults').orderByChild('date').limitToLast(10).onValue.listen((e) {
      if (!e.snapshot.exists || !mounted) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      final list = (e.snapshot.value as Map).entries.map((en) {
        final m = Map<String, dynamic>.from(en.value as Map);
        m['id'] = en.key;
        return m;
      }).toList()..sort((a, b) => ((b['date'] ?? 0) as num).compareTo((a['date'] ?? 0) as num));
      final mine = list.where((m) {
        final pl = m['players'] as Map? ?? {};
        return pl.containsKey(_uid);
      }).toList();
      if (mounted) setState(() { _recentMatches = mine.take(5).toList(); _loading = false; });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A1A), elevation: 0,
        title: const Text('👑 Ludo King', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.leaderboard_rounded, color: Colors.white),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LudoLeaderboardScreen())),
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          // Stats card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AppTheme.mainGradient,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(children: [
              Row(children: [
                Container(
                  width: 50, height: 50,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.2)),
                  child: _photo.isNotEmpty
                    ? ClipOval(child: Image.network(_photo, fit: BoxFit.cover))
                    : Center(child: Text(_name[0].toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900))),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Welcome, $_name 👋', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                  const Text('Ludo King Champion', style: TextStyle(color: Colors.white70, fontSize: 12)),
                ])),
              ]),
              const SizedBox(height: 20),
              Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                _stat('⭐', '$_xp', 'XP'),
                _stat('🏆', '$_wins', 'Wins'),
                _stat('🎮', '$_matches', 'Matches'),
              ]),
            ]),
          ),

          const SizedBox(height: 20),

          // Create Match
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LudoKingInviteScreen())),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent, shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
              ),
              child: Ink(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFF60A5FA)]),
                  borderRadius: BorderRadius.circular(100),
                  boxShadow: [BoxShadow(color: const Color(0xFF7C3AED).withOpacity(0.4), blurRadius: 16)],
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  alignment: Alignment.center,
                  child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text('🎲', style: TextStyle(fontSize: 24)),
                    SizedBox(width: 10),
                    Text('Create New Match', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)),
                  ]),
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Recent Matches
          if (_recentMatches.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('📋 Recent Matches', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white)),
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LudoMatchHistoryScreen())),
                child: const Text('See all', style: TextStyle(color: Colors.white54, fontSize: 13)),
              ),
            ]),
            const SizedBox(height: 10),
            ..._recentMatches.map((m) => _recentMatchTile(m)),
          ],

          if (_loading && _recentMatches.isEmpty)
            const Padding(padding: EdgeInsets.only(top: 40),
              child: Center(child: CircularProgressIndicator(color: Colors.white24))),

          const SizedBox(height: 40),
        ]),
      ),
    );
  }

  Widget _stat(String icon, String value, String label) => Column(children: [
    Text(icon, style: const TextStyle(fontSize: 22)),
    const SizedBox(height: 4),
    Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
    Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
  ]);

  Widget _recentMatchTile(Map<String, dynamic> m) {
    final players = Map<String, dynamic>.from(m['players'] as Map? ?? {});
    final sorted = players.entries.toList()..sort((a, b) => ((a.value['rank'] ?? 0) as int).compareTo((b.value['rank'] ?? 0) as int));
    final winner = sorted.isNotEmpty ? sorted.first.value['name'] ?? 'Unknown' : 'Unknown';
    final myEntry = players[_uid];
    final myRank = myEntry?['rank'] ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFF1A1A2E), borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Text(myRank == 1 ? '🥇' : myRank == 2 ? '🥈' : myRank == 3 ? '🥉' : '🎮', style: const TextStyle(fontSize: 24)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Winner: $winner', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
          Text('Room: ${m['roomCode'] ?? ''}', style: const TextStyle(color: Colors.white38, fontSize: 11)),
        ])),
        Text('+${myEntry?['xpEarned'] ?? 0} XP', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w800, fontSize: 13)),
      ]),
    );
  }
}
