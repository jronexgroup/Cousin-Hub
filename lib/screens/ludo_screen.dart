import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:math';
import 'dart:async';
import '../app_theme.dart';
import '../services/auth_service.dart';
import '../services/cache_service.dart';

// ══════════════════════════════════════════════════════════
// LUDO MENU — Choose mode
// ══════════════════════════════════════════════════════════
class LudoMenuScreen extends StatelessWidget {
  const LudoMenuScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A1A), elevation: 0,
        title: const Text('🎲 Ludo', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white))),
      body: Padding(padding: const EdgeInsets.all(20), child: Column(
        mainAxisAlignment: MainAxisAlignment.center, children: [
        const Text('🎲', style: TextStyle(fontSize: 80)),
        const SizedBox(height: 12),
        const Text('Choose Mode', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
        const SizedBox(height: 6),
        const Text('Invite cousins — then play together!', style: TextStyle(color: Colors.white54)),
        const SizedBox(height: 36),

        // Option 1 — Ludo King WebView
        _ModeCard(
          emoji: '👑', title: 'Ludo King™ Official',
          desc: 'Invitation পাঠানোর পর সবাই Ludo King এ join করবে Room Code দিয়ে',
          tags: const ['✅ Official', '✅ Room code auto sent', '✅ Best quality'],
          color: const Color(0xFF7C3AED),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LudoInviteScreen(mode: 'webview'))),
        ),
        const SizedBox(height: 14),

        // Option 2 — In-app Firebase
        _ModeCard(
          emoji: '🎲', title: 'Cousin Hub Ludo',
          desc: 'Invitation পাঠানোর পর সবাই সরাসরি app এর ভেতরে game এ যাবে',
          tags: const ['✅ In-app', '✅ Real-time', '✅ No extra app needed'],
          color: const Color(0xFF43A047),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LudoInviteScreen(mode: 'firebase'))),
        ),
        const Spacer(),
        const Text('উভয় mode এ invitation → notification → auto join',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white24, fontSize: 11)),
        const SizedBox(height: 16),
      ])),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final String emoji, title, desc;
  final List<String> tags;
  final Color color;
  final VoidCallback onTap;
  const _ModeCard({required this.emoji, required this.title, required this.desc,
    required this.tags, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap,
    child: Container(width: double.infinity, padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5), width: 1.5)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(emoji, style: const TextStyle(fontSize: 30)),
          const SizedBox(width: 12),
          Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white))),
          Icon(Icons.arrow_forward_ios_rounded, color: color, size: 16),
        ]),
        const SizedBox(height: 8),
        Text(desc, style: const TextStyle(color: Colors.white60, fontSize: 12, height: 1.4)),
        const SizedBox(height: 10),
        Wrap(spacing: 6, runSpacing: 4, children: tags.map((t) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(100)),
          child: Text(t, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)))).toList()),
      ])));
}

// ══════════════════════════════════════════════════════════
// INVITE SCREEN — same UI for both modes
// ══════════════════════════════════════════════════════════
class LudoInviteScreen extends StatefulWidget {
  final String mode; // 'webview' | 'firebase'
  const LudoInviteScreen({super.key, required this.mode});
  @override State<LudoInviteScreen> createState() => _LudoInviteState();
}

class _LudoInviteState extends State<LudoInviteScreen> {
  final _db = FirebaseDatabase.instance;
  List<Map<String, dynamic>> _cousins = [];
  final List<String> _sel = [];
  bool _loading = false;
  String _myUid = '', _myName = '', _myPhoto = '';

  @override void initState() { super.initState(); _init(); }

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

