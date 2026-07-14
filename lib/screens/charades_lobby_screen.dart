import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_database/firebase_database.dart';
import '../app_theme.dart';
import '../services/auth_service.dart';
import 'charades_game_screen.dart';

class CharadesLobbyScreen extends StatefulWidget {
  final String? inviteCode;
  const CharadesLobbyScreen({super.key, this.inviteCode});
  @override
  State<CharadesLobbyScreen> createState() => _CharadesLobbyScreenState();
}

class _CharadesLobbyScreenState extends State<CharadesLobbyScreen> {
  final _db = FirebaseDatabase.instance;
  final _auth = AuthService();
  final _codeCtrl = TextEditingController();
  String? _roomId;
  Map<String, dynamic> _room = {};
  bool _isHost = false, _ready = false;
  bool _creating = false;
  int _totalRounds = 8;
  String _myName = '', _myPhoto = '';

  String get _myUid => _auth.currentUid!;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    if (widget.inviteCode != null) {
      _codeCtrl.text = widget.inviteCode!;
      _joinRoom();
    }
  }

  Future<void> _loadProfile() async {
    final p = await _auth.getProfile(_myUid);
    if (p != null && mounted) setState(() { _myName = p['nickname'] ?? p['name'] ?? 'Cousin'; _myPhoto = p['photoUrl'] ?? ''; });
  }

  Future<void> _createRoom() async {
    setState(() => _creating = true);
    _roomId = _db.ref('charadesRooms').push().key;
    await _db.ref('charadesRooms/$_roomId').set({
      'host': _myUid,
      'totalRounds': _totalRounds,
      'status': 'lobby',
      'createdAt': ServerValue.timestamp,
      'roomCode': _roomId!.substring(_roomId!.length - 4).toUpperCase(),
      'players': {_myUid: {'name': _myName, 'ready': false, 'photo': _myPhoto, 'score': 0}},
    });
    _isHost = true;
    _listen();
    setState(() => _creating = false);
  }

  Future<void> _joinRoom() async {
    final code = _codeCtrl.text.trim().toUpperCase();
    if (code.isEmpty) return;
    final snap = await _db.ref('charadesRooms').orderByChild('roomCode').equalTo(code).limitToFirst(1).get();
    if (!snap.exists) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Room not found'), backgroundColor: Colors.red));
      return;
    }
    _roomId = (snap.value as Map).entries.first.key;
    _listen();
  }

  void _listen() {
    _db.ref('charadesRooms/$_roomId').onValue.listen((e) {
      if (!e.snapshot.exists || !mounted) return;
      setState(() => _room = Map<String, dynamic>.from(e.snapshot.value as Map));
      if (_room['players'] is Map && (_room['players'] as Map).containsKey(_myUid)) _isHost = _room['host'] == _myUid;
      if (_room['status'] == 'playing' && mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => CharadesGameScreen(roomId: _roomId!)));
      }
    });
  }

  Future<void> _toggleReady() async {
    _ready = !_ready;
    await _db.ref('charadesRooms/$_roomId/players/$_myUid/ready').set(_ready);
  }

  Future<void> _startGame() async {
    await _db.ref('charadesRooms/$_roomId/status').set('playing');
    await _db.ref('charadesRooms/$_roomId/currentRound').set(0);
    await _db.ref('charadesRooms/$_roomId/actorIndex').set(0);
    if (mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => CharadesGameScreen(roomId: _roomId!)));
    }
  }

  Future<void> _leave() async {
    if (_roomId != null) {
      await _db.ref('charadesRooms/$_roomId/players/$_myUid').remove();
      final snap = await _db.ref('charadesRooms/$_roomId/players').get();
      if (!snap.exists) await _db.ref('charadesRooms/$_roomId').remove();
    }
    if (mounted) Navigator.pop(context);
  }

  int get _playerCount => (_room['players'] as Map?)?.length ?? 0;
  String get _roomCode => _room['roomCode'] ?? '';
  bool get _allReady => _room['players'] is Map && (_room['players'] as Map).values.every((p) => (p as Map)['ready'] == true);

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: AppTheme.ink), onPressed: _leave),
        title: const Text('🎭 Charades', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.ink)),
      ),
      body: _roomId == null ? _buildJoinCreate() : _buildLobby(),
    );
  }

  Widget _buildJoinCreate() {
    return SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(children: [
      const SizedBox(height: 40),
      const Text('🎭', style: TextStyle(fontSize: 64)),
      const SizedBox(height: 16),
      const Text('Charades', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.ink)),
      const SizedBox(height: 8),
      const Text('Describe without saying the word!', style: TextStyle(fontSize: 13, color: AppTheme.muted)),
      const SizedBox(height: 32),
      TextField(controller: _codeCtrl,
        decoration: InputDecoration(
          hintText: 'Enter room code', filled: true, fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          suffixIcon: GestureDetector(onTap: _joinRoom,
            child: Container(margin: const EdgeInsets.all(4), padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.login, color: Colors.white, size: 18)),
          ),
        ),
        style: const TextStyle(fontSize: 16, letterSpacing: 4, fontWeight: FontWeight.w700)),
      const SizedBox(height: 16),
      const Row(children: [Expanded(child: Divider()), Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('or', style: TextStyle(color: AppTheme.soft))), Expanded(child: Divider())]),
      const SizedBox(height: 16),
      Container(padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Column(children: [
          const Text('Create New Room', style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.ink)),
          const SizedBox(height: 12),
          Row(children: [
            _roundBtn(5), _roundBtn(8), _roundBtn(10),
          ]),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: AppTheme.gradientButton(
            label: _creating ? 'Creating...' : '🎭 Create Room',
            onTap: _creating ? null : _createRoom, height: 48)),
        ])),
    ]));
  }

  Widget _roundBtn(int n) {
    final active = _totalRounds == n;
    return Expanded(child: GestureDetector(onTap: () => setState(() => _totalRounds = n),
      child: Container(margin: const EdgeInsets.symmetric(horizontal: 4), padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppTheme.primary : AppTheme.bg,
          borderRadius: BorderRadius.circular(100)),
        child: Text('$n Rounds', textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
            color: active ? Colors.white : AppTheme.muted)))));
  }

  Widget _buildLobby() {
    final players = (_room['players'] as Map?) ?? {};
    return Column(children: [
      Container(margin: const EdgeInsets.all(16), padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Text('Room ', style: TextStyle(color: AppTheme.soft)),
            Text(_roomCode, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.primary, letterSpacing: 4)),
            const SizedBox(width: 8),
            GestureDetector(onTap: () => Clipboard.setData(ClipboardData(text: _roomCode)),
              child: const Icon(Icons.copy, size: 16, color: AppTheme.soft)),
          ]),
          const SizedBox(height: 8),
          Text('${_room['totalRounds'] ?? 0} rounds', style: const TextStyle(fontSize: 11, color: AppTheme.muted)),
        ])),
      Expanded(child: ListView(padding: const EdgeInsets.symmetric(horizontal: 16), children: [
        Text('${_playerCount} players', style: const TextStyle(fontSize: 12, color: AppTheme.muted, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        ...players.entries.map((e) {
          final p = Map<String, dynamic>.from(e.value as Map);
          final isMe = e.key == _myUid;
          final isHost = e.key == _room['host'];
          final ready = p['ready'] == true;
          return Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ready ? AppTheme.primary : const Color(0xFFE8D9C5))),
            child: Row(children: [
              Container(width: 36, height: 36,
                decoration: BoxDecoration(gradient: AppTheme.mainGradient, shape: BoxShape.circle),
                child: Center(child: Text((p['name'] as String? ?? '?')[0].toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)))),
              const SizedBox(width: 10),
              Expanded(child: Text(p['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.ink))),
              if (isHost) const Padding(padding: EdgeInsets.only(right: 8), child: Text('👑', style: TextStyle(fontSize: 14))),
              if (isMe) _chip('You', const Color(0xFFEDE9FE), AppTheme.primary),
              const SizedBox(width: 8),
              Icon(ready ? Icons.check_circle : Icons.hourglass_empty, size: 18,
                color: ready ? Colors.green : AppTheme.soft),
            ]));
        }),
      ])),
      Container(padding: const EdgeInsets.all(16), color: Colors.white, child: Row(children: [
        if (_isHost)
          Expanded(child: AppTheme.gradientButton(label: '▶ Start', onTap: _allReady && _playerCount >= 2 ? _startGame : null, height: 48))
        else
          Expanded(child: OutlinedButton(onPressed: _toggleReady,
            style: OutlinedButton.styleFrom(
              foregroundColor: _ready ? Colors.orange : AppTheme.primary,
              side: BorderSide(color: _ready ? Colors.orange : AppTheme.primary),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(vertical: 14)),
            child: Text(_ready ? '⏳ Unready' : '✅ Ready', style: const TextStyle(fontWeight: FontWeight.w700))),
          ),
      ])),
    ]);
  }

  Widget _chip(String text, Color bg, Color fg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(100)),
    child: Text(text, style: TextStyle(fontSize: 10, color: fg, fontWeight: FontWeight.w600)));
}
