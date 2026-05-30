import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:math';
import 'dart:async';
import '../app_theme.dart';
import '../services/auth_service.dart';
import '../services/cache_service.dart';

// ═══════════════════════════════════════════════════════════
// COUSIN RACER — Multiplayer Endless Runner
// ═══════════════════════════════════════════════════════════

const double kRaceDistance = 2000.0; // Total race distance in meters
const double kLaneWidth = 80.0;
const double kGameSpeed = 180.0; // pixels/sec base speed
const double kPenaltySecs = 4.0; // seconds penalty on crash
const int kMaxPlayers = 5;

class RacerLobbyScreen extends StatefulWidget {
  const RacerLobbyScreen({super.key});
  @override
  State<RacerLobbyScreen> createState() => _RacerLobbyScreenState();
}

class _RacerLobbyScreenState extends State<RacerLobbyScreen> {
  final _db = FirebaseDatabase.instance;
  List<Map<String, dynamic>> _cousins = [];
  final List<String> _selected = [];
  bool _loading = false;
  String _myUid = '', _myName = '', _myPhoto = '';

  @override
  void initState() { super.initState(); _init(); }

  Future<void> _init() async {
    _myUid = AuthService().currentUid ?? '';
    final p = await AuthService().getProfile(_myUid);
    if (p != null && mounted) setState(() {
      _myName = p['nickname'] ?? p['name'] ?? 'Cousin';
      _myPhoto = p['photoUrl'] ?? '';
    });
    final cached = CacheService.loadAllUsers();
    if (cached != null) {
      final list = cached.entries.where((e) => e.key != _myUid).map((e) {
        final u = Map<String, dynamic>.from(e.value as Map);
        u['uid'] = e.key; return u;
      }).toList()..sort((a,b) => (a['name']??'').compareTo(b['name']??''));
      if (mounted) setState(() => _cousins = list);
    }
  }

  void _toggle(String uid) => setState(() {
    if (_selected.contains(uid)) _selected.remove(uid);
    else if (_selected.length < kMaxPlayers - 1) _selected.add(uid);
  });

