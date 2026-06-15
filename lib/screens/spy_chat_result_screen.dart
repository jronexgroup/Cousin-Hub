import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../app_theme.dart';
import '../screens/home_screen.dart';
import 'spy_chat_models.dart';
import 'spy_chat_lobby_screen.dart';
import '../services/badge_service.dart';

class SpyChatResultScreen extends StatefulWidget {
  final String roomId, myUid, myName, myPhoto;

  const SpyChatResultScreen({
    super.key,
    required this.roomId,
    required this.myUid,
    required this.myName,
    required this.myPhoto,
  });

  @override
  State<SpyChatResultScreen> createState() => _SpyChatResultScreenState();
}

class _SpyChatResultScreenState extends State<SpyChatResultScreen> {
  final _db = FirebaseDatabase.instance;
  StreamSubscription? _sub;
  bool _loading = true;
  Map<String, dynamic>? _roomData;
  List<Map<String, dynamic>> _clueMessages = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final roomEvent = await _db.ref('spyChatRooms/${widget.roomId}').once();
    if (!roomEvent.snapshot.exists || !mounted) return;
    _roomData = Map<String, dynamic>.from(roomEvent.snapshot.value as Map);

    final clueEvent = await _db.ref('spyChatRooms/${widget.roomId}/clueMessages')
        .orderByChild('timestamp').once();
    final clues = <Map<String, dynamic>>[];
    if (clueEvent.snapshot.exists) {
      (clueEvent.snapshot.value as Map).forEach((k, v) {
        final m = Map<String, dynamic>.from(v as Map);
        m['key'] = k;
        clues.add(m);
      });
      clues.sort((a, b) => ((a['timestamp'] as num?) ?? 0).compareTo((b['timestamp'] as num?) ?? 0));
    }

    if (mounted) {
      final civWon = _roomData?['winner'] as String? == 'civilians';
      final playersMap = _roomData?['players'] as Map? ?? {};
      final winners = playersMap.entries.where((e) {
        final role = (e.value as Map)['role'] as String?;
        return civWon ? role == 'civilian' : role == 'spy';
      });
      for (final e in winners) {
        BadgeService.incrementStat(e.key, 'game');
      }
      setState(() {
        _clueMessages = clues;
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  String? get _winner => _roomData?['winner'] as String?;
  String get _civilianWord => _roomData?['civilianWord'] as String? ?? '???';
  String get _spyWord => _roomData?['spyWord'] as String? ?? '???';
  List<SpyPlayerData> get _players {
    final pm = _roomData?['players'] as Map? ?? {};
    return pm.entries.map((e) =>
      SpyPlayerData.fromMap(Map<String, dynamic>.from(e.value as Map), e.key)).toList();
  }
  Map<String, dynamic> get _votes {
    final v = _roomData?['votes'];
    return v is Map ? Map<String, dynamic>.from(v) : {};
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: const Color(0xFF0A0A1A),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final civWon = _winner == 'civilians';
    final spies = _players.where((p) => p.role == 'spy').toList();
    final civilians = _players.where((p) => p.role == 'civilian').toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A1A), elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text('🕵️ Spy Chat',
          style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: civWon ? [const Color(0xFF1B3A2D), const Color(0xFF0A0A1A)]
                              : [const Color(0xFF3A1B1B), const Color(0xFF0A0A1A)]),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: civWon ? Colors.greenAccent : Colors.redAccent, width: 2)),
            child: Column(children: [
              Text(civWon ? '🕵️ CIVILIAN VICTORY!' : '🕵️ SPY VICTORY!',
                style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w900,
                  color: civWon ? Colors.greenAccent : Colors.redAccent)),
              const SizedBox(height: 16),
              _wordRow('Civilian Word', _civilianWord, Colors.greenAccent),
              const SizedBox(height: 8),
              _wordRow('Spy Word', _spyWord, Colors.redAccent),
            ]),
          ),

          const SizedBox(height: 20),
          const Text('WHO WAS SPY', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.w700, fontSize: 12)),
          const SizedBox(height: 8),
          ...spies.map((p) => _roleCard(p, 'SPY', Colors.redAccent)),
          const SizedBox(height: 12),
          ...civilians.map((p) => _roleCard(p, 'CIVILIAN', Colors.greenAccent)),

          const SizedBox(height: 20),
          const Text('ALL CLUES', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.w700, fontSize: 12)),
          const SizedBox(height: 8),
          if (_clueMessages.isEmpty)
            const Text('No clues submitted', style: TextStyle(color: Colors.white24, fontSize: 12))
          else
            ..._clueMessages.map((m) => Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF1B3A2D),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.greenAccent.withOpacity(0.3))),
              child: Text('🔍 ${m['senderName']}: "${m['text']}"',
                style: const TextStyle(color: Colors.white, fontSize: 13)),
            )),

          const SizedBox(height: 20),
          if (_votes.isNotEmpty) ...[
            const Text('VOTE HISTORY', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.w700, fontSize: 12)),
            const SizedBox(height: 8),
            ..._votes.entries.map((e) {
              final voter = _players.firstWhere((p) => p.uid == e.key, orElse: () =>
                SpyPlayerData(uid: '', name: '?', photo: ''));
              final target = _players.firstWhere((p) => p.uid == (e.value as String), orElse: () =>
                SpyPlayerData(uid: '', name: '?', photo: ''));
              return Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A2E),
                  borderRadius: BorderRadius.circular(8)),
                child: Row(children: [
                  Text('${voter.name}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  const Spacer(),
                  const Icon(Icons.arrow_forward, color: Colors.white24, size: 14),
                  const Spacer(),
                  Text('${target.name}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                ]),
              );
            }),
          ],

          const SizedBox(height: 24),
          AppTheme.gradientButton(
            label: '🕵️ Play Again',
            onTap: _playAgain,
            height: 52),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _goHome,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.white24),
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Back to Home', style: TextStyle(color: Colors.white54))),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  Widget _wordRow(String label, String word, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3))),
      child: Row(children: [
        Text('$label: ', style: const TextStyle(color: Colors.white54, fontSize: 13)),
        Text(word.toUpperCase(), style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 16)),
      ]),
    );
  }

  Widget _roleCard(SpyPlayerData p, String role, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3))),
      child: Row(children: [
        Container(width: 36, height: 36,
          decoration: const BoxDecoration(color: Colors.grey, shape: BoxShape.circle),
          child: p.photo.isNotEmpty
              ? ClipOval(child: Image.network(p.photo, fit: BoxFit.cover))
              : Center(child: Text(p.name[0].toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)))),
        const SizedBox(width: 12),
        Expanded(child: Text(p.name,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(6)),
          child: Text(role, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 10)),
        ),
      ]),
    );
  }

  Future<void> _playAgain() async {
    Navigator.pushReplacement(context, MaterialPageRoute(
      builder: (_) => const SpyChatLobbyScreen()));
  }

  void _goHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()), (_) => false);
  }
}
