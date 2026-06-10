import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'pass_the_bomb_models.dart';
import 'pass_the_bomb_result_screen.dart';

class PassTheBombGameScreen extends StatefulWidget {
  final String roomId, myUid, myName, myPhoto;
  final bool isHost;
  const PassTheBombGameScreen({
    super.key, required this.roomId, required this.myUid,
    required this.myName, required this.myPhoto, required this.isHost});
  @override
  State<PassTheBombGameScreen> createState() => _PassTheBombGameState();
}

class _PassTheBombGameState extends State<PassTheBombGameScreen>
    with SingleTickerProviderStateMixin {
  final _db = FirebaseDatabase.instance;
  StreamSubscription? _sub;
  List<PlayerData> _players = [];
  String? _currentBombHolder;
  String _status = 'waiting', _bombState = 'held';
  int _round = 1, _countdown = 0;
  int? _cooldownUntil;
  bool _showExplosion = false, _navigated = false;
  String _eliminatedName = '';

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  Timer? _cdTimer;
  int _cdRemaining = 0;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _listen();
  }

  void _listen() {
    _sub = _db.ref('passBombRooms/${widget.roomId}').onValue.listen((e) {
      if (!e.snapshot.exists || !mounted) return;
      final d = Map<String, dynamic>.from(e.snapshot.value as Map);
      final pm = d['players'] as Map? ?? {};
      final list = pm.entries.map((e) {
        final p = Map<String, dynamic>.from(e.value as Map);
        return PlayerData(
          uid: e.key,
          name: p['name'] as String? ?? 'Cousin',
          photo: p['photo'] as String? ?? '',
          alive: p['alive'] as bool? ?? true,
          eliminationOrder: p['eliminationOrder'] as int?,
        );
      }).toList();

      final st = d['status'] as String? ?? 'waiting';
      final holder = d['currentBombHolder'] as String?;
      final bs = d['bombState'] as String? ?? 'held';
      final round = d['round'] as int? ?? 1;
      final cu = d['cooldownUntil'] as int?;
      final winner = d['winner'] as String?;

      if (st == 'countdown' && _status != 'countdown') _startCountdown();

      if (bs == 'exploded' && _bombState != 'exploded') {
        final dead = list.where((p) => !p.alive && p.eliminationOrder != null).toList()
          ..sort((a, b) => (b.eliminationOrder ?? 0).compareTo(a.eliminationOrder ?? 0));
        if (dead.isNotEmpty) _triggerExplosion(dead.first.name);
      }

      setState(() {
        _players = list; _status = st; _currentBombHolder = holder;
        _bombState = bs; _round = round; _cooldownUntil = cu;
      });

      if (st == 'finished' && winner != null && !_navigated) {
        _navigated = true;
        _goToResult(winner);
      }
    });
  }

  void _startCountdown() {
    _countdown = 3;
    Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _countdown--);
      if (_countdown <= 0) t.cancel();
    });
  }

  void _triggerExplosion(String name) {
    setState(() { _showExplosion = true; _eliminatedName = name; });
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _showExplosion = false);
    });
  }

  bool get _isHolder => _currentBombHolder == widget.myUid;
  bool get _spectator => _players.any((p) => p.uid == widget.myUid && !p.alive);
  bool get _onCooldown => _cooldownUntil != null &&
      DateTime.now().millisecondsSinceEpoch < _cooldownUntil!;

  void _passBomb(String targetUid) {
    if (!_isHolder || _onCooldown) return;
    _db.ref('passBombRooms/${widget.roomId}/currentBombHolder').set(targetUid);
  }

  void _goToResult(String winnerUid) {
    _sub?.cancel();
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(
      builder: (_) => PassTheBombResultScreen(
        players: _players, winnerUid: winnerUid, myUid: widget.myUid,
        myName: widget.myName, myPhoto: widget.myPhoto,
        roomId: widget.roomId, isHost: widget.isHost)));
  }

  @override
  void dispose() {
    _sub?.cancel();
    _pulseCtrl.dispose();
    _cdTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final alive = _players.where((p) => p.alive).toList();
    final dead = _players.where((p) => !p.alive).toList();
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A1A), elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: _spectator
              ? null
              : () => showDialog(context: context, builder: (_) => AlertDialog(
                  title: const Text('Leave Game?'),
                  content: const Text('You will be eliminated if you leave.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Stay')),
                    TextButton(onPressed: () { Navigator.pop(context); Navigator.pop(context); },
                      child: const Text('Leave', style: TextStyle(color: Colors.red))),
                  ]))),
        title: Text('💣 Round $_round',
          style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 16)),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20)),
            child: Text('${alive.length} alive',
              style: const TextStyle(color: Colors.white70, fontSize: 12))),
        ]),
      body: Stack(children: [
        Column(children: [
          Expanded(child: _buildPlayerGrid(alive, dead)),
          _buildStatusBar(),
        ]),
        if (_status == 'countdown' && _countdown > 0) _buildCountdownOverlay(),
        if (_showExplosion) _buildExplosionOverlay(),
      ]));
  }

  Widget _buildPlayerGrid(List<PlayerData> alive, List<PlayerData> dead) {
    final all = [...alive, ...dead];
    return LayoutBuilder(builder: (_, constraints) {
      final crossAxisCount = constraints.maxWidth > 500 ? 3 : 2;
      final gap = 8.0;
      final childW = (constraints.maxWidth - 24 - gap * (crossAxisCount - 1)) / crossAxisCount;
      final childH = childW * 1.1;
      return SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: gap, runSpacing: gap,
          children: all.map((p) => SizedBox(
            width: childW, height: childH,
            child: _buildPlayerCard(p),
          )).toList()),
      );
    });
  }

  Widget _buildPlayerCard(PlayerData p) {
    final isHolder = p.uid == _currentBombHolder;
    final me = p.uid == widget.myUid;
    final isAlive = p.alive;
    final canPass = isHolder && _isHolder && !_onCooldown && isAlive;

    if (canPass && _cdTimer == null) {
      _cdTimer = Timer.periodic(const Duration(milliseconds: 200), (t) {
        if (!mounted) { t.cancel(); return; }
        final remaining = _cooldownUntil != null
            ? (_cooldownUntil! - DateTime.now().millisecondsSinceEpoch) ~/ 1000
            : 0;
        if (remaining <= 0) { t.cancel(); _cdTimer = null; }
        setState(() => _cdRemaining = remaining.clamp(0, 999));
      });
    }

    final cardBody = Container(
      decoration: BoxDecoration(
        color: isHolder
            ? const Color(0xFF4A0E4E).withOpacity(0.6)
            : isAlive ? const Color(0xFF1A1A2E) : const Color(0xFF111111),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHolder ? const Color(0xFF7C3AED).withOpacity(0.7)
              : isAlive ? Colors.white12 : Colors.white10,
          width: isHolder ? 2.5 : 1),
        boxShadow: isHolder
            ? [BoxShadow(color: const Color(0xFF7C3AED).withOpacity(0.3), blurRadius: 12)]
            : null),
      child: Stack(children: [
        Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: me && !isAlive ? 42 : 48,
            height: me && !isAlive ? 42 : 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isHolder ? const Color(0xFF7C3AED) : Colors.grey.shade700,
              border: Border.all(color: isHolder ? Colors.amber : Colors.transparent, width: 2),
              image: p.photo.isNotEmpty
                  ? DecorationImage(image: NetworkImage(p.photo), fit: BoxFit.cover)
                  : null),
            child: p.photo.isEmpty
                ? Center(child: Text(p.name[0].toUpperCase(),
                    style: TextStyle(color: Colors.white,
                      fontWeight: FontWeight.w800, fontSize: me && !isAlive ? 16 : 20)))
                : null),
          const SizedBox(height: 6),
          if (isHolder && isAlive) const Text('💣', style: TextStyle(fontSize: 20)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(p.name, textAlign: TextAlign.center,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: me && !isAlive ? 12 : 13,
                fontWeight: FontWeight.w700,
                color: isAlive ? Colors.white : Colors.white38)),
          ),
        ]),
        if (!isAlive)
          const Positioned.fill(child: Center(child: Text('💀', style: TextStyle(fontSize: 32)))),
        if (isHolder && _onCooldown && isAlive)
          Positioned(
            top: 8, right: 8,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Colors.black87, shape: BoxShape.circle),
              child: Text('$_cdRemaining',
                style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.w900, fontSize: 14))),
          ),
        if (canPass)
          const Positioned(left: 4, top: 4, child: Icon(Icons.touch_app, color: Color(0xFF7C3AED), size: 20)),
      ]),
    );

    Widget card = AnimatedBuilder(
      animation: _pulseAnim,
      builder: (_, child) {
        final scale = isHolder ? _pulseAnim.value : 1.0;
        return Transform.scale(scale: scale, child: cardBody);
      },
    );

    if (canPass) {
      card = LongPressDraggable<String>(
        data: p.uid,
        feedback: Material(
          elevation: 8, borderRadius: BorderRadius.circular(16),
          child: Container(
            width: 80, height: 90,
            decoration: BoxDecoration(
              color: const Color(0xFF4A0E4E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.amber, width: 2)),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Text('💣', style: TextStyle(fontSize: 32)),
              Text('Pass', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
            ])),
        ),
        child: card,
      );
    }

    if (_isHolder && isAlive && !isHolder) {
      card = DragTarget<String>(
        onAcceptWithDetails: (_) => _passBomb(p.uid),
        builder: (_, candidates, __) => AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: candidates.isNotEmpty ? Colors.amber : Colors.transparent,
              width: 2),
          ),
          child: card),
      );
    }

    return card;
  }

  Widget _buildStatusBar() {
    final alive = _players.where((p) => p.alive).toList();
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
      decoration: const BoxDecoration(
        color: Color(0xFF111122),
        border: Border(top: BorderSide(color: Colors.white12))),
      child: SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (_spectator)
          const Text('👻 You are a spectator',
            style: TextStyle(color: Colors.white54, fontSize: 14))
        else if (!_isHolder)
          Text('💣 ${_players.firstWhere((p) => p.uid == _currentBombHolder,
            orElse: () => PlayerData(uid: '', name: '...', photo: '')).name} has the bomb',
            style: const TextStyle(color: Colors.white70, fontSize: 14))
        else if (_onCooldown)
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const SizedBox(width: 8, height: 8, child: CircularProgressIndicator(
              color: Colors.amber, strokeWidth: 2)),
            const SizedBox(width: 8),
            Text('Cooldown $_cdRemaining', style: const TextStyle(color: Colors.amber, fontSize: 14)),
          ])
        else
          const Text('👆 Long-press & drag the bomb to pass',
            style: TextStyle(color: Colors.amber, fontSize: 13)),
        if (alive.length <= 4 && alive.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('⚠️ ${alive.length} players remain!',
              style: TextStyle(color: Colors.red.shade400, fontSize: 12, fontWeight: FontWeight.w700)),
          ),
      ])),
    );
  }

  Widget _buildCountdownOverlay() {
    return Positioned.fill(child: Container(
      color: Colors.black87,
      child: Center(child: TweenAnimationBuilder<int>(
        tween: IntTween(begin: _countdown, end: _countdown),
        duration: const Duration(seconds: 1),
        builder: (_, v, __) => Text('$v',
          style: const TextStyle(fontSize: 120, fontWeight: FontWeight.w900, color: Colors.white))))));
  }

  Widget _buildExplosionOverlay() {
    return Positioned.fill(child: AnimatedOpacity(
      opacity: _showExplosion ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: Container(
        color: Colors.black87,
        child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text('💥', style: TextStyle(fontSize: 80)),
          const SizedBox(height: 10),
          const Text('BOOM!', style: TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: Colors.red)),
          const SizedBox(height: 8),
          Text('$_eliminatedName eliminated',
            style: const TextStyle(fontSize: 18, color: Colors.white70)),
        ])))));
  }
}