  Future<void> _createRoom() async {
    setState(() => _loading = true);
    final roomId = 'race_${DateTime.now().millisecondsSinceEpoch}';
    final all = [_myUid, ..._selected];

    final avatarColors = [0xFFE53935, 0xFF1E88E5, 0xFF43A047, 0xFFFF9800, 0xFF9C27B0];
    final playersMap = <String, dynamic>{};

    for (int i = 0; i < all.length; i++) {
      final uid = all[i];
      final isMe = uid == _myUid;
      Map<String, dynamic> prof;
      if (isMe) {
        prof = {'name': _myName, 'photoUrl': _myPhoto};
      } else {
        final c = CacheService.loadAllUsers();
        final d = c?[uid];
        prof = d != null ? Map<String, dynamic>.from(d as Map) : {'name': 'Cousin', 'photoUrl': ''};
      }
      playersMap[uid] = {
        'name': prof['nickname'] ?? prof['name'] ?? 'Cousin',
        'photo': prof['photoUrl'] ?? '',
        'color': avatarColors[i % avatarColors.length],
        'lane': i,
        'distance': 0.0,
        'speed': kGameSpeed,
        'penalty': 0,
        'penaltyEnd': 0,
        'status': isMe ? 'ready' : 'pending',
        'finished': false,
        'rank': 0,
      };
    }

    await _db.ref('raceRooms/$roomId').set({
      'host': _myUid, 'status': 'waiting',
      'players': playersMap, 'totalDistance': kRaceDistance,
      'startTime': 0, 'createdAt': ServerValue.timestamp,
    });

    // Send invites
    for (final uid in _selected) {
      await _db.ref('raceInvites/$uid/$roomId').set({
        'roomId': roomId, 'hostName': _myName,
        'hostPhoto': _myPhoto, 'timestamp': ServerValue.timestamp,
      });
      final ts = await _db.ref('users/$uid/fcmToken').get();
      if (ts.exists) await _db.ref('notifications').push().set({
        'toToken': ts.value, 'title': '🏃 Race Invite!',
        'body': '$_myName wants to race with you!',
        'sent': false, 'timestamp': ServerValue.timestamp,
      });
    }

    setState(() => _loading = false);
    if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(
      builder: (_) => RaceWaitingScreen(roomId: roomId, isHost: true)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      appBar: AppBar(backgroundColor: const Color(0xFF0A0A1A), elevation: 0,
        title: const Text('🏃 Cousin Racer', style: TextStyle(fontSize: 20,
          fontWeight: FontWeight.w900, color: Colors.white))),
      body: Column(children: [
        // Info card
        Container(margin: const EdgeInsets.all(16), padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF1A1A3E), Color(0xFF2D1B69)]),
            borderRadius: BorderRadius.circular(20)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('🏁 Endless Runner Race', style: TextStyle(fontSize: 16,
              fontWeight: FontWeight.w800, color: Colors.white)),
            const SizedBox(height: 8),
            Row(children: [
              _infoChip('🏃 ${_selected.length + 1} players'),
              const SizedBox(width: 8),
              _infoChip('📏 ${kRaceDistance.toInt()}m race'),
              const SizedBox(width: 8),
              _infoChip('⚠️ ${kPenaltySecs.toInt()}s penalty'),
            ]),
            const SizedBox(height: 8),
            const Text('Hit obstacles → 4s penalty\nFirst to 2000m wins! 🏆',
              style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.5)),
          ])),

        Expanded(child: _cousins.isEmpty
          ? const Center(child: CircularProgressIndicator(color: Colors.purple))
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _cousins.length,
              itemBuilder: (_, i) {
                final c = _cousins[i];
                final uid = c['uid'] as String;
                final selected = _selected.contains(uid);
                final idx = _selected.indexOf(uid);
                final photo = c['photoUrl'] ?? '';
                final name = c['nickname'] ?? c['name'] ?? 'Cousin';
                final colors = [Colors.blue, Colors.green, Colors.orange, Colors.purple];

                return GestureDetector(onTap: () => _toggle(uid),
                  child: AnimatedContainer(duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: selected ? colors[idx % colors.length].withOpacity(0.15) : const Color(0xFF1A1A2E),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: selected ? colors[idx % colors.length] : Colors.grey.shade800,
                        width: selected ? 2 : 1)),
                    child: Row(children: [
                      Container(width: 44, height: 44, decoration: BoxDecoration(
                        color: selected ? colors[idx % colors.length] : Colors.grey.shade700,
                        shape: BoxShape.circle),
                        child: photo.isNotEmpty
                          ? ClipOval(child: Image.network(photo, fit: BoxFit.cover))
                          : Center(child: Text(name[0].toUpperCase(),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18)))),
                      const SizedBox(width: 12),
                      Expanded(child: Text(name, style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white))),
                      if (selected) Container(width: 28, height: 28,
                        decoration: BoxDecoration(color: colors[idx % colors.length], shape: BoxShape.circle),
                        child: const Icon(Icons.check, color: Colors.white, size: 16))
                      else Container(width: 28, height: 28, decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade700, width: 2),
                        shape: BoxShape.circle)),
                    ])));
              })),

        Container(padding: const EdgeInsets.all(16), color: const Color(0xFF0A0A1A),
          child: SafeArea(child: AppTheme.gradientButton(
            label: _selected.isEmpty ? 'Select cousins to race' :
              '🏁 Start Race (${_selected.length + 1} players)',
            loading: _loading,
            onTap: _selected.isEmpty ? null : _createRoom, height: 56))),
      ]),
    );
  }

  Widget _infoChip(String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(100)),
    child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w700)));
}

// ═══════════════════════════════════════════════════════════
// RACE WAITING SCREEN
// ═══════════════════════════════════════════════════════════
class RaceWaitingScreen extends StatefulWidget {
  final String roomId;
  final bool isHost;
  const RaceWaitingScreen({super.key, required this.roomId, required this.isHost});
  @override
  State<RaceWaitingScreen> createState() => _RaceWaitingScreenState();
}

class _RaceWaitingScreenState extends State<RaceWaitingScreen> {
  final _db = FirebaseDatabase.instance;
  Map<String, dynamic> _room = {};
  final _myUid = AuthService().currentUid ?? '';

  @override
  void initState() {
    super.initState();
    _db.ref('raceRooms/${widget.roomId}').onValue.listen((e) {
      if (!e.snapshot.exists || !mounted) return;
      final room = Map<String, dynamic>.from(e.snapshot.value as Map);
      setState(() => _room = room);
      if (room['status'] == 'playing') {
        Navigator.pushReplacement(context, MaterialPageRoute(
          builder: (_) => RaceGameScreen(roomId: widget.roomId)));
      }
    });
  }

  Future<void> _start() async {
    await _db.ref('raceRooms/${widget.roomId}').update({
      'status': 'playing',
      'startTime': ServerValue.timestamp,
    });
  }

