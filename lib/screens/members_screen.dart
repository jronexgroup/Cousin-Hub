import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../app_theme.dart';
import '../services/auth_service.dart';
import '../services/cache_service.dart';
import 'call_screen.dart';

class CallButtons extends StatelessWidget {
  final String toUid;
  final String toName;
  final String toPhoto;

  const CallButtons({super.key, required this.toUid, required this.toName, required this.toPhoto});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(Icons.call),
          onPressed: () {
            // TODO: Implement call functionality
          },
        ),
        IconButton(
          icon: Icon(Icons.video_call),
          onPressed: () {
            // TODO: Implement video call functionality
          },
        ),
      ],
    );
  }
}

class MembersScreen extends StatefulWidget {
  const MembersScreen({super.key});
  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  final _db = FirebaseDatabase.instance;
  List<Map<String, dynamic>> _members = [];

  @override
  void initState() {
    super.initState();
    // Load from cache first
    final cached = CacheService.loadAllUsers();
    if (cached != null) {
      setState(() => _members = cached.entries.map((e) {
        final u = Map<String, dynamic>.from(e.value as Map);
        u['uid'] = e.key; return u;
      }).toList()..sort((a, b) => (a['name'] ?? '').compareTo(b['name'] ?? '')));
    }
    // Update from Firebase
    _db.ref('users').onValue.listen((e) {
      if (!e.snapshot.exists || !mounted) return;
      final map = e.snapshot.value as Map;
      setState(() => _members = map.entries.map((en) {
        final u = Map<String, dynamic>.from(en.value as Map);
        u['uid'] = en.key; return u;
      }).toList()..sort((a, b) => (a['name'] ?? '').compareTo(b['name'] ?? '')));
    });
  }

  @override
  Widget build(BuildContext context) {
    final myUid = AuthService().currentUid;
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(backgroundColor: Colors.white, elevation: 0,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Cousin Pro', style: TextStyle(fontSize: 12, color: AppTheme.soft)),
          Text('${_members.length} Cousins', style: const TextStyle(fontSize: 20,
            fontWeight: FontWeight.w800, color: AppTheme.ink)),
        ])),
      body: _members.isEmpty
        ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
        : ListView.builder(padding: const EdgeInsets.all(16), itemCount: _members.length,
            itemBuilder: (_, i) {
              final m = _members[i];
              final isMe = m['uid'] == myUid;
              final name = m['name'] ?? 'Cousin';
              final nick = m['nickname'] ?? '';
              final role = m['role'] ?? 'member';
              final photo = m['photoUrl'] ?? '';
              final uid = m['uid'] as String;

              return Container(margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)]),
                child: Row(children: [
                  Container(width: 48, height: 48,
                    decoration: BoxDecoration(gradient: AppTheme.mainGradient, shape: BoxShape.circle),
                    child: photo.isNotEmpty
                      ? ClipOval(child: Image.network(photo, fit: BoxFit.cover, width: 48, height: 48))
                      : Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)))),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Text(name, style: const TextStyle(fontSize: 14,
                        fontWeight: FontWeight.w700, color: AppTheme.ink)),
                      if (isMe) Container(margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: const Color(0xFFEDE9FE),
                          borderRadius: BorderRadius.circular(100)),
                        child: const Text('You', style: TextStyle(fontSize: 10,
                          color: AppTheme.primary, fontWeight: FontWeight.w600))),
                      if (role == 'admin') const Text(' 👑', style: TextStyle(fontSize: 14)),
                    ]),
                    if (nick.isNotEmpty) Text('"$nick"',
                      style: const TextStyle(fontSize: 12, color: AppTheme.soft)),
                  ])),
                  // Call buttons (not for self)
                  if (!isMe) CallButtons(toUid: uid, toName: nick.isNotEmpty ? nick : name, toPhoto: photo),
                ]));
            }),
    );
  }
}