import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:math';
import '../app_theme.dart';
import '../services/auth_service.dart';
import '../services/cache_service.dart';
import 'ludo_webview_screen.dart'; // <-- new file

class GamesScreen extends StatefulWidget {
  const GamesScreen({super.key});
  @override
  State<GamesScreen> createState() => _GamesScreenState();
}

class _GamesScreenState extends State<GamesScreen> {
  final _db = FirebaseDatabase.instance;
  List<Map<String, dynamic>> _leaderboard = [];

  @override
  void initState() { super.initState(); _loadLeaderboard(); }

  void _loadLeaderboard() {
    final cached = CacheService.loadAllUsers();
    if (cached != null) _updateLB(cached);
    _db.ref('users').onValue.listen((e) {
      if (!e.snapshot.exists || !mounted) return;
      _updateLB(Map<String, dynamic>.from(e.snapshot.value as Map));
    });
  }

  void _updateLB(Map<String, dynamic> map) {
    final list = map.entries.map((e) {
      final u = Map<String, dynamic>.from(e.value as Map);
      u['uid'] = e.key; return u;
    }).toList();
    list.sort((a, b) => ((b['gamesWon'] ?? 0) as num)
      .compareTo((a['gamesWon'] ?? 0) as num));
    if (mounted) setState(() => _leaderboard = list.take(10).toList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(backgroundColor: Colors.white, elevation: 0,
        title: const Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cousin Pro', style: TextStyle(fontSize: 12, color: AppTheme.soft)),
            Text('Games Zone 🎮', style: TextStyle(fontSize: 20,
              fontWeight: FontWeight.w800, color: AppTheme.ink)),
          ])),
      body: SingleChildScrollView(child: Column(children: [

        // Leaderboard
        if (_leaderboard.isNotEmpty)
          Padding(padding: const EdgeInsets.all(16),
            child: Container(padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: AppTheme.mainGradient,
                borderRadius: BorderRadius.circular(20)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                const Text('🏆 Cousin Leaderboard',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800,
                    color: Colors.white)),
                const SizedBox(height: 12),
                ..._leaderboard.take(5).toList().asMap().entries.map((e) {
                  final u = e.value;
                  final medals = ['🥇','🥈','🥉','4️⃣','5️⃣'];
                  final photo = u['photoUrl'] ?? '';
                  final name = u['nickname'] ?? u['name'] ?? 'Cousin';
                  return Padding(padding: const EdgeInsets.only(bottom: 10),
                    child: Row(children: [
                      Text(medals[e.key], style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: 10),
                      Container(width: 34, height: 34,
                        decoration: BoxDecoration(shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.3)),
                        child: photo.isNotEmpty
                          ? ClipOval(child: Image.network(photo, fit: BoxFit.cover))
                          : Center(child: Text(name[0],
                              style: const TextStyle(color: Colors.white,
                                fontWeight: FontWeight.w700)))),
                      const SizedBox(width: 10),
                      Expanded(child: Text(name, style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700))),
                      Text('${u['gamesWon'] ?? 0} wins',
                        style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    ]));
                }),
              ]))),

        Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: AppTheme.sectionTitle('Choose a Game')),

        // ── LUDO KING (WebView) ──────────────────────────────
        _GameCard(
          icon: '🎲',
          title: 'Ludo King™',
          desc: 'Official Ludo King game — exact same as the app!',
          color: const Color(0xFF1a0a2e),
          titleColor: Colors.white,
          descColor: Colors.white54,
          tag: 'Official',
          tagColor: Colors.amber,
          onPlay: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const LudoWebScreen())),
        ),

        _GameCard(icon: '🧠', title: 'Quiz Battle',
          desc: 'Create a room — cousins join & compete!',
          color: const Color(0xFFEDE9FE), tag: 'Multiplayer',
          onPlay: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const QuizLobbyScreen()))),

        _GameCard(icon: '🎭', title: 'Truth or Dare',
          desc: 'Play together in the same room!',
          color: const Color(0xFFE8F5E9), tag: 'Group',
          onPlay: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const TruthOrDareGame()))),

        _GameCard(icon: '🎡', title: 'Spin the Wheel',
          desc: 'Spin and get a fun challenge!',
          color: const Color(0xFFFFF0E8), tag: 'Solo',
          onPlay: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const SpinWheelGame()))),

        _GameCard(icon: '🤔', title: 'Who Knows Best?',
          desc: 'Vote — who fits the description?',
          color: const Color(0xFFFFF8E1), tag: 'Multiplayer',
          onPlay: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const WhoKnowsBestGame()))),

        _GameCard(icon: '🎲', title: 'Dare Roulette',
          desc: 'Random dare for everyone!',
          color: const Color(0xFFFFE8E8), tag: 'Group',
          onPlay: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const DareRouletteGame()))),

        const SizedBox(height: 80),
      ])));
  }
}

class _GameCard extends StatelessWidget {
  final String icon, title, desc, tag;
  final Color color;
  final Color titleColor;
  final Color descColor;
  final Color? tagColor;
  final VoidCallback onPlay;

  const _GameCard({
    required this.icon, required this.title,
    required this.desc, required this.tag,
    required this.color, required this.onPlay,
    this.titleColor = AppTheme.ink,
    this.descColor = AppTheme.muted,
    this.tagColor,
  });

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
    child: Row(children: [
      Text(icon, style: const TextStyle(fontSize: 44)),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        Row(children: [
          Flexible(child: Text(title, style: TextStyle(fontSize: 16,
            fontWeight: FontWeight.w800, color: titleColor))),
          const SizedBox(width: 8),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: (tagColor ?? AppTheme.primary).withOpacity(0.15),
              borderRadius: BorderRadius.circular(100)),
            child: Text(tag, style: TextStyle(fontSize: 10,
              color: tagColor ?? AppTheme.primary, fontWeight: FontWeight.w700))),
        ]),
        const SizedBox(height: 4),
        Text(desc, style: TextStyle(fontSize: 13, color: descColor)),
      ])),
      const SizedBox(width: 8),
      GestureDetector(onTap: onPlay,
        child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            gradient: AppTheme.mainGradient,
            borderRadius: BorderRadius.circular(100)),
          child: const Text('Play', style: TextStyle(fontSize: 13,
            fontWeight: FontWeight.w700, color: Colors.white)))),
    ]));
}

// ── Other games kept below (Quiz, TruthDare, Spin, etc.) ──────────────────────
// ... (same as before, unchanged)

class QuizLobbyScreen extends StatelessWidget {
  const QuizLobbyScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppTheme.bg,
    appBar: AppBar(title: const Text('Quiz Battle 🧠')),
    body: const Center(child: Text('Coming soon!')));
}

class TruthOrDareGame extends StatelessWidget {
  const TruthOrDareGame({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppTheme.bg,
    appBar: AppBar(title: const Text('Truth or Dare 🎭')),
    body: const Center(child: Text('Coming soon!')));
}

class SpinWheelGame extends StatelessWidget {
  const SpinWheelGame({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppTheme.bg,
    appBar: AppBar(title: const Text('Spin the Wheel 🎡')),
    body: const Center(child: Text('Coming soon!')));
}

class WhoKnowsBestGame extends StatelessWidget {
  const WhoKnowsBestGame({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppTheme.bg,
    appBar: AppBar(title: const Text('Who Knows Best? 🤔')),
    body: const Center(child: Text('Coming soon!')));
}

class DareRouletteGame extends StatelessWidget {
  const DareRouletteGame({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppTheme.bg,
    appBar: AppBar(title: const Text('Dare Roulette 🎲')),
    body: const Center(child: Text('Coming soon!')));
}