  String _genCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    return List.generate(6, (_) => chars[Random.secure().nextInt(chars.length)]).join();
  }

  Future<void> _start() async {
    if (_sel.isEmpty) return;
    setState(() => _loading = true);
    final roomId = 'ludo_${DateTime.now().millisecondsSinceEpoch}';
    final roomCode = widget.mode == 'webview' ? _genCode() : '';
    final all = [_myUid, ..._sel];

    final playersMap = <String, dynamic>{};
    for (int i = 0; i < all.length; i++) {
      final uid = all[i];
      final isMe = uid == _myUid;
      final c = isMe ? null : CacheService.loadAllUsers();
      final d = isMe ? null : c?[uid];
      final prof = d != null ? Map<String, dynamic>.from(d as Map) : (isMe ? {'name': _myName, 'photoUrl': _myPhoto} : {'name': 'Cousin', 'photoUrl': ''});
      playersMap[uid] = {
        'name': prof['nickname'] ?? prof['name'] ?? 'Cousin',
        'photo': prof['photoUrl'] ?? '',
        'ci': i, 'status': isMe ? 'joined' : 'pending',
        'pieces': [-1, -1, -1, -1], 'rank': 0,
      };
    }

    await _db.ref('ludoRooms/$roomId').set({
      'mode': widget.mode, 'host': _myUid, 'hostName': _myName,
      'roomCode': roomCode, 'status': 'waiting',
      'players': playersMap, 'turn': _myUid,
      'dv': 0, 'dr': false, 'cons6': 0, 'created': ServerValue.timestamp,
    });

    for (final uid in _sel) {
      await _db.ref('ludoInvites/$uid/$roomId').set({
        'roomId': roomId, 'hostName': _myName, 'hostPhoto': _myPhoto,
        'roomCode': roomCode, 'mode': widget.mode, 'timestamp': ServerValue.timestamp,
      });
      final ts = await _db.ref('users/$uid/fcmToken').get();
      if (ts.exists) await _db.ref('notifications').push().set({
        'toToken': ts.value,
        'title': '🎲 Ludo Invite from $_myName!',
        'body': widget.mode == 'webview'
          ? '$_myName তোমাকে Ludo King এ invite করেছে! Code: $roomCode'
          : '$_myName তোমাকে Ludo খেলতে invite করেছে!',
        'sent': false, 'timestamp': ServerValue.timestamp,
      });
    }

    // WebView: auto-post room code to main chat
    if (widget.mode == 'webview') {
      await _db.ref('chats/main').push().set({
        'text': '🎲 Ludo King Room!\n\nRoom Code: *$roomCode*\n\nLudo King এ → Multiplayer → Join by Code → code দাও!\n👑 ${all.length} players invited',
        'type': 'ludo_room', 'roomCode': roomCode,
        'senderUid': _myUid, 'senderName': _myName, 'senderPhoto': _myPhoto,
        'timestamp': ServerValue.timestamp, 'seenBy': {}, 'delivered': true,
      });
    }

    setState(() => _loading = false);
    if (!mounted) return;

    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) =>
      widget.mode == 'webview'
        ? LudoKingWaitingScreen(roomId: roomId, roomCode: roomCode, playerCount: all.length)
        : LudoFirebaseWaiting(roomId: roomId, isHost: true)));
  }

  @override
  Widget build(BuildContext context) {
    final isWV = widget.mode == 'webview';
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      appBar: AppBar(backgroundColor: const Color(0xFF0A0A1A), elevation: 0,
        title: Text(isWV ? '👑 Ludo King™ Invite' : '🎲 Cousin Ludo Invite',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white))),
      body: Column(children: [
        Container(margin: const EdgeInsets.all(12), padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: (isWV ? const Color(0xFF7C3AED) : const Color(0xFF43A047)).withOpacity(0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: (isWV ? const Color(0xFF7C3AED) : const Color(0xFF43A047)).withOpacity(0.4))),
          child: Text(
            isWV ? '👑 Invite পাঠানোর পর → সবাই Ludo King WebView তে যাবে → Room Code দিয়ে join করবে'
                 : '🎲 Invite পাঠানোর পর → সবাই directly app এর ভেতরে game এ enter করবে',
            style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.5))),

        if (_sel.isNotEmpty) Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
          child: Row(children: [
            ...[_myUid, ..._sel].take(5).map((uid) {
              final isMe = uid == _myUid;
              final c = isMe ? null : _cousins.firstWhere((x) => x['uid'] == uid, orElse: () => {});
              final photo = isMe ? _myPhoto : (c?['photoUrl'] ?? '');
              final name = isMe ? _myName : (c?['nickname'] ?? c?['name'] ?? 'Cousin');
              return Container(width: 36, height: 36, margin: const EdgeInsets.only(right: 4),
                decoration: BoxDecoration(shape: BoxShape.circle, gradient: AppTheme.mainGradient,
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
                return GestureDetector(onTap: () => _toggle(uid),
                  child: AnimatedContainer(duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: sel ? AppTheme.primary.withOpacity(0.15) : const Color(0xFF1A1A2E),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: sel ? AppTheme.primary : Colors.grey.shade800, width: sel ? 2 : 1)),
                    child: Row(children: [
                      Container(width: 42, height: 42, decoration: BoxDecoration(
                        gradient: sel ? AppTheme.mainGradient : null,
                        color: sel ? null : Colors.grey.shade700, shape: BoxShape.circle),
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

        Container(padding: const EdgeInsets.fromLTRB(12, 8, 12, 16), color: const Color(0xFF0A0A1A),
          child: SafeArea(child: AppTheme.gradientButton(
            label: _sel.isEmpty ? '⬆️ Select cousins to invite' :
              isWV ? '👑 Send Invites & Open Ludo King (${_sel.length + 1}P)' :
                     '🎲 Send Invites & Start Game (${_sel.length + 1}P)',
            loading: _loading, onTap: _sel.isEmpty ? null : _start, height: 52))),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════
// LUDO KING WAITING — Room code display
// ══════════════════════════════════════════════════════════
class LudoKingWaitingScreen extends StatefulWidget {
  final String roomId, roomCode;
  final int playerCount;
  const LudoKingWaitingScreen({super.key, required this.roomId, required this.roomCode, required this.playerCount});
  @override State<LudoKingWaitingScreen> createState() => _LudoKingWaitState();
}
class _LudoKingWaitState extends State<LudoKingWaitingScreen> {
  final _db = FirebaseDatabase.instance;
  int _joined = 1;
  @override
  void initState() {
    super.initState();
    final myUid = AuthService().currentUid ?? '';
    _db.ref('ludoRooms/${widget.roomId}/joined/$myUid').set(true);
    _db.ref('ludoRooms/${widget.roomId}/joined').onValue.listen((e) {
      if (!e.snapshot.exists || !mounted) return;
      setState(() => _joined = (e.snapshot.value as Map).length);
    });
  }

  void _copy() {
    Clipboard.setData(ClipboardData(text: widget.roomCode));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('✅ Room code copied!'), backgroundColor: Colors.green, duration: Duration(seconds: 1)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF0A0A1A),
    body: SafeArea(child: SingleChildScrollView(child: Padding(padding: const EdgeInsets.all(20), child: Column(children: [
      const SizedBox(height: 20),
      const Text('👑', style: TextStyle(fontSize: 80)),
      const Text('Ludo King™ Ready!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
      const SizedBox(height: 24),

      GestureDetector(onTap: _copy,
        child: Container(width: double.infinity, padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(gradient: AppTheme.mainGradient, borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: AppTheme.primary.withOpacity(0.4), blurRadius: 20)]),
          child: Column(children: [
            const Text('ROOM CODE — TAP TO COPY', style: TextStyle(color: Colors.white70, fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Text(widget.roomCode, style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 10)),
            const SizedBox(height: 8),
            Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(100)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.copy_rounded, color: Colors.white, size: 14),
                SizedBox(width: 4),
                Text('Copy', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
              ])),
          ]))),

      const SizedBox(height: 16),

      Container(padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: const Color(0xFF1A1A2E), borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('কীভাবে join করবে:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
          const SizedBox(height: 10),
          _step('1️⃣', '"Open Ludo King" button tap করো'),
          _step('2️⃣', 'Ludo King → Multiplayer → Online Mode'),
          _step('3️⃣', '"Join by Room Code" select করো'),
          _step('4️⃣', 'Code enter করো: ${widget.roomCode}'),
          _step('5️⃣', 'সব cousin একই ভাবে join করবে!'),
          const SizedBox(height: 8),
          Container(padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.amber.withOpacity(0.1), borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.withOpacity(0.3))),
            child: const Row(children: [
              Text('💡', style: TextStyle(fontSize: 16)), SizedBox(width: 6),
              Expanded(child: Text('Room code chat এ automatically send হয়েছে!',
                style: TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.w700))),
            ])),
        ])),

      const SizedBox(height: 16),
      Text('$_joined/${widget.playerCount} players ready',
        style: TextStyle(color: _joined >= widget.playerCount ? Colors.green : Colors.white60, fontWeight: FontWeight.w700)),
      const SizedBox(height: 20),

      AppTheme.gradientButton(label: '👑 Open Ludo King™',
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LudoKingWebView(roomCode: widget.roomCode))),
        height: 54),
      const SizedBox(height: 10),

      SizedBox(width: double.infinity, child: OutlinedButton(
        onPressed: _copy,
        style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF7C3AED), width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
          padding: const EdgeInsets.symmetric(vertical: 14)),
        child: Text('📋 Copy Room Code: ${widget.roomCode}',
          style: const TextStyle(color: Color(0xFF7C3AED), fontWeight: FontWeight.w800)))),
      const SizedBox(height: 10),
      TextButton(onPressed: () {
        _db.ref('ludoRooms/${widget.roomId}').remove();
        Navigator.of(context).popUntil((r) => r.isFirst);
      }, child: const Text('← Cancel', style: TextStyle(color: Colors.white38))),
      const SizedBox(height: 20),
    ])))),
  );

  Widget _step(String e, String t) => Padding(padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [Text(e, style: const TextStyle(fontSize: 14)), const SizedBox(width: 8),
      Expanded(child: Text(t, style: const TextStyle(color: Colors.white70, fontSize: 13)))]));
}

