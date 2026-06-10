import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../app_theme.dart';
import '../services/auth_service.dart';
import '../services/cache_service.dart';
import 'pass_the_bomb_game_screen.dart';

class PassTheBombLobbyScreen extends StatefulWidget {
  final String? roomId;
  final bool isHost;
  const PassTheBombLobbyScreen({super.key, this.roomId, this.isHost = true});

  @override
  State<PassTheBombLobbyScreen> createState() => _PassTheBombLobbyState();
}

class _PassTheBombLobbyState extends State<PassTheBombLobbyScreen> {
  final _db = FirebaseDatabase.instance;
  StreamSubscription? _sub;
  List<Map<String, dynamic>> _cousins = [];
  final Set<String> _selected = {};
  String? _roomId;
  String _myUid = '', _myName = '', _myPhoto = '', _hostUid = '';
  List<Map<String, dynamic>> _players = [];
  bool _loading = true, _creating = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _myUid = AuthService().currentUid ?? '';
    final p = await AuthService().getProfile(_myUid);
    if (p != null) {
      _myName = p['nickname'] ?? p['name'] ?? 'Cousin';
      _myPhoto = p['photoUrl'] ?? '';
    }

    if (widget.roomId != null) {
      _roomId = widget.roomId;
      await _joinRoom();
    } else {
      final users = CacheService.loadAllUsers();
      if (users != null) {
        _cousins = users.entries.where((e) => e.key != _myUid).map((e) {
          final u = Map<String, dynamic>.from(e.value as Map);
          u['uid'] = e.key;
          return u;
        }).toList()..sort((a, b) => ((a['nickname'] ?? a['name'] ?? '') as String)
            .compareTo(b['nickname'] ?? b['name'] ?? ''));
      }
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _joinRoom() async {
    if (_roomId == null) return;
    await _db.ref('passBombRooms/$_roomId/players/$_myUid').set({
      'name': _myName, 'photo': _myPhoto, 'alive': true,
    });
    _listenRoom();
    if (mounted) setState(() => _loading = false);
  }

  void _listenRoom() {
    if (_roomId == null) return;
    _sub = _db.ref('passBombRooms/$_roomId').onValue.listen((e) {
      if (!e.snapshot.exists || !mounted) return;
      final d = Map<String, dynamic>.from(e.snapshot.value as Map);
      final pm = d['players'] as Map? ?? {};
      final list = pm.entries.map((e) {
        final p = Map<String, dynamic>.from(e.value as Map);
        p['uid'] = e.key;
        return p;
      }).toList();
      final st = d['status'] as String? ?? 'waiting';
      setState(() { _players = list; _hostUid = d['hostUid'] as String? ?? ''; });

      if ((st == 'playing' || st == 'countdown') && _roomId != null) {
        _sub?.cancel();
        Navigator.pushReplacement(context, MaterialPageRoute(
          builder: (_) => PassTheBombGameScreen(
            roomId: _roomId!, myUid: _myUid,
            myName: _myName, myPhoto: _myPhoto,
            isHost: d['hostUid'] == _myUid)));
      }
    });
  }

  Future<void> _createRoom() async {
    if (_selected.length < 3) return;
    setState(() => _creating = true);
    _roomId = 'ptb_${DateTime.now().millisecondsSinceEpoch}';

    final players = <String, dynamic>{
      _myUid: {'name': _myName, 'photo': _myPhoto, 'alive': true},
    };
    for (final cuid in _selected) {
      final u = _cousins.firstWhere((c) => c['uid'] == cuid, orElse: () => {});
      players[cuid] = {
        'name': u['nickname'] ?? u['name'] ?? 'Cousin',
        'photo': u['photoUrl'] ?? '', 'alive': true,
      };
    }

    await _db.ref('passBombRooms/$_roomId').set({
      'hostUid': _myUid, 'hostName': _myName, 'status': 'waiting',
      'players': players,
    });

    for (final cuid in _selected) {
      await _db.ref('passBombInvites/$cuid/$_roomId').set({
        'hostName': _myName, 'hostPhoto': _myPhoto,
        'roomId': _roomId, 'timestamp': ServerValue.timestamp,
      });
      final tk = await _db.ref('users/$cuid/fcmToken').get();
      if (tk.exists) {
        await _db.ref('notifications').push().set({
          'toToken': tk.value,
          'title': '💣 $_myName invited you to Pass The Bomb!',
          'body': 'Tap to join the room.',
          'sent': false, 'timestamp': ServerValue.timestamp,
        });
      }
    }

    _listenRoom();
    if (mounted) setState(() => _creating = false);
  }

  Future<void> _startGame() async {
    if (_roomId == null) return;
    await _db.ref('passBombRooms/$_roomId/status').set('countdown');
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inRoom = _roomId != null;
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A1A), elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context)),
        title: Text(inRoom ? '💣 Pass The Bomb' : '💣 Pass The Bomb',
          style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white))),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF7C3AED)))
          : inRoom ? _buildLobby() : _buildPicker(),
    );
  }

  Widget _buildPicker() {
    final total = _selected.length + 1;
    final canCreate = _selected.length >= 3;
    return Column(children: [
      Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.primary.withOpacity(0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.primary.withOpacity(0.4))),
        child: Text(
          'Select ${3 - _selected.length} more cousin${_selected.length >= 3 ? '' : 's'} (need 4–15 total)',
          style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.5))),

      Expanded(child: _cousins.isEmpty
          ? const Center(child: Text('No cousins found', style: TextStyle(color: Colors.white54)))
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _cousins.length,
              itemBuilder: (_, i) {
                final c = _cousins[i];
                final uid = c['uid'] as String;
                final sel = _selected.contains(uid);
                final name = c['nickname'] ?? c['name'] ?? 'Cousin';
                final photo = c['photoUrl'] ?? '';
                return GestureDetector(
                  onTap: () => setState(() => sel ? _selected.remove(uid) : _selected.add(uid)),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: sel ? AppTheme.primary.withOpacity(0.15) : const Color(0xFF1A1A2E),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: sel ? AppTheme.primary : Colors.grey.shade800, width: sel ? 2 : 1)),
                    child: Row(children: [
                      Container(width: 42, height: 42,
                        decoration: BoxDecoration(
                          gradient: sel ? AppTheme.mainGradient : null,
                          color: sel ? null : Colors.grey.shade700,
                          shape: BoxShape.circle),
                        child: photo.isNotEmpty
                            ? ClipOval(child: Image.network(photo, fit: BoxFit.cover))
                            : Center(child: Text(name[0].toUpperCase(),
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)))),
                      const SizedBox(width: 12),
                      Expanded(child: Text(name,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white))),
                      Icon(sel ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                        color: sel ? AppTheme.primary : Colors.grey, size: 24),
                    ])));
              })),
      Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
        color: const Color(0xFF0A0A1A),
        child: SafeArea(child: AppTheme.gradientButton(
          label: canCreate
              ? '💣 Create Room ($total/4–15)'
              : '👆 Select ${3 - _selected.length} more',
          loading: _creating,
          onTap: canCreate ? _createRoom : null,
          height: 52))),
    ]);
  }

  Widget _buildLobby() {
    final isHost = _hostUid == _myUid;
    final canStart = _players.length >= 4 && isHost;

    return Column(children: [
      Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.primary.withOpacity(0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.primary.withOpacity(0.4))),
        child: Row(children: [
          const Text('💣', style: TextStyle(fontSize: 24)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Room: ${_roomId?.substring(4) ?? ''}',
              style: const TextStyle(color: Colors.white70, fontSize: 11)),
            Text('${_players.length} player${_players.length == 1 ? '' : 's'} joined',
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
          ])),
        ])),

      Expanded(child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _players.length,
        itemBuilder: (_, i) {
          final p = _players[i];
          final isMe = p['uid'] == _myUid;
          final name = p['name'] as String? ?? 'Cousin';
          final photo = p['photo'] as String? ?? '';
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isMe ? AppTheme.primary.withOpacity(0.15) : const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isMe ? AppTheme.primary : Colors.grey.shade800, width: isMe ? 2 : 1)),
            child: Row(children: [
              Container(width: 42, height: 42,
                decoration: const BoxDecoration(
                  color: Colors.grey, shape: BoxShape.circle),
                child: photo.isNotEmpty
                    ? ClipOval(child: Image.network(photo, fit: BoxFit.cover))
                    : Center(child: Text(name[0].toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)))),
              const SizedBox(width: 12),
              Expanded(child: Text(name,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white))),
            ]));
        })),

      Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
        color: const Color(0xFF0A0A1A),
        child: SafeArea(child: isHost ? AppTheme.gradientButton(
          label: _players.length >= 4
              ? '💣 Start Match'
              : 'Waiting for ${4 - _players.length} more...',
          onTap: canStart ? _startGame : null,
          height: 52) : Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: const Text('Waiting for host to start...',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 14))))),
    ]);
  }
}