  @override
  Widget build(BuildContext context) {
    final players = _room['players'] != null
      ? Map<String, dynamic>.from(_room['players'] as Map) : <String, dynamic>{};
    final joined = players.values.where((p) =>
      (Map<String, dynamic>.from(p as Map))['status'] == 'ready').length;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      appBar: AppBar(backgroundColor: const Color(0xFF0A0A1A), elevation: 0,
        title: const Text('Race Lobby 🏁', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white)),
        actions: [TextButton(onPressed: () {
          _db.ref('raceRooms/${widget.roomId}').remove();
          Navigator.pop(context);
        }, child: const Text('Cancel', style: TextStyle(color: Colors.red)))]),
      body: Padding(padding: const EdgeInsets.all(20), child: Column(children: [
        Container(width: double.infinity, padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF1A1A3E), Color(0xFF2D1B69)]),
            borderRadius: BorderRadius.circular(20)),
          child: Column(children: [
            const Text('🏁', style: TextStyle(fontSize: 50)),
            const SizedBox(height: 8),
            Text('$joined/${players.length} Ready', style: const TextStyle(
              fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
          ])),
        const SizedBox(height: 20),
        Expanded(child: ListView(children: players.entries.map((e) {
          final p = Map<String, dynamic>.from(e.value as Map);
          final isMe = e.key == _myUid;
          final ready = p['status'] == 'ready';
          return Container(margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ready ? Colors.green : Colors.grey.shade800,
                width: ready ? 2 : 1)),
            child: Row(children: [
              Container(width: 10, height: 10, margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(shape: BoxShape.circle,
                  color: Color((p['color'] ?? 0xFFE53935) as int))),
              Container(width: 40, height: 40,
                decoration: BoxDecoration(
                  color: Color((p['color'] ?? 0xFFE53935) as int), shape: BoxShape.circle),
                child: (p['photo'] ?? '').isNotEmpty
                  ? ClipOval(child: Image.network(p['photo'], fit: BoxFit.cover))
                  : Center(child: Text((p['name'] ?? '?')[0],
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)))),
              const SizedBox(width: 10),
              Expanded(child: Text('${p['name'] ?? 'Cousin'}${isMe ? ' (You)' : ''}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white))),
              Text(ready ? '✅ Ready' : '⏳ Joining...',
                style: TextStyle(fontSize: 12, color: ready ? Colors.green : Colors.grey.shade500)),
            ]));
        }).toList())),
        if (widget.isHost)
          AppTheme.gradientButton(
            label: joined >= 2 ? '🏁 Start Race!' : 'Waiting...',
            onTap: joined >= 2 ? _start : null, height: 56)
        else
          const Text('Waiting for host to start...', style: TextStyle(color: Colors.white54)),
        const SizedBox(height: 16),
      ])));
  }
}

// ═══════════════════════════════════════════════════════════
// RACE GAME SCREEN — THE ACTUAL GAME
// ═══════════════════════════════════════════════════════════
class RaceGameScreen extends StatefulWidget {
  final String roomId;
  const RaceGameScreen({super.key, required this.roomId});
  @override
  State<RaceGameScreen> createState() => _RaceGameScreenState();
}

class _RaceGameScreenState extends State<RaceGameScreen> with TickerProviderStateMixin {
  final _db = FirebaseDatabase.instance;
  final _myUid = AuthService().currentUid ?? '';

  // Game state
  Map<String, dynamic> _room = {};
  bool _gameOver = false;
  bool _started = false;
  int _countdown = 3;

  // My player state (local, synced to Firebase periodically)
  double _myDistance = 0;
  double _mySpeed = kGameSpeed;
  bool _inPenalty = false;
  DateTime? _penaltyEnd;
  bool _jumping = false;
  bool _sliding = false;
  int _myLane = 0;
  int _coinsCollected = 0;

  // Game world
  final Random _rng = Random();
  final List<_Obstacle> _obstacles = [];
  final List<_Coin> _coins = [];
  double _worldOffset = 0;
  double _bgOffset = 0;

  // Animation
  late AnimationController _runAnim;
  late AnimationController _jumpAnim;
  late Animation<double> _jumpHeight;
  Timer? _gameLoop;
  Timer? _syncTimer;
  DateTime? _lastFrame;

  // Firebase listener
  Map<String, dynamic> _remotePlayers = {};

