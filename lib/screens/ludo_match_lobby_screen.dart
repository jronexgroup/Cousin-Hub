import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app_theme.dart';
import '../services/auth_service.dart';
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
        if (!e.snapshot.exists && mounted) {
          Navigator.of(context).popUntil((r) => r.isFirst);
        }
        return;
      }
      setState(() => _match = Map<String, dynamic>.from(e.snapshot.value as Map));
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

  void _goToResults() {
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
    final botStatus = _match['botStatus'] as String? ?? '';
    final hasRoom = roomCode.isNotEmpty && botStatus == 'in_room';
    final botLeft = botStatus == 'departed';

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A1A), elevation: 0,
        title: const Text('Match Lobby 🎮', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white)),
        actions: [
          if (widget.isHost)
            TextButton(
              onPressed: () {
                _db.ref('ludoKingMatches/${widget.matchId}').update({'status': 'cancelled'});
                _db.ref('ludoKingMatches/${widget.matchId}').remove();
                for (final uid in players.keys) {
                  _db.ref('ludoKingInvites/$uid/${widget.matchId}').remove();
                }
                Navigator.of(context).popUntil((r) => r.isFirst);
              },
              child: const Text('Cancel', style: TextStyle(color: Colors.red))),
        ],
      ),
      body: Padding(padding: const EdgeInsets.all(14), child: Column(children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF1A1A3E), Color(0xFF2D1B69)]),
            borderRadius: BorderRadius.circular(20)),
          child: Column(children: [
            Text(hasRoom ? '👑' : botLeft ? '🚪' : '🤖', style: const TextStyle(fontSize: 44)),
            Text(hasRoom ? '$joined/$total Joined' : botLeft ? 'Bot has left' : 'Waiting for bot...',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)),
            const SizedBox(height: 8),
            if (hasRoom)
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(100)),
                  child: Text('Code: $roomCode', style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w700))),
              ]),
            if (!hasRoom && !botLeft)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.amber.withOpacity(0.2), borderRadius: BorderRadius.circular(100)),
                child: Text(botStatus == 'creating_room' ? '🔨 Creating room...' : '🤖 Bot will create room shortly',
                  style: const TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.w700))),
          ])),

        const SizedBox(height: 12),

        // Bot status banner
        if (botStatus == 'creating_room')
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.amber.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amber)),
              const SizedBox(width: 10),
              const Expanded(child: Text('Bot is creating a room in Ludo King...', style: TextStyle(color: Colors.amber, fontSize: 12))),
            ])),

        Expanded(child: ListView(children: [
          ...players.entries.map((e) {
            final uid = e.key;
            final p = Map<String, dynamic>.from(e.value as Map);
            final isMe = uid == _uid;
            final status = p['status'] ?? 'pending';
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A2E),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: status == 'joined' ? Colors.green : Colors.grey.shade800,
                  width: status == 'joined' ? 2 : 1)),
              child: Row(children: [
                Container(
                  width: 10, height: 10,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: status == 'joined' ? Colors.green : Colors.grey.shade700)),
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: status == 'joined' ? AppTheme.primary : Colors.grey.shade700,
                    shape: BoxShape.circle),
                  child: Center(child: Text(
                    (p['name'] ?? '?').toString().substring(0, 1).toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)))),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${p['name'] ?? 'Cousin'}${isMe ? ' (You)' : ''}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                  Text(status == 'joined' ? '✅ Joined!' : status == 'pending' ? '⏳ Waiting...' : '❌ Cancelled',
                    style: TextStyle(fontSize: 11, color: status == 'joined' ? Colors.green : Colors.grey.shade500)),
                ])),
              ]));
          }),
        ])),

        if (widget.isHost) ...[
          if (joined >= 2 && hasRoom)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: Text('$joined players joined! Go play in Ludo King!',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.green, fontSize: 13))),
          if (hasRoom && !botLeft && joined >= 1) ...[
            AppTheme.gradientButton(
              label: '👑 Open Ludo King & Join Room',
              onTap: _openLudoKing,
              height: 50),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  _db.ref('ludoKingMatches/${widget.matchId}').update({'botLeave': true});
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('🤖 Bot will leave the room'), backgroundColor: Colors.green, duration: Duration(seconds: 2)));
                },
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.orange.shade300, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                  padding: const EdgeInsets.symmetric(vertical: 12)),
                child: Text('🚪 Bot Leave Room (so bot can serve others)',
                  style: TextStyle(color: Colors.orange.shade300, fontSize: 12, fontWeight: FontWeight.w800))),
          ] else if (!hasRoom) ...[
            const SizedBox(height: 10),
            const Text('⏳ Room code will appear here once the bot creates it',
              textAlign: TextAlign.center, style: TextStyle(color: Colors.white38, fontSize: 12)),
          ],
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: hasRoom && joined >= 2 ? _goToResults : null,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: hasRoom && joined >= 2 ? Colors.green : Colors.grey.shade700, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                padding: const EdgeInsets.symmetric(vertical: 14)),
              child: Text(hasRoom && joined >= 2 ? '🏁 Declare Results (after match)' : 'Wait for players & bot...',
                style: TextStyle(
                  color: hasRoom && joined >= 2 ? Colors.green : Colors.grey.shade600,
                  fontWeight: FontWeight.w800))),
        ] else ...[
          if (!hasRoom) ...[
            const SizedBox(height: 8),
            const Text('Waiting for bot to create room...',
              style: TextStyle(color: Colors.white54, fontSize: 13)),
          ],
          if (hasRoom) ...[
            const SizedBox(height: 8),
            const Text('Waiting for host to start playing...',
              style: TextStyle(color: Colors.white54, fontSize: 13)),
            const SizedBox(height: 10),
            AppTheme.gradientButton(
              label: '👑 Open Ludo King & Join Room',
              onTap: _openLudoKing,
              height: 50),
          ],
        ],

        const SizedBox(height: 12),
      ])),
    );
  }
}
