import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../screens/home_screen.dart';
import 'pass_the_card_models.dart';
import 'pass_the_card_lobby_screen.dart';

class PassTheCardResultScreen extends StatefulWidget {
  final List<PlayerCardData> players;
  final String winnerUid, myUid, myName, myPhoto, roomId;
  final bool isHost;
  final int turnsPlayed, cardsPassed, startedAt;

  const PassTheCardResultScreen({
    super.key,
    required this.players,
    required this.winnerUid,
    required this.myUid,
    required this.myName,
    required this.myPhoto,
    required this.roomId,
    this.isHost = false,
    this.turnsPlayed = 0,
    this.cardsPassed = 0,
    this.startedAt = 0,
  });

  @override
  State<PassTheCardResultScreen> createState() => _PassTheCardResultScreenState();
}

class _PassTheCardResultScreenState extends State<PassTheCardResultScreen> {
  bool _waitingPlayAgain = false;

  String get _duration {
    if (widget.startedAt <= 0) return '--';
    final sec = ((DateTime.now().millisecondsSinceEpoch - widget.startedAt) / 1000).round();
    if (sec < 60) return '${sec}s';
    return '${sec ~/ 60}m ${sec % 60}s';
  }

  @override
  Widget build(BuildContext context) {
    final isWinner = widget.winnerUid == widget.myUid;
    final winner = widget.players.firstWhere(
      (p) => p.uid == widget.winnerUid,
      orElse: () => PlayerCardData(uid: '', name: 'Winner', photo: '', cardCount: 0));
    final others = widget.players.where((p) => p.uid != widget.winnerUid).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A1A), elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text('🃏 Game Over',
          style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF1B3A1B), Color(0xFF0A0A1A)]),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.amber.shade700, width: 2)),
            child: Column(children: [
              Text(isWinner ? '🏆 YOU WIN!' : '🏆 ${winner.name} WINS!',
                style: TextStyle(
                  fontSize: isWinner ? 28 : 22,
                  fontWeight: FontWeight.w900,
                  color: isWinner ? Colors.amber : Colors.white),
                textAlign: TextAlign.center),
              const SizedBox(height: 8),
              if (winner.photo.isNotEmpty)
                Container(width: 64, height: 64,
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.grey),
                  child: ClipOval(child: Image.network(winner.photo, fit: BoxFit.cover))),
              const SizedBox(height: 16),
              _statRow('⏱ Duration', _duration),
              _statRow('🔄 Turns Played', '${widget.turnsPlayed}'),
              _statRow('🃏 Cards Passed', '${widget.cardsPassed}'),
            ]),
          ),

          const SizedBox(height: 24),
          ...others.map((p) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white12)),
            child: Row(children: [
              Container(width: 36, height: 36,
                decoration: const BoxDecoration(color: Colors.grey, shape: BoxShape.circle),
                child: p.photo.isNotEmpty
                    ? ClipOval(child: Image.network(p.photo, fit: BoxFit.cover))
                    : Center(child: Text(p.name[0].toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)))),
              const SizedBox(width: 12),
              Expanded(child: Text(p.name,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
              Text('🃏 ${p.cardCount} cards',
                style: TextStyle(color: Colors.white54, fontSize: 12)),
            ]),
          )),

          const SizedBox(height: 24),
          AppTheme.gradientButton(
            label: _waitingPlayAgain ? 'Waiting for winner...' : '🃏 Play Again',
            onTap: _waitingPlayAgain ? null : _playAgain,
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

  Widget _statRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 13)),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
      ]),
    );
  }

  Future<void> _playAgain() async {
    setState(() => _waitingPlayAgain = true);
    Navigator.pushReplacement(context, MaterialPageRoute(
      builder: (_) => const PassTheCardLobbyScreen()));
  }

  void _goHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()), (_) => false);
  }
}