  @override
  void initState() {
    super.initState();
    _runAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 300))..repeat(reverse: true);
    _jumpAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _jumpHeight = Tween<double>(begin: 0, end: -80).animate(CurvedAnimation(parent: _jumpAnim, curve: Curves.easeOut));

    _listenRoom();
    _startCountdown();
  }

  void _listenRoom() {
    _db.ref('raceRooms/${widget.roomId}').onValue.listen((e) {
      if (!e.snapshot.exists || !mounted) return;
      final room = Map<String, dynamic>.from(e.snapshot.value as Map);
      setState(() { _room = room; });
      if (room['status'] == 'finished' && !_gameOver) {
        setState(() => _gameOver = true);
        _showResults();
      }
      // Update remote players
      final players = room['players'] as Map? ?? {};
      _remotePlayers = Map<String, dynamic>.from(players);
      final me = players[_myUid];
      if (me != null) {
        final mep = Map<String, dynamic>.from(me as Map);
        _myLane = (mep['lane'] ?? 0) as int;
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
    setState(() { _countdown = 0; _started = true; });
    HapticFeedback.heavyImpact();
    _startGameLoop();
  }

  void _startGameLoop() {
    _lastFrame = DateTime.now();
    _spawnInitialObstacles();
    _spawnInitialCoins();

    _gameLoop = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!mounted || _gameOver) return;
      final now = DateTime.now();
      final dt = now.difference(_lastFrame!).inMilliseconds / 1000.0;
      _lastFrame = now;
      _updateGame(dt);
    });

    // Sync to Firebase every 200ms
    _syncTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!_gameOver) _syncMyState();
    });
  }

  void _updateGame(double dt) {
    if (_gameOver || !_started) return;

    // Check penalty
    if (_inPenalty && _penaltyEnd != null) {
      if (DateTime.now().isAfter(_penaltyEnd!)) {
        _inPenalty = false;
        _mySpeed = kGameSpeed + (_myDistance / 200); // speed increases with distance
      }
    }

    if (!_inPenalty) {
      // Move forward
      final speedBoost = 1.0 + (_coinsCollected * 0.02); // coins give small boost
      final moveBy = _mySpeed * speedBoost * dt;
      _myDistance += moveBy;
      _worldOffset += moveBy;
      _bgOffset += moveBy * 0.3; // parallax background

      // Check win
      if (_myDistance >= kRaceDistance && !_gameOver) {
        _finishRace();
        return;
      }
    }

    // Update obstacles
    for (final obs in _obstacles) { obs.x -= _mySpeed * dt; }
    _obstacles.removeWhere((o) => o.x < -100);

    // Update coins
    for (final coin in _coins) { coin.x -= _mySpeed * dt; }
    _coins.removeWhere((c) => c.x < -50 || c.collected);

    // Spawn new obstacles
    if (_obstacles.isEmpty || _obstacles.last.x < 400) {
      _spawnObstacle();
    }

    // Spawn coins
    if (_coins.where((c) => !c.collected).length < 5) {
      _spawnCoin();
    }

    // Collision detection
    _checkCollisions();

    setState(() {});
  }

  void _spawnInitialObstacles() {
    for (int i = 0; i < 3; i++) {
      _spawnObstacleAt(500.0 + i * 300);
    }
  }

  void _spawnInitialCoins() {
    for (int i = 0; i < 8; i++) {
      _spawnCoinAt(300.0 + i * 120);
    }
  }

  void _spawnObstacle() {
    _spawnObstacleAt(MediaQuery.of(context).size.width + 200 + _rng.nextDouble() * 200);
  }

  void _spawnObstacleAt(double x) {
    final types = ['barrier', 'spike', 'block'];
    final type = types[_rng.nextInt(types.length)];
    final height = type == 'barrier' ? 40.0 : type == 'spike' ? 30.0 : 50.0;
    _obstacles.add(_Obstacle(x: x, type: type, height: height));
  }

  void _spawnCoin() {
    _spawnCoinAt(MediaQuery.of(context).size.width + 100 + _rng.nextDouble() * 150);
  }

  void _spawnCoinAt(double x) {
    _coins.add(_Coin(x: x, y: _rng.nextBool() ? -30.0 : -70.0));
  }

  void _checkCollisions() {
    if (_jumping && _jumpHeight.value < -35) return; // jumping over obstacles
    if (_sliding) return; // sliding under some obstacles

    const playerLeft = 80.0;
    const playerRight = 120.0;
    const playerBottom = 0.0;
    const playerTop = -60.0;

    for (final obs in _obstacles) {
      final obsRight = obs.x + obs.width;
      final obsTop = -obs.height;

      if (playerRight > obs.x && playerLeft < obsRight &&
          playerBottom > obsTop && !_inPenalty) {
        _triggerPenalty();
        break;
      }
    }

    // Collect coins
    for (final coin in _coins) {
      if (!coin.collected &&
          (100 - coin.x).abs() < 30 &&
          (-30 - coin.y).abs() < 30) {
        coin.collected = true;
        _coinsCollected++;
        HapticFeedback.lightImpact();
      }
    }
  }

  void _triggerPenalty() {
    HapticFeedback.heavyImpact();
    setState(() {
      _inPenalty = true;
      _penaltyEnd = DateTime.now().add(Duration(seconds: kPenaltySecs.toInt()));
      _mySpeed = 0;
      _jumping = false;
    });
    // Push back 3 seconds worth of distance
    _myDistance -= kGameSpeed * 3;
    if (_myDistance < 0) _myDistance = 0;
    _db.ref('raceRooms/${widget.roomId}/players/$_myUid/penalty').set(
      DateTime.now().millisecondsSinceEpoch + (kPenaltySecs * 1000).toInt());
  }

  void _finishRace() async {
    final players = _remotePlayers;
    final finishedCount = players.values.where((p) =>
      (Map<String, dynamic>.from(p as Map))['finished'] == true).length;
    final myRank = finishedCount + 1;

    await _db.ref('raceRooms/${widget.roomId}/players/$_myUid').update({
      'finished': true, 'rank': myRank, 'distance': kRaceDistance,
    });

    // Check if everyone finished
    if (myRank >= (players.length)) {
      await _db.ref('raceRooms/${widget.roomId}').update({'status': 'finished'});
    }
    setState(() => _gameOver = true);
    _showResults();
  }

  void _syncMyState() {
    _db.ref('raceRooms/${widget.roomId}/players/$_myUid').update({
      'distance': _myDistance.clamp(0, kRaceDistance),
      'speed': _mySpeed,
      'inPenalty': _inPenalty,
    });
  }

  void _jump() {
    if (_jumping || _inPenalty || !_started) return;
    HapticFeedback.mediumImpact();
    setState(() => _jumping = true);
    _jumpAnim.forward().then((_) {
      _jumpAnim.reverse().then((_) => setState(() => _jumping = false));
    });
  }

  void _slide() {
    if (_sliding || _inPenalty || !_started) return;
    HapticFeedback.lightImpact();
    setState(() => _sliding = true);
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _sliding = false);
    });
  }

  void _showResults() {
    _gameLoop?.cancel();
    _syncTimer?.cancel();
    showDialog(context: context, barrierDismissible: false, builder: (_) => _ResultsDialog(
      roomId: widget.roomId, myUid: _myUid,
      myDistance: _myDistance, myCoins: _coinsCollected,
      onClose: () {
        _db.ref('raceRooms/${widget.roomId}').remove();
        Navigator.of(context).popUntil((r) => r.isFirst);
      }));
  }

  @override
  void dispose() {
    _gameLoop?.cancel(); _syncTimer?.cancel();
    _runAnim.dispose(); _jumpAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final players = _room['players'] != null
      ? Map<String, dynamic>.from(_room['players'] as Map) : <String, dynamic>{};

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapDown: (_) => _jump(),
        onVerticalDragDown: (d) { if (d.globalPosition.dy > size.height * 0.6) _slide(); },
        child: Stack(children: [

          // ── BACKGROUND ──────────────────────────────────────
          CustomPaint(size: size, painter: _BackgroundPainter(
            offset: _bgOffset % (size.width * 2))),

          // ── RACE TRACKS (one per player) ────────────────────
          ...players.entries.map((e) {
            final uid = e.key;
            final p = Map<String, dynamic>.from(e.value as Map);
            final lane = (p['lane'] ?? 0) as int;
            final isMe = uid == _myUid;
            final distance = isMe ? _myDistance :
              ((p['distance'] ?? 0.0) as num).toDouble();
            final inPen = isMe ? _inPenalty : (p['inPenalty'] == true);
            final color = Color((p['color'] ?? 0xFFE53935) as int);

            return _RaceLane(
              lane: lane, totalLanes: players.length,
              playerName: isMe ? 'You' : (p['name'] ?? 'Cousin'),
              playerPhoto: p['photo'] ?? '',
              playerColor: color, isMe: isMe,
              distance: distance, totalDistance: kRaceDistance,
              inPenalty: inPen, jumping: isMe ? _jumping : false,
              sliding: isMe ? _sliding : false,
              jumpOffset: isMe ? _jumpHeight.value : 0,
              obstacles: isMe ? _obstacles : [],
              coins: isMe ? _coins : [],
              screenWidth: size.width,
            );
          }),

          // ── HUD ─────────────────────────────────────────────
          SafeArea(child: Column(children: [
            // Top: distance progress
            Container(margin: const EdgeInsets.all(12), padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(12)),
              child: Column(children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('${_myDistance.toInt()}m', style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
                  Row(children: [
                    const Text('🪙 ', style: TextStyle(fontSize: 16)),
                    Text('$_coinsCollected', style: const TextStyle(
                      color: Colors.amber, fontWeight: FontWeight.w900, fontSize: 16)),
                  ]),
                  Text('${kRaceDistance.toInt()}m', style: const TextStyle(
                    color: Colors.white54, fontSize: 14)),
                ]),
                const SizedBox(height: 6),
                ClipRRect(borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (_myDistance / kRaceDistance).clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: Colors.white24,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _inPenalty ? Colors.red : Colors.green))),
                // Player positions
                const SizedBox(height: 8),
                Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: players.entries.map((e) {
                    final p = Map<String, dynamic>.from(e.value as Map);
                    final isMe = e.key == _myUid;
                    final d = isMe ? _myDistance : ((p['distance'] ?? 0) as num).toDouble();
                    final color = Color((p['color'] ?? 0xFFE53935) as int);
                    return Column(children: [
                      Container(width: 8, height: 8,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
                      const SizedBox(height: 2),
                      Text('${d.toInt()}m', style: TextStyle(
                        color: isMe ? Colors.white : Colors.white54,
                        fontSize: 9, fontWeight: FontWeight.w700)),
                    ]);
                  }).toList()),
              ])),

            // Penalty indicator
            if (_inPenalty && _penaltyEnd != null)
              Container(margin: const EdgeInsets.symmetric(horizontal: 12),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(color: Colors.red.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(100)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Text('💥 CRASHED! ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: kPenaltySecs, end: 0),
                    duration: Duration(seconds: kPenaltySecs.toInt()),
                    builder: (_, v, __) => Text('${v.toInt()}s',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18))),
                ])),
          ])),

          // Controls
          Positioned(bottom: 40, left: 0, right: 0,
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              _ControlBtn(icon: '🦵', label: 'SLIDE', onTap: _slide,
                color: Colors.orange),
              _ControlBtn(icon: '⬆️', label: 'JUMP', onTap: _jump,
                color: Colors.green),
            ])),

          // Countdown overlay
          if (_countdown > 0) Container(color: Colors.black.withOpacity(0.7),
            child: Center(child: Text('$_countdown',
              style: const TextStyle(fontSize: 100, fontWeight: FontWeight.w900,
                color: Colors.white)))),

          if (_countdown == 0 && !_started) Container(color: Colors.black.withOpacity(0.7),
            child: const Center(child: Text('GO! 🏁',
              style: TextStyle(fontSize: 80, fontWeight: FontWeight.w900, color: Colors.green)))),
        ])));
  }
}

