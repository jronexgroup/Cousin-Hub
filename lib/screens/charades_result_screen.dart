import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../app_theme.dart';
import '../services/auth_service.dart';
import '../services/badge_service.dart';

class CharadesResultScreen extends StatefulWidget {
  final String roomId;
  const CharadesResultScreen({super.key, required this.roomId});
  @override
  State<CharadesResultScreen> createState() => _CharadesResultScreenState();
}

class _CharadesResultScreenState extends State<CharadesResultScreen> {
  final _db = FirebaseDatabase.instance;
  Map<String, dynamic> _room = {};

  @override
  void initState() {
    super.initState();
    _db.ref('charadesRooms/${widget.roomId}').once().then((s) {
      if (s.exists && mounted) setState(() => _room = Map<String, dynamic>.from(s.value as Map));
    });
    BadgeService.incrementStat(AuthService().currentUid!, 'games');
  }

  String get _winnerName {
    final scores = _scoreEntries;
    if (scores.isEmpty) return 'No one';
    return scores.first['name'] as String;
  }

  List<Map<String, dynamic>> get _scoreEntries {
    final scores = (_room['scores'] as Map?) ?? {};
    final players = (_room['players'] as Map?) ?? {};
    return scores.entries.map((e) {
      final p = players[e.key] as Map? ?? {};
      return {'uid': e.key, 'name': p['name'] ?? '?', 'score': (e.value as num).toInt()};
    }).toList()..sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: AppTheme.ink),
          onPressed: () => Navigator.pop(context)),
        title: const Text('Game Over', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.ink)),
      ),
      body: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(children: [
        const SizedBox(height: 20),
        const Text('🎭', style: TextStyle(fontSize: 72)),
        const SizedBox(height: 12),
        Text(_winnerName, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppTheme.ink)),
        const Text('wins!', style: TextStyle(fontSize: 16, color: AppTheme.muted)),
        const SizedBox(height: 32),
        Container(padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: Column(children: [
            const Text('Final Scores', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppTheme.ink)),
            const SizedBox(height: 12),
            ..._scoreEntries.asMap().entries.map((e) {
              final i = e.key;
              final s = e.value;
              return Padding(padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(children: [
                  SizedBox(width: 30, child: Text(i == 0 ? '🥇' : i == 1 ? '🥈' : i == 2 ? '🥉' : '${i+1}.',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.ink))),
                  Expanded(child: Text(s['name'] as String, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.ink))),
                  Text('${s['score']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppTheme.primary)),
                ]));
            }),
          ])),
        const SizedBox(height: 24),
        AppTheme.gradientButton(label: '🔄 Play Again',
          onTap: () { Navigator.pop(context); Navigator.pop(context); }, height: 48),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: () => Navigator.pop(context),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.muted, side: const BorderSide(color: Color(0xFFE8D9C5)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 32)),
          child: const Text('🏠 Leave', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ])),
    );
  }
}