// ══════════════════════════════════════════════════════════
// LUDO KING WEBVIEW
// ══════════════════════════════════════════════════════════
class LudoKingWebView extends StatefulWidget {
  final String? roomCode;
  const LudoKingWebView({super.key, this.roomCode});
  @override State<LudoKingWebView> createState() => _LudoKingWVState();
}
class _LudoKingWVState extends State<LudoKingWebView> {
  late WebViewController _ctrl;
  bool _loading = true, _error = false;
  int _src = 0;
  final _urls = ['https://www.crazygames.com/game/ludo-king', 'https://playpager.com/ludo/', 'https://ludo.game/'];

  @override void initState() { super.initState(); _init(); }

  void _init() {
    _ctrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => setState(() { _loading = true; _error = false; }),
        onPageFinished: (_) { setState(() => _loading = false);
          _ctrl.runJavaScript("var s=document.createElement('style');s.textContent='header,footer,nav,.ad,.cookie-notice,.popup{display:none!important}body{overflow:hidden!important;margin:0!important}';document.head.appendChild(s);");
        },
        onWebResourceError: (_) => setState(() { _loading = false; _error = true; }),
      ))
      ..loadRequest(Uri.parse(_urls[_src]));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      backgroundColor: const Color(0xFF0A0A1A), elevation: 0,
      leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
      title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('👑 Ludo King™', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white)),
        if (widget.roomCode != null) GestureDetector(
          onTap: () { Clipboard.setData(ClipboardData(text: widget.roomCode!));
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied!'), duration: Duration(seconds: 1))); },
          child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(gradient: AppTheme.mainGradient, borderRadius: BorderRadius.circular(100)),
            child: Text('Code: ${widget.roomCode} 📋', style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w800)))),
      ]),
      actions: [
        IconButton(icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          onPressed: () { setState(() => _loading = true); _ctrl.reload(); }),
      ]),
    body: Stack(children: [
      WebViewWidget(controller: _ctrl),
      if (_loading) Container(color: const Color(0xFF0A0A1A),
        child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text('👑', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          const Text('Loading Ludo King...', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          const SizedBox(width: 200, child: LinearProgressIndicator(color: Color(0xFF9d4edd), backgroundColor: Color(0xFF2a1a4e))),
          if (widget.roomCode != null) ...[
            const SizedBox(height: 20),
            GestureDetector(onTap: () => Clipboard.setData(ClipboardData(text: widget.roomCode!)),
              child: Container(margin: const EdgeInsets.symmetric(horizontal: 20), padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(gradient: AppTheme.mainGradient, borderRadius: BorderRadius.circular(14)),
                child: Column(children: [
                  const Text('Room Code (tap to copy)', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  Text(widget.roomCode!, style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: 6)),
                ]))),
          ],
        ]))),
      if (_error) Container(color: const Color(0xFF0A0A1A),
        child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text('😕', style: TextStyle(fontSize: 56)),
          const Text('Could not load', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 20),
          if (_src < _urls.length - 1) AppTheme.gradientButton(label: 'Try Another Source', onTap: () {
            _src++; setState(() { _loading = true; _error = false; });
            _ctrl.loadRequest(Uri.parse(_urls[_src]));
          }),
          const SizedBox(height: 10),
          TextButton(onPressed: () { setState(() { _loading = true; _error = false; }); _ctrl.reload(); },
            child: const Text('Retry', style: TextStyle(color: Colors.white54))),
        ]))),
    ]),
  );
}

// ══════════════════════════════════════════════════════════
// FIREBASE WAITING ROOM
// ══════════════════════════════════════════════════════════
class LudoFirebaseWaiting extends StatefulWidget {
  final String roomId; final bool isHost;
  const LudoFirebaseWaiting({super.key, required this.roomId, required this.isHost});
  @override State<LudoFirebaseWaiting> createState() => _LudoFBWaitState();
}
class _LudoFBWaitState extends State<LudoFirebaseWaiting> {
  final _db = FirebaseDatabase.instance;
  Map<String, dynamic> _room = {};
  final _myUid = AuthService().currentUid ?? '';
  static const _cols = [Color(0xFFE53935), Color(0xFF1E88E5), Color(0xFFFDD835), Color(0xFF43A047)];