// ── Race Lane Widget ───────────────────────────────────────────────────────────
class _RaceLane extends StatelessWidget {
  final int lane, totalLanes;
  final String playerName, playerPhoto;
  final Color playerColor;
  final bool isMe, inPenalty, jumping, sliding;
  final double distance, totalDistance, jumpOffset;
  final List<_Obstacle> obstacles;
  final List<_Coin> coins;
  final double screenWidth;

  const _RaceLane({
    required this.lane, required this.totalLanes,
    required this.playerName, required this.playerPhoto,
    required this.playerColor, required this.isMe,
    required this.distance, required this.totalDistance,
    required this.inPenalty, required this.jumping,
    required this.sliding, required this.jumpOffset,
    required this.obstacles, required this.coins,
    required this.screenWidth,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final laneH = (size.height - 200) / totalLanes;
    final laneY = 100.0 + lane * laneH;
    final groundY = laneY + laneH - 60;

    return Positioned(
      top: laneY, left: 0, right: 0, height: laneH,
      child: CustomPaint(painter: _LanePainter(
        laneHeight: laneH, playerColor: playerColor,
        isMe: isMe, inPenalty: inPenalty,
        playerName: playerName, playerPhoto: playerPhoto,
        distance: distance, totalDistance: totalDistance,
        obstacles: obstacles, coins: coins,
        jumping: jumping, sliding: sliding, jumpOffset: jumpOffset,
        screenWidth: screenWidth)));
  }
}

class _LanePainter extends CustomPainter {
  final double laneHeight, distance, totalDistance, jumpOffset;
  final Color playerColor;
  final bool isMe, inPenalty, jumping, sliding;
  final String playerName, playerPhoto;
  final List<_Obstacle> obstacles;
  final List<_Coin> coins;
  final double screenWidth;

