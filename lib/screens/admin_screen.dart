import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../app_theme.dart';
import '../services/auth_service.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});
  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final _db = FirebaseDatabase.instance;
  List<Map<String, dynamic>> _members = [];
  int _photoCount = 0, _eventCount = 0, _chatCount = 0;

  @override
  void initState() { super.initState(); _load(); }

  void _load() {
    _db.ref('users').onValue.listen((e) {
      if (!e.snapshot.exists || !mounted) return;
      final map = e.snapshot.value as Map;
      setState(() => _members = map.entries.map((en) {
        final u = Map<String, dynamic>.from(en.value as Map);
        u['uid'] = en.key;
        return u;
      }).toList());
    });
    _db.ref('photos').get().then((s) {
      if (s.exists && mounted) setState(() => _photoCount = (s.value as Map).length);
    });
    _db.ref('events').get().then((s) {
      if (s.exists && mounted) setState(() => _eventCount = (s.value as Map).length);
    });
    _db.ref('chats/main').get().then((s) {
      if (s.exists && mounted) setState(() => _chatCount = (s.value as Map).length);
    });
  }

  Future<void> _setRole(String uid, String role) async {
    await _db.ref('users/$uid/role').set(role);
  }

  Future<void> _removeMember(String uid) async {
    final confirm = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Remove Member?'),
      content: const Text('This will remove the member from the family group.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(context, true),
          child: const Text('Remove', style: TextStyle(color: Colors.red))),
      ],
    ));
    if (confirm == true) await _db.ref('users/$uid').remove();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(backgroundColor: Colors.white, elevation: 0,
        title: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Cousin Pro', style: TextStyle(fontSize: 12, color: AppTheme.soft)),
          Text('Admin Control', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.ink)),
        ])),
      body: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Stats
        Padding(padding: const EdgeInsets.all(16), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
          AppTheme.sectionTitle('App Analytics'),
          const SizedBox(height: 12),
          Row(children: [
            _statCard('👥', '${_members.length}', 'Members', const Color(0xFFEDE9FE)),
            const SizedBox(width: 12),
            _statCard('📸', '$_photoCount', 'Photos', const Color(0xFFFFF0E8)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            _statCard('🎉', '$_eventCount', 'Events', const Color(0xFFE8F4FD)),
            const SizedBox(width: 12),
            _statCard('💬', '$_chatCount', 'Messages', const Color(0xFFE8F5E9)),
          ]),
        ])),

        // Members
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
          child: AppTheme.sectionTitle('Member Management')),
        const SizedBox(height: 12),

        ..._members.map((m) {
          final uid = m['uid'] as String;
          final myUid = AuthService().currentUid;
          final isMe = uid == myUid;
          final role = m['role'] ?? 'member';
          final name = m['name'] ?? 'Cousin';
          final photoUrl = m['photoUrl'] ?? '';

          return Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)]),
            child: Row(children: [
              Container(width: 44, height: 44,
                decoration: BoxDecoration(gradient: AppTheme.mainGradient, shape: BoxShape.circle),
                child: photoUrl.isNotEmpty
                  ? ClipOval(child: Image.network(photoUrl, fit: BoxFit.cover))
                  : Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.ink)),
                  if (role == 'admin') const Text(' 👑', style: TextStyle(fontSize: 14)),
                ]),
                Text(m['email'] ?? '', style: const TextStyle(fontSize: 11, color: AppTheme.soft)),
              ])),
              if (isMe)
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xFFEDE9FE), borderRadius: BorderRadius.circular(100)),
                  child: const Text('You', style: TextStyle(fontSize: 11, color: AppTheme.primary, fontWeight: FontWeight.w600)))
              else
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: AppTheme.muted),
                  onSelected: (val) {
                    if (val == 'admin') _setRole(uid, 'admin');
                    else if (val == 'member') _setRole(uid, 'member');
                    else if (val == 'remove') _removeMember(uid);
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'admin',
                      child: Text(role == 'admin' ? '👑 Remove Admin' : '👑 Make Admin')),
                    const PopupMenuItem(value: 'member', child: Text('Set as Member')),
                    const PopupMenuItem(value: 'remove',
                      child: Text('Remove Member', style: TextStyle(color: Colors.red))),
                  ]),
            ]));
        }),

        const SizedBox(height: 80),
      ])),
    );
  }

  Widget _statCard(String icon, String val, String lbl, Color bg) =>
    Expanded(child: Container(padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(icon, style: const TextStyle(fontSize: 24)),
        const SizedBox(height: 6),
        Text(val, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppTheme.ink)),
        Text(lbl, style: const TextStyle(fontSize: 12, color: AppTheme.muted)),
      ])));
}