  @override
  void initState() {
    super.initState();
    if (!widget.isHost) _db.ref('ludoRooms/${widget.roomId}/players/$_myUid/status').set('joined');
    _db.ref('ludoRooms/${widget.roomId}').onValue.listen((e) {
      if (!e.snapshot.exists || !mounted) return;
      final room = Map<String, dynamic>.from(e.snapshot.value as Map);
      setState(() => _room = room);
      if (room['status'] == 'playing') {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LudoGameScreen(roomId: widget.roomId)));
      }
    });
  }

  Future<void> _start() async => _db.ref('ludoRooms/${widget.roomId}').update({'status': 'playing'});
  Future<void> _ignore(String uid) async {
    await _db.ref('ludoRooms/${widget.roomId}/players/$uid/status').set('cancelled');
    await _db.ref('ludoInvites/$uid/${widget.roomId}').remove();
  }
  Future<void> _cancel() async {
    final p = _room['players'] as Map? ?? {};
    for (final uid in p.keys) await _db.ref('ludoInvites/$uid/${widget.roomId}').remove();
    await _db.ref('ludoRooms/${widget.roomId}').remove();
    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final players = _room['players'] != null ? Map<String, dynamic>.from(_room['players'] as Map) : <String, dynamic>{};
    final joined = players.values.where((p) => (Map<String, dynamic>.from(p as Map))['status'] == 'joined').length;

    return Scaffold(backgroundColor: const Color(0xFF0A0A1A),
      appBar: AppBar(backgroundColor: const Color(0xFF0A0A1A), elevation: 0,
        title: const Text('Waiting Room 🎲', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white)),
        actions: [TextButton(onPressed: _cancel, child: const Text('Cancel', style: TextStyle(color: Colors.red)))]),
      body: Padding(padding: const EdgeInsets.all(14), child: Column(children: [
        Container(width: double.infinity, padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF1A1A3E), Color(0xFF2D1B69)]), borderRadius: BorderRadius.circular(20)),
          child: Column(children: [
            const Text('🎲', style: TextStyle(fontSize: 44)),
            Text('$joined/${players.length} Joined', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: players.values.map((p) {
              final pd = Map<String, dynamic>.from(p as Map);
              final ci = (pd['ci'] ?? 0) as int;
              return Container(width: 14, height: 14, margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(shape: BoxShape.circle, color: pd['status']=='joined' ? _cols[ci.clamp(0,3)] : Colors.grey.shade700));
            }).toList()),
          ])),
        const SizedBox(height: 12),
        Expanded(child: ListView(children: players.entries.map((e) {
          final uid = e.key; final p = Map<String, dynamic>.from(e.value as Map);
          final isMe = uid == _myUid; final ci = (p['ci'] ?? 0) as int;
          final status = p['status'] ?? 'pending';
          return Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: const Color(0xFF1A1A2E), borderRadius: BorderRadius.circular(14),
              border: Border.all(color: status=='joined' ? _cols[ci.clamp(0,3)] : Colors.grey.shade800, width: status=='joined'?2:1)),
            child: Row(children: [
              Container(width: 10, height: 10, margin: const EdgeInsets.only(right: 10), decoration: BoxDecoration(shape: BoxShape.circle, color: _cols[ci.clamp(0,3)])),
              Container(width: 38, height: 38, decoration: BoxDecoration(color: _cols[ci.clamp(0,3)], shape: BoxShape.circle),
                child: (p['photo']??'').isNotEmpty ? ClipOval(child: Image.network(p['photo'], fit: BoxFit.cover)) :
                  Center(child: Text((p['name']??'?')[0], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)))),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${p['name']??'Cousin'}${isMe?' (You)':''}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                Text(status=='joined'?'✅ Ready!':status=='pending'?'⏳ Waiting...':'❌ Cancelled',
                  style: TextStyle(fontSize: 11, color: status=='joined'?Colors.green:Colors.grey.shade500)),
              ])),
              if (widget.isHost && !isMe && status=='pending')
                GestureDetector(onTap: () => _ignore(uid),
                  child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(100), border: Border.all(color: Colors.red.withOpacity(0.4))),
                    child: const Text('Ignore', style: TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.w700)))),
            ]));
        }).toList())),
        if (widget.isHost) ...[
          if (joined >= 2) Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Text('$joined players ready!', textAlign: TextAlign.center, style: const TextStyle(color: Colors.green, fontSize: 13))),
          AppTheme.gradientButton(label: joined>=2?'🎲 Start Game ($joined players)!':'Waiting for cousins...', onTap: joined>=2?_start:null, height: 50),
        ] else const Text('Waiting for host to start...', style: TextStyle(color: Colors.white54)),
        const SizedBox(height: 12),
      ])));
  }
}

// ══════════════════════════════════════════════════════════
// GAME BOARD — Correct Ludo layout
// ══════════════════════════════════════════════════════════
const _kPC = [Color(0xFFE53935),Color(0xFF1E88E5),Color(0xFFFDD835),Color(0xFF43A047)];
const _kPCD = [Color(0xFFB71C1C),Color(0xFF0D47A1),Color(0xFFF9A825),Color(0xFF1B5E20)];
final _kSlots = [[[1.5,1.5],[3.5,1.5],[1.5,3.5],[3.5,3.5]],[[10.5,1.5],[12.5,1.5],[10.5,3.5],[12.5,3.5]],[[10.5,10.5],[12.5,10.5],[10.5,12.5],[12.5,12.5]],[[1.5,10.5],[3.5,10.5],[1.5,12.5],[3.5,12.5]]];
const _kPath = [[1,6],[2,6],[3,6],[4,6],[5,6],[6,5],[6,4],[6,3],[6,2],[6,1],[6,0],[7,0],[8,0],[8,1],[8,2],[8,3],[8,4],[8,5],[9,6],[10,6],[11,6],[12,6],[13,6],[14,6],[14,7],[14,8],[13,8],[12,8],[11,8],[10,8],[9,8],[8,9],[8,10],[8,11],[8,12],[8,13],[8,14],[7,14],[6,14],[6,13],[6,12],[6,11],[6,10],[6,9],[5,8],[4,8],[3,8],[2,8],[1,8],[0,8],[0,7],[0,6]];
const _kHC = [[[1,7],[2,7],[3,7],[4,7],[5,7]],[[7,1],[7,2],[7,3],[7,4],[7,5]],[[13,7],[12,7],[11,7],[10,7],[9,7]],[[7,13],[7,12],[7,11],[7,10],[7,9]]];
const _kCS = [0,13,26,39];
const _kSafe = {0,8,13,21,26,34,39,47};

int _roll() => Random.secure().nextInt(6)+1;
bool _can(int pos, int dv, int ci){if(pos==999)return false;if(pos==-1)return dv==6;if(pos>=100)return(pos-100)+dv<=4;return pos+dv<=55;}
int _mv(int pos, int dv){if(pos==-1)return 0;if(pos>=100){final ns=pos-100+dv;return ns>=5?999:100+ns;}final np=pos+dv;if(np>=51){final hs=np-51;return hs>=5?999:100+hs;}return np;}
int _absP(int rel, int ci){if(rel<0||rel>=100)return-1;return(rel+_kCS[ci])%52;}

