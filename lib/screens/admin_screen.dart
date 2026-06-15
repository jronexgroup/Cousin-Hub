import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../app_theme.dart';
import '../services/auth_service.dart';
import '../services/badge_service.dart';
import '../services/cloudinary_service.dart';
import 'badges_screen.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});
  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> with SingleTickerProviderStateMixin {
  final _db = FirebaseDatabase.instance;
  late TabController _tabCtrl;

  // Dashboard
  int _memberCount = 0, _onlineCount = 0, _activeStories = 0, _unsentNotifs = 0;
  int _activeRaces = 0, _activeLudo = 0, _photoCount = 0, _chatCount = 0, _eventCount = 0;
  List<Map<String, dynamic>> _adminLogs = [], _members = [];

  // Members
  String _memberSearch = '', _memberRoleFilter = 'all', _memberStatusFilter = 'all', _memberSortBy = 'name';
  Map<String, dynamic>? _selectedMember;
  List<Map<String, dynamic>> _inviteCodes = [];
  final _codeCtrl = TextEditingController();
  bool _inviteDialogOpen = false;

  // Moderation
  String _modTab = 'stories', _chatGroup = 'main', _modSearch = '';
  List<Map<String, dynamic>> _stories = [], _photos = [], _messages = [];
  Map<String, dynamic>? _storyPreview;
  Set<String> _selectedStories = {};

  // Notifications
  final _notifTitleCtrl = TextEditingController(), _notifBodyCtrl = TextEditingController();
  bool _sendingNotif = false;

  // Database
  String _dbPath = 'users';
  Map<String, dynamic> _dbData = {};
  bool _dbLoading = false;
  final _dbPathCtrl = TextEditingController(text: 'users');

  // Confirm action
  Map<String, dynamic>? _confirmAction;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 7, vsync: this);
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
      setState(() { _members = list; _memberCount = list.length; _onlineCount = online; });
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
      if (!e.snapshot.exists || !mounted) return;
      setState(() => _unsentNotifs = (e.snapshot.value as Map).values.where((v) => (v as Map)['sent'] != true).length);
    });
    _db.ref('raceRooms').onValue.listen((e) {
      if (!e.snapshot.exists) { setState(() => _activeRaces = 0); return; }
      setState(() => _activeRaces = (e.snapshot.value as Map).values.where((v) => (v as Map)['status'] == 'playing').length);
    });
    _db.ref('ludoRooms').onValue.listen((e) {
      if (!e.snapshot.exists) { setState(() => _activeLudo = 0); return; }
      setState(() => _activeLudo = (e.snapshot.value as Map).values.where((v) => (v as Map)['status'] == 'playing').length);
    });
    _db.ref('adminLogs').orderByChild('timestamp').limitToLast(20).onValue.listen((e) {
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
            Tab(text: 'Notifications'), Tab(text: 'Config'), Tab(text: 'Database'),
            Tab(text: 'Storage'),
          ],
        ),
      ),
      body: TabBarView(controller: _tabCtrl, children: [
        _buildDashboard(),
        _buildMembers(),
        _buildModeration(),
        _buildNotifications(),
        _buildConfig(),
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
          _statCard('🎲', '$_activeLudo', 'Ludo Rooms', const Color(0xFFEF4444)),
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
        _quickAction('🗄️', 'Browse Database', () => _tabCtrl.animateTo(5)),
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
    final recent = _stories.where((s) => (s['timestamp'] as num?)?.toInt() ?? 0 > cutoff).toList();
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
  // NOTIFICATIONS
  // ═══════════════════════════════════════════════════════════
  Widget _buildNotifications() {
    return SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(children: [
      _sectionCard('Send Notification', [
        TextField(controller: _notifTitleCtrl,
          decoration: InputDecoration(
            hintText: 'Notification title', filled: true, fillColor: AppTheme.bg,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        TextField(controller: _notifBodyCtrl, maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Notification body', filled: true, fillColor: AppTheme.bg,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
          style: const TextStyle(fontSize: 13)),
        const SizedBox(height: 16),
        SizedBox(width: double.infinity,
          child: AppTheme.gradientButton(label: _sendingNotif ? 'Sending...' : '🚀 Send Notification',
            onTap: _sendingNotif ? null : _sendNotification, height: 48)),
      ]),
      const SizedBox(height: 16),
      _sectionCard('Notification History', [
        const Text('Recent notifications appear here',
          style: TextStyle(fontSize: 12, color: AppTheme.muted)),
      ]),
    ]));
  }

  Future<void> _sendNotification() async {
    final title = _notifTitleCtrl.text.trim();
    final body = _notifBodyCtrl.text.trim();
    if (title.isEmpty || body.isEmpty) return;
    setState(() => _sendingNotif = true);
    try {
      await _db.ref('notifications').push().set({
        'title': title, 'body': body, 'sent': false, 'createdAt': ServerValue.timestamp,
      });
      await _logAction('NOTIFICATION', 'Sent: $title', '🔔');
      _notifTitleCtrl.clear();
      _notifBodyCtrl.clear();
    } catch (_) {}
    setState(() => _sendingNotif = false);
  }

  // ═══════════════════════════════════════════════════════════
  // CONFIG
  // ═══════════════════════════════════════════════════════════
  Widget _buildConfig() {
    return SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(children: [
      _sectionCard('App Settings', [
        const Text('Basic app configuration options.',
          style: TextStyle(fontSize: 12, color: AppTheme.muted)),
        const SizedBox(height: 16),
        _configItem('👥 Max Members', '${_memberCount}', 'Maximum allowed members'),
        _configItem('🎫 Active Codes', '${_inviteCodes.where((c) => c['active'] == true).length}', 'Active invite codes'),
        _configItem('📸 Total Photos', '$_photoCount', 'Photos uploaded'),
        _configItem('💬 Total Messages', '$_chatCount', 'Messages in main chat'),
        _configItem('📅 Created', '2024', 'App creation year'),
      ]),
      const SizedBox(height: 16),
      _sectionCard('Firebase Status', [
        _statusRow('Authentication', '✅ Firebase Auth', Colors.green),
        _statusRow('Database', '✅ Realtime DB', Colors.green),
        _statusRow('Storage', '☁️ Cloudinary', Colors.blue),
        _statusRow('Notifications', _unsentNotifs > 0 ? '⚠️ $_unsentNotifs unsent' : '✅ All sent',
          _unsentNotifs > 0 ? Colors.orange : Colors.green),
      ]),
    ]));
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
