import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../app_theme.dart';
import '../services/auth_service.dart';
import '../services/cache_service.dart';
import '../services/badge_service.dart';

// ═══════════════════════════════════════════════════════════
// ACHIEVEMENT BADGES — Gamification system
// ═══════════════════════════════════════════════════════════

class Badge {
  final String id, title, desc, emoji;
  final Color color;
  final int requirement;
  final String type; // 'chat','photo','game','story','call','login'

  const Badge({required this.id, required this.title, required this.desc,
    required this.emoji, required this.color, required this.requirement,
    required this.type});
}

const List<Badge> kAllBadges = [
  // Chat badges
  Badge(id:'chat_10',   title:'Chatterbox',    desc:'Send 10 messages',      emoji:'💬', color:Color(0xFF1E88E5), requirement:10,   type:'chat'),
  Badge(id:'chat_100',  title:'Gossip King',   desc:'Send 100 messages',     emoji:'👑', color:Color(0xFF7C3AED), requirement:100,  type:'chat'),
  Badge(id:'chat_500',  title:'Chat Legend',   desc:'Send 500 messages',     emoji:'🏆', color:Color(0xFFFF9800), requirement:500,  type:'chat'),
  // Photo badges
  Badge(id:'photo_5',   title:'Photographer',  desc:'Upload 5 photos',       emoji:'📸', color:Color(0xFFE91E63), requirement:5,    type:'photo'),
  Badge(id:'photo_20',  title:'Memory Keeper', desc:'Upload 20 photos',      emoji:'🖼️', color:Color(0xFF9C27B0), requirement:20,   type:'photo'),
  // Game badges
  Badge(id:'game_1',    title:'First Win',     desc:'Win your first game',   emoji:'🥇', color:Color(0xFFFDD835), requirement:1,    type:'game'),
  Badge(id:'game_10',   title:'Champion',      desc:'Win 10 games',          emoji:'🏆', color:Color(0xFFFF5722), requirement:10,   type:'game'),
  Badge(id:'game_50',   title:'Ludo Legend',   desc:'Win 50 games',          emoji:'👑', color:Color(0xFF7C3AED), requirement:50,   type:'game'),
  // Story badges
  Badge(id:'story_1',   title:'Storyteller',   desc:'Post your first story', emoji:'✨', color:Color(0xFF00BCD4), requirement:1,    type:'story'),
  Badge(id:'story_7',   title:'Story Streak',  desc:'7 days story streak',   emoji:'🔥', color:Color(0xFFF44336), requirement:7,    type:'story'),
  // Call badges
  Badge(id:'call_1',    title:'First Call',    desc:'Make your first call',  emoji:'📞', color:Color(0xFF43A047), requirement:1,    type:'call'),
  Badge(id:'call_10',   title:'Social Butterfly',desc:'Make 10 calls',       emoji:'🦋', color:Color(0xFF1E88E5), requirement:10,   type:'call'),
  // Login badges
  Badge(id:'login_7',   title:'Week Warrior',  desc:'Login 7 days in a row', emoji:'📅', color:Color(0xFF795548), requirement:7,    type:'login'),
  Badge(id:'login_30',  title:'Dedicated',     desc:'Login 30 days',         emoji:'💪', color:Color(0xFFFF9800), requirement:30,   type:'login'),
  // Special
  Badge(id:'early',     title:'Early Bird',    desc:'One of first 10 members',emoji:'🐦',color:Color(0xFF4CAF50), requirement:1,    type:'special'),
  Badge(id:'race_1',    title:'Speed Demon',   desc:'Win a Cousin Race',     emoji:'🏃', color:Color(0xFFE53935), requirement:1,    type:'race'),
];

class BadgesScreen extends StatefulWidget {
  const BadgesScreen({super.key});
  @override
  State<BadgesScreen> createState() => _BadgesScreenState();
}

class _BadgesScreenState extends State<BadgesScreen> {
  final _db = FirebaseDatabase.instance;
  Map<String, int> _userStats = {};
  Set<String> _earnedBadges = {};
  String _myUid = '';
  bool _loading = true;
  String _viewUid = '';
  String _viewName = '';
  List<Map<String, dynamic>> _allMembers = [];