class LudoGameScreen extends StatefulWidget {
  final String roomId;
  const LudoGameScreen({super.key, required this.roomId});
  @override State<LudoGameScreen> createState() => _LGState();
}
class _LGState extends State<LudoGameScreen> with TickerProviderStateMixin {
  final _db = FirebaseDatabase.instance;
  Map<String,dynamic> _room={};
  final _myUid = AuthService().currentUid??'';
  bool _rolling=false; int _animDv=1; double _glow=0;
  Timer? _gt; late AnimationController _da,_ta; late Animation<double> _ds,_tp;

  @override void initState(){super.initState();
    _da=AnimationController(vsync:this,duration:const Duration(milliseconds:500));
    _ta=AnimationController(vsync:this,duration:const Duration(milliseconds:800))..repeat(reverse:true);
    _ds=TweenSequence([TweenSequenceItem(tween:Tween<double>(begin:1,end:1.3),weight:50),TweenSequenceItem(tween:Tween<double>(begin:1.3,end:1),weight:50)]).animate(_da);
    _tp=Tween<double>(begin:1.0,end:1.08).animate(CurvedAnimation(parent:_ta,curve:Curves.easeInOut));
    _gt=Timer.periodic(const Duration(milliseconds:50),(_){if(mounted)setState(()=>_glow+=0.1);});
    _db.ref('ludoRooms/${widget.roomId}').onValue.listen((e){if(!e.snapshot.exists||!mounted)return;setState(()=>_room=Map<String,dynamic>.from(e.snapshot.value as Map));if(_room['status']=='finished')_showWin();});
  }
  @override void dispose(){_da.dispose();_ta.dispose();_gt?.cancel();super.dispose();}

  bool get _mt=>_room['turn']==_myUid;
  bool get _dr=>_room['dr']==true;
  int get _dv=>(_room['dv']??0) as int;

  List<int> _mvs(Map<String,dynamic> pl){
    if(!_mt||!_dr)return[];
    final me=pl[_myUid]; if(me==null)return[];
    final mp=Map<String,dynamic>.from(me as Map);
    final pieces=List<int>.from(mp['pieces'] as List);
    final ci=(mp['ci']??0) as int;
    return [0,1,2,3].where((i)=>_can(pieces[i],_dv,ci)).toList();
  }

  Future<void> _rollDice() async {
    if(!_mt||_dr||_rolling)return; HapticFeedback.mediumImpact();
    setState(()=>_rolling=true); _da.reset(); _da.forward();
    for(int i=0;i<12;i++){await Future.delayed(const Duration(milliseconds:55));if(mounted)setState(()=>_animDv=Random().nextInt(6)+1);}
    final v=_roll(); if(mounted)setState((){_animDv=v;_rolling=false;});
    final c6=((_room['cons6']??0) as int)+(v==6?1:0);
    await _db.ref('ludoRooms/${widget.roomId}').update({'dv':v,'dr':true,'cons6':c6});
    if(v==6&&c6>=3){_toast('😱 3 sixes! Turn forfeited!');await Future.delayed(const Duration(seconds:1));await _nt();return;}
    await Future.delayed(const Duration(milliseconds:300));
    if(!mounted)return;
    final pl=_room['players']!=null?Map<String,dynamic>.from(_room['players'] as Map):<String,dynamic>{};
    if(_mvs(pl).isEmpty){_toast('No moves — skipping');await Future.delayed(const Duration(milliseconds:800));await _nt();}
  }

  Future<void> _move(int pi) async {
    final pl=Map<String,dynamic>.from(_room['players'] as Map);
    final me=Map<String,dynamic>.from(pl[_myUid] as Map);
    final pieces=List<int>.from(me['pieces'] as List); final ci=(me['ci']??0) as int;
    if(!_can(pieces[pi],_dv,ci))return; HapticFeedback.lightImpact();
    final np=_mv(pieces[pi],_dv); pieces[pi]=np; bool cap=false;
    if(np>=0&&np<100){final a=_absP(np,ci);if(!_kSafe.contains(a)){for(final en in pl.entries){if(en.key==_myUid)continue;final op=Map<String,dynamic>.from(en.value as Map);final oci=(op['ci']??0) as int;final op2=List<int>.from(op['pieces'] as List);for(int j=0;j<op2.length;j++){if(op2[j]<0||op2[j]>=100)continue;if(_absP(op2[j],oci)==a){op2[j]=-1;op['pieces']=op2;pl[en.key]=op;cap=true;HapticFeedback.heavyImpact();_toast('💥 Captured ${op['name']}\'s piece!');}}}}}
    if(np==999)_toast('🏠 Piece ${pi+1} home!');
    me['pieces']=pieces;
    if(pieces.every((x)=>x==999)&&(me['rank']??0)==0){final r=pl.values.where((p)=>((Map<String,dynamic>.from(p as Map))['rank']??0)>0).length;me['rank']=r+1;}
    pl[_myUid]=me;
    final allDone=pl.values.where((p)=>!List<int>.from((Map<String,dynamic>.from(p as Map))['pieces'] as List).every((x)=>x==999)).length<=1;
    final rep=(_dv==6||cap)&&!allDone;
    await _db.ref('ludoRooms/${widget.roomId}').update({'players':pl,'dr':false,'dv':0,'turn':rep?_myUid:_np(pl),'status':allDone?'finished':'playing'});
  }

