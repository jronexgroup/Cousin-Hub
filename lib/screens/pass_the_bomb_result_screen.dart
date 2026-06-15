import 'package:flutter/material.dart';
import '../app_theme.dart';
import 'home_screen.dart';
import 'pass_the_bomb_lobby_screen.dart';
import 'pass_the_bomb_models.dart';
import '../services/badge_service.dart';

class PassTheBombResultScreen extends StatefulWidget {
  final List<PlayerData> players;
  final String winnerUid, myUid, myName, myPhoto, roomId;
  final bool isHost;
  const PassTheBombResultScreen({
    super.key, required this.players, required this.winnerUid,
    required this.myUid, required this.myName, required this.myPhoto,
    required this.roomId, required this.isHost});
  @override
  State<PassTheBombResultScreen> createState() => _PassTheBombResultState();
}

class _PassTheBombResultState extends State<PassTheBombResultScreen> {

  List<PlayerData> get _ranked {
    final alive = widget.players.where((p) => p.uid == widget.winnerUid).toList();
    final eliminated = widget.players.where((p) => p.uid != widget.winnerUid).toList()
      ..sort((a, b) => (a.eliminationOrder ?? 999).compareTo(b.eliminationOrder ?? 999));
    return [...alive, ...eliminated];
  }

  bool get _iWon => widget.winnerUid == widget.myUid;

  int _points(int position) {
    if (position == 0) return 100;
    if (position == 1) return 60;
    if (position == 3) return 30;
    return 10;
  }

  Future<void> _playAgain() async {
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(
      builder: (_) => PassTheBombLobbyScreen()));
  }

  void _goHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final ranked = _ranked;
    BadgeService.incrementStat(widget.winnerUid, 'game');

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A1A), elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text('💣 Game Over',
          style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white))),

      body: Column(children: [
        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            // Winner announcement
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4A0E4E), Color(0xFF7C3AED)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(
                  color: const Color(0xFF7C3AED).withOpacity(0.4),
                  blurRadius: 20, offset: const Offset(0, 8))]),
              child: Column(children: [
                const Text('🏆', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 8),
                Text('${_iWon ? "You" : ranked[0].name} won!',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white)),
                const SizedBox(height: 4),
                Text('+100 points', style: TextStyle(
                  color: Colors.amber.shade300, fontWeight: FontWeight.w700, fontSize: 16)),
              ])),
            const SizedBox(height: 20),

            // Podium
            if (ranked.length >= 3)
              _buildPodium(ranked),
            const SizedBox(height: 20),

            // Full ranking
            _buildRanking(ranked),
          ]),
        )),

        // Bottom buttons
        Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          decoration: const BoxDecoration(
            color: Color(0xFF111122),
            border: Border(top: BorderSide(color: Colors.white12))),
          child: SafeArea(child: Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: _goHome,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white24),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                padding: const EdgeInsets.symmetric(vertical: 14)),
              child: const Text('🏠 Home', style: TextStyle(color: Colors.white70)))),
            const SizedBox(width: 12),
            Expanded(child: AppTheme.gradientButton(
              label: '🔄 Play Again',
              onTap: _playAgain,
              height: 48)),
          ])),
        ),
      ]));
  }

  Widget _buildPodium(List<PlayerData> ranked) {
    final labels = ['🥇', '🥈', '🥉'];
    final colors = [
      const Color(0xFFFFD700),
      const Color(0xFFC0C0C0),
      const Color(0xFFCD7F32),
    ];
    final heights = [120.0, 90.0, 60.0];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        if (i >= ranked.length) return const SizedBox();
        final p = ranked[i];
        final isMe = p.uid == widget.myUid;
        return Container(
          width: 100,
          margin: EdgeInsets.only(right: i < 2 ? 8 : 0),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Avatar
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey.shade700,
                border: Border.all(color: colors[i], width: 2),
                image: p.photo.isNotEmpty
                    ? DecorationImage(image: NetworkImage(p.photo), fit: BoxFit.cover)
                    : null),
              child: p.photo.isEmpty
                  ? Center(child: Text(p.name[0].toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)))
                  : null),
            const SizedBox(height: 4),
            Text(labels[i], style: const TextStyle(fontSize: 24)),
            Text(p.name, textAlign: TextAlign.center,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: isMe ? 13 : 12,
                fontWeight: isMe ? FontWeight.w800 : FontWeight.w600,
                color: isMe ? Colors.amber : Colors.white70)),
            const SizedBox(height: 4),
            Container(
              width: 60, height: heights[i],
              decoration: BoxDecoration(
                color: colors[i].withOpacity(0.2),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                border: Border.all(color: colors[i].withOpacity(0.4))),
              child: Center(child: Text('+${_points(i)}',
                style: TextStyle(color: colors[i], fontWeight: FontWeight.w800, fontSize: 14))),
            ),
          ]),
        );
      }),
    );
  }

  Widget _buildRanking(List<PlayerData> ranked) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Elimination Order', style: TextStyle(
        fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white54)),
      const SizedBox(height: 8),
      ...List.generate(ranked.length, (i) {
        final p = ranked[i];
        final isMe = p.uid == widget.myUid;
        final pos = i + 1;
        final posEmoji = pos == 1 ? '🏆' : pos == 2 ? '🥈' : pos == 3 ? '🥉' : '$pos.';
        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isMe ? AppTheme.primary.withOpacity(0.15) : const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isMe ? AppTheme.primary : Colors.grey.shade800,
              width: isMe ? 1.5 : 1)),
          child: Row(children: [
            SizedBox(width: 32, child: Text(posEmoji,
              style: TextStyle(fontSize: pos <= 3 ? 18 : 14, fontWeight: FontWeight.w800, color: Colors.white))),
            const SizedBox(width: 8),
            Container(width: 32, height: 32,
              decoration: BoxDecoration(
                color: Colors.grey.shade700, shape: BoxShape.circle,
                image: p.photo.isNotEmpty
                    ? DecorationImage(image: NetworkImage(p.photo), fit: BoxFit.cover)
                    : null),
              child: p.photo.isEmpty
                  ? Center(child: Text(p.name[0].toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)))
                  : null),
            const SizedBox(width: 10),
            Expanded(child: Text(p.name,
              style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700,
                color: isMe ? Colors.amber : Colors.white))),
            Text('+${_points(i)}',
              style: TextStyle(
                color: i <= 2 ? const Color(0xFFFFD700) : Colors.white38,
                fontWeight: FontWeight.w700, fontSize: 13)),
          ]),
        );
      }),
    ]);
  }
}