  @override
  void initState() {
    super.initState();
    _myUid = AuthService().currentUid ?? '';
    _viewUid = _myUid;
    _loadData();
    _loadMembers();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      _userStats = await BadgeService.getStats(_viewUid);
      _earnedBadges = await BadgeService.getEarnedBadges(_viewUid);
      await _checkAndAwardBadges();
    } catch (e) { /* offline */ }
    if (mounted) setState(() => _loading = false);
  }

  void _loadMembers() {
    final cached = CacheService.loadAllUsers();
    if (cached != null) {
      setState(() => _allMembers = cached.entries.map((e) {
        final u = Map<String, dynamic>.from(e.value as Map);
        u['uid'] = e.key; return u;
      }).toList());
    }
  }

  Future<void> _checkAndAwardBadges() async {
    final newBadges = await BadgeService.checkAndAward(_viewUid);
    _earnedBadges.addAll(newBadges);
    if (newBadges.isNotEmpty && mounted) {
      _showBadgeEarned(newBadges);
    }
  }

  void _showBadgeEarned(List<String> badgeIds) {
    for (final id in badgeIds) {
      final badge = kAllBadges.firstWhere((b) => b.id == id, orElse: () => kAllBadges.first);
      showDialog(context: context, builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(padding: const EdgeInsets.all(24), child: Column(
          mainAxisSize: MainAxisSize.min, children: [
          Container(width: 80, height: 80, decoration: BoxDecoration(
            color: badge.color.withOpacity(0.15), shape: BoxShape.circle,
            border: Border.all(color: badge.color, width: 2.5)),
            child: Center(child: Text(badge.emoji, style: const TextStyle(fontSize: 40)))),
          const SizedBox(height: 16),
          const Text('🎉 Badge Earned!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppTheme.ink)),
          const SizedBox(height: 6),
          Text(badge.title, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: badge.color)),
          const SizedBox(height: 4),
          Text(badge.desc, style: const TextStyle(fontSize: 14, color: AppTheme.muted)),
          const SizedBox(height: 20),
          AppTheme.gradientButton(label: 'Awesome! 🙌', onTap: () => Navigator.pop(context)),
        ]))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMe = _viewUid == _myUid;
    final earnedBadges = kAllBadges.where((b) => _earnedBadges.contains(b.id)).toList();
    final lockedBadges = kAllBadges.where((b) => !_earnedBadges.contains(b.id)).toList();

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Cousin Pro', style: TextStyle(fontSize: 12, color: AppTheme.soft)),
          Text(isMe ? 'My Badges 🏅' : '${_viewName} Badges',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.ink)),
        ])),
      body: _loading ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
        : SingleChildScrollView(child: Column(children: [

        // Member selector
        SizedBox(height: 80, child: ListView(scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.all(12),
          children: [
            // Me
            GestureDetector(
              onTap: () { setState(() { _viewUid = _myUid; _viewName = ''; }); _loadData(); },
              child: _MemberChip(uid: _myUid, isSelected: _viewUid == _myUid, isMe: true, members: _allMembers)),
            ..._allMembers.where((m) => m['uid'] != _myUid).map((m) =>
              GestureDetector(
                onTap: () { setState(() { _viewUid = m['uid']!; _viewName = m['nickname'] ?? m['name'] ?? 'Cousin'; }); _loadData(); },
                child: _MemberChip(uid: m['uid']!, isSelected: _viewUid == m['uid'], isMe: false, members: _allMembers))),
          ])),

        // Stats row
        Padding(padding: const EdgeInsets.all(16), child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(gradient: AppTheme.mainGradient, borderRadius: BorderRadius.circular(20)),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            _statCol('🏅', '${earnedBadges.length}', 'Earned'),
            _statCol('🔒', '${lockedBadges.length}', 'Locked'),
            _statCol('💬', '${_userStats['chat'] ?? 0}', 'Messages'),
            _statCol('🎮', '${_userStats['game'] ?? 0}', 'Wins'),
          ]))),

        // Earned badges
        if (earnedBadges.isNotEmpty) ...[
          Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Row(children: [
              AppTheme.sectionTitle('Earned Badges'),
              const SizedBox(width: 8),
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: const Color(0xFFEDE9FE), borderRadius: BorderRadius.circular(100)),
                child: Text('${earnedBadges.length}', style: const TextStyle(
                  color: AppTheme.primary, fontWeight: FontWeight.w800, fontSize: 12))),
            ])),
          GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3, padding: const EdgeInsets.symmetric(horizontal: 16),
            mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.85,
            children: earnedBadges.map((b) => _BadgeCard(badge: b, earned: true,
              progress: _userStats[b.type] ?? 0)).toList()),
        ],

        // Locked badges
        Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: AppTheme.sectionTitle('Locked Badges')),
        GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3, padding: const EdgeInsets.symmetric(horizontal: 16),
          mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.85,
          children: lockedBadges.map((b) => _BadgeCard(badge: b, earned: false,
            progress: _userStats[b.type] ?? 0)).toList()),

        const SizedBox(height: 80),
      ])));
  }

  Widget _statCol(String emoji, String val, String lbl) => Column(children: [
    Text(emoji, style: const TextStyle(fontSize: 22)),
    Text(val, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
    Text(lbl, style: const TextStyle(color: Colors.white70, fontSize: 11)),
  ]);
}