  _LanePainter({
    required this.laneHeight, required this.playerColor,
    required this.isMe, required this.inPenalty,
    required this.playerName, required this.playerPhoto,
    required this.distance, required this.totalDistance,
    required this.obstacles, required this.coins,
    required this.jumping, required this.sliding,
    required this.jumpOffset, required this.screenWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final groundY = laneHeight - 30;
    final playerX = isMe ? 100.0 : screenWidth * 0.3;

    // Lane background
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, laneHeight),
      Paint()..color = isMe ? Colors.white.withOpacity(0.05) : Colors.transparent);

    // Ground line
    canvas.drawRect(Rect.fromLTWH(0, groundY, size.width, 2),
      Paint()..color = playerColor.withOpacity(0.4));

    // Obstacles (only for my lane)
    for (final obs in obstacles) {
      final obsColor = obs.type == 'spike' ? Colors.red :
        obs.type == 'barrier' ? Colors.orange : Colors.grey;
      final rect = Rect.fromLTWH(obs.x, groundY - obs.height, obs.width, obs.height);
      canvas.drawRect(rect, Paint()..color = obsColor);
      // Obstacle emoji
      final tp = TextPainter(text: TextSpan(
        text: obs.type == 'spike' ? '🔺' : obs.type == 'barrier' ? '🚧' : '⬛',
        style: TextStyle(fontSize: obs.height * 0.8)),
        textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(obs.x + (obs.width - tp.width)/2, groundY - obs.height));
    }