  String _np(Map<String,dynamic> pl){final list=pl.keys.toList();final idx=list.indexOf(_myUid);for(int i=1;i<=list.length;i++){final uid=list[(idx+i)%list.length];final p=Map<String,dynamic>.from(pl[uid] as Map);if(!List<int>.from(p['pieces'] as List).every((x)=>x==999))return uid;}return _myUid;}
  Future<void> _nt() async {final pl=Map<String,dynamic>.from(_room['players'] as Map? ?? {});await _db.ref('ludoRooms/${widget.roomId}').update({'turn':_np(pl),'dr':false,'dv':0});}
  void _toast(String m){if(!mounted)return;ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(m),duration:const Duration(seconds:2),backgroundColor:const Color(0xFF1A1A2E)));}

  void _showWin(){
    if(!mounted)return;
    final pl=_room['players'] as Map? ?? {};
    final sorted=pl.entries.toList()..sort((a,b){final ar=((Map<String,dynamic>.from(a.value as Map))['rank']??0) as int;final br=((Map<String,dynamic>.from(b.value as Map))['rank']??0) as int;if(ar==0)return 1;if(br==0)return-1;return ar.compareTo(br);});
    showDialog(context:context,barrierDismissible:false,builder:(_)=>Dialog(
      backgroundColor:const Color(0xFF1A1A2E),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(24)),
      child:Padding(padding:const EdgeInsets.all(24),child:Column(mainAxisSize:MainAxisSize.min,children:[
        const Text('🏆',style:TextStyle(fontSize:64)),
        const Text('Game Over!',style:TextStyle(fontSize:22,fontWeight:FontWeight.w900,color:Colors.white)),
        const SizedBox(height:16),
        ...sorted.asMap().entries.take(4).map((e){
          final p=Map<String,dynamic>.from(e.value.value as Map);final ci=(p['ci']??0) as int;
          final medals=['🥇','🥈','🥉','4️⃣'];
          return Container(margin:const EdgeInsets.only(bottom:8),padding:const EdgeInsets.all(12),
            decoration:BoxDecoration(color:e.key==0?_kPC[ci.clamp(0,3)].withOpacity(0.15):Colors.white.withOpacity(0.04),borderRadius:BorderRadius.circular(12),border:e.key==0?Border.all(color:_kPC[ci.clamp(0,3)],width:1.5):null),
            child:Row(children:[Text(medals[e.key<4?e.key:3],style:const TextStyle(fontSize:22)),const SizedBox(width:10),Container(width:36,height:36,decoration:BoxDecoration(color:_kPC[ci.clamp(0,3)],shape:BoxShape.circle),child:(p['photo']??'').isNotEmpty?ClipOval(child:Image.network(p['photo'],fit:BoxFit.cover)):Center(child:Text((p['name']??'?')[0],style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w700)))),const SizedBox(width:10),Text(e.value.key==_myUid?'${p['name']} (You)':p['name']??'Cousin',style:const TextStyle(fontSize:14,fontWeight:FontWeight.w700,color:Colors.white))]));
        }),
        const SizedBox(height:16),
        AppTheme.gradientButton(label:'Back to Games 🎮',onTap:(){_db.ref('ludoRooms/${widget.roomId}').remove();Navigator.of(context).popUntil((r)=>r.isFirst);}),
      ]))));
  }

  @override
  Widget build(BuildContext context){
    final pl=_room['players']!=null?Map<String,dynamic>.from(_room['players'] as Map):<String,dynamic>{};
    final curUid=_room['turn'] as String?? '';
    final curP=pl[curUid]!=null?Map<String,dynamic>.from(pl[curUid] as Map):<String,dynamic>{};
    final movables=_mvs(pl);
    return Scaffold(backgroundColor:const Color(0xFF0A0A1A),body:SafeArea(child:Column(children:[
      // Header
      Padding(padding:const EdgeInsets.fromLTRB(4,4,12,0),child:Row(children:[
        IconButton(icon:const Icon(Icons.arrow_back,color:Colors.white),onPressed:()=>showDialog(context:context,builder:(_)=>AlertDialog(backgroundColor:const Color(0xFF1A1A2E),title:const Text('Quit?',style:TextStyle(color:Colors.white)),content:const Text('Leave game?',style:TextStyle(color:Colors.white70)),actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Stay')),TextButton(onPressed:(){_db.ref('ludoRooms/${widget.roomId}').remove();Navigator.of(context).popUntil((r)=>r.isFirst);},child:const Text('Quit',style:TextStyle(color:Colors.red)))]))),
        const Text('🎲 Cousin Ludo',style:TextStyle(fontSize:15,fontWeight:FontWeight.w900,color:Colors.white)),const Spacer(),
        AnimatedBuilder(animation:_tp,builder:(_,c)=>Transform.scale(scale:_mt?_tp.value:1.0,child:c),child:Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:5),decoration:BoxDecoration(color:_mt?Colors.green.withOpacity(0.15):Colors.grey.withOpacity(0.08),borderRadius:BorderRadius.circular(100),border:Border.all(color:_mt?Colors.green:Colors.grey.shade700)),child:Text(_mt?'⚡ Your Turn!':'${curP['name']??'...'}\'s turn',style:TextStyle(fontSize:10,fontWeight:FontWeight.w800,color:_mt?Colors.green:Colors.white54)))),
      ])),
      // Player chips
      SizedBox(height:52,child:ListView(scrollDirection:Axis.horizontal,padding:const EdgeInsets.symmetric(horizontal:8,vertical:6),children:pl.entries.map((e){
        final uid=e.key;final p=Map<String,dynamic>.from(e.value as Map);final on=curUid==uid;final ci=(p['ci']??0) as int;final photo=p['photo']??'';
        final pieces=List<int>.from(p['pieces'] as List);final done=pieces.where((x)=>x==999).length;
        return AnimatedContainer(duration:const Duration(milliseconds:250),margin:const EdgeInsets.only(right:8),padding:const EdgeInsets.symmetric(horizontal:9,vertical:4),decoration:BoxDecoration(color:on?_kPC[ci.clamp(0,3)].withOpacity(0.2):const Color(0xFF1A1A2E),borderRadius:BorderRadius.circular(100),border:Border.all(color:on?_kPC[ci.clamp(0,3)]:Colors.grey.shade800,width:on?2:1)),
          child:Row(children:[Container(width:26,height:26,decoration:BoxDecoration(color:_kPC[ci.clamp(0,3)],shape:BoxShape.circle),child:photo.isNotEmpty?ClipOval(child:Image.network(photo,fit:BoxFit.cover)):Center(child:Text((p['name']??'?')[0],style:const TextStyle(color:Colors.white,fontSize:12,fontWeight:FontWeight.w900)))),const SizedBox(width:5),Column(mainAxisAlignment:MainAxisAlignment.center,crossAxisAlignment:CrossAxisAlignment.start,children:[Text(uid==_myUid?'You':(p['name']??''),style:const TextStyle(color:Colors.white,fontSize:10,fontWeight:FontWeight.w700)),Row(children:List.generate(4,(i)=>Container(width:7,height:7,margin:const EdgeInsets.only(right:2),decoration:BoxDecoration(shape:BoxShape.circle,color:i<done?_kPC[ci.clamp(0,3)]:Colors.grey.shade700))))]),]));
      }).toList())),
      // Board
      Expanded(child:Padding(padding:const EdgeInsets.symmetric(horizontal:4),child:AspectRatio(aspectRatio:1,child:GestureDetector(onTapUp:(d){if(!_mt||!_dr||movables.isEmpty)return;_move(movables.first);},child:CustomPaint(painter:_LBP(players:pl,myUid:_myUid,movables:movables,glow:_glow)))))),
      // Controls
      Container(color:const Color(0xFF0A0A1A),padding:const EdgeInsets.fromLTRB(14,8,14,16),child:Row(children:[
        GestureDetector(onTap:_mt&&!_dr&&!_rolling?_rollDice:null,child:AnimatedBuilder(animation:_ds,builder:(_,c)=>Transform.scale(scale:_rolling?_ds.value:1.0,child:c),child:Container(width:66,height:66,decoration:BoxDecoration(color:_mt&&!_dr?Colors.white:const Color(0xFF2A2A4E),borderRadius:BorderRadius.circular(16),boxShadow:_mt&&!_dr?[BoxShadow(color:Colors.white.withOpacity(0.2),blurRadius:10)]:[]),child:Center(child:Text(['','⚀','⚁','⚂','⚃','⚄','⚅'][(_rolling?_animDv:(_dv>0&&_dv<=6?_dv:0)).clamp(0,6)],style:const TextStyle(fontSize:36)))))),
        const SizedBox(width:12),
        Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(_mt?(_dr?(movables.isEmpty?'No moves — skipping':'Tap a glowing piece! ⚡'):'Tap dice to roll! 🎲'):'${curP['name']??'...'}\'s turn',style:const TextStyle(color:Colors.white,fontSize:13,fontWeight:FontWeight.w800)),if(_dr&&_dv>0)Row(children:[const Text('Rolled: ',style:TextStyle(color:Colors.white54,fontSize:11)),Text('$_dv',style:TextStyle(color:_dv==6?Colors.yellow:Colors.white,fontSize:17,fontWeight:FontWeight.w900)),if(_dv==6)const Text(' 🎉 Again!',style:TextStyle(color:Colors.yellow,fontSize:11))])])),
        if(_mt&&_dr&&pl[_myUid]!=null)(){
          final me=Map<String,dynamic>.from(pl[_myUid] as Map);final pieces=List<int>.from(me['pieces'] as List);final ci=(me['ci']??0) as int;
          return Row(children:pieces.asMap().entries.map((e){final i=e.key;final pos=e.value;final can=movables.contains(i);return GestureDetector(onTap:can?()=>_move(i):null,child:AnimatedContainer(duration:const Duration(milliseconds:180),width:can?34:26,height:can?34:26,margin:const EdgeInsets.only(left:5),decoration:BoxDecoration(shape:BoxShape.circle,color:can?_kPC[ci.clamp(0,3)]:_kPC[ci.clamp(0,3)].withOpacity(0.3),border:can?Border.all(color:Colors.white,width:2):null,boxShadow:can?[BoxShadow(color:_kPC[ci.clamp(0,3)].withOpacity(0.5),blurRadius:8)]:[]),child:Center(child:Text(pos==999?'✓':pos==-1?'⌂':'${i+1}',style:TextStyle(color:ci==2?Colors.brown.shade900:Colors.white,fontSize:can?12:9,fontWeight:FontWeight.w900)))));}).toList());
        }(),
      ])),
    ])));
  }
}

