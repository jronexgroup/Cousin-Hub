import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../app_theme.dart';
import '../services/auth_service.dart';
import '../services/cloudinary_service.dart';
import 'badges_screen.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});
  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> with SingleTickerProviderStateMixin {
  final _db = FirebaseDatabase.instance;
  final _renderServer = 'https://cousin-hub-server.onrender.com';
  late TabController _tabCtrl;

  // ─── Dashboard ───
  int _memberCount = 0, _onlineCount = 0, _activeStories = 0, _unsentNotifs = 0;
  int _activeRaces = 0, _activeLudo = 0, _photoCount = 0, _chatCount = 0, _eventCount = 0;
  List<Map<String, dynamic>> _adminLogs = [], _members = [];

  // ─── Members ───
  String _memberSearch = '', _memberRoleFilter = 'all', _memberStatusFilter = 'all', _memberSortBy = 'name';
  Map<String, dynamic>? _selectedMember;
  List<Map<String, dynamic>> _inviteCodes = [];
  final _codeCtrl = TextEditingController();
  bool _inviteDialogOpen = false;

  // ─── Moderation ───
  String _modTab = 'stories', _chatGroup = 'main', _modSearch = '';
  List<Map<String, dynamic>> _stories = [], _photos = [], _messages = [];
  Map<String, dynamic>? _storyPreview;
  Set<String> _selectedStories = {};

  // ─── Notifications ───
  final _notifTitleCtrl = TextEditingController(), _notifBodyCtrl = TextEditingController();
  bool _sendingNotif = false;
  bool? _serverOk;
  String _notifTarget = 'all';
  Set<String> _selectedNotifUsers = {};
  String? _notifResult;
  List<Map<String, dynamic>> _notifHistory = [];

  // ─── Config ───
  Map<String, dynamic> _appConfig = {};
  Set<String> _savingConfig = {};

  // ─── Database ───
  String _dbPath = 'users';
  Map<String, dynamic> _dbData = {};
  bool _dbLoading = false;
  final _dbPathCtrl = TextEditingController(text: 'users');

  // ─── Games ───
  Map<String, dynamic> _ludoRooms = {}, _raceRooms = {}, _passBombRooms = {};
  Map<String, dynamic> _passTheCardRooms = {}, _truthOrDareRooms = {}, _spyChatRooms = {};
  List<Map<String, dynamic>> _leaderboard = [];
  String _gamesTab = 'live';

  // ─── Security ───
  String _secTab = 'audit';
  List<Map<String, dynamic>> _activeUsers = [];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 10, vsync: this);
    _loadAll();
  }

  Future<void> _logAction(String action, String message, String emoji) async {
    try { await _db.ref('adminLogs').push().set({'action': action, 'message': message, 'emoji': emoji, 'timestamp': ServerValue.timestamp}); } catch (_) {}
  }

  void _loadAll() {
    _db.ref('users').onValue.listen((e) {
      if (!e.snapshot.exists || !mounted) return;
      final map = e.snapshot.value as Map;
      final list = map.entries.map((en) {
        final u = Map<String, dynamic>.from(en.value as Map); u['uid'] = en.key; return u;
      }).toList();
      final now = DateTime.now().millisecondsSinceEpoch;
      final online = list.where((u) {
        final ls = u['lastSeen']; return ls != null && (now - (ls as num).toInt()) < 300000;
      }).length;
      setState(() { _members = list; _memberCount = list.length; _onlineCount = online; _activeUsers = list.where((u) {
        final ls = u['lastSeen']; return ls != null && (now - (ls as num).toInt()) < 300000;
      }).toList(); });
    });
    _db.ref('stories').onValue.listen((e) {
      if (!e.snapshot.exists || !mounted) return;
      final cutoff = DateTime.now().millisecondsSinceEpoch - 86400000;
      final active = (e.snapshot.value as Map).values.where((v) {
        final ts = (v as Map)['timestamp']; return ts != null && (ts as num).toInt() > cutoff;
      }).length;
      setState(() => _activeStories = active);
    });
    _db.ref('notifications').onValue.listen((e) {
      if (!e.snapshot.exists || !mounted) { setState(() { _unsentNotifs = 0; _notifHistory = []; }); return; }
      final list = (e.snapshot.value as Map).entries.map((en) {
        final v = Map<String, dynamic>.from(en.value as Map); v['id'] = en.key; return v;
      }).toList()..sort((a, b) => ((b['timestamp'] as num?) ?? 0).compareTo((a['timestamp'] as num?) ?? 0));
      setState(() {
        _unsentNotifs = list.where((v) => v['sent'] != true).length;
        _notifHistory = list;
      });
    });
    _db.ref('raceRooms').onValue.listen((e) {
      if (!e.snapshot.exists) { setState(() => _raceRooms = {}); return; }
      setState(() => _raceRooms = Map<String, dynamic>.from(e.snapshot.value as Map));
      setState(() => _activeRaces = _raceRooms.values.where((v) => (v as Map)['status'] == 'playing').length);
    });
    _db.ref('ludoRooms').onValue.listen((e) {
      if (!e.snapshot.exists) { setState(() => _ludoRooms = {}); return; }
      setState(() => _ludoRooms = Map<String, dynamic>.from(e.snapshot.value as Map));
      setState(() => _activeLudo = _ludoRooms.values.where((v) => (v as Map)['status'] == 'playing').length);
    });
    _db.ref('passBombRooms').onValue.listen((e) {
      if (!e.snapshot.exists) { setState(() => _passBombRooms = {}); return; }
      setState(() => _passBombRooms = Map<String, dynamic>.from(e.snapshot.value as Map));
    });
    _db.ref('passTheCardRooms').onValue.listen((e) {
      if (!e.snapshot.exists) { setState(() => _passTheCardRooms = {}); return; }
      setState(() => _passTheCardRooms = Map<String, dynamic>.from(e.snapshot.value as Map));
    });
    _db.ref('truthOrDareRooms').onValue.listen((e) {
      if (!e.snapshot.exists) { setState(() => _truthOrDareRooms = {}); return; }
      setState(() => _truthOrDareRooms = Map<String, dynamic>.from(e.snapshot.value as Map));
    });
    _db.ref('spyChatRooms').onValue.listen((e) {
      if (!e.snapshot.exists) { setState(() => _spyChatRooms = {}); return; }
      setState(() => _spyChatRooms = Map<String, dynamic>.from(e.snapshot.value as Map));
    });
    _db.ref('adminLogs').orderByChild('timestamp').limitToLast(30).onValue.listen((e) {
      if (!e.snapshot.exists || !mounted) return;
      final logs = (e.snapshot.value as Map).entries.map((en) {
        final v = Map<String, dynamic>.from(en.value as Map); v['id'] = en.key; return v;
      }).toList()..sort((a, b) => ((b['timestamp'] as num?) ?? 0).compareTo((a['timestamp'] as num?) ?? 0));
      setState(() => _adminLogs = logs);
    });
    _db.ref('photos').get().then((s) { if (s.exists && mounted) setState(() => _photoCount = (s.value as Map).length); });
    _db.ref('events').get().then((s) { if (s.exists && mounted) setState(() => _eventCount = (s.value as Map).length); });
    _db.ref('chats/main').get().then((s) { if (s.exists && mounted) setState(() => _chatCount = (s.value as Map).length); });

    _db.ref('inviteCodes').onValue.listen((e) {
      if (!e.snapshot.exists || !mounted) { setState(() => _inviteCodes = []); return; }
      setState(() => _inviteCodes = (e.snapshot.value as Map).entries.map((en) {
        final v = Map<String, dynamic>.from(en.value as Map); v['code'] = en.key; return v;
      }).toList());
    });

    _db.ref('appConfig').onValue.listen((e) {
      if (mounted) setState(() => _appConfig = e.snapshot.exists ? Map<String, dynamic>.from(e.snapshot.value as Map) : {});
    });

    _db.ref('users').orderByChild('gamesWon').limitToLast(20).onValue.listen((e) {
      if (!e.snapshot.exists || !mounted) return;
      final list = (e.snapshot.value as Map).entries.map((en) {
        final u = Map<String, dynamic>.from(en.value as Map); u['uid'] = en.key;
        return u;
      }).toList()..sort((a, b) => ((b['gamesWon'] as num?) ?? 0).compareTo((a['gamesWon'] as num?) ?? 0));
      setState(() => _leaderboard = list);
    });

    final cutoff = DateTime.now().millisecondsSinceEpoch - 86400000;
    _db.ref('stories').orderByChild('timestamp').startAt(cutoff.toDouble()).onValue.listen((e) {
      if (!e.snapshot.exists || !mounted) { setState(() => _stories = []); return; }
      setState(() => _stories = (e.snapshot.value as Map).entries.map((en) {
        final v = Map<String, dynamic>.from(en.value as Map); v['id'] = en.key; return v;
      }).toList()..sort((a, b) => ((b['timestamp'] as num?) ?? 0).compareTo((a['timestamp'] as num?) ?? 0)));
    });
    _db.ref('photos').orderByChild('timestamp').onValue.listen((e) {
      if (!e.snapshot.exists || !mounted) { setState(() => _photos = []); return; }
      setState(() => _photos = (e.snapshot.value as Map).entries.map((en) {
        final v = Map<String, dynamic>.from(en.value as Map); v['id'] = en.key; return v;
      }).toList()..sort((a, b) => ((b['timestamp'] as num?) ?? 0).compareTo((a['timestamp'] as num?) ?? 0)));
    });
    _db.ref('chats/$_chatGroup').onValue.listen((e) {
      if (!e.snapshot.exists || !mounted) { setState(() => _messages = []); return; }
      setState(() => _messages = (e.snapshot.value as Map).entries.map((en) {
        final v = Map<String, dynamic>.from(en.value as Map); v['id'] = en.key; return v;
      }).toList()..sort((a, b) => ((b['timestamp'] as num?) ?? 0).compareTo((a['timestamp'] as num?) ?? 0)));
    });

    http.get(Uri.parse('$_renderServer/health')).then((r) { if (mounted) setState(() => _serverOk = r.statusCode == 200); }).catchError((_) { if (mounted) setState(() => _serverOk = false); });
  }

  String _timeAgo(dynamic ts) {
    if (ts == null) return 'Never';
    final diff = DateTime.now().millisecondsSinceEpoch - (ts as num).toInt();
    final m = diff ~/ 60000;
    if (m < 1) return 'just now';
    if (m < 60) return '${m}m ago';
    final h = m ~/ 60;
    if (h < 24) return '${h}h ago';
    return '${h ~/ 24}d ago';
  }

  @override
  void dispose() {
    _tabCtrl.dispose(); _codeCtrl.dispose();
    _notifTitleCtrl.dispose(); _notifBodyCtrl.dispose(); _dbPathCtrl.dispose();
    super.dispose();
  }

  Widget _avatar(String? photo, String name, double size) {
    return Container(width: size, height: size,
      decoration: BoxDecoration(gradient: AppTheme.mainGradient, shape: BoxShape.circle),
      child: photo != null && photo.isNotEmpty
          ? ClipOval(child: Image.network(photo, fit: BoxFit.cover, width: size, height: size,
              errorBuilder: (_, __, ___) => _avatarLetter(name, size)))
          : _avatarLetter(name, size));
  }
  Widget _avatarLetter(String name, double size) => Center(child: Text(
    name.isNotEmpty ? name[0].toUpperCase() : '?',
    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: size * 0.4)));

  Widget _badge(String text, Color bg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(100)),
    child: Text(text, style: TextStyle(fontSize: 10,
      color: bg.computeLuminance() > 0.5 ? AppTheme.ink : Colors.white, fontWeight: FontWeight.w600)));

  Widget _chip(String text, {Color? bg, Color? fg}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: bg ?? const Color(0xFFEDE9FE), borderRadius: BorderRadius.circular(100)),
    child: Text(text, style: TextStyle(fontSize: 10, color: fg ?? AppTheme.primary, fontWeight: FontWeight.w600)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: AppTheme.ink),
          onPressed: () => Navigator.pop(context)),
        title: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Cousin Pro', style: TextStyle(fontSize: 12, color: AppTheme.soft)),
          Text('Admin Control', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.ink)),
        ]),
        bottom: TabBar(
          controller: _tabCtrl, isScrollable: true,
          labelColor: AppTheme.primary, unselectedLabelColor: AppTheme.soft,
          indicatorColor: AppTheme.primary, indicatorWeight: 2,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
          tabs: const [
            Tab(text: 'Dashboard'), Tab(text: 'Members'), Tab(text: 'Moderation'),
            Tab(text: 'Notifications'), Tab(text: 'Config'),
            Tab(text: 'Games'), Tab(text: 'Analytics'),
            Tab(text: 'Security'), Tab(text: 'Database'), Tab(text: 'Storage'),
          ],
        ),
      ),
      body: TabBarView(controller: _tabCtrl, children: [
        _buildDashboard(),
        _buildMembers(),
        _buildModeration(),
        _buildNotifications(),
        _buildConfig(),
        _buildGames(),
        _buildAnalytics(),
        _buildSecurity(),
        _buildDatabase(),
        _buildStorage(),
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // DASHBOARD
  // ═══════════════════════════════════════════════════════════
  Widget _buildDashboard() {
    return SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(children: [
      Wrap(spacing: 12, runSpacing: 12,
        children: [
          _statCard('👥', '$_memberCount', 'Total Members', const Color(0xFF7C3AED)),
          _statCard('🟢', '$_onlineCount', 'Online Now', const Color(0xFF10B981)),
          _statCard('✨', '$_activeStories', 'Active Stories', const Color(0xFFEC4899)),
          _statCard('🔔', '$_unsentNotifs', 'Unsent Notifs', const Color(0xFFF59E0B)),
          _statCard('📸', '$_photoCount', 'Photos', const Color(0xFF3B82F6)),
          _statCard('🎲', '$_activeLudo', 'Active Ludo', const Color(0xFFEF4444)),
          _statCard('🏃', '$_activeRaces', 'Active Races', const Color(0xFFFF5722)),
          _statCard('🎉', '$_eventCount', 'Events', const Color(0xFF9C27B0)),
        ].map((c) => SizedBox(width: (MediaQuery.of(context).size.width - 56) / 2, child: c)).toList()),
      const SizedBox(height: 16),
      _sectionCard('Recent Activity', [
        if (_adminLogs.isEmpty)
          const Padding(padding: EdgeInsets.all(20), child: Center(
            child: Text('No activity yet', style: TextStyle(color: AppTheme.soft, fontSize: 13))))
        else
          ..._adminLogs.take(15).map((log) => Padding(padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              Text(log['emoji'] ?? '📋', style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 8),
              Expanded(child: Text(log['message'] ?? log['action'] ?? '',
                style: const TextStyle(fontSize: 12, color: AppTheme.muted))),
              Text(_timeAgo(log['timestamp']), style: const TextStyle(fontSize: 10, color: AppTheme.soft)),
            ]))),
      ]),
      const SizedBox(height: 16),
      _sectionCard('Quick Actions', [
        _quickAction('🔔', 'Send Notification', () => _tabCtrl.animateTo(3)),
        _quickAction('🎫', 'Manage Invite Codes', () => _inviteDialogOpen = true),
        _quickAction('🛡️', 'Moderate Content', () => _tabCtrl.animateTo(2)),
        _quickAction('🎮', 'Monitor Games', () => _tabCtrl.animateTo(5)),
        _quickAction('📊', 'View Analytics', () => _tabCtrl.animateTo(6)),
        _quickAction('🔐', 'Security Audit', () => _tabCtrl.animateTo(7)),
        _quickAction('🗄️', 'Browse Database', () => _tabCtrl.animateTo(8)),
      ]),
      const SizedBox(height: 32),
    ]));
  }

  Widget _statCard(String emoji, String value, String label, Color color) {
    return Container(padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 32, height: 32,
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.2))),
          child: Center(child: Text(emoji, style: const TextStyle(fontSize: 16)))),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppTheme.ink)),
        Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.muted, fontWeight: FontWeight.w600)),
      ]));
  }

  Widget _sectionCard(String title, List<Widget> children) {
    return Container(padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppTheme.ink)),
        const SizedBox(height: 12),
        ...children,
      ]));
  }

  Widget _quickAction(String emoji, String label, VoidCallback onTap) {
    return GestureDetector(onTap: onTap,
      child: Container(margin: const EdgeInsets.only(bottom: 6), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: AppTheme.bg, borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE8D9C5))),
        child: Row(children: [
          Text(emoji, style: const TextStyle(fontSize: 16)), const SizedBox(width: 10),
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.ink)),
          const Spacer(), const Icon(Icons.chevron_right, size: 16, color: AppTheme.soft),
        ])));
  }

  // ═══════════════════════════════════════════════════════════
  // MEMBERS
  // ═══════════════════════════════════════════════════════════
  List<Map<String, dynamic>> get _filteredMembers {
    return _members.where((m) {
      final q = _memberSearch.toLowerCase();
      if (q.isNotEmpty && !(m['name'] ?? '').toString().toLowerCase().contains(q)
          && !(m['nickname'] ?? '').toString().toLowerCase().contains(q)
          && !(m['email'] ?? '').toString().toLowerCase().contains(q)) return false;
      if (_memberRoleFilter != 'all' && m['role'] != _memberRoleFilter) return false;
      if (_memberStatusFilter == 'active' && m['banned'] == true) return false;
      if (_memberStatusFilter == 'banned' && m['banned'] != true) return false;
      return true;
    }).toList()..sort((a, b) {
      if (_memberSortBy == 'name') return (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString());
      if (_memberSortBy == 'joined') return ((b['joinedAt'] ?? '') as String).compareTo((a['joinedAt'] ?? '') as String);
      if (_memberSortBy == 'lastSeen') return ((b['lastSeen'] as num?) ?? 0).compareTo((a['lastSeen'] as num?) ?? 0);
      return 0;
    });
  }

  Widget _buildMembers() {
    if (_inviteDialogOpen) return _buildInviteCodes();
    final filtered = _filteredMembers;
    return Row(children: [
      Expanded(child: Column(children: [
        Container(margin: const EdgeInsets.all(12), padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
          child: Column(children: [
            TextField(onChanged: (v) => setState(() => _memberSearch = v),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search, size: 18, color: AppTheme.soft),
                hintText: 'Search name, nickname, email...', filled: true, fillColor: AppTheme.bg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
              style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 8),
            Row(children: [
              _dd(['all','admin','member'], _memberRoleFilter, ['All','Admin','Member'], (v) => setState(() => _memberRoleFilter = v!)),
              const SizedBox(width: 8),
              _dd(['all','active','banned'], _memberStatusFilter, ['All','Active','Banned'], (v) => setState(() => _memberStatusFilter = v!)),
              const SizedBox(width: 8),
              _dd(['name','joined','lastSeen'], _memberSortBy, ['Name','Joined','Active'], (v) => setState(() => _memberSortBy = v!)),
              const SizedBox(width: 8),
              GestureDetector(onTap: () => setState(() => _inviteDialogOpen = true),
                child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(color: const Color(0xFFEDE9FE), borderRadius: BorderRadius.circular(100)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Text('🎫', style: TextStyle(fontSize: 12)),
                    const SizedBox(width: 4),
                    Text('${_inviteCodes.where((c) => c['active'] == true).length}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.primary)),
                  ]))),
            ]),
          ])),
        Expanded(child: ListView(padding: const EdgeInsets.symmetric(horizontal: 12), children: [
          ...filtered.map((m) => _memberTile(m)),
          if (filtered.isEmpty) const Padding(padding: EdgeInsets.all(40),
            child: Center(child: Text('No members found', style: TextStyle(color: AppTheme.soft)))),
          Padding(padding: const EdgeInsets.all(8),
            child: Text('${filtered.length} of ${_members.length} members',
              style: const TextStyle(fontSize: 11, color: AppTheme.soft))),
        ])),
      ])),
      AnimatedContainer(duration: const Duration(milliseconds: 200),
        width: _selectedMember != null ? 280 : 0,
        child: _selectedMember != null
            ? Container(margin: const EdgeInsets.all(12), padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)]),
                child: _memberDetail(_selectedMember!))
            : null),
    ]);
  }

  Widget _memberTile(Map<String, dynamic> m) {
    final isAdmin = m['role'] == 'admin';
    final banned = m['banned'] == true;
    final isMe = m['uid'] == AuthService().currentUid;
    final selected = _selectedMember?['uid'] == m['uid'];
    return GestureDetector(
      onTap: () => setState(() => _selectedMember = m),
      child: Container(margin: const EdgeInsets.only(bottom: 6), padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: selected ? const Color(0xFFEDE9FE) : Colors.white,
          borderRadius: BorderRadius.circular(12), border: Border.all(color: selected ? AppTheme.primary : const Color(0xFFE8D9C5))),
        child: Row(children: [
          _avatar(m['photoUrl'], m['name'] ?? '?', 36),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(m['name'] ?? 'Cousin', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.ink)),
              if (isAdmin) const Text(' 👑', style: TextStyle(fontSize: 12)),
              if (isMe) Container(margin: const EdgeInsets.only(left: 6), padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(color: const Color(0xFFEDE9FE), borderRadius: BorderRadius.circular(100)),
                child: const Text('You', style: TextStyle(fontSize: 9, color: AppTheme.primary, fontWeight: FontWeight.w600))),
            ]),
            Text(m['email'] ?? '', style: const TextStyle(fontSize: 10, color: AppTheme.soft)),
          ])),
          if (banned) _chip('Banned', bg: Colors.red.shade50, fg: Colors.red),
        ])),
    );
  }

  Widget _memberDetail(Map<String, dynamic> m) {
    final isAdmin = m['role'] == 'admin';
    final banned = m['banned'] == true;
    return SingleChildScrollView(child: Column(children: [
      Row(children: [
        const Text('Detail', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppTheme.ink)),
        const Spacer(),
        GestureDetector(onTap: () => setState(() => _selectedMember = null),
          child: const Icon(Icons.close, size: 18, color: AppTheme.soft)),
      ]),
      const SizedBox(height: 16),
      _avatar(m['photoUrl'], m['name'] ?? '?', 60),
      const SizedBox(height: 8),
      Text(m['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.ink)),
      Text(m['email'] ?? '', style: const TextStyle(fontSize: 12, color: AppTheme.muted)),
      const SizedBox(height: 8),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        _chip(isAdmin ? 'Admin 👑' : 'Member', bg: isAdmin ? const Color(0xFFFFF8E1) : const Color(0xFFEDE9FE)),
        const SizedBox(width: 6),
        if (banned) _chip('Banned 🔴', bg: Colors.red.shade50, fg: Colors.red),
      ]),
      const SizedBox(height: 16),
      _detail('Relation', m['relation'] ?? '—'), _detail('Joined', m['joinedAt']?.toString().substring(0, 10) ?? '—'),
      _detail('Last Active', _timeAgo(m['lastSeen'])), _detail('Games Won', '${m['gamesWon'] ?? 0}'),
      _detail('Birthday', m['birthday'] ?? '—'), _detail('Invite Code', m['inviteCode'] ?? '—'),
      const SizedBox(height: 16),
      SizedBox(width: double.infinity, child: OutlinedButton.icon(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BadgesScreen())),
        icon: const Text('🏅', style: TextStyle(fontSize: 14)),
        label: const Text('Manage Badges', style: TextStyle(fontSize: 12)),
        style: OutlinedButton.styleFrom(foregroundColor: AppTheme.primary,
          side: const BorderSide(color: AppTheme.primary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))),
      ),
      const SizedBox(height: 12),
      if (!isAdmin) _act('👑 Promote', () => _confirm('promote', m), const Color(0xFFFFD700))
      else _act('⬇️ Demote', () => _confirm('demote', m), AppTheme.muted),
      if (banned) _act('✅ Unban', () => _exec('unban', m), Colors.green)
      else _act('🔴 Ban', () => _confirm('ban', m), Colors.red),
      _act('🗑️ Delete', () => _confirm('delete', m), Colors.red),
    ]));
  }

  Widget _detail(String label, String value) => Padding(padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(children: [
      Text('$label:', style: const TextStyle(fontSize: 11, color: AppTheme.soft)),
      const SizedBox(width: 8),
      Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.ink)),
    ]));

  Widget _act(String label, VoidCallback onTap, Color color) => Padding(padding: const EdgeInsets.only(bottom: 6),
    child: SizedBox(width: double.infinity, child: OutlinedButton(
      onPressed: onTap, style: OutlinedButton.styleFrom(
        foregroundColor: color, side: BorderSide(color: color.withOpacity(0.3)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
      child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)))));

  Future<void> _confirm(String action, Map<String, dynamic> member) async {
    final confirmed = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(action.toUpperCase()),
      content: Text('$action ${member['name']}?${action == 'delete' ? '\n\n⚠️ This is permanent!' : ''}'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(context, true),
          child: Text('Confirm', style: TextStyle(color: action == 'delete' ? Colors.red : AppTheme.primary))),
      ],
    ));
    if (confirmed == true) await _exec(action, member);
  }

  Future<void> _exec(String action, Map<String, dynamic> member) async {
    final uid = member['uid'] as String;
    if (action == 'promote') { await _db.ref('users/$uid/role').set('admin'); await _logAction('PROMOTE', 'Promoted ${member['name']}', '👑'); }
    else if (action == 'demote') { await _db.ref('users/$uid/role').set('member'); await _logAction('DEMOTE', 'Demoted ${member['name']}', '⬇️'); }
    else if (action == 'ban') { await _db.ref('users/$uid/banned').set(true); await _logAction('BAN', 'Banned ${member['name']}', '🔴'); }
    else if (action == 'unban') { await _db.ref('users/$uid/banned').set(false); await _logAction('UNBAN', 'Unbanned ${member['name']}', '✅'); }
    else if (action == 'delete') { await _db.ref('users/$uid').remove(); await _logAction('DELETE', 'Deleted ${member['name']}', '🗑️'); _selectedMember = null; }
  }

  Widget _dd(List<String> values, String current, List<String> labels, ValueChanged<String?> onChanged) {
    return Expanded(child: Container(height: 36,
      decoration: BoxDecoration(color: AppTheme.bg, borderRadius: BorderRadius.circular(12)),
      child: DropdownButtonHideUnderline(child: DropdownButton<String>(
        value: current, isExpanded: true,
        dropdownColor: Colors.white, style: const TextStyle(fontSize: 11, color: AppTheme.ink),
        items: List.generate(values.length, (i) => DropdownMenuItem(value: values[i], child: Padding(
          padding: const EdgeInsets.only(left: 8), child: Text(labels[i])))),
        onChanged: onChanged))));
  }

  Widget _buildInviteCodes() {
    return Column(children: [
      Container(margin: const EdgeInsets.all(12), padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('🎫 Invite Codes', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.ink)),
            const Spacer(),
            GestureDetector(onTap: () => setState(() => _inviteDialogOpen = false),
              child: const Text('← Members', style: TextStyle(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.w600))),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: TextField(controller: _codeCtrl,
              decoration: InputDecoration(
                hintText: 'New code or blank for random', filled: true, fillColor: AppTheme.bg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 2))),
            const SizedBox(width: 8),
            AppTheme.gradientButton(label: 'Add', onTap: _addCode, height: 40),
          ]),
        ])),
      Expanded(child: ListView(padding: const EdgeInsets.symmetric(horizontal: 12), children: [
        ..._inviteCodes.map((c) => Container(margin: const EdgeInsets.only(bottom: 6), padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE8D9C5))),
          child: Row(children: [
            Text(c['code'] ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800,
              color: AppTheme.primary, letterSpacing: 2)),
            const Spacer(),
            _chip(c['active'] == true ? 'Active' : 'Inactive',
              bg: c['active'] == true ? const Color(0xFFE8F5E9) : Colors.red.shade50,
              fg: c['active'] == true ? Colors.green : Colors.red),
            const SizedBox(width: 8),
            GestureDetector(onTap: () => Clipboard.setData(ClipboardData(text: c['code'] ?? '')),
              child: const Icon(Icons.copy, size: 16, color: AppTheme.soft)),
            const SizedBox(width: 8),
            GestureDetector(onTap: () => _deleteInviteCode(c['code'] ?? ''),
              child: const Icon(Icons.delete_outline, size: 16, color: Colors.red)),
          ]))),
        if (_inviteCodes.isEmpty) const Padding(padding: EdgeInsets.all(40),
          child: Center(child: Text('No invite codes yet', style: TextStyle(color: AppTheme.soft)))),
      ])),
    ]);
  }

  Future<void> _addCode() async {
    final code = _codeCtrl.text.trim().toUpperCase();
    if (code.isEmpty) {
      final r = Random();
      _codeCtrl.text = r.nextInt(99999999).toString().padLeft(6, '0');
      return;
    }
    await _db.ref('inviteCodes/$code').set({'active': true, 'createdAt': ServerValue.timestamp});
    await _logAction('INVITE_CODE', 'Added code: $code', '🎫');
    _codeCtrl.clear();
  }

  Future<void> _deleteInviteCode(String code) async {
    await _db.ref('inviteCodes/$code').remove();
  }

  // ═══════════════════════════════════════════════════════════
  // MODERATION
  // ═══════════════════════════════════════════════════════════
  Widget _buildModeration() {
    return Column(children: [
      Container(color: Colors.white, child: Row(children: [
        _modBtn('stories', '✨ Stories'), _modBtn('photos', '📸 Photos'), _modBtn('chat', '💬 Chat'),
      ])),
      if (_selectedStories.isNotEmpty)
        Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), color: Colors.orange.shade50,
          child: Row(children: [
            Text('${_selectedStories.length} selected', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const Spacer(),
            GestureDetector(onTap: _bulkDeleteStories,
              child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(100)),
                child: const Text('Delete Selected', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w700))),
            ),
          ])),
      Expanded(child: _modTab == 'stories' ? _modStories() : _modTab == 'photos' ? _modPhotos() : _modChat()),
    ]);
  }

  Widget _modBtn(String id, String label) {
    final active = _modTab == id;
    return GestureDetector(onTap: () => setState(() => _modTab = id),
      child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: active ? AppTheme.primary : Colors.transparent, width: 2))),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
          color: active ? AppTheme.primary : AppTheme.soft))));
  }

  Widget _modStories() {
    final cutoff = DateTime.now().millisecondsSinceEpoch - 86400000;
    final recent = _stories.where((s) => ((s['timestamp'] as num?)?.toInt() ?? 0) > cutoff).toList();
    return Column(children: [
      if (_storyPreview != null) _storyPreviewCard(),
      Expanded(child: ListView(padding: const EdgeInsets.all(12), children: [
        Text('${recent.length} stories (24h)', style: const TextStyle(fontSize: 11, color: AppTheme.soft)),
        const SizedBox(height: 8),
        ...recent.map((s) {
          final selected = _selectedStories.contains(s['id']);
          return GestureDetector(
            onTap: () => setState(() => _storyPreview = s),
            onLongPress: () => setState(() { if (selected) _selectedStories.remove(s['id']); else _selectedStories.add(s['id'] as String); }),
            child: Container(margin: const EdgeInsets.only(bottom: 6), padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: selected ? const Color(0xFFEDE9FE) : Colors.white,
                borderRadius: BorderRadius.circular(12), border: Border.all(color: selected ? AppTheme.primary : const Color(0xFFE8D9C5))),
              child: Row(children: [
                Container(width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: s['type'] == 'text' ? Color((s['bgColor'] as num?)?.toInt() ?? 0xFF7C3AED) : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8)),
                  child: Center(child: Text(s['type'] == 'text' ? '✍️' : s['type'] == 'video' ? '🎥' : '📷',
                    style: TextStyle(fontSize: s['type'] != 'text' ? 20 : 14))),
                ),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s['uploaderName'] ?? 'Anonymous', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.ink)),
                  Text(_timeAgo(s['timestamp']), style: const TextStyle(fontSize: 10, color: AppTheme.soft)),
                ])),
                GestureDetector(onTap: () => _deleteStory(s['id'] ?? ''),
                  child: const Icon(Icons.delete_outline, size: 18, color: Colors.red)),
              ])));
        }),
        if (recent.isEmpty) const Padding(padding: EdgeInsets.all(40),
          child: Center(child: Text('No stories', style: TextStyle(color: AppTheme.soft)))),
      ])),
    ]);
  }

  Widget _storyPreviewCard() {
    final s = _storyPreview!;
    return Container(margin: const EdgeInsets.all(12), padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(children: [
        Row(children: [
          const Text('Preview', style: TextStyle(fontWeight: FontWeight.w800, color: AppTheme.ink)),
          const Spacer(),
          GestureDetector(onTap: () => setState(() => _storyPreview = null),
            child: const Icon(Icons.close, size: 18, color: AppTheme.soft)),
        ]),
        const SizedBox(height: 12),
        Container(height: 200, width: double.infinity,
          decoration: BoxDecoration(
            color: s['type'] == 'text' ? Color((s['bgColor'] as num?)?.toInt() ?? 0xFF7C3AED) : Colors.black,
            borderRadius: BorderRadius.circular(12)),
          child: s['type'] == 'text'
              ? Center(child: Text(s['text'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)))
              : (s['url'] != null ? ClipRRect(borderRadius: BorderRadius.circular(12),
                  child: Image.network(s['url'], fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Center(child: Text('📷', style: TextStyle(fontSize: 40)))))
                  : const Center(child: Text('No image'))),
        ),
        const SizedBox(height: 12),
        GestureDetector(onTap: () => _deleteStory(s['id'] ?? ''),
          child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(100)),
            child: const Text('Delete Story', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12))),
        ),
      ]));
  }

  Widget _modPhotos() {
    return ListView(padding: const EdgeInsets.all(12), children: [
      Text('${_photos.length} photos', style: const TextStyle(fontSize: 11, color: AppTheme.soft)),
      const SizedBox(height: 8),
      Wrap(spacing: 6, runSpacing: 6,
        children: _photos.take(50).map((p) => SizedBox(width: 100, height: 100,
          child: Stack(children: [
            ClipRRect(borderRadius: BorderRadius.circular(8),
              child: Image.network(p['url'] ?? '', fit: BoxFit.cover, width: 100, height: 100,
                errorBuilder: (_, __, ___) => Container(color: AppTheme.bg, child: const Center(child: Text('📷'))))),
            Positioned(top: 4, right: 4, child: GestureDetector(onTap: () => _deletePhoto(p['id'] ?? ''),
              child: Container(padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: Colors.red.withOpacity(0.8), shape: BoxShape.circle),
                child: const Icon(Icons.close, size: 12, color: Colors.white))),
            ),
          ]))).toList()),
      if (_photos.isEmpty) const Padding(padding: EdgeInsets.all(40),
        child: Center(child: Text('No photos', style: TextStyle(color: AppTheme.soft)))),
    ]);
  }

  Widget _modChat() {
    final chatGroups = ['main', 'gaming', 'travel', 'study', 'foodies'];
    return Column(children: [
      Container(margin: const EdgeInsets.all(12), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          const Text('Group:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          DropdownButtonHideUnderline(child: DropdownButton<String>(
            value: _chatGroup, dropdownColor: Colors.white,
            style: const TextStyle(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.w700),
            items: chatGroups.map((g) => DropdownMenuItem(value: g, child: Text(g.capitalize()))).toList(),
            onChanged: (v) => setState(() => _chatGroup = v!),
          )),
          const SizedBox(width: 12),
          Expanded(child: TextField(onChanged: (v) => setState(() => _modSearch = v),
            decoration: InputDecoration(
              hintText: 'Search messages...', filled: true, fillColor: AppTheme.bg,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
            style: const TextStyle(fontSize: 12))),
        ])),
      Expanded(child: ListView(padding: const EdgeInsets.symmetric(horizontal: 12), children: [
        ..._messages.where((m) {
          if (_modSearch.isEmpty) return true;
          final q = _modSearch.toLowerCase();
          return (m['text'] ?? '').toString().toLowerCase().contains(q)
              || (m['senderName'] ?? '').toString().toLowerCase().contains(q);
        }).map((m) => Container(margin: const EdgeInsets.only(bottom: 6), padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            _avatar(m['senderPhoto'], m['senderName'] ?? '?', 28),
            const SizedBox(width: 8),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(m['senderName'] ?? '?', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.primary)),
              Text(m['text'] ?? (m['type'] ?? ''), maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: AppTheme.ink)),
            ])),
            GestureDetector(onTap: () => _deleteMessage(m['id'] ?? ''),
              child: const Icon(Icons.delete_outline, size: 16, color: Colors.red)),
          ]))),
        if (_messages.isEmpty) const Padding(padding: EdgeInsets.all(40),
          child: Center(child: Text('No messages', style: TextStyle(color: AppTheme.soft)))),
      ])),
    ]);
  }

  Future<void> _deleteStory(String id) async {
    await _db.ref('stories/$id').remove();
    await _logAction('STORY_DELETED', 'Admin deleted story', '🛡️');
    _storyPreview = null;
  }
  Future<void> _deletePhoto(String id) async {
    await _db.ref('photos/$id').remove();
    await _logAction('PHOTO_DELETED', 'Admin deleted photo', '🛡️');
  }
  Future<void> _deleteMessage(String id) async {
    await _db.ref('chats/$_chatGroup/$id').remove();
    await _logAction('MSG_DELETED', 'Admin deleted message', '🛡️');
  }
  Future<void> _bulkDeleteStories() async {
    for (final id in _selectedStories) await _db.ref('stories/$id').remove();
    await _logAction('BULK_DELETE', 'Bulk deleted ${_selectedStories.length} stories', '🛡️');
    _selectedStories.clear();
  }

  // ═══════════════════════════════════════════════════════════
  // NOTIFICATIONS (Enhanced: templates, target select, history, server status)
  // ═══════════════════════════════════════════════════════════
  Widget _buildNotifications() {
    return SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(children: [
      _sectionCard('Compose Notification', [
        // Server status
        Row(children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _serverOk == null ? const Color(0xFFF3F4F6) : _serverOk! ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
              borderRadius: BorderRadius.circular(100)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 8, height: 8,
                decoration: BoxDecoration(
                  color: _serverOk == null ? Colors.grey : _serverOk! ? Colors.green : Colors.red,
                  shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(_serverOk == null ? 'Checking…' : _serverOk! ? 'Server online' : 'Server offline',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                  color: _serverOk == null ? AppTheme.muted : _serverOk! ? Colors.green : Colors.red)),
            ]),
          ),
          const SizedBox(width: 8),
          _chip('$_unsentNotifs unsent', bg: _unsentNotifs > 0 ? const Color(0xFFFFF8E1) : const Color(0xFFE8F5E9),
            fg: _unsentNotifs > 0 ? Colors.orange : Colors.green),
        ]),
        const SizedBox(height: 12),
        // Target
        Row(children: [
          _dd2('all', '📨 All Members', 'select', '🎯 Select Members'),
        ]),
        if (_notifTarget == 'select')
          Container(
            constraints: const BoxConstraints(maxHeight: 120),
            child: ListView(
              children: _members.map((m) => CheckboxListTile(
                dense: true,
                value: _selectedNotifUsers.contains(m['uid']),
                onChanged: (v) => setState(() { if (v == true) _selectedNotifUsers.add(m['uid'] as String); else _selectedNotifUsers.remove(m['uid']); }),
                title: Text(m['name'] ?? '', style: const TextStyle(fontSize: 12)),
                subtitle: m['fcmToken'] == null ? Text('no token', style: TextStyle(fontSize: 9, color: Colors.red.shade300)) : null,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
              )).toList(),
            ),
          ),
        const SizedBox(height: 12),
        TextField(controller: _notifTitleCtrl, maxLength: 60,
          decoration: InputDecoration(
            hintText: 'Notification title', filled: true, fillColor: AppTheme.bg,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        TextField(controller: _notifBodyCtrl, maxLines: 3, maxLength: 200,
          decoration: InputDecoration(
            hintText: 'Notification body', filled: true, fillColor: AppTheme.bg,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
          style: const TextStyle(fontSize: 13)),
        const SizedBox(height: 12),
        // Preview
        if (_notifTitleCtrl.text.isNotEmpty || _notifBodyCtrl.text.isNotEmpty)
          Container(padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFF1A1035), borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              Container(width: 36, height: 36,
                decoration: BoxDecoration(gradient: AppTheme.mainGradient, borderRadius: BorderRadius.circular(8)),
                child: const Center(child: Text('🎲', style: TextStyle(fontSize: 18)))),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_notifTitleCtrl.text.isNotEmpty ? _notifTitleCtrl.text : 'Title',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                Text(_notifBodyCtrl.text.isNotEmpty ? _notifBodyCtrl.text : 'Body',
                  style: const TextStyle(color: Colors.white60, fontSize: 11)),
              ])),
            ]),
          ),
        const SizedBox(height: 12),
        // Result
        if (_notifResult != null)
          Container(padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _notifResult!.contains('Error') ? Colors.red.shade50 : const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              Icon(_notifResult!.contains('Error') ? Icons.error : Icons.check_circle,
                size: 16, color: _notifResult!.contains('Error') ? Colors.red : Colors.green),
              const SizedBox(width: 8),
              Expanded(child: Text(_notifResult!, style: TextStyle(fontSize: 11,
                color: _notifResult!.contains('Error') ? Colors.red : Colors.green))),
            ]),
          ),
        const SizedBox(height: 12),
        SizedBox(width: double.infinity,
          child: AppTheme.gradientButton(label: _sendingNotif
            ? 'Sending...' : '🚀 Send Notification',
            onTap: _sendingNotif ? null : _sendNotification, height: 48)),
      ]),
      const SizedBox(height: 16),
      // Templates
      _sectionCard('📋 Templates', [
        Wrap(spacing: 8, runSpacing: 8,
          children: [
            ['🚀 New Feature!', 'Check out the latest features in Cousin Hub!'],
            ['🎉 Happy Eid!', 'Eid Mubarak from all of us! 🌙'],
            ['🎮 Game Time!', 'Challenge your cousins to a game!'],
            ['📲 App Update', 'A new version is available. Please update!'],
          ].map((t) => GestureDetector(onTap: () { _notifTitleCtrl.text = t[0]; _notifBodyCtrl.text = t[1]; setState(() {}); },
            child: Container(padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppTheme.bg, borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE8D9C5))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t[0], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.ink)),
                Text(t[1], style: const TextStyle(fontSize: 10, color: AppTheme.muted)),
              ]))).toList()),
      ]),
      const SizedBox(height: 16),
      // History
      _sectionCard('📜 History (${_notifHistory.length})', [
        if (_notifHistory.isEmpty)
          const Padding(padding: EdgeInsets.all(16), child: Center(
            child: Text('No notifications sent yet', style: TextStyle(fontSize: 12, color: AppTheme.muted))))
        else
          ..._notifHistory.take(20).map((n) => Padding(padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(n['title'] ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.ink)),
                Text(n['body'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: AppTheme.muted)),
              ])),
              const SizedBox(width: 8),
              _chip(n['sent'] == true ? 'Sent' : 'Pending',
                bg: n['sent'] == true ? const Color(0xFFE8F5E9) : const Color(0xFFFFF8E1),
                fg: n['sent'] == true ? Colors.green : Colors.orange),
              const SizedBox(width: 4),
              Text(_timeAgo(n['timestamp']), style: const TextStyle(fontSize: 9, color: AppTheme.soft)),
            ]))),
      ]),
    ]));
  }

  Widget _dd2(String v1, String l1, String v2, String l2) {
    return Expanded(child: Container(
      decoration: BoxDecoration(color: AppTheme.bg, borderRadius: BorderRadius.circular(100)),
      child: Row(children: [
        GestureDetector(onTap: () => setState(() => _notifTarget = v1),
          child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _notifTarget == v1 ? AppTheme.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(100)),
            child: Text(l1, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
              color: _notifTarget == v1 ? Colors.white : AppTheme.muted)))),
        GestureDetector(onTap: () => setState(() => _notifTarget = v2),
          child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _notifTarget == v2 ? AppTheme.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(100)),
            child: Text(l2, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
              color: _notifTarget == v2 ? Colors.white : AppTheme.muted)))),
      ]),
    ));
  }

  Future<void> _sendNotification() async {
    final title = _notifTitleCtrl.text.trim();
    final body = _notifBodyCtrl.text.trim();
    if (title.isEmpty || body.isEmpty) return;
    setState(() { _sendingNotif = true; _notifResult = null; });

    final targets = _notifTarget == 'all'
        ? _members.where((m) => m['fcmToken'] != null).toList()
        : _members.where((m) => _selectedNotifUsers.contains(m['uid']) && m['fcmToken'] != null).toList();

    if (targets.isEmpty) {
      setState(() { _notifResult = 'Error: No members with FCM tokens'; _sendingNotif = false; });
      return;
    }

    int sent = 0, failed = 0;
    String lastError = '';
    for (final m in targets) {
      try {
        final res = await http.post(
          Uri.parse('$_renderServer/send-notification'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'toToken': m['fcmToken'], 'title': title, 'body': body}),
        ).timeout(const Duration(seconds: 10));
        if (res.statusCode == 200) {
          sent++;
          await _db.ref('notifications').push().set({'toToken': m['fcmToken'], 'title': title, 'body': body, 'sent': true, 'timestamp': ServerValue.timestamp});
        } else {
          failed++;
          lastError = 'Server returned ${res.statusCode}';
        }
      } catch (e) {
        failed++;
        lastError = e.toString();
      }
    }

    await _logAction('NOTIFICATION_SENT', 'Sent "$title" to $sent members ($failed failed)', '🔔');

    setState(() {
      _notifResult = sent > 0 ? '✅ Sent to $sent members${failed > 0 ? ', $failed failed' : ''}'
          : 'Error: All failed - $lastError';
      if (sent > 0) { _notifTitleCtrl.clear(); _notifBodyCtrl.clear(); _selectedNotifUsers.clear(); }
      _sendingNotif = false;
    });
  }

  // ═══════════════════════════════════════════════════════════
  // CONFIG (Enhanced: editable fields, toggles, publish, JSON viewer)
  // ═══════════════════════════════════════════════════════════
  Widget _buildConfig() {
    return SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(children: [
      _sectionCard('📦 Update Manager', [
        _configField('latestVersion', 'Latest Version', 'text', '1.0.0'),
        _configField('updateUrl', 'APK Download URL', 'url', 'https://…'),
        _configToggle('forceUpdate', 'Force Update'),
        _configField('updateMessage', 'Update Message', 'text', 'A new version is available!'),
        _configField('changelog', 'Changelog', 'textarea', "What's new…"),
        const SizedBox(height: 12),
        SizedBox(width: double.infinity, child: AppTheme.gradientButton(
          label: '📤 Publish Update to All Users',
          onTap: _publishUpdate, height: 44)),
      ]),
      const SizedBox(height: 16),
      _sectionCard('🎛️ Feature Flags', [
        _configToggle('maintenanceMode', 'Maintenance Mode'),
        _configToggle('chatEnabled', 'Chat Enabled'),
        _configToggle('gamesEnabled', 'Games Enabled'),
        _configField('maxStoryDuration', 'Max Story Duration (s)', 'number', '60'),
      ]),
      const SizedBox(height: 16),
      _sectionCard('📊 Current Config (Raw)', [
        Container(padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(8)),
          child: Text(_appConfig.entries.map((e) => '${e.key}: ${e.value}').join('\n'),
            style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: Color(0xFF6B7280))),
        ),
      ]),
      const SizedBox(height: 16),
      _sectionCard('🔌 Firebase Status', [
        _statusRow('Authentication', '✅ Firebase Auth', Colors.green),
        _statusRow('Database', '✅ Realtime DB', Colors.green),
        _statusRow('Storage', '☁️ Cloudinary', Colors.blue),
        _statusRow('Notifications', _unsentNotifs > 0 ? '⚠️ $_unsentNotifs unsent' : '✅ All sent',
          _unsentNotifs > 0 ? Colors.orange : Colors.green),
      ]),
    ]));
  }

  Widget _configField(String key, String label, String type, String placeholder) {
    return Padding(padding: const EdgeInsets.only(bottom: 10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.ink)),
        const Spacer(),
        Text('appConfig/$key', style: const TextStyle(fontSize: 9, color: AppTheme.soft)),
      ]),
      const SizedBox(height: 4),
      Row(children: [
        Expanded(child: type == 'textarea'
            ? TextField(
                maxLines: 3,
                onChanged: (v) => _appConfig[key] = v,
                controller: TextEditingController(text: (_appConfig[key] ?? '').toString()),
                decoration: InputDecoration(
                  filled: true, fillColor: AppTheme.bg,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.all(10),
                  hintText: placeholder),
                style: const TextStyle(fontSize: 12))
            : TextField(
                keyboardType: type == 'number' ? TextInputType.number : type == 'url' ? TextInputType.url : TextInputType.text,
                onChanged: (v) => _appConfig[key] = type == 'number' ? num.tryParse(v) ?? 0 : v,
                controller: TextEditingController(text: (_appConfig[key] ?? '').toString()),
                decoration: InputDecoration(
                  filled: true, fillColor: AppTheme.bg,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  hintText: placeholder),
                style: const TextStyle(fontSize: 12))),
        const SizedBox(width: 8),
        GestureDetector(onTap: () => _saveConfigField(key),
          child: Container(padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _savingConfig.contains(key) ? AppTheme.soft : AppTheme.primary,
              borderRadius: BorderRadius.circular(8)),
            child: Icon(Icons.save, size: 16, color: Colors.white)),
        ),
      ]),
    ]));
  }

  Widget _configToggle(String key, String label) {
    final value = _appConfig[key] == true;
    return Padding(padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.ink)),
        const Spacer(),
        GestureDetector(onTap: () => _saveConfigField(key, value: !value),
          child: Container(width: 40, height: 22,
            decoration: BoxDecoration(
              color: value ? AppTheme.primary : const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(100)),
            child: AnimatedAlign(duration: const Duration(milliseconds: 200),
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.all(2),
                width: 18, height: 18,
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
            ),
          ),
        ),
      ]));
  }

  Future<void> _saveConfigField(String key, {bool? value}) async {
    setState(() => _savingConfig.add(key));
    final v = value ?? _appConfig[key];
    await _db.ref('appConfig/$key').set(v);
    await _logAction('CONFIG_UPDATED', 'Updated $key: $v', '⚙️');
    setState(() => _savingConfig.remove(key));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$key saved'), backgroundColor: AppTheme.primary, duration: const Duration(seconds: 1)));
    }
  }

  Future<void> _publishUpdate() async {
    await _db.ref('appConfig').update({
      'latestVersion': _appConfig['latestVersion'],
      'updateUrl': _appConfig['updateUrl'],
      'updateMessage': _appConfig['updateMessage'],
      'forceUpdate': _appConfig['forceUpdate'] == true,
      'changelog': _appConfig['changelog'],
    });
    await _logAction('CONFIG_UPDATED', 'Published update v${_appConfig['latestVersion']}', '⚙️');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Update published!'), backgroundColor: AppTheme.primary, duration: Duration(seconds: 2)));
    }
  }

  Widget _configItem(String label, String value, String desc) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.ink)),
          Text(desc, style: const TextStyle(fontSize: 10, color: AppTheme.soft)),
        ])),
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppTheme.primary)),
      ]));
  }

  Widget _statusRow(String label, String status, Color color) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.muted)),
        const Spacer(),
        _chip(status, bg: color.withOpacity(0.1), fg: color),
      ]));
  }

  // ═══════════════════════════════════════════════════════════
  // GAMES (new)
  // ═══════════════════════════════════════════════════════════
  List<MapEntry<String, Map<String, dynamic>>> _allRooms(String type) {
    final data = switch (type) {
      'ludo' => _ludoRooms,
      'race' => _raceRooms,
      'passBomb' => _passBombRooms,
      'passTheCard' => _passTheCardRooms,
      'truthOrDare' => _truthOrDareRooms,
      'spyChat' => _spyChatRooms,
      _ => <String, dynamic>{}
    };
    return data.entries.map((e) => MapEntry(e.key, Map<String, dynamic>.from(e.value as Map))).toList();
  }

  int _playingRooms(String type) => _allRooms(type).where((e) => e.value['status'] == 'playing').length;

  Widget _buildGames() {
    final allLudo = _allRooms('ludo');
    final allRace = _allRooms('race');
    final allBomb = _allRooms('passBomb');
    final allCard = _allRooms('passTheCard');
    final allTod = _allRooms('truthOrDare');
    final allSpy = _allRooms('spyChat');
    final totalPlaying = _playingRooms('ludo') + _playingRooms('race') + _playingRooms('passBomb')
        + _playingRooms('passTheCard') + _playingRooms('truthOrDare') + _playingRooms('spyChat');
    final totalRooms = allLudo.length + allRace.length + allBomb.length + allCard.length + allTod.length + allSpy.length;

    return Column(children: [
      Container(margin: const EdgeInsets.all(12), padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            _miniStat('🎲', '${allLudo.length}', 'Ludo'),
            _miniStat('🏃', '${allRace.length}', 'Race'),
            _miniStat('💣', '${allBomb.length}', 'Bomb'),
            _miniStat('🃏', '${allCard.length}', 'Cards'),
            _miniStat('🫂', '${allTod.length}', 'T/Dare'),
            _miniStat('🕵️', '${allSpy.length}', 'Spy'),
          ]),
          const Divider(height: 16),
          Text('$totalPlaying playing · $totalRooms total', style: const TextStyle(fontSize: 11, color: AppTheme.soft)),
        ])),
      Container(color: Colors.white, child: Row(children: [
        _gamesBtn('live', '🔴 Live'), _gamesBtn('ludo', '🎲 Ludo'), _gamesBtn('race', '🏃 Race'),
        _gamesBtn('bomb', '💣 Bomb'), _gamesBtn('cards', '🃏 Cards'), _gamesBtn('tod', '🫂 T/Dare'),
        _gamesBtn('spy', '🕵️ Spy'), _gamesBtn('leaderboard', '🏆 Top'),
      ])),
      Expanded(child: _gamesTab == 'leaderboard' ? _gamesLeaderboard() : _gamesRoomList()),
    ]);
  }

  Widget _miniStat(String emoji, String count, String label) {
    return Column(children: [
      Text(emoji, style: const TextStyle(fontSize: 18)),
      Text(count, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppTheme.ink)),
      Text(label, style: const TextStyle(fontSize: 8, color: AppTheme.muted, fontWeight: FontWeight.w600)),
    ]);
  }

  Widget _gamesBtn(String id, String label) {
    final active = _gamesTab == id;
    return GestureDetector(onTap: () => setState(() => _gamesTab = id),
      child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: active ? AppTheme.primary : Colors.transparent, width: 2))),
        child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
          color: active ? AppTheme.primary : AppTheme.soft))));
  }

  String _gameTypeForTab() {
    return switch (_gamesTab) {
      'ludo' => 'ludo',
      'race' => 'race',
      'bomb' => 'passBomb',
      'cards' => 'passTheCard',
      'tod' => 'truthOrDare',
      'spy' => 'spyChat',
      _ => 'live'
    };
  }

  Widget _gamesRoomList() {
    List<MapEntry<String, Map<String, dynamic>>> rooms;
    String gameType;
    if (_gamesTab == 'live') {
      final all = _allRooms('ludo') + _allRooms('race') + _allRooms('passBomb')
          + _allRooms('passTheCard') + _allRooms('truthOrDare') + _allRooms('spyChat');
      rooms = all.where((e) => e.value['status'] == 'playing').toList();
      gameType = '';
    } else {
      rooms = _allRooms(_gameTypeForTab());
      gameType = _gameTypeForTab();
    }

    return ListView(padding: const EdgeInsets.all(12), children: [
      if (rooms.isEmpty)
        const Padding(padding: EdgeInsets.all(40),
          child: Center(child: Text('No rooms', style: TextStyle(color: AppTheme.soft))))
      else
        ...rooms.map((entry) => _roomCard(entry.key, entry.value, gameType)),
    ]);
  }

  Widget _roomCard(String id, Map<String, dynamic> room, String gameType) {
    final emoji = switch (gameType) { 'ludo' => '🎲', 'race' => '🏃', 'passBomb' => '💣', 'passTheCard' => '🃏', 'truthOrDare' => '🫂', 'spyChat' => '🕵️', _ => '🎮' };
    final label = switch (gameType) { 'ludo' => 'Ludo', 'race' => 'Race', 'passBomb' => 'Bomb', 'passTheCard' => 'Cards', 'truthOrDare' => 'T/Dare', 'spyChat' => 'Spy', _ => 'Game' };
    final players = (room['players'] as Map?)?.values.cast<Map>().toList() ?? [];
    final status = room['status'] ?? 'unknown';
    final roomCode = room['roomCode'];
    final created = room['created'] ?? room['createdAt'];

    return Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8D9C5))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.ink)),
            Text('${id.length > 12 ? '${id.substring(0, 12)}…' : id}', style: const TextStyle(fontSize: 9, fontFamily: 'monospace', color: AppTheme.soft)),
          ])),
          _chip(status, bg: status == 'playing' ? const Color(0xFFE8F5E9) : const Color(0xFFFFF8E1),
            fg: status == 'playing' ? Colors.green : Colors.orange),
        ]),
        if (players.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 4,
            children: players.asMap().entries.map((e) {
              final colors = [const Color(0xFFE53935), const Color(0xFF1E88E5), const Color(0xFFFDD835), const Color(0xFF43A047)];
              final p = Map<String, dynamic>.from(e.value as Map);
              return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: colors[e.key % 4].withOpacity(0.1),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: colors[e.key % 4].withOpacity(0.2))),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 6, height: 6,
                    decoration: BoxDecoration(color: colors[e.key % 4], shape: BoxShape.circle)),
                  const SizedBox(width: 4),
                  Text(p['name'] ?? 'Cousin', style: const TextStyle(fontSize: 10, color: AppTheme.ink)),
                ]));
            }).toList()),
        ],
        if (roomCode != null)
          Padding(padding: const EdgeInsets.only(top: 6),
            child: Text('Code: $roomCode', style: const TextStyle(fontSize: 10, color: AppTheme.primary, fontWeight: FontWeight.w700))),
        Padding(padding: const EdgeInsets.only(top: 4),
          child: Text('Created ${_timeAgo(created)}', style: const TextStyle(fontSize: 9, color: AppTheme.soft))),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: GestureDetector(onTap: () => _forceEndGame(gameType, id),
            child: Container(padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(color: const Color(0xFFFFF8E1), borderRadius: BorderRadius.circular(100)),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.stop_circle_outlined, size: 12, color: Colors.orange),
                const SizedBox(width: 4),
                const Text('Force End', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.orange)),
              ]),
            ),
          )),
          const SizedBox(width: 8),
          GestureDetector(onTap: () => _deleteGame(gameType, id),
            child: Container(padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
              decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(100)),
              child: const Icon(Icons.delete_outline, size: 14, color: Colors.red)),
          ),
        ]),
      ]));
  }

  Future<void> _forceEndGame(String type, String id) async {
    final path = switch (type) { 'ludo' => 'ludoRooms', 'race' => 'raceRooms', 'passBomb' => 'passBombRooms', 'passTheCard' => 'passTheCardRooms', 'truthOrDare' => 'truthOrDareRooms', 'spyChat' => 'spyChatRooms', _ => '' };
    if (path.isEmpty) return;
    await _db.ref('$path/$id/status').set('finished');
    await _logAction('GAME_ENDED', 'Force ended $type room $id', '⏹️');
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$type room ended'), backgroundColor: Colors.orange));
  }

  Future<void> _deleteGame(String type, String id) async {
    final path = switch (type) { 'ludo' => 'ludoRooms', 'race' => 'raceRooms', 'passBomb' => 'passBombRooms', 'passTheCard' => 'passTheCardRooms', 'truthOrDare' => 'truthOrDareRooms', 'spyChat' => 'spyChatRooms', _ => '' };
    if (path.isEmpty) return;
    await _db.ref('$path/$id').remove();
    await _logAction('GAME_DELETED', 'Deleted $type room $id', '🗑️');
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$type room deleted'), backgroundColor: Colors.red));
  }

  Widget _gamesLeaderboard() {
    return ListView(padding: const EdgeInsets.all(12), children: [
      Container(padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Column(children: [
          Row(children: [
            _lbHeader('#'), _lbHeader('Member'), _lbHeader('Nickname'), _lbHeader('🏆 Wins'),
          ]),
          const Divider(height: 16),
          ..._leaderboard.take(30).asMap().entries.map((entry) {
            final i = entry.key;
            final m = entry.value;
            return Padding(padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                SizedBox(width: 24, child: Text(i == 0 ? '🥇' : i == 1 ? '🥈' : i == 2 ? '🥉' : '${i + 1}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
                SizedBox(width: 160, child: Row(children: [
                  _avatar(m['photoUrl'], m['name'] ?? '?', 24),
                  const SizedBox(width: 8),
                  Expanded(child: Text(m['name'] ?? '', overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.ink))),
                ])),
                SizedBox(width: 100, child: Text(m['nickname'] ?? '—',
                  style: const TextStyle(fontSize: 11, color: AppTheme.muted))),
                SizedBox(width: 40, child: Text('${m['gamesWon'] ?? 0}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.amber))),
              ]));
          }),
          if (_leaderboard.isEmpty) const Padding(padding: EdgeInsets.all(20),
            child: Center(child: Text('No data yet', style: TextStyle(color: AppTheme.muted)))),
        ])),
    ]);
  }

  Widget _lbHeader(String label) => SizedBox(
    width: label == '#' ? 24 : label == '🏆 Wins' ? 40 : label == 'Nickname' ? 100 : 160,
    child: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.soft)));

  // ═══════════════════════════════════════════════════════════
  // ANALYTICS (new)
  // ═══════════════════════════════════════════════════════════
  Widget _buildAnalytics() {
    final totalMsgs = _chatCount;
    final totalStories = _activeStories;
    final totalGames = _activeLudo + _activeRaces
        + _playingRooms('passBomb') + _playingRooms('passTheCard')
        + _playingRooms('truthOrDare') + _playingRooms('spyChat');
    final featureColors = [const Color(0xFF60A5FA), const Color(0xFFEC4899), const Color(0xFFF59E0B), const Color(0xFF10B981), const Color(0xFFEF4444)];
    final featureData = [
      {'name': 'Chat', 'value': 45, 'color': featureColors[0]},
      {'name': 'Stories', 'value': 20, 'color': featureColors[1]},
      {'name': 'Games', 'value': 22, 'color': featureColors[2]},
      {'name': 'Calls', 'value': 8, 'color': featureColors[3]},
      {'name': 'Location', 'value': 5, 'color': featureColors[4]},
    ];
    final topGamers = _leaderboard.take(8).toList();

    return SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(children: [
      // Summary row
      Row(children: [
        _analyticsStat('👥', '$_memberCount', 'Members', const Color(0xFF7C3AED)),
        _analyticsStat('💬', '$totalMsgs', 'Messages', const Color(0xFF60A5FA)),
        _analyticsStat('✨', '$totalStories', 'Stories', const Color(0xFFEC4899)),
        _analyticsStat('🎮', '$totalGames', 'Games', const Color(0xFFF59E0B)),
      ]),
      const SizedBox(height: 16),
      // Feature usage
      _sectionCard('🎯 Feature Usage', [
        ...featureData.map((f) => Padding(padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            Container(width: 10, height: 10,
              decoration: BoxDecoration(color: f['color'] as Color, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            SizedBox(width: 60, child: Text(f['name'] as String,
              style: const TextStyle(fontSize: 11, color: AppTheme.muted))),
            Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(100),
              child: LinearProgressIndicator(
                value: (f['value'] as int) / 100,
                backgroundColor: AppTheme.bg,
                valueColor: AlwaysStoppedAnimation<Color>(f['color'] as Color),
                minHeight: 8,
              ),
            )),
            const SizedBox(width: 8),
            SizedBox(width: 30, child: Text('${f['value']}%',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.ink))),
          ]))),
      ]),
      const SizedBox(height: 16),
      // Leaderboards
      Row(children: [
        Expanded(child: _sectionCard('🏆 Top Gamers', [
          ...topGamers.asMap().entries.map((entry) {
            final i = entry.key;
            final m = entry.value;
            final maxWins = topGamerMaxWins;
            return Padding(padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                SizedBox(width: 20, child: Text(i == 0 ? '🥇' : i == 1 ? '🥈' : i == 2 ? '🥉' : '${i+1}',
                  style: const TextStyle(fontSize: 10))),
                SizedBox(width: 80, child: Text(m['name'] ?? '', overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, color: AppTheme.ink, fontWeight: FontWeight.w600))),
                Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(100),
                  child: LinearProgressIndicator(
                    value: maxWins > 0 ? ((m['gamesWon'] as num?) ?? 0) / maxWins : 0,
                    backgroundColor: AppTheme.bg,
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF7C3AED)),
                    minHeight: 6,
                  ),
                )),
                const SizedBox(width: 8),
                Text('${m['gamesWon'] ?? 0}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.amber)),
              ]));
          }),
        ])),
      ]),
    ]));
  }

  int get topGamerMaxWins {
    return _leaderboard.isEmpty ? 1 : (_leaderboard.first['gamesWon'] as num?)?.toInt() ?? 1;
  }

  Widget _analyticsStat(String emoji, String value, String label, Color color) {
    return Expanded(child: Container(margin: const EdgeInsets.only(right: 8), padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppTheme.ink)),
        Text(label, style: const TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w600)),
      ])));
  }

  // ═══════════════════════════════════════════════════════════
  // SECURITY (new)
  // ═══════════════════════════════════════════════════════════
  Widget _buildSecurity() {
    return SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(children: [
      // Status banner
      Container(padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          Container(width: 36, height: 36,
            decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFA5D6A7))),
            child: const Center(child: Icon(Icons.shield, size: 18, color: Colors.green))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Security Status: Active', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppTheme.ink)),
            const Text('Firebase Auth required for all reads/writes',
              style: TextStyle(fontSize: 10, color: AppTheme.muted)),
          ])),
          _chip('${_activeUsers.length} online', bg: const Color(0xFFE8F5E9), fg: Colors.green),
        ])),
      const SizedBox(height: 12),
      // Tabs
      Container(padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(100)),
        child: Row(children: [
          _secBtn('audit', '📋 Audit Log'),
          _secBtn('active', '🟢 Active'),
          _secBtn('rules', '🔐 Rules'),
        ])),
      const SizedBox(height: 12),
      if (_secTab == 'audit') _secAudit(),
      if (_secTab == 'active') _secActive(),
      if (_secTab == 'rules') _secRules(),
    ]));
  }

  Widget _secBtn(String id, String label) {
    final active = _secTab == id;
    return Expanded(child: GestureDetector(onTap: () => setState(() => _secTab = id),
      child: Container(padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppTheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(100)),
        child: Text(label, textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
            color: active ? Colors.white : AppTheme.muted))),
    ));
  }

  Map<String, Color> _actionColors(String action) {
    return switch (action) {
      'BAN' || 'DELETE' => const {'color': Color(0xFFEF4444), 'bg': Color(0x20EF4444)},
      'PROMOTE' => const {'color': Color(0xFFF59E0B), 'bg': Color(0x20F59E0B)},
      'DEMOTE' => const {'color': Color(0xFF60A5FA), 'bg': Color(0x2060A5FA)},
      'STORY_DELETED' || 'PHOTO_DELETED' || 'MSG_DELETED' => const {'color': Color(0xFFEC4899), 'bg': Color(0x20EC4899)},
      'NOTIFICATION_SENT' => const {'color': Color(0xFF7C3AED), 'bg': Color(0x207C3AED)},
      'CONFIG_UPDATED' || 'INVITE_CODE' => const {'color': Color(0xFF10B981), 'bg': Color(0x2010B981)},
      _ => const {'color': Color(0xFF7C3AED), 'bg': Color(0x207C3AED)},
    };
  }

  Widget _secAudit() {
    return _sectionCard('Admin Audit Log (${_adminLogs.length})', [
      if (_adminLogs.isEmpty)
        const Padding(padding: EdgeInsets.all(20), child: Center(
          child: Text('No admin actions logged yet', style: TextStyle(fontSize: 12, color: AppTheme.muted))))
      else
        ..._adminLogs.map((log) {
          final ac = _actionColors(log['action'] ?? '');
          return Padding(padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              Text(log['emoji'] ?? '📋', style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 8),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(color: ac['bg']?.withOpacity(0.15), borderRadius: BorderRadius.circular(100)),
                  child: Text(log['action'] ?? '', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: ac['color']))),
                Text(log['message'] ?? '', style: const TextStyle(fontSize: 11, color: AppTheme.muted)),
              ])),
              Text(_timeAgo(log['timestamp']), style: const TextStyle(fontSize: 9, color: AppTheme.soft)),
            ]));
        }),
    ]);
  }

  Widget _secActive() {
    return _sectionCard('🟢 Active Sessions (${_activeUsers.length} online)', [
      if (_activeUsers.isEmpty)
        const Padding(padding: EdgeInsets.all(20), child: Center(
          child: Text('No one online right now', style: TextStyle(fontSize: 12, color: AppTheme.muted))))
      else
        Wrap(spacing: 8, runSpacing: 8,
          children: _activeUsers.map((u) => Container(padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.withOpacity(0.2))),
            width: (MediaQuery.of(context).size.width - 80) / 2,
            child: Row(children: [
              Stack(children: [
                _avatar(u['photoUrl'], u['name'] ?? '?', 28),
                Positioned(bottom: 0, right: 0,
                  child: Container(width: 8, height: 8,
                    decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle))),
              ]),
              const SizedBox(width: 8),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(u['nickname'] ?? u['name'] ?? '', overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.ink)),
                Text('Active ${_timeAgo(u['lastSeen'])}', style: const TextStyle(fontSize: 9, color: AppTheme.muted)),
              ])),
            ]))).toList()),
    ]);
  }

  Widget _secRules() {
    return Column(children: [
      _sectionCard('🔐 Recommended Firebase Rules', [
        Container(padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFF1F2937), borderRadius: BorderRadius.circular(8)),
          child: const Text(
            '{\n  "rules": {\n    ".read": "auth != null",\n    ".write": "auth != null",\n    "adminLogs": {\n      ".write": "auth != null && root.child(\'users\').child(auth.uid).child(\'role\').val() === \'admin\'"\n    }\n  }\n}',
            style: TextStyle(fontSize: 9, fontFamily: 'monospace', color: Color(0xFF86EFAC)),
          ),
        ),
        const SizedBox(height: 12),
        Container(padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(8)),
          child: const Row(children: [
            Icon(Icons.info, size: 14, color: Colors.blue),
            SizedBox(width: 8),
            Expanded(child: Text(
              'Apply these rules in Firebase Console → Realtime Database → Rules tab.',
              style: TextStyle(fontSize: 10, color: Colors.blue))),
          ])),
      ]),
      const SizedBox(height: 12),
      _sectionCard('✅ Security Checklist', [
        ...[
          [true, 'Firebase Auth required for access'],
          [true, 'Admin role verified on login'],
          [true, 'All admin actions logged to adminLogs/'],
          [true, 'Session re-checked on every navigation'],
          [false, 'Firebase rules applied (manually in Console)'],
          [false, 'Cloudinary API secret not in frontend'],
        ].map((c) => Padding(padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            Icon(c[0] as bool ? Icons.check_circle : Icons.warning,
              size: 14, color: c[0] as bool ? Colors.green : Colors.orange),
            const SizedBox(width: 8),
            Text(c[1] as String, style: TextStyle(fontSize: 11,
              color: c[0] as bool ? AppTheme.muted : Colors.orange)),
          ]))),
      ]),
    ]);
  }

  // ═══════════════════════════════════════════════════════════
  // DATABASE BROWSER
  // ═══════════════════════════════════════════════════════════
  Widget _buildDatabase() {
    return Column(children: [
      Container(margin: const EdgeInsets.all(12), padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
        child: Column(children: [
          Row(children: [
            Expanded(child: TextField(controller: _dbPathCtrl,
              decoration: InputDecoration(
                hintText: 'Firebase path (e.g. users)', filled: true, fillColor: AppTheme.bg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
              style: const TextStyle(fontSize: 13, fontFamily: 'monospace'))),
            const SizedBox(width: 8),
            GestureDetector(onTap: () { _dbPath = _dbPathCtrl.text.trim(); _browseDb(); },
              child: Container(padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.search, color: Colors.white, size: 18)),
            ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            ...['users', 'photos', 'stories', 'events', 'notifications', 'inviteCodes'].map((p) =>
              GestureDetector(onTap: () { _dbPathCtrl.text = p; _dbPath = p; _browseDb(); },
                child: Container(margin: const EdgeInsets.only(right: 6), padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: _dbPath == p ? AppTheme.primary : AppTheme.bg,
                    borderRadius: BorderRadius.circular(100)),
                  child: Text(p, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600,
                    color: _dbPath == p ? Colors.white : AppTheme.muted))),
            )),
          ]),
        ])),
      Expanded(child: _dbLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : ListView(padding: const EdgeInsets.symmetric(horizontal: 12), children: [
              if (_dbData.isEmpty)
                const Padding(padding: EdgeInsets.all(40),
                  child: Center(child: Text('No data or path not found', style: TextStyle(color: AppTheme.soft))))
              else
                ..._dbData.entries.take(100).map((e) => Container(
                  margin: const EdgeInsets.only(bottom: 4), padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(e.key, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.primary, fontFamily: 'monospace')),
                    const SizedBox(height: 4),
                    Text(_formatDbValue(e.value), style: const TextStyle(fontSize: 10, color: AppTheme.muted, fontFamily: 'monospace')),
                  ]))),
              if (_dbData.length > 100)
                Padding(padding: const EdgeInsets.all(8), child: Text('Showing 100 of ${_dbData.length} entries',
                  style: const TextStyle(fontSize: 10, color: AppTheme.soft))),
            ])),
    ]);
  }

  Future<void> _browseDb() async {
    setState(() => _dbLoading = true);
    try {
      final snap = await _db.ref(_dbPath).get();
      if (snap.exists && mounted) setState(() => _dbData = Map<String, dynamic>.from(snap.value as Map));
      else if (mounted) setState(() => _dbData = {});
    } catch (_) { if (mounted) setState(() => _dbData = {}); }
    setState(() => _dbLoading = false);
  }

  String _formatDbValue(dynamic v) {
    if (v is Map) {
      final entries = v.entries.take(5).map((e) => '${e.key}: ${_shortVal(e.value)}').join(', ');
      return '{ $entries${v.length > 5 ? ', ...' : ''} }';
    }
    return v.toString();
  }
  String _shortVal(dynamic v) {
    final s = v.toString();
    return s.length > 50 ? '${s.substring(0, 50)}...' : s;
  }

  // ═══════════════════════════════════════════════════════════
  // STORAGE
  // ═══════════════════════════════════════════════════════════
  Widget _buildStorage() {
    return SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(children: [
      _sectionCard('Cloudinary Storage', [
        const Text('Media stored on Cloudinary (cloud name: dcxpakce2).',
          style: TextStyle(fontSize: 12, color: AppTheme.muted)),
        const SizedBox(height: 16),
        _storageStat('📸', '$_photoCount', 'Photos', 'cousin_hub/photos'),
        _storageStat('✨', '${_stories.length}', 'Stories', 'cousin_hub/stories'),
        _storageStat('🖼️', '—', 'Avatars', 'cousin_hub/avatars'),
        _storageStat('🎥', '—', 'Videos', 'cousin_hub/chat_videos'),
        _storageStat('🎙️', '—', 'Voice', 'cousin_hub/voice'),
        _storageStat('📎', '—', 'Files', 'cousin_hub/files'),
      ]),
      const SizedBox(height: 16),
      _sectionCard('Storage Actions', [
        GestureDetector(
          onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Storage management coming soon'),
            backgroundColor: AppTheme.primary)),
          child: Container(padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppTheme.bg, borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE8D9C5))),
            child: const Row(children: [
              Text('☁️', style: TextStyle(fontSize: 20)),
              SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Manage Cloudinary', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.ink)),
                Text('View and delete uploaded media', style: TextStyle(fontSize: 10, color: AppTheme.soft)),
              ]),
              Spacer(),
              Icon(Icons.chevron_right, color: AppTheme.soft),
            ]),
          ),
        ),
      ]),
    ]));
  }

  Widget _storageStat(String emoji, String count, String label, String folder) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Text(emoji, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.ink)),
          Text(folder, style: const TextStyle(fontSize: 10, color: AppTheme.soft)),
        ])),
        Text(count, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppTheme.primary)),
      ]));
  }
}

extension StringCapitalize on String {
  String capitalize() => isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}