    // Coins
    for (final coin in coins) {
      if (coin.collected) continue;
      final tp = TextPainter(text: const TextSpan(text: '🪙',
        style: TextStyle(fontSize: 20)), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(coin.x, groundY + coin.y));
    }

    // Player character
    final charY = groundY - 50 + (sliding ? 25 : 0) + (jumping ? jumpOffset : 0);
    final charH = sliding ? 25.0 : 50.0;

    // Penalty flash effect
    if (inPenalty) {
      canvas.drawCircle(Offset(playerX + 15, charY + charH/2),
        40, Paint()..color = Colors.red.withOpacity(0.3));
    }

    // Player body
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(playerX, charY, 30, charH), const Radius.circular(8)),
      Paint()..color = playerColor);

    // Player face
    final tp = TextPainter(text: TextSpan(
      text: inPenalty ? '😵' : jumping ? '😄' : '🏃',
      style: const TextStyle(fontSize: 22)), textDirection: TextDirection.ltr)..layout();
    tp.paint(canvas, Offset(playerX + (30 - tp.width)/2, charY - 4));

    // Name label
    final nameTp = TextPainter(text: TextSpan(text: playerName,
      style: TextStyle(color: isMe ? Colors.white : Colors.white70,
        fontSize: 10, fontWeight: FontWeight.w700)),
      textDirection: TextDirection.ltr)..layout();
    canvas.drawRRect(RRect.fromRectAndRadius(
      Rect.fromLTWH(playerX - 5, charY - 18, nameTp.width + 10, 16),
      const Radius.circular(8)), Paint()..color = Colors.black54);
    nameTp.paint(canvas, Offset(playerX, charY - 17));

    // Distance label (right side)
    final distTp = TextPainter(text: TextSpan(
      text: '${distance.toInt()}m',
      style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w700)),
      textDirection: TextDirection.ltr)..layout();
    distTp.paint(canvas, Offset(size.width - 50, groundY - 15));
  }

  @override
  bool shouldRepaint(_LanePainter old) => true;
}

class _BackgroundPainter extends CustomPainter {
  final double offset;
  _BackgroundPainter({required this.offset});

  @override
  void paint(Canvas canvas, Size size) {
    // Sky gradient
    final sky = LinearGradient(colors: [const Color(0xFF1a0a2e), const Color(0xFF0d1b2a)])
      .createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..shader = sky);

    // Moving city buildings (parallax)
    final buildPaint = Paint()..color = const Color(0xFF1E1E3F);
    for (int i = 0; i < 8; i++) {
      final bx = ((i * 120 - offset * 0.3) % (size.width + 120)) - 60;
      final bh = 60.0 + (i % 3) * 40;
      canvas.drawRect(Rect.fromLTWH(bx, size.height * 0.2 - bh, 80, bh), buildPaint);
      // Windows
      final winPaint = Paint()..color = const Color(0xFFFFF9C4).withOpacity(0.5);
      for (int r = 0; r < 3; r++) {
        for (int c = 0; c < 2; c++) {
          canvas.drawRect(Rect.fromLTWH(bx + 10 + c * 30, size.height * 0.2 - bh + 10 + r * 18, 15, 10), winPaint);
        }
      }
    }

