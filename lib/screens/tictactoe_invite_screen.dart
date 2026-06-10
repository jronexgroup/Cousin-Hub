import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../app_theme.dart';
import '../services/auth_service.dart';
import '../services/cache_service.dart';
import 'home_screen.dart';
import 'tictactoe_game_screen.dart';

class TicTacToeInviteScreen extends StatefulWidget {
  const TicTacToeInviteScreen({super.key});
  @override
  State<TicTacToeInviteScreen> createState() => _TicTacToeInviteState();
}

class _TicTacToeInviteState extends State<TicTacToeInviteScreen> {
  final _db = FirebaseDatabase.instance;
  List<Map<String, dynamic>> _cousins = [];
  bool _loading = false;
  String _myUid = '', _myName = '', _myPhoto = '';
  String? _selectedUid;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _myUid = AuthService().currentUid ?? '';
    final p = await AuthService().getProfile(_myUid);
    if (p != null && mounted) setState(() {
      _myName = p['nickname'] ?? p['name'] ?? 'Cousin';
      _myPhoto = p['photoUrl'] ?? '';
    });
    final c = CacheService.loadAllUsers();
    if (c != null) {
      final list = c.entries.where((e) => e.key != _myUid).map((e) {
        final u = Map<String, dynamic>.from(e.value as Map); u['uid'] = e.key; return u;
      }).toList()..sort((a, b) => (a['name'] ?? '').compareTo(b['name'] ?? ''));
      if (mounted) setState(() => _cousins = list);
    }
  }

  Future<void> _createMatch() async {
    if (_selectedUid == null) return;
    setState(() => _loading = true);

    final matchId = 'ttt_${DateTime.now().millisecondsSinceEpoch}';
    final guest = _cousins.firstWhere((c) => c['uid'] == _selectedUid);
    final guestName = guest['nickname'] ?? guest['name'] ?? 'Cousin';
    final guestPhoto = guest['photoUrl'] ?? '';

    await _db.ref('ticTacToeMatches/$matchId').set({
      'hostUid': _myUid,
      'hostName': _myName,
      'hostPhoto': _myPhoto,
      'guestUid': _selectedUid,
      'guestName': guestName,
      'guestPhoto': guestPhoto,
      'status': 'waiting',
      'board': [0, 0, 0, 0, 0, 0, 0, 0, 0],
      'currentTurn': 1,
      'winner': 0,
      'createdAt': ServerValue.timestamp,
      'lastMoveAt': ServerValue.timestamp,
    });

    await _db.ref('ticTacToeInvites/$_selectedUid/$matchId').set({
      'matchId': matchId,
      'hostName': _myName,
      'hostPhoto': _myPhoto,
      'timestamp': ServerValue.timestamp,
    });

    final ts = await _db.ref('users/$_selectedUid/fcmToken').get();
    if (ts.exists) {
      await _db.ref('notifications').push().set({
        'toToken': ts.value,
        'title': '❌ $_myName challenged you to Tic Tac Toe!',
        'body': 'Tap to accept the challenge.',
        'sent': false,
        'timestamp': ServerValue.timestamp,
      });
    }

    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(
      builder: (_) => TicTacToeGameScreen(
        matchId: matchId,
        myUid: _myUid,
        player: 1,
        opponentName: guestName,
        opponentPhoto: guestPhoto,
        isHost: true,
      )));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A1A), elevation: 0,
        title: const Text('❌ Tic Tac Toe',
          style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white))),
      body: Column(children: [
        Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.primary.withOpacity(0.4))),
          child: const Text(
            'Pick a cousin to challenge. They will receive a notification to join.',
            style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.5))),

        Expanded(child: _cousins.isEmpty
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF7C3AED)))
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _cousins.length,
                itemBuilder: (_, i) {
                  final c = _cousins[i];
                  final uid = c['uid'] as String;
                  final sel = _selectedUid == uid;
                  final photo = c['photoUrl'] ?? '';
                  final name = c['nickname'] ?? c['name'] ?? 'Cousin';
                  return GestureDetector(
                    onTap: () => setState(() => _selectedUid = sel ? null : uid),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: sel ? AppTheme.primary.withOpacity(0.15) : const Color(0xFF1A1A2E),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: sel ? AppTheme.primary : Colors.grey.shade800, width: sel ? 2 : 1)),
                      child: Row(children: [
                        Container(
                          width: 42, height: 42,
                          decoration: BoxDecoration(
                            gradient: sel ? AppTheme.mainGradient : null,
                            color: sel ? null : Colors.grey.shade700,
                            shape: BoxShape.circle),
                          child: photo.isNotEmpty
                              ? ClipOval(child: Image.network(photo, fit: BoxFit.cover))
                              : Center(child: Text(name[0].toUpperCase(),
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)))),
                        const SizedBox(width: 12),
                        Expanded(child: Text(name,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white))),
                        Icon(sel ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                          color: sel ? AppTheme.primary : Colors.grey, size: 24),
                      ])));
                })),

        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
          color: const Color(0xFF0A0A1A),
          child: SafeArea(child: AppTheme.gradientButton(
            label: _selectedUid == null
                ? '👆 Pick a cousin'
                : '❌ Challenge to Tic Tac Toe',
            loading: _loading,
            onTap: _selectedUid == null ? null : _createMatch,
            height: 52))),
      ]),
    );
  }
}
