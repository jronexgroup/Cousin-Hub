import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';
import '../app_theme.dart';
import 'home_screen.dart';
import 'tictactoe_result_screen.dart';

class TicTacToeGameScreen extends StatefulWidget {
  final String matchId, myUid, opponentName, opponentPhoto;
  final int player; // 1=host(X), 2=guest(O)
  final bool isHost;
  const TicTacToeGameScreen({
    super.key, required this.matchId, required this.myUid,
    required this.player, required this.opponentName,
    required this.opponentPhoto, required this.isHost,
  });
  @override
  State<TicTacToeGameScreen> createState() => _TicTacToeGameState();
}

class _TicTacToeGameState extends State<TicTacToeGameScreen> {
  final _db = FirebaseDatabase.instance;
  List<int> _board = [0, 0, 0, 0, 0, 0, 0, 0, 0];
  int _winner = 0;
  bool _myTurn = false;
  bool _started = false;
  StreamSubscription? _sub;

  static const _winPatterns = [
    [0,1,2],[3,4,5],[6,7,8],
    [0,3,6],[1,4,7],[2,5,8],
    [0,4,8],[2,4,6],
  ];

  @override
  void initState() {
    super.initState();
    _sub = _db.ref('ticTacToeMatches/${widget.matchId}').onValue.listen((e) {
      if (!e.snapshot.exists || !mounted) return;
      final data = Map<String, dynamic>.from(e.snapshot.value as Map);
      final board = (data['board'] as List).cast<int>();
      final turn = data['currentTurn'] as int? ?? 1;
      final winner = data['winner'] as int? ?? 0;
      final status = data['status'] as String? ?? 'waiting';
      setState(() {
        _board = board;
        _winner = winner;
        _started = status == 'playing';
        _myTurn = status == 'playing' && turn == widget.player && winner == 0;
      });

      if (winner != 0 && mounted && !_navigated) {
        _navigated = true;
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(
            builder: (_) => TicTacToeResultScreen(
              matchId: widget.matchId,
              myUid: widget.myUid,
              winner: winner,
              myPlayer: widget.player,
              opponentName: widget.opponentName,
            )));
        });
      }
    });
  }
  bool _navigated = false;

  @override
  void dispose() { _sub?.cancel(); super.dispose(); }

  Future<void> _tap(int idx) async {
    if (!_myTurn || _board[idx] != 0 || _winner != 0) return;
    final newBoard = [..._board];
    newBoard[idx] = widget.player;

    final opponent = widget.player == 1 ? 2 : 1;
    int winner = 0;
    for (final p in _winPatterns) {
      if (newBoard[p[0]] == newBoard[p[1]] && newBoard[p[1]] == newBoard[p[2]] && newBoard[p[0]] != 0) {
        winner = newBoard[p[0]];
        break;
      }
    }
    if (winner == 0 && !newBoard.any((c) => c == 0)) winner = -1; // draw

    await _db.ref('ticTacToeMatches/${widget.matchId}').update({
      'board': newBoard,
      'currentTurn': opponent,
      'winner': winner,
      'status': winner != 0 ? 'finished' : 'playing',
      'lastMoveAt': ServerValue.timestamp,
    });
  }

  String get _statusText {
    if (_winner == -1) return 'Draw!';
    if (_winner != 0) return _winner == widget.player ? 'You Won! 🎉' : 'You Lost 😔';
    if (!_started) return 'Waiting for opponent...';
    return _myTurn ? 'Your Turn' : '${widget.opponentName}\'s Turn';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A1A), elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const HomeScreen()), (route) => false)),
        title: const Text('❌ Tic Tac Toe',
          style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white))),
      body: SafeArea(child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          // Opponent info
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _avatar(widget.opponentPhoto, widget.opponentName, widget.player == 2),
            const Padding(padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text('VS', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white54))),
            _avatar('', 'You', widget.player == 1),
          ]),
          const SizedBox(height: 8),

          // Turn indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: _myTurn ? AppTheme.primary.withOpacity(0.15) : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(100),
              border: Border.all(
                color: _myTurn ? AppTheme.primary : Colors.white12,
                width: 1.5)),
            child: Text(_statusText,
              style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w800,
                color: _myTurn ? AppTheme.primary : Colors.white54)),
          ),
          const SizedBox(height: 20),

          // Board
          Expanded(child: Center(child: Container(
            width: 300, height: 300,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12, width: 2)),
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 2, crossAxisSpacing: 2),
              itemCount: 9,
              itemBuilder: (_, i) => GestureDetector(
                onTap: () => _tap(i),
                child: Container(
                  decoration: BoxDecoration(
                    color: _board[i] == 0
                        ? const Color(0xFF1A1A2E)
                        : _board[i] == 1
                            ? const Color(0xFF2D1B69).withOpacity(0.8)
                            : const Color(0xFF1B3A2D).withOpacity(0.8),
                    border: Border.all(color: Colors.white10, width: 0.5)),
                  child: Center(child: Text(
                    _board[i] == 0 ? '' : _board[i] == 1 ? 'X' : 'O',
                    style: TextStyle(
                      fontSize: 52, fontWeight: FontWeight.w900,
                      color: _board[i] == 1
                          ? const Color(0xFF7C3AED)
                          : const Color(0xFF4CAF50)))))
            ))))),

          // Player legend
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _playerTile('X', const Color(0xFF7C3AED), widget.isHost ? 'You' : widget.opponentName),
              const SizedBox(width: 24),
              _playerTile('O', const Color(0xFF4CAF50), widget.isHost ? widget.opponentName : 'You'),
            ]),
          ),
          const SizedBox(height: 16),
        ]),
      )),
    );
  }

  Widget _avatar(String photo, String name, bool isX) => Column(children: [
    Container(
      width: 48, height: 48,
      decoration: BoxDecoration(
        gradient: AppTheme.mainGradient,
        shape: BoxShape.circle,
        border: Border.all(color: isX ? const Color(0xFF7C3AED) : const Color(0xFF4CAF50), width: 3)),
      child: photo.isNotEmpty
          ? ClipOval(child: Image.network(photo, fit: BoxFit.cover))
          : Center(child: Text(name[0].toUpperCase(),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20)))),
    const SizedBox(height: 4),
    Text(name, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
  ]);

  Widget _playerTile(String icon, Color color, String name) => Row(children: [
    Container(width: 24, height: 24,
      decoration: BoxDecoration(color: color.withOpacity(0.2), shape: BoxShape.circle),
      child: Center(child: Text(icon, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w900)))),
    const SizedBox(width: 6),
    Text(name, style: const TextStyle(color: Colors.white54, fontSize: 12)),
  ]);
}
