import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../app_theme.dart';
import 'pass_the_card_models.dart';
import 'pass_the_card_result_screen.dart';

class PassTheCardGameScreen extends StatefulWidget {
  final String roomId, myUid, myName, myPhoto;
  final bool isHost;

  const PassTheCardGameScreen({
    super.key,
    required this.roomId,
    required this.myUid,
    required this.myName,
    required this.myPhoto,
    this.isHost = false,
  });

  @override
  State<PassTheCardGameScreen> createState() => _PassTheCardGameScreenState();
}

class _PassTheCardGameScreenState extends State<PassTheCardGameScreen> {
  final _db = FirebaseDatabase.instance;
  StreamSubscription? _sub;
  Timer? _turnTimer;

  List<PlayerCardData> _players = [];
  List<int> _myHand = [];
  String? _currentTurn;
  int? _selectedCardIdx;
  Map<String, dynamic>? _recentPass;
  String? _afkMessageUid;
  bool _navigated = false;
  int? _turnEndAt;
  int _turnsPlayed = 0, _cardsPassed = 0, _startedAt = 0;
  bool _showReceivedCard = false;

  @override
  void initState() {
    super.initState();
    _listenRoom();
    _startTurnCountdown();
  }

  void _startTurnCountdown() {
    _turnTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  void _listenRoom() {
    _sub = _db.ref('passTheCardRooms/${widget.roomId}').onValue.listen((e) {
      if (!e.snapshot.exists || !mounted) return;
      final d = Map<String, dynamic>.from(e.snapshot.value as Map);

      final st = d['status'] as String? ?? 'waiting';
      if (st == 'finished') {
        final winner = d['winner'] as String?;
        if (winner != null && !_navigated) {
          _navigated = true;
          _sub?.cancel();
          _turnTimer?.cancel();
          Navigator.pushReplacement(context, MaterialPageRoute(
            builder: (_) => PassTheCardResultScreen(
              players: _players, winnerUid: winner, myUid: widget.myUid,
              myName: widget.myName, myPhoto: widget.myPhoto,
              roomId: widget.roomId, isHost: widget.isHost,
              turnsPlayed: _turnsPlayed, cardsPassed: _cardsPassed,
              startedAt: _startedAt)));
        }
        return;
      }

      final pm = d['players'] as Map? ?? {};
      final list = pm.entries.map((e) {
        return PlayerCardData.fromMap(
          Map<String, dynamic>.from(e.value as Map), e.key);
      }).toList();

      final myHandRaw = pm[widget.myUid] is Map
          ? (pm[widget.myUid]['hand'] as List<dynamic>?)
          : null;
      final myHand = myHandRaw?.map((e) => (e as num).toInt()).toList() ?? _myHand;
      final turnEndAt = d['turnEndAt'] as int?;
      final rp = d['recentPass'] as Map<String, dynamic>?;
      final afkMsg = d['afkMessage'] as String?;
      final rr = d['revealResult'] as String?;

      setState(() {
        _players = list;
        _currentTurn = d['currentTurn'] as String?;
        _turnsPlayed = d['turnsPlayed'] as int? ?? _turnsPlayed;
        _cardsPassed = d['cardsPassed'] as int? ?? _cardsPassed;
        _startedAt = d['startedAt'] as int? ?? _startedAt;
        _turnEndAt = turnEndAt;
        if (myHandRaw != null) _myHand = myHand;
        _recentPass = rp;
      });

      if (afkMsg != null && afkMsg != _afkMessageUid) {
        setState(() => _afkMessageUid = afkMsg);
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) setState(() => _afkMessageUid = null);
        });
      }

      if (_myHand.isNotEmpty && _recentPass != null &&
          _recentPass!['toUid'] == widget.myUid && !_showReceivedCard) {
        setState(() => _showReceivedCard = true);
      }

      if (rr == 'invalid') {
        _db.ref('passTheCardRooms/${widget.roomId}/revealResult').remove();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid Reveal — cards do not match!')),
          );
        }
      }
    });
  }

  bool get _myTurn => _currentTurn == widget.myUid;

  void _selectCard(int idx) {
    if (!_myTurn || _showReceivedCard) return;
    setState(() => _selectedCardIdx = _selectedCardIdx == idx ? null : idx);
  }

  Future<void> _passCard() async {
    if (_selectedCardIdx == null || !_myTurn) return;
    await _db.ref('passTheCardRooms/${widget.roomId}/passAction').set({
      'cardIndex': _selectedCardIdx,
    });
    setState(() => _selectedCardIdx = null);
  }

  Future<void> _reveal() async {
    await _db.ref('passTheCardRooms/${widget.roomId}/revealRequest')
        .set(widget.myUid);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _turnTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A1A), elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text('🃏 Pass The Card',
          style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app, color: Colors.white54),
            onPressed: () => _showExitDialog(),
            tooltip: 'Exit match'),
        ],
      ),
      body: _players.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : isPortrait ? _buildPortrait() : _buildLandscape(),
    );
  }

  Widget _buildPortrait() {
    return Column(children: [
      _buildStatusBar(),
      Expanded(child: _buildTableGrid()),
      _buildHandArea(),
    ]);
  }

  Widget _buildLandscape() {
    return Column(children: [
      Expanded(child: Row(children: [
        Expanded(child: _buildPlayerColumn(0)), // Player A left
        Expanded(flex: 2, child: Column(children: [
          Expanded(child: _buildPlayerColumn(1)), // Player B top-center
          _buildCenterButtons(),
          Expanded(child: _buildPlayerColumn(2)), // Player C bottom-center
        ])),
        Expanded(child: _buildPlayerColumn(3)), // Player D right
      ])),
      _myTurn ? _buildHandRow() : const SizedBox.shrink(),
    ]);
  }

  Widget _buildStatusBar() {
    final ct = _currentTurn;
    final turnName = _players.firstWhere(
      (p) => p.uid == ct, orElse: () => PlayerCardData(uid: '', name: '?', photo: '')).name;
    final remaining = _turnEndAt != null
        ? ((_turnEndAt! - DateTime.now().millisecondsSinceEpoch) / 1000).ceil().clamp(0, 99)
        : 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: const Color(0xFF111122),
      child: Row(children: [
        Text('${_myTurn ? "YOUR" : "$turnName's"} TURN',
          style: TextStyle(
            color: _myTurn ? AppTheme.primary : Colors.white54,
            fontWeight: FontWeight.w900, fontSize: 12)),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: remaining <= 3 ? Colors.red.shade900 : Colors.white12,
            borderRadius: BorderRadius.circular(6)),
          child: Text('${remaining}s',
            style: TextStyle(
              color: remaining <= 3 ? Colors.redAccent : Colors.white70,
              fontWeight: FontWeight.w900, fontSize: 13)),
        ),
      ]),
    );
  }

  Widget _buildTableGrid() {
    final turnPlayerIds = _getTurnOrder();
    return LayoutBuilder(builder: (_, c) {
      final w = (c.maxWidth - 24) / 3;
      final h = (c.maxHeight - 24) / 2;
      return Center(
        child: SizedBox(
          width: c.maxWidth,
          child: Stack(children: [
            // Player B (top center)
            Positioned(top: 4, left: w, child: _playerSeat(turnPlayerIds[1], w, h)),
            // Player A (left center)
            Positioned(left: 4, top: h, child: _playerSeat(turnPlayerIds[0], w, h)),
            // Player C (right center)
            Positioned(right: 4, top: h, child: _playerSeat(turnPlayerIds[2], w, h)),
            // Player D (bottom center)
            Positioned(bottom: 4, left: w, child: _playerSeat(turnPlayerIds[3], w, h)),
          ]),
        ),
      );
    });
  }

  List<String> _getTurnOrder() {
    final sorted = List<PlayerCardData>.from(_players)
      ..sort((a, b) => a.position.compareTo(b.position));
    return sorted.map((p) => p.uid).toList();
  }

  Widget _playerSeat(String uid, double w, double h) {
    final p = _players.firstWhere((e) => e.uid == uid, orElse: () =>
      PlayerCardData(uid: '', name: '?', photo: '', cardCount: 0));
    final isTurn = uid == _currentTurn;
    return Container(
      width: w - 8, height: h - 8,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isTurn ? AppTheme.primary : Colors.white12,
          width: isTurn ? 2 : 1)),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 36, height: 36,
          decoration: const BoxDecoration(color: Colors.grey, shape: BoxShape.circle),
          child: p.photo.isNotEmpty
              ? ClipOval(child: Image.network(p.photo, fit: BoxFit.cover))
              : Center(child: Text((p.name.isNotEmpty ? p.name[0] : '?').toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)))),
        const SizedBox(height: 4),
        Text(p.name, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
          overflow: TextOverflow.ellipsis),
        Text('🃏 ${p.cardCount}',
          style: const TextStyle(color: Colors.white54, fontSize: 11)),
      ]),
    );
  }

  Widget _buildHandArea() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      color: const Color(0xFF111122),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        _myTurn && !_showReceivedCard ? _buildHandRow() : _notMyTurnWidget(),
        const SizedBox(height: 6),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          SizedBox(width: 100, child: AppTheme.gradientButton(
            label: 'PASS',
            onTap: _myTurn && _selectedCardIdx != null && !_showReceivedCard ? _passCard : null,
            height: 38)),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: _myHand.length == kHandSize ? _reveal : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber.shade700,
              disabledBackgroundColor: Colors.grey.shade800,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('🏆 REVEAL', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 13))),
        ]),
      ]),
    );
  }

  Widget _notMyTurnWidget() {
    return Container(
      height: 80,
      alignment: Alignment.center,
      child: const Text('Waiting for your turn...',
        style: TextStyle(color: Colors.white38, fontSize: 13)),
    );
  }

  Widget _buildHandRow() {
    if (_myHand.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 80,
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children:
        List.generate(_myHand.length, (i) {
          final ct = cardTypeById(_myHand[i]);
          final selected = _selectedCardIdx == i;
          return GestureDetector(
            onTap: () => _selectCard(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 56, height: 76,
              margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
              decoration: BoxDecoration(
                color: ct.color.withOpacity(0.7),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: selected ? Colors.white : Colors.white24,
                  width: selected ? 3 : 1)),
              child: Center(
                child: Text(ct.label, style: const TextStyle(fontSize: 24)),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCenterButtons() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        if (_myTurn && !_showReceivedCard) SizedBox(width: 80, child: AppTheme.gradientButton(
          label: 'PASS',
          onTap: _selectedCardIdx != null ? _passCard : null,
          height: 34)),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: _myHand.length == kHandSize ? _reveal : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.amber.shade700,
            disabledBackgroundColor: Colors.grey.shade800,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          child: const Text('🏆 REVEAL', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 11))),
      ]),
    );
  }

  Widget _buildPlayerColumn(int pos) {
    final p = _players.firstWhere((e) => e.position == pos, orElse: () =>
      PlayerCardData(uid: '', name: '?', photo: '', cardCount: 0));
    final isTurn = p.uid == _currentTurn;
    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isTurn ? AppTheme.primary : Colors.white12,
          width: isTurn ? 2 : 1)),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 32, height: 32,
          decoration: const BoxDecoration(color: Colors.grey, shape: BoxShape.circle),
          child: p.photo.isNotEmpty
              ? ClipOval(child: Image.network(p.photo, fit: BoxFit.cover))
              : Center(child: Text((p.name.isNotEmpty ? p.name[0] : '?').toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)))),
        Text(p.name, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
          overflow: TextOverflow.ellipsis),
        Text('🃏 ${p.cardCount}', style: const TextStyle(color: Colors.white54, fontSize: 10)),
      ]),
    );
  }

  void _showExitDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Exit Match?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
        content: const Text('Leaving will end the match for everyone.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          TextButton(onPressed: () {
            Navigator.pop(ctx);
            _exitMatch();
          }, child: const Text('Exit', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }

  Future<void> _exitMatch() async {
    await _db.ref('passTheCardRooms/${widget.roomId}/players/${widget.myUid}').remove();
    _sub?.cancel();
    _turnTimer?.cancel();
    if (mounted) Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const SizedBox()), (_) => false);
  }
}
