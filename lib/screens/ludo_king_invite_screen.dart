import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app_theme.dart';
import '../services/auth_service.dart';
import '../services/cache_service.dart';
import '../services/notification_service.dart';
import 'ludo_match_lobby_screen.dart';

class LudoKingInviteScreen extends StatefulWidget {
  const LudoKingInviteScreen({super.key});
  @override
  State<LudoKingInviteScreen> createState() => _LudoKingInviteState();
}

class _LudoKingInviteState extends State<LudoKingInviteScreen> {
  final _db = FirebaseDatabase.instance;
  List<Map<String, dynamic>> _cousins = [];
  final List<String> _sel = [];
  bool _loading = false;
  bool _roomCreated = false;
  bool _listeningForCode = false;
  String _myUid = '', _myName = '', _myPhoto = '';
  String _roomCode = '', _matchId = '', _deepLink = '';
  StreamSubscription<DatabaseEvent>? _codeSub;

  @override
  void dispose() {
    _codeSub?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  Widget build(BuildContext context) {
    return _roomCreated ? _roomCreatedView() : _inviteView();
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

  void _toggle(String uid) => setState(() {
    if (_sel.contains(uid)) _sel.remove(uid);
    else if (_sel.length < 4) _sel.add(uid);
  });

  Future<void> _createMatch() async {
    if (_sel.isEmpty) return;
    setState(() => _loading = true);

    _matchId = 'ludoKing_${DateTime.now().millisecondsSinceEpoch}';

    final all = [_myUid, ..._sel];
    final playersMap = <String, dynamic>{};
    for (final uid in all) {
      final isMe = uid == _myUid;
      final cached = isMe ? null : CacheService.loadAllUsers();
      final d = isMe ? null : cached?[uid];
      final name = isMe
          ? _myName
          : (d != null ? (Map<String, dynamic>.from(d as Map)['nickname'] ?? Map.from(d)['name'] ?? 'Cousin') : 'Cousin');
      playersMap[uid] = {
        'name': name,
        'status': isMe ? 'joined' : 'pending',
        'joinedAt': isMe ? ServerValue.timestamp : 0,
      };
    }

    // Match created without roomCode/deepLink — the bot will write them
    await _db.ref('ludoKingMatches/$_matchId').set({
      'hostUid': _myUid,
      'hostName': _myName,
      'status': 'waiting',
      'players': playersMap,
      'createdAt': ServerValue.timestamp,
    });

    for (final uid in _sel) {
      await _db.ref('ludoKingInvites/$uid/$_matchId').set({
        'matchId': _matchId,
        'hostName': _myName,
        'hostPhoto': _myPhoto,
        'timestamp': ServerValue.timestamp,
      });
      final ts = await _db.ref('users/$uid/fcmToken').get();
      if (ts.exists) {
        await _db.ref('notifications').push().set({
          'toToken': ts.value,
          'title': '🎮 $_myName invited you to Ludo King!',
          'body': 'Bot is setting up the room — join now!',
          'data': {'matchId': _matchId},
          'sent': false,
          'timestamp': ServerValue.timestamp,
        });
      }
    }

    await _db.ref('chats/main').push().set({
      'text': '🎮 Ludo King Match Started!\n\nHost: $_myName\nPlayers: ${all.length}\n\nBot is creating the room — join the lobby!',
      'type': 'ludo_king_invite',
      'matchId': _matchId,
      'senderUid': _myUid,
      'senderName': _myName,
      'senderPhoto': _myPhoto,
      'timestamp': ServerValue.timestamp,
      'seenBy': {},
      'delivered': true,
    });

    setState(() {
      _loading = false;
      _roomCreated = true;
      _listenForBotCode();
    });
  }

  void _listenForBotCode() {
    if (_listeningForCode || _matchId.isEmpty) return;
    _listeningForCode = true;
    _codeSub = _db.ref('ludoKingMatches/$_matchId').onValue.listen((e) {
      if (!e.snapshot.exists || !mounted) return;
      final data = Map<String, dynamic>.from(e.snapshot.value as Map);
      if (data['roomCode'] != null && data['deepLink'] != null) {
        setState(() {
          _roomCode = data['roomCode'] as String? ?? '';
          _deepLink = data['deepLink'] as String? ?? '';
        });
      }
    });
  }

  Widget _inviteView() {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A1A), elevation: 0,
        title: const Text('👑 Create Ludo King Match', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white))),
      body: Column(children: [
        Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF7C3AED).withOpacity(0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF7C3AED).withOpacity(0.4))),
          child: const Text(
            'Select cousins to invite. They will receive a notification with a link to join your Ludo King match.',
            style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.5))),

        if (_sel.isNotEmpty) Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
          child: Row(children: [
            ...[_myUid, ..._sel].take(5).map((uid) {
              final isMe = uid == _myUid;
              final c = isMe ? null : _cousins.firstWhere((x) => x['uid'] == uid, orElse: () => {});
              final photo = isMe ? _myPhoto : (c?['photoUrl'] ?? '');
              final name = isMe ? _myName : (c?['nickname'] ?? c?['name'] ?? 'Cousin');
              return Container(
                width: 36, height: 36,
                margin: const EdgeInsets.only(right: 4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppTheme.mainGradient,
                  border: Border.all(color: Colors.white, width: 2)),
                child: photo.isNotEmpty
                    ? ClipOval(child: Image.network(photo, fit: BoxFit.cover))
                    : Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14))));
            }),
            const SizedBox(width: 8),
            Text('${_sel.length + 1} players', style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w700)),
          ])),

        Expanded(child: _cousins.isEmpty
            ? const Center(child: CircularProgressIndicator(color: Colors.purple))
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _cousins.length,
                itemBuilder: (_, i) {
                  final c = _cousins[i];
                  final uid = c['uid'] as String;
                  final sel = _sel.contains(uid);
                  final photo = c['photoUrl'] ?? '';
                  final name = c['nickname'] ?? c['name'] ?? 'Cousin';
                  return GestureDetector(
                    onTap: () => _toggle(uid),
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
                        Expanded(child: Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white))),
                        Icon(sel ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                          color: sel ? AppTheme.primary : Colors.grey, size: 24),
                      ])));
                })),

        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
          color: const Color(0xFF0A0A1A),
          child: SafeArea(child: AppTheme.gradientButton(
            label: _sel.isEmpty ? '⬆️ Select cousins to invite'
                : '🎮 Send Invites & Start Match (${_sel.length + 1}P)',
            loading: _loading,
            onTap: _sel.isEmpty ? null : _createMatch,
            height: 52))),
      ]),
    );
  }

  // ── Match Created View (waiting for bot or showing room code) ──
  Widget _roomCreatedView() {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A1A), elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst)),
        title: const Text('🎮 Match Created!', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white))),
      body: SafeArea(child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          const Spacer(flex: 2),
          Text(_roomCode.isNotEmpty ? '✅' : '🤖', style: const TextStyle(fontSize: 80)),
          const SizedBox(height: 16),
          Text(_roomCode.isNotEmpty ? 'Room Created!' : 'Bot is setting up...',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white)),
          const SizedBox(height: 8),
          Text(_roomCode.isNotEmpty
              ? 'Invitations sent via notification & chat'
              : 'The bot is creating a room in Ludo King on the server',
            style: const TextStyle(color: Colors.white54, fontSize: 13)),
          const SizedBox(height: 24),

          if (_roomCode.isEmpty)
            const Padding(padding: EdgeInsets.symmetric(vertical: 20),
              child: SizedBox(width: 40, height: 40,
                child: CircularProgressIndicator(color: Color(0xFF7C3AED)))),

          if (_roomCode.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: AppTheme.mainGradient,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: AppTheme.primary.withOpacity(0.4), blurRadius: 20)],
              ),
              child: Column(children: [
                const Text('ROOM CODE', style: TextStyle(color: Colors.white70, fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(_roomCode, style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 8)),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: _roomCode));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('✅ Room code copied!'), backgroundColor: Colors.green, duration: Duration(seconds: 1)));
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(100)),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.copy_rounded, color: Colors.white, size: 14),
                      SizedBox(width: 4),
                      Text('Copy', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                    ])),
                ),
              ])),

            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: const Color(0xFF1A1A2E), borderRadius: BorderRadius.circular(16)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('How to join:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
                const SizedBox(height: 10),
                _step('1️⃣', 'Tap "Join Room" button below'),
                _step('2️⃣', 'Ludo King app will open automatically'),
                _step('3️⃣', 'Room will auto-join (no code entry needed)'),
                _step('4️⃣', 'Wait for other cousins to join'),
                _step('5️⃣', 'Match starts in Ludo King!'),
              ])),

            const SizedBox(height: 24),

            AppTheme.gradientButton(
              label: '🎮 Join Room Now',
              onTap: () {
                final uri = Uri.parse(_deepLink);
                if (uri.isAbsolute) launchUrl(uri, mode: LaunchMode.externalApplication);
              },
              height: 54),

            const SizedBox(height: 10),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _deepLink));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('✅ Link copied! Share with cousins'), backgroundColor: Colors.green, duration: Duration(seconds: 2)));
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF7C3AED), width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                  padding: const EdgeInsets.symmetric(vertical: 14)),
                child: Text('📋 Copy Invite Link',
                  style: const TextStyle(color: Color(0xFF7C3AED), fontWeight: FontWeight.w800)))),

            const SizedBox(height: 16),
          ],

          ElevatedButton(
            onPressed: () => Navigator.pushReplacement(context,
              MaterialPageRoute(builder: (_) => LudoMatchLobbyScreen(matchId: _matchId, isHost: true))),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A1A2E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24)),
            child: const Text('👥 Match Lobby →', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),

          const Spacer(flex: 2),
        ]),
      )),
    );
  }

  Widget _step(String e, String t) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [Text(e, style: const TextStyle(fontSize: 14)), const SizedBox(width: 8),
      Expanded(child: Text(t, style: const TextStyle(color: Colors.white70, fontSize: 13)))]));
}