// Board Painter
class _LBP extends CustomPainter {
  final Map<String,dynamic> players; final String myUid; final List<int> movables; final double glow;
  _LBP({required this.players,required this.myUid,required this.movables,required this.glow});
  @override void paint(Canvas canvas,Size size){
    final c=size.width/15;
    canvas.drawRect(Rect.fromLTWH(0,0,size.width,size.height),Paint()..color=const Color(0xFFF5F0E8));
    for(final yd in [{'c':0,'r':0,'ci':0},{'c':9,'r':0,'ci':1},{'c':9,'r':9,'ci':2},{'c':0,'r':9,'ci':3}]){_yard(canvas,c,(yd['c'] as int)*c.toDouble(),(yd['r'] as int)*c.toDouble(),_kPC[yd['ci'] as int]);}
    for(final sq in _kPath){canvas.drawRect(Rect.fromLTWH(sq[0]*c,sq[1]*c,c,c),Paint()..color=Colors.white);canvas.drawRect(Rect.fromLTWH(sq[0]*c,sq[1]*c,c,c),Paint()..color=Colors.black.withOpacity(0.07)..style=PaintingStyle.stroke..strokeWidth=0.5);}
    for(final sq in [[0,7],[7,0],[14,7],[7,14]]){canvas.drawRect(Rect.fromLTWH(sq[0]*c,sq[1]*c,c,c),Paint()..color=Colors.white);}
    final hcc=[const Color(0xFFEF9A9A),const Color(0xFF90CAF9),const Color(0xFFFFF59D),const Color(0xFFA5D6A7)];
    for(int ci=0;ci<4;ci++){_kHC[ci].asMap().forEach((step,sq){canvas.drawRect(Rect.fromLTWH(sq[0]*c,sq[1]*c,c,c),Paint()..color=hcc[ci].withOpacity(0.5+step*0.1));canvas.drawRect(Rect.fromLTWH(sq[0]*c,sq[1]*c,c,c),Paint()..color=Colors.black.withOpacity(0.06)..style=PaintingStyle.stroke..strokeWidth=0.5);});}
    final cx=7.5*c,cy=7.5*c,x6=6*c,y6=6*c,s3=3*c;
    canvas.drawRect(Rect.fromLTWH(x6,y6,s3,s3),Paint()..color=Colors.white);
    for(final t in [{'pts':[[x6,y6],[x6+s3,y6],[cx,cy]],'ci':0},{'pts':[[x6+s3,y6],[x6+s3,y6+s3],[cx,cy]],'ci':1},{'pts':[[x6+s3,y6+s3],[x6,y6+s3],[cx,cy]],'ci':2},{'pts':[[x6,y6+s3],[x6,y6],[cx,cy]],'ci':3}]){final pts=t['pts'] as List;final ci=t['ci'] as int;final path=Path()..moveTo((pts[0] as List)[0].toDouble(),(pts[0] as List)[1].toDouble())..lineTo((pts[1] as List)[0].toDouble(),(pts[1] as List)[1].toDouble())..lineTo((pts[2] as List)[0].toDouble(),(pts[2] as List)[1].toDouble())..close();canvas.drawPath(path,Paint()..color=_kPC[ci].withOpacity(0.85));}
    _txt(canvas,'⭐',Offset(cx,cy),c);
    for(final si in _kSafe){if(si>=_kPath.length)continue;final sq=_kPath[si];_star(canvas,(sq[0]+0.5)*c,(sq[1]+0.5)*c,c*0.24);}
    _drawPieces(canvas,c);
  }
  void _yard(Canvas canvas,double c,double x,double y,Color col){
    final s=6*c;canvas.drawRect(Rect.fromLTWH(x,y,s,s),Paint()..color=col.withOpacity(0.12));canvas.drawRect(Rect.fromLTWH(x,y,s,s),Paint()..color=col..style=PaintingStyle.stroke..strokeWidth=2.5);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x+c,y+c,4*c,4*c),Radius.circular(c*0.4)),Paint()..color=col.withOpacity(0.8));
    final ci=x==0&&y==0?0:x>0&&y==0?1:x>0&&y>0?2:3;
    _kSlots[ci].forEach((sl){canvas.drawCircle(Offset(sl[0]*c,sl[1]*c),c*0.34,Paint()..color=Colors.black.withOpacity(0.18));canvas.drawCircle(Offset(sl[0]*c,sl[1]*c),c*0.3,Paint()..color=Colors.white.withOpacity(0.28));canvas.drawCircle(Offset(sl[0]*c,sl[1]*c),c*0.3,Paint()..color=Colors.white.withOpacity(0.45)..style=PaintingStyle.stroke..strokeWidth=1.5);});
  }
  void _drawPieces(Canvas canvas,double c){
    final map=<String,List<Map>>{};
    for(final entry in players.entries){final uid=entry.key;final p=Map<String,dynamic>.from(entry.value as Map);final ci=(p['ci']??0) as int;final pieces=List<int>.from(p['pieces'] as List);for(int i=0;i<pieces.length;i++){final pos=pieces[i];if(pos==999)continue;final cen=_getCen(pos,ci,i,c);if(cen==null)continue;final key='${cen.dx.round()}_${cen.dy.round()}';map.putIfAbsent(key,()=>[]);map[key]!.add({'ci':ci,'pi':i,'uid':uid,'cen':cen});}}
    map.forEach((_,items){if(items.length==1){final it=items[0];_piece(canvas,it['cen'] as Offset,it['ci'] as int,it['pi'] as int,it['uid']==myUid&&movables.contains(it['pi']),1.0);}else{final r=c*0.14;items.asMap().forEach((idx,it){final a=(idx/items.length)*2*pi;_piece(canvas,(it['cen'] as Offset)+Offset(cos(a)*r,sin(a)*r),it['ci'] as int,it['pi'] as int,it['uid']==myUid&&movables.contains(it['pi']),0.78);});}});
  }
  Offset? _getCen(int pos,int ci,int pi,double c){if(pos==-1){final sl=_kSlots[ci][pi];return Offset(sl[0]*c,sl[1]*c);}if(pos>=100){final step=pos-100;if(step>=_kHC[ci].length)return null;final sq=_kHC[ci][step];return Offset((sq[0]+0.5)*c,(sq[1]+0.5)*c);}final a=(pos+_kCS[ci])%52;final sq=_kPath[a];return Offset((sq[0]+0.5)*c,(sq[1]+0.5)*c);}
  void _piece(Canvas canvas,Offset cen,int ci,int pi,bool movable,double scale){final gv=(sin(glow+pi*1.3)+1)/2;final r=13.5*scale*(movable?1.0+gv*0.14:1.0);canvas.drawCircle(cen+const Offset(1.5,2),r,Paint()..color=Colors.black.withOpacity(0.28)..maskFilter=const MaskFilter.blur(BlurStyle.normal,4));final g=RadialGradient(colors:[Colors.white,_kPC[ci.clamp(0,3)],_kPCD[ci.clamp(0,3)]],stops:const[0.0,0.3,1.0],center:const Alignment(-0.3,-0.3));canvas.drawCircle(cen,r,Paint()..shader=g.createShader(Rect.fromCircle(center:cen,radius:r)));if(movable){final a=0.5+gv*0.5;canvas.drawCircle(cen,r+3,Paint()..color=Colors.white.withOpacity(a)..style=PaintingStyle.stroke..strokeWidth=2.5);canvas.drawCircle(cen,r+6.5,Paint()..color=Colors.yellow.withOpacity(a*0.5)..style=PaintingStyle.stroke..strokeWidth=2);}else{canvas.drawCircle(cen,r,Paint()..color=Colors.white.withOpacity(0.35)..style=PaintingStyle.stroke..strokeWidth=1.5);}canvas.drawCircle(Offset(cen.dx-r*0.28,cen.dy-r*0.3),r*0.22,Paint()..color=Colors.white.withOpacity(0.62));_txt(canvas,'${pi+1}',cen,r*0.85,color:ci==2?Colors.brown.shade800:Colors.white);}
  void _star(Canvas canvas,double cx,double cy,double r){final path=Path();for(int i=0;i<10;i++){final rad=i.isEven?r:r*0.4;final a=(i*pi/5)-pi/2;i==0?path.moveTo(cx+rad*cos(a),cy+rad*sin(a)):path.lineTo(cx+rad*cos(a),cy+rad*sin(a));}path.close();canvas.drawPath(path,Paint()..color=Colors.grey.shade500.withOpacity(0.45));}
  void _txt(Canvas canvas,String t,Offset cen,double sz,{Color color=Colors.white}){final tp=TextPainter(text:TextSpan(text:t,style:TextStyle(fontSize:sz,fontWeight:FontWeight.w900,color:color,shadows:[Shadow(color:Colors.black.withOpacity(0.25),blurRadius:2)])),textDirection:TextDirection.ltr)..layout();tp.paint(canvas,cen-Offset(tp.width/2,tp.height/2));}
  @override bool shouldRepaint(_LBP o)=>true;
}
