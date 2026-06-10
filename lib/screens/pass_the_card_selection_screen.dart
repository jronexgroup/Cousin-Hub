import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../app_theme.dart';
import 'pass_the_card_game_screen.dart';
import 'pass_the_card_models.dart';

class PassTheCardSelectionScreen extends StatefulWidget {
  final String roomId, myUid, myName, myPhoto;
  final bool isHost;

  const PassTheCardSelectionScreen({
    super.key,
    required this.roomId,
    required this.myUid,
    required this.myName,
    required this.myPhoto,
    this.isHost = false,
  });

  @override
  State<PassTheCardSelectionScreen> createState() => _PassTheCardSelectionState();
}

class _PassTheCardSelectionState extends State<PassTheCardSelectionScreen> {
  final _db = FirebaseDatabase.instance;
  StreamSubscription? _sub;
  Timer? _timer;
  int _secondsLeft = kSelectionTimeSec;
  final Set<int> _myPicks = {};
  final Set<int> _takenPositions = {};
  bool _confirmed = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
    _listenRoom();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) {
        t.cancel();
        _confirmSelection();
      }
    });
  }

  void _listenRoom() {
    _sub = _db.ref('passTheCardRooms/${widget.roomId}').onValue.listen((e) {
      if (!e.snapshot.exists || !mounted) return;
      final d = Map<String, dynamic>.from(e.snapshot.value as Map);
      final st = d['status'] as String? ?? 'waiting';

      if (st == 'playing') {
        _sub?.cancel();
        _timer?.cancel();
        Navigator.pushReplacement(context, MaterialPageRoute(
          builder: (_) => PassTheCardGameScreen(
            roomId: widget.roomId, myUid: widget.myUid,
            myName: widget.myName, myPhoto: widget.myPhoto,
            isHost: widget.isHost)));
        return;
      }

      final sel = d['selectedPositions'] as Map? ?? {};
      final taken = <int>{};
      for (final entry in sel.entries) {
        if (entry.key != widget.myUid && entry.value is List) {
          for (final pos in (entry.value as List).cast<num>()) {
            taken.add(pos.toInt());
          }
        }
      }
      setState(() => _takenPositions.addAll(taken));
    });
  }

  void _togglePick(int pos) {
    if (_confirmed) return;
    setState(() {
      if (_myPicks.contains(pos)) {
        _myPicks.remove(pos);
      } else if (_myPicks.length < kHandSize) {
        _myPicks.add(pos);
      }
    });
    if (_myPicks.length >= kHandSize) {
      _confirmSelection();
    }
  }

  Future<void> _confirmSelection() async {
    if (_confirmed) return;
    setState(() => _confirmed = true);
    _timer?.cancel();
    if (_myPicks.length < kHandSize) return;

    await _db.ref('passTheCardRooms/${widget.roomId}/selectedPositions/${widget.myUid}')
        .set(_myPicks.toList()..sort());
  }

  @override
  void dispose() {
    _sub?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A1A), elevation: 0,
        leading: const SizedBox(), // no back
        title: const Text('🃏 Pick Your Cards',
          style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white))),
      body: Column(children: [
        Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.primary.withOpacity(0.4))),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Tap 4 cards to collect', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('${_myPicks.length}/4 selected  •  ${_secondsLeft}s left',
                style: TextStyle(color: _secondsLeft <= 5 ? Colors.redAccent : Colors.white70, fontSize: 12)),
            ])),
            SizedBox(
              width: 52, height: 52,
              child: Stack(alignment: Alignment.center, children: [
                SizedBox(width: 48, height: 48,
                  child: CircularProgressIndicator(
                    value: _secondsLeft / kSelectionTimeSec,
                    color: _secondsLeft <= 5 ? Colors.redAccent : AppTheme.primary,
                    strokeWidth: 4, backgroundColor: Colors.white12)),
                Text('$_secondsLeft',
                  style: TextStyle(
                    color: _secondsLeft <= 5 ? Colors.redAccent : Colors.white,
                    fontWeight: FontWeight.w900, fontSize: 16)),
              ])),
          ])),
        Expanded(child: LayoutBuilder(builder: (_, c) {
          final gap = 8.0;
          final cols = 4;
          final w = (c.maxWidth - 24 - gap * (cols - 1)) / cols;
          final h = w * 1.3;
          return Center(
            child: Wrap(
              spacing: gap, runSpacing: gap,
              alignment: WrapAlignment.center,
              children: List.generate(kTotalCards, (i) {
                final taken = _takenPositions.contains(i);
                final picked = _myPicks.contains(i);
                return GestureDetector(
                  onTap: taken ? null : () => _togglePick(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: w, height: h,
                    decoration: BoxDecoration(
                      color: taken ? Colors.grey.shade800
                          : picked ? AppTheme.primary.withOpacity(0.3)
                                  : const Color(0xFF1A1A2E),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: picked ? AppTheme.primary
                            : taken ? Colors.red.shade900
                                    : Colors.white12,
                        width: picked ? 3 : 1)),
                    child: Center(
                      child: taken
                          ? const Icon(Icons.close, color: Colors.red, size: 28)
                          : picked
                              ? const Icon(Icons.check, color: Colors.white, size: 28)
                              : Text('${i + 1}',
                                  style: TextStyle(
                                    color: Colors.white38, fontSize: 20,
                                    fontWeight: FontWeight.w800)),
                    ),
                  ),
                );
              }),
            ),
          );
        })),
        if (_confirmed)
          Container(
            padding: const EdgeInsets.all(16),
            child: const Text('Waiting for other players...',
              style: TextStyle(color: Colors.white54, fontSize: 14)),
          ),
        const SizedBox(height: 16),
      ]),
    );
  }
}