    // Ground
    canvas.drawRect(Rect.fromLTWH(0, size.height - 60, size.width, 60),
      Paint()..color = const Color(0xFF1A2E1A));
    // Road lines
    final linePaint = Paint()..color = Colors.white24..strokeWidth = 3;
    for (int i = 0; i < 10; i++) {
      final lx = ((i * 100 - offset) % (size.width + 50)) - 25;
      canvas.drawLine(Offset(lx, size.height - 30), Offset(lx + 50, size.height - 30), linePaint);
    }
  }

  @override
  bool shouldRepaint(_BackgroundPainter old) => old.offset != offset;
}

class _ControlBtn extends StatelessWidget {
  final String icon, label;
  final VoidCallback onTap;
  final Color color;
  const _ControlBtn({required this.icon, required this.label, required this.onTap, required this.color});

  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap,
    child: Container(width: 80, height: 80,
      decoration: BoxDecoration(color: color.withOpacity(0.25),
        shape: BoxShape.circle, border: Border.all(color: color, width: 2)),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(icon, style: const TextStyle(fontSize: 28)),
        Text(label, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w800)),
      ])));
}

class _ResultsDialog extends StatefulWidget {
  final String roomId, myUid;
  final double myDistance;
  final int myCoins;
  final VoidCallback onClose;
  const _ResultsDialog({required this.roomId, required this.myUid,
    required this.myDistance, required this.myCoins, required this.onClose});
  @override
  State<_ResultsDialog> createState() => _ResultsDialogState();
}

class _ResultsDialogState extends State<_ResultsDialog> {
  final _db = FirebaseDatabase.instance;
  Map<String, dynamic> _players = {};

  @override
  void initState() {
    super.initState();
    _db.ref('raceRooms/${widget.roomId}/players').get().then((snap) {
      if (snap.exists && mounted) {
        setState(() => _players = Map<String, dynamic>.from(snap.value as Map));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final sorted = _players.entries.toList()..sort((a, b) {
      final ad = (Map<String, dynamic>.from(a.value as Map)['distance'] ?? 0) as num;
      final bd = (Map<String, dynamic>.from(b.value as Map)['distance'] ?? 0) as num;
      return bd.compareTo(ad);
    });
    final medals = ['🥇','🥈','🥉','4️⃣','5️⃣'];

    return Dialog(backgroundColor: const Color(0xFF1A1A2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min,
        children: [
        const Text('🏁', style: TextStyle(fontSize: 60)),
        const Text('Race Finished!', style: TextStyle(fontSize: 22,
          fontWeight: FontWeight.w900, color: Colors.white)),
        const SizedBox(height: 16),
        ...sorted.asMap().entries.map((e) {
          final p = Map<String, dynamic>.from(e.value.value as Map);
          final isMe = e.value.key == widget.myUid;
          final d = isMe ? widget.myDistance : ((p['distance'] ?? 0) as num).toDouble();
          return Container(margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: e.key == 0 ? Colors.amber.withOpacity(0.15) : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: e.key == 0 ? Border.all(color: Colors.amber, width: 1.5) : null),
            child: Row(children: [
              Text(medals[e.key < 5 ? e.key : 4], style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Container(width: 36, height: 36, decoration: BoxDecoration(
                color: Color((p['color'] ?? 0xFFE53935) as int), shape: BoxShape.circle),
                child: (p['photo'] ?? '').isNotEmpty
                  ? ClipOval(child: Image.network(p['photo'], fit: BoxFit.cover))
                  : Center(child: Text((p['name'] ?? '?')[0],
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)))),
              const SizedBox(width: 10),
              Expanded(child: Text(isMe ? '${p['name']} (You)' : p['name'] ?? 'Cousin',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white))),
              Text('${d.toInt()}m', style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ]));
        }),
        const SizedBox(height: 16),
        AppTheme.gradientButton(label: 'Back to Games', onTap: widget.onClose),
      ])));
  }
}

// ── Data Models ────────────────────────────────────────────────────────────────
class _Obstacle {
  double x;
  final String type;
  final double height;
  final double width;
  _Obstacle({required this.x, required this.type, required this.height})
    : width = type == 'spike' ? 25 : 40;
}

class _Coin {
  double x;
  final double y;
  bool collected = false;
  _Coin({required this.x, required this.y});
}
