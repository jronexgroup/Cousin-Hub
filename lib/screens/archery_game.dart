import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:math';
import 'dart:async';
import '../app_theme.dart';
import '../services/auth_service.dart';
import '../services/cache_service.dart';

// ═══════════════════════════════════════════════════════════
// ARCHERY CHALLENGE — Tap timing multiplayer game
// একজন target set করবে, বাকিরা tap করে aim করবে
// সবচেয়ে কাছে লাগলে জয়
// ═══════════════════════════════════════════════════════════
class ArcheryGameScreen extends StatefulWidget {
  const ArcheryGameScreen({super.key});
  @override
  State<ArcheryGameScreen> createState() => _ArcheryGameScreenState();
}

class _ArcheryGameScreenState extends State<ArcheryGameScreen>
    with TickerProviderStateMixin {
  final _db = FirebaseDatabase.instance;
  final _myUid = AuthService().currentUid ?? '';
  String _myName = '', _myPhoto = '';

  // Game state
  String _roomId = '';
  String _phase = 'lobby'; // lobby→countdown→shooting→results
  Map<String, dynamic> _room = {};
  int _countdown = 3;
  bool _hasShot = false;

  // Target animation
  late AnimationController _targetCtrl;
  late Animation<Offset> _targetPos;

  // Arrow animation
  late AnimationController _arrowCtrl;
  Offset? _arrowHit;

  // Scores
  Map<String, double> _scores = {};

  @override
  void initState() {
    super.initState();
    _initAnims();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final p = await AuthService().getProfile(_myUid);
    if (p != null && mounted) setState(() {
      _myName = p['nickname'] ?? p['name'] ?? 'Cousin';
      _myPhoto = p['photoUrl'] ?? '';
    });
  }

  void _initAnims() {
    _targetCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _arrowCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));

    _targetPos = Tween<Offset>(begin: Offset.zero, end: const Offset(0.3, 0.2))
      .animate(CurvedAnimation(parent: _targetCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _targetCtrl.dispose(); _arrowCtrl.dispose(); super.dispose(); }

  Future<void> _quickPlay() async {
    // Single player practice mode
    setState(() { _phase = 'countdown'; _roomId = 'solo'; });
    _startCountdown();
  }

  Future<void> _createRoom() async {
    final roomId = 'archery_${DateTime.now().millisecondsSinceEpoch}';
    await _db.ref('archeryRooms/$roomId').set({
      'host': _myUid,
      'status': 'waiting',
      'players': {
        _myUid: {'name': _myName, 'photo': _myPhoto, 'score': 0, 'ready': true}
      },
      'round': 1,
      'totalRounds': 5,
      'targetX': 0.5, 'targetY': 0.5,
      'createdAt': ServerValue.timestamp,
    });
    setState(() { _roomId = roomId; _phase = 'waiting'; });
    _listenRoom(roomId);
  }

  void _listenRoom(String roomId) {
    _db.ref('archeryRooms/$roomId').onValue.listen((e) {
      if (!e.snapshot.exists || !mounted) return;
      setState(() => _room = Map<String, dynamic>.from(e.snapshot.value as Map));
      if (_room['status'] == 'playing' && _phase == 'waiting') {
        setState(() => _phase = 'countdown');
        _startCountdown();
      }
      if (_room['status'] == 'results') {
        _showResults();
      }
    });
  }

  void _startCountdown() async {
    for (int i = 3; i >= 1; i--) {
      if (!mounted) return;
      setState(() => _countdown = i);
      HapticFeedback.mediumImpact();
      await Future.delayed(const Duration(seconds: 1));
    }
    if (!mounted) return;
    setState(() { _phase = 'shooting'; _hasShot = false; _arrowHit = null; });
    // Random target movement pattern
    _targetCtrl.repeat(reverse: true);
    // Auto-advance after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && !_hasShot) _shoot(null); // missed!
    });
  }

  void _shoot(Offset? tapPos) {
    if (_hasShot) return;
    HapticFeedback.heavyImpact();
    setState(() { _hasShot = true; _arrowHit = tapPos; });

    // Calculate score based on distance from target center
    double score = 0;
    if (tapPos != null) {
      final size = MediaQuery.of(context).size;
      final targetCenter = Offset(size.width * 0.5, size.height * 0.4);
      final dist = (tapPos - targetCenter).distance;
      final maxDist = size.width * 0.3;
      score = ((1 - (dist / maxDist).clamp(0.0, 1.0)) * 100).roundToDouble();
    }

    _scores[_myUid] = score;

    if (_roomId == 'solo') {
      setState(() => _phase = 'results');
    } else {
      _db.ref('archeryRooms/$_roomId/players/$_myUid').update({'score': score, 'shot': true});
    }
  }

  void _showResults() {
    setState(() => _phase = 'results');
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF0d1b0d),
      appBar: _phase == 'lobby' ? AppBar(
        backgroundColor: const Color(0xFF0d1b0d), elevation: 0,
        title: const Text('🏹 Archery Challenge', style: TextStyle(
          fontWeight: FontWeight.w900, color: Colors.white))) : null,
      body: _buildPhase(size),
    );
  }

  Widget _buildPhase(Size size) {
    switch (_phase) {
      case 'lobby': return _buildLobby();
      case 'waiting': return _buildWaiting();
      case 'countdown': return _buildCountdown();
      case 'shooting': return _buildShooting(size);
      case 'results': return _buildResults();
      default: return _buildLobby();
    }
  }

  Widget _buildLobby() => SafeArea(child: Padding(padding: const EdgeInsets.all(24),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Text('🏹', style: TextStyle(fontSize: 80)),
      const SizedBox(height: 16),
      const Text('Archery Challenge', style: TextStyle(fontSize: 26,
        fontWeight: FontWeight.w900, color: Colors.white)),
      const SizedBox(height: 8),
      const Text('Tap to hit the moving target!\nClosest to center wins 🎯',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white54, fontSize: 14, height: 1.5)),
      const SizedBox(height: 40),
      AppTheme.gradientButton(label: '🏹 Quick Play (Solo)', onTap: _quickPlay, height: 56),
      const SizedBox(height: 16),
      SizedBox(width: double.infinity, height: 52,
        child: OutlinedButton(onPressed: _createRoom,
          style: OutlinedButton.styleFrom(side: const BorderSide(color: AppTheme.primary, width: 2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100))),
          child: const Text('👥 Multiplayer', style: TextStyle(fontSize: 15,
            fontWeight: FontWeight.w700, color: AppTheme.primary)))),
    ])));

  Widget _buildWaiting() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center,
    children: [
    const Text('🏹', style: TextStyle(fontSize: 60, color: Colors.white)),
    const SizedBox(height: 16),
    Text('Room: ${_roomId.split('_').last}', style: const TextStyle(
      color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20)),
    const SizedBox(height: 8),
    const Text('Waiting for cousins...', style: TextStyle(color: Colors.white54)),
  ]));

  Widget _buildCountdown() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center,
    children: [
    const Text('Get Ready!', style: TextStyle(color: Colors.white, fontSize: 22,
      fontWeight: FontWeight.w800)),
    const SizedBox(height: 20),
    TweenAnimationBuilder<double>(
      tween: Tween(begin: 1.5, end: 1.0),
      duration: const Duration(milliseconds: 700),
      builder: (_, scale, child) => Transform.scale(scale: scale, child: child),
      child: Text('$_countdown', style: const TextStyle(
        color: Colors.white, fontSize: 100, fontWeight: FontWeight.w900))),
    const SizedBox(height: 16),
    const Text('Tap the target as close to center as possible!',
      textAlign: TextAlign.center,
      style: TextStyle(color: Colors.white54, fontSize: 14)),
  ]));

  Widget _buildShooting(Size size) {
    return GestureDetector(
      onTapDown: _hasShot ? null : (d) => _shoot(d.globalPosition),
      child: Stack(children: [
        // Forest background
        Container(decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Color(0xFF1a3a1a), Color(0xFF0d1b0d)]))),

        // Target (moving)
        AnimatedBuilder(animation: _targetPos,
          builder: (_, child) {
            final dx = size.width * 0.5 + _targetPos.value.dx * size.width * 0.3;
            final dy = size.height * 0.4 + _targetPos.value.dy * size.height * 0.2;
            return Positioned(left: dx - 60, top: dy - 60, child: child!);
          },
          child: CustomPaint(size: const Size(120, 120), painter: _TargetPainter())),

        // Arrow hit
        if (_arrowHit != null) Positioned(
          left: _arrowHit!.dx - 10,
          top: _arrowHit!.dy - 30,
          child: const Text('🏹', style: TextStyle(fontSize: 28))),

        // Score popup
        if (_hasShot && _scores[_myUid] != null)
          Center(child: Container(padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(gradient: AppTheme.mainGradient,
              borderRadius: BorderRadius.circular(20)),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(_scores[_myUid]! > 70 ? '🎯 Excellent!' :
                _scores[_myUid]! > 40 ? '👍 Good Shot!' : '😅 Missed!',
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text('${_scores[_myUid]!.toInt()} points',
                style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900)),
            ]))),

        // Top HUD
        SafeArea(child: Padding(padding: const EdgeInsets.all(16),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('🏹 Tap to shoot!', style: TextStyle(color: Colors.white70, fontSize: 14)),
            if (!_hasShot) const Text('5s', style: TextStyle(color: Colors.red,
              fontSize: 18, fontWeight: FontWeight.w900)),
          ]))),
      ]));
  }

  Widget _buildResults() {
    final score = _scores[_myUid] ?? 0;
    final stars = score > 80 ? 3 : score > 50 ? 2 : score > 20 ? 1 : 0;

    return Center(child: Padding(padding: const EdgeInsets.all(24),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(List.generate(3, (i) => i < stars ? '⭐' : '☆').join(),
        style: const TextStyle(fontSize: 40)),
      const SizedBox(height: 16),
      Container(padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(gradient: AppTheme.mainGradient, borderRadius: BorderRadius.circular(20)),
        child: Column(children: [
          Text(score > 80 ? '🎯 Bullseye!' : score > 50 ? '👍 Great Shot!' :
            score > 20 ? '😅 Close enough!' : '🙈 Missed!',
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text('${score.toInt()} / 100 points',
            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)),
        ])),
      const SizedBox(height: 24),
      AppTheme.gradientButton(label: '🔄 Play Again', onTap: () {
        setState(() { _phase = 'lobby'; _hasShot = false; _scores.clear(); });
      }),
      const SizedBox(height: 12),
      TextButton(onPressed: () {
        if (_roomId != 'solo') _db.ref('archeryRooms/$_roomId').remove();
        Navigator.pop(context);
      }, child: const Text('← Back to Games', style: TextStyle(color: Colors.white54))),
    ])));
  }
}

class _TargetPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, cy = size.height / 2;
    final rings = [
      {'r': 60.0, 'color': const Color(0xFFFFFFFF)},
      {'r': 48.0, 'color': const Color(0xFF000000)},
      {'r': 36.0, 'color': const Color(0xFF1565C0)},
      {'r': 24.0, 'color': const Color(0xFFC62828)},
      {'r': 12.0, 'color': const Color(0xFFFFEB3B)},
    ];
    for (final ring in rings) {
      canvas.drawCircle(Offset(cx, cy), ring['r'] as double,
        Paint()..color = ring['color'] as Color);
      canvas.drawCircle(Offset(cx, cy), ring['r'] as double,
        Paint()..color = Colors.black12..style = PaintingStyle.stroke..strokeWidth = 1);
    }
  }
  @override bool shouldRepaint(_) => false;
}
