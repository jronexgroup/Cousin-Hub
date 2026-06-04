import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app_theme.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';
import 'ludo_result_screen.dart';
import 'ludo_declare_results_screen.dart';

class LudoMatchLobbyScreen extends StatefulWidget {
  final String matchId;
  final bool isHost;
  const LudoMatchLobbyScreen({super.key, required this.matchId, required this.isHost});
  @override
  State<LudoMatchLobbyScreen> createState() => _LudoMatchLobbyState();
}

class _LudoMatchLobbyState extends State<LudoMatchLobbyScreen> {
  final _db = FirebaseDatabase.instance;
  final _uid = AuthService().currentUid ?? '';
  Map<String, dynamic> _match = {};
  bool _hasAutoLaunched = false;

  void _goHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false);
  }

  @override
  void initState() {
    super.initState();
    if (!widget.isHost) {
      _db.ref('ludoKingMatches/${widget.matchId}/players/$_uid/status').set('joined');
      _db.ref('ludoKingMatches/${widget.matchId}/players/$_uid/joinedAt').set(ServerValue.timestamp);
      _db.ref('ludoKingInvites/$_uid/${widget.matchId}').remove();
    }
    _db.ref('ludoKingMatches/${widget.matchId}').onValue.listen((e) {
      if (!e.snapshot.exists || !mounted) {
        if (!e.snapshot.exists && mounted) _goHome();
        return;
      }
      final data = Map<String, dynamic>.from(e.snapshot.value as Map);
      setState(() => _match = data);

      if (data['matchStarted'] == true && data['deepLink'] != null && !_hasAutoLaunched) {
        _hasAutoLaunched = true;
        _openLudoKing();
      }

      if (data['status'] == 'finished' && mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(
          builder: (_) => LudoResultScreen(matchId: widget.matchId, uid: _uid)));
      }
    });
  }

  Future<void> _openLudoKing() async {
    final link = _match['deepLink'] as String? ?? '';
    if (link.isNotEmpty) {
      final uri = Uri.parse(link);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  void _startMatch() {
    _db.ref('ludoKingMatches/${widget.matchId}').update({
      'matchStarted': true,
      'startedAt': ServerValue.timestamp,
    });
  }

  void _goDeclareResults() {
    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => LudoDeclareResultsScreen(
        matchId: widget.matchId,
        roomCode: _match['roomCode'] as String? ?? '',
        hostUid: _match['hostUid'] as String? ?? '',
        hostName: _match['hostName'] as String? ?? '',
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final players = _match['players'] != null
        ? Map<String, dynamic>.from(_match['players'] as Map)
        : <String, dynamic>{};
    final joined = players.values.where((p) => (Map.from(p as Map))['status'] == 'joined').length;
    final total = players.length;
    final roomCode = _match['roomCode'] as String? ?? '';
    final hasRoom = roomCode.isNotEmpty;
    final matchStarted = _match['matchStarted'] == true;
    final status = _match['status'] as String? ?? 'waiting';
    final pending = players.entries.where((e) => (Map.from(e.value as Map))['status'] != 'joined').toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A1A), elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: _goHome),
        title: const Text('Match Lobby 🎮', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white)),
        actions: [
          if (widget.isHost && !matchStarted && status != 'finished')
            TextButton(
              onPressed: () {
                _db.ref('ludoKingMatches/${widget.matchId}').update({'status': 'cancelled'});
                _db.ref('ludoKingMatches/${widget.matchId}').remove();
                for (final uid in players.keys) {
                  _db.ref('ludoKingInvites/$uid/${widget.matchId}').remove();
                }
                _goHome();
              },
              child: const Text('Cancel', style: TextStyle(color: Colors.red))),
        ],
      ),
      body: Padding(padding: const EdgeInsets.all(14), child: Column(children: [
        // Status header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF1A1A3E), Color(0xFF2D1B69)]),
            borderRadius: BorderRadius.circular(20)),
          child: Column(children: [
            Text(matchStarted ? '🚀' : status == 'finished' ? '🏁' : hasRoom ? '👑' : '🤖',
              style: const TextStyle(fontSize: 44)),
            Text(matchStarted
                ? 'Starting...'
                : hasRoom
                    ? '$joined/$total Joined'
                    : 'Setting up...',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)),
            const SizedBox(height: 8),
            if (hasRoom)
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(100)),
                  child: Text('Code: $roomCode', style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w700))),
              ]),
          ])),
        const SizedBox(height: 12),

        // Pending players warning (only before match starts)
        if (!matchStarted && status != 'finished' && pending.isNotEmpty)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.access_time_rounded, color: Colors.orange, size: 16),
                const SizedBox(width: 6),
                Text('Waiting for ${pending.length} player${pending.length > 1 ? 's' : ''}',
                  style: const TextStyle(color: Colors.orange, fontSize: 13, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 6),
              ...pending.map((e) {
                final p = Map<String, dynamic>.from(e.value as Map);
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(children: [
                    const Text('⏳ ', style: TextStyle(fontSize: 12)),
                    Text(p['name']?.toString() ?? 'Cousin',
                      style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  ]));
              }),
            ])),

        // Player list
        Expanded(child: ListView(children: [
          ...players.entries.map((e) {
            final uid = e.key;
            final p = Map<String, dynamic>.from(e.value as Map);
            final isMe = uid == _uid;
            final s = p['status'] ?? 'pending';
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A2E),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: s == 'joined' ? Colors.green : Colors.grey.shade800,
                  width: s == 'joined' ? 2 : 1)),
              child: Row(children: [
                Container(
                  width: 10, height: 10,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: s == 'joined' ? Colors.green : Colors.grey.shade700)),
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: s == 'joined' ? AppTheme.primary : Colors.grey.shade700,
                    shape: BoxShape.circle),
                  child: Center(child: Text(
                    (p['name'] ?? '?').toString().substring(0, 1).toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)))),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${p['name'] ?? 'Cousin'}${isMe ? ' (You)' : ''}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                  Text(s == 'joined' ? '✅ Joined!' : '⏳ Waiting...',
                    style: TextStyle(fontSize: 11, color: s == 'joined' ? Colors.green : Colors.grey.shade500)),
                ])),
              ]));
          }),
        ])),

        // ── Host section ──
        if (widget.isHost && status != 'finished') ...[
          const SizedBox(height: 8),

          // Start Match button
          SizedBox(
            width: double.infinity,
            child: AppTheme.gradientButton(
              label: matchStarted
                  ? '🚀 Match Starting...'
                  : joined < total
                      ? '🚀 Start Match Anyway (${total - joined} waiting)'
                      : '🚀 Start Match',
              onTap: matchStarted ? null : _startMatch,
              height: 52),
          ),

          if (!matchStarted) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _goDeclareResults,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.green.shade400, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                  padding: const EdgeInsets.symmetric(vertical: 14)),
                child: Text('🏁 Declare Results',
                  style: TextStyle(color: Colors.green.shade400, fontWeight: FontWeight.w800))),
            ),
          ],
        ],

        // ── Player section (non-host) ──
        if (!widget.isHost && status != 'finished') ...[
          const SizedBox(height: 16),
          Text(matchStarted
              ? '🚀 Auto-starting Ludo King...'
              : hasRoom
                  ? '⏳ Waiting for host to start the match...'
                  : '⏳ Room is being set up...',
            style: const TextStyle(color: Colors.white54, fontSize: 14, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center),
        ],

        const SizedBox(height: 12),
      ])),
    );
  }
}