class _MemberChip extends StatelessWidget {
  final String uid;
  final bool isSelected, isMe;
  final List<Map<String, dynamic>> members;
  const _MemberChip({required this.uid, required this.isSelected, required this.isMe, required this.members});

  @override
  Widget build(BuildContext context) {
    final member = isMe ? {'name': 'You', 'photoUrl': '', 'nickname': 'You'} :
      members.firstWhere((m) => m['uid'] == uid, orElse: () => {'name': 'Cousin', 'photoUrl': ''});
    final name = isMe ? 'You' : (member['nickname'] ?? member['name'] ?? 'Cousin');
    final photo = member['photoUrl'] ?? '';

    return AnimatedContainer(duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFEDE9FE) : Colors.white,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: isSelected ? AppTheme.primary : const Color(0xFFE0D0C0),
          width: isSelected ? 2 : 1)),
      child: Row(children: [
        Container(width: 30, height: 30, decoration: BoxDecoration(
          gradient: isSelected ? AppTheme.mainGradient : null,
          color: isSelected ? null : Colors.grey.shade200, shape: BoxShape.circle),
          child: photo.isNotEmpty
            ? ClipOval(child: Image.network(photo, fit: BoxFit.cover))
            : Center(child: Text(name[0].toUpperCase(),
                style: TextStyle(color: isSelected ? Colors.white : AppTheme.muted,
                  fontWeight: FontWeight.w700, fontSize: 13)))),
        const SizedBox(width: 6),
        Text(name, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
          color: isSelected ? AppTheme.primary : AppTheme.muted)),
      ]));
  }
}

class _BadgeCard extends StatelessWidget {
  final Badge badge;
  final bool earned;
  final int progress;
  const _BadgeCard({required this.badge, required this.earned, required this.progress});

  @override
  Widget build(BuildContext context) {
    final pct = (progress / badge.requirement).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: earned ? badge.color.withOpacity(0.1) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: earned ? badge.color : const Color(0xFFE8D9C5),
          width: earned ? 1.5 : 1),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)]),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        // Badge icon
        Container(width: 48, height: 48, decoration: BoxDecoration(
          color: earned ? badge.color.withOpacity(0.15) : Colors.grey.shade100,
          shape: BoxShape.circle,
          border: earned ? Border.all(color: badge.color, width: 1.5) : null),
          child: Center(child: Text(
            earned ? badge.emoji : '🔒',
            style: TextStyle(fontSize: 24, color: earned ? null : Colors.grey.shade400)))),
        const SizedBox(height: 6),
        Text(badge.title, textAlign: TextAlign.center, maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800,
            color: earned ? AppTheme.ink : AppTheme.soft)),
        const SizedBox(height: 4),
        // Progress bar
        if (!earned) ...[
          ClipRRect(borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(value: pct, minHeight: 3,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(badge.color))),
          const SizedBox(height: 2),
          Text('$progress/${badge.requirement}',
            style: const TextStyle(fontSize: 9, color: AppTheme.soft)),
        ] else
          Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: badge.color, borderRadius: BorderRadius.circular(100)),
            child: const Text('Earned ✓', style: TextStyle(fontSize: 9, color: Colors.white,
              fontWeight: FontWeight.w700))),
      ]));
  }
}
