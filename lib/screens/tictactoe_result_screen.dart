import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../app_theme.dart';
import 'home_screen.dart';

class TicTacToeResultScreen extends StatefulWidget {
  final String matchId, myUid, opponentName;
  final int winner, myPlayer;
  const TicTacToeResultScreen({
    super.key, required this.matchId, required this.myUid,
    required this.winner, required this.myPlayer,
    required this.opponentName,
  });
  @override
  State<TicTacToeResultScreen> createState() => _TicTacToeResultState();
}

class _TicTacToeResultState extends State<TicTacToeResultScreen> {
  final _db = FirebaseDatabase.instance;

  void _goHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()), (route) => false);
  }

  Future<void> _rematch() async {
    await _db.ref('ticTacToeMatches/${widget.matchId}').update({
      'board': [0, 0, 0, 0, 0, 0, 0, 0, 0],
      'currentTurn': 1,
      'winner': 0,
      'status': 'playing',
      'lastMoveAt': ServerValue.timestamp,
    });
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isWin = widget.winner == widget.myPlayer;
    final isDraw = widget.winner == -1;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A1A), elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: _goHome),
        title: const Text('❌ Result', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white))),
      body: SafeArea(child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          const Spacer(flex: 2),
          Text(isDraw ? '🤝' : isWin ? '🎉' : '😔', style: const TextStyle(fontSize: 80)),
          const SizedBox(height: 16),
          Text(
            isDraw ? 'Draw!' : isWin ? 'You Won!' : 'You Lost',
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white)),
          const SizedBox(height: 8),
          Text(
            isDraw ? 'No one wins this time' : isWin
                ? 'Great game against ${widget.opponentName}!'
                : '${widget.opponentName} beat you this time',
            style: const TextStyle(color: Colors.white54, fontSize: 14),
            textAlign: TextAlign.center),
          const Spacer(flex: 2),
          SizedBox(
            width: double.infinity,
            child: AppTheme.gradientButton(
              label: '🔄 Play Again',
              onTap: _rematch,
              height: 52)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _goHome,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white24),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                padding: const EdgeInsets.symmetric(vertical: 14)),
              child: const Text('🏠 Back to Home',
                style: TextStyle(color: Colors.white54, fontWeight: FontWeight.w700))),
          ),
          const Spacer(flex: 1),
        ]),
      )),
    );
  }
}
