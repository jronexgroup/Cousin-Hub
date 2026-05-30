import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../services/cache_service.dart';
import '../app_theme.dart';
import 'login_screen.dart';
import 'chat_screen.dart';
import 'event_screen.dart';
import 'memory_screen.dart';
import 'profile_screen.dart';
import 'voting_screen.dart';
import 'eidi_screen.dart';
import 'games_screen.dart';
import 'members_screen.dart';
import 'admin_screen.dart';
import 'ludo_screen.dart';
import 'story_screen.dart';
import 'racer_game.dart';
import 'badges_screen.dart';
import 'live_location_screen.dart';
import 'family_storybook_screen.dart';
import 'birthday_expense_screen.dart';
import 'archery_game.dart';

// ══════════════════════════════════════════════════════════
//  HOME SCREEN — All features visible
// ══════════════════════════════════════════════════════════
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Bottom nav index
  // 0=Home, 1=Chat, 2=Stories, 3=Memories, 4=Profile
  int _navIdx = 0;

  // Data
  String _name = 'Cousin', _photo = '', _role = 'member';
  int _memberCount = 0;
  String _upcomingEvent = '';
  List<Map<String, dynamic>> _memories = [];
  List<Map<String, dynamic>> _cousins = [];
  bool _offline = false;

  @override
  void initState() {
    super.initState();
    _boot();
    _watchInvites();
  }

  // ── Boot: cache first, then Firebase ──────────────────
  Future<void> _boot() async {
    await CacheService.init();
    final uid = AuthService().currentUid ?? '';

    // Instant from cache
    final cached = CacheService.loadUserProfile(uid);
    if (cached != null && mounted) _applyProfile(cached);
    final cachedUsers = CacheService.loadAllUsers();
    if (cachedUsers != null && mounted) _applyUsers(cachedUsers);
    final cachedPhotos = CacheService.loadPhotos();
    if (cachedPhotos.isNotEmpty && mounted) setState(() => _memories = cachedPhotos.take(5).toList());

    // Then Firebase
    try {
      final data = await AuthService().getProfile(uid);
      if (data != null) { await CacheService.saveUserProfile(uid, data); if (mounted) _applyProfile(data); }
      FirebaseDatabase.instance.ref('users').onValue.listen((e) async {
        if (!e.snapshot.exists || !mounted) return;
        final m = Map<String, dynamic>.from(e.snapshot.value as Map);
        await CacheService.saveAllUsers(m);
        if (mounted) _applyUsers(m);
      });
      FirebaseDatabase.instance.ref('photos').orderByChild('timestamp').limitToLast(5).onValue.listen((e) async {
        if (!e.snapshot.exists || !mounted) return;
        final list = (e.snapshot.value as Map).entries.map((en) {
          final p = Map<String, dynamic>.from(en.value as Map); p['id'] = en.key; return p;
        }).toList()..sort((a,b) => (b['timestamp']??0).compareTo(a['timestamp']??0));
        await CacheService.savePhotos(list);
        if (mounted) setState(() => _memories = list);
      });
      FirebaseDatabase.instance.ref('events').orderByChild('date').limitToFirst(1).onValue.listen((e) {
        if (!e.snapshot.exists || !mounted) return;
        final v = (e.snapshot.value as Map).values.first;
        if (mounted) setState(() => _upcomingEvent = (Map<String, dynamic>.from(v as Map))['title'] ?? '');
      });
      NotificationService.saveTokenForCurrentUser();
      if (mounted) setState(() => _offline = false);
    } catch (_) { if (mounted) setState(() => _offline = true); }
  }

  void _applyProfile(Map<String, dynamic> d) => setState(() {
    _name = d['nickname'] ?? d['name'] ?? 'Cousin';
    _photo = d['photoUrl'] ?? '';
    _role = d['role'] ?? 'member';
  });

  void _applyUsers(Map<String, dynamic> m) => setState(() {
    _memberCount = m.length;
    _cousins = m.entries.map((e) { final u = Map<String, dynamic>.from(e.value as Map); u['uid'] = e.key; return u; }).toList();
  });

  // ── Watch ALL invites ──────────────────────────────────
  void _watchInvites() {
    final uid = AuthService().currentUid; if (uid == null) return;

    // Ludo invites
    FirebaseDatabase.instance.ref('ludoInvites/$uid').onChildAdded.listen((e) {
      if (!e.snapshot.exists || !mounted) return;
      final inv = Map<String, dynamic>.from(e.snapshot.value as Map);
      final roomId = inv['roomId'] as String? ?? e.snapshot.key ?? '';
      _showInviteDialog('🎲', inv['hostName'] ?? 'Cousin', 'Ludo Multiplayer 👑',
        onAccept: () async {
          final p = await AuthService().getProfile(uid);
          await FirebaseDatabase.instance.ref('ludoRooms/$roomId/players/$uid').update({
            'status': 'joined', 'name': p?['nickname']??p?['name']??'Cousin', 'photo': p?['photoUrl']??'',
          });
          await FirebaseDatabase.instance.ref('ludoInvites/$uid/$roomId').remove();
          if (mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => LudoFirebaseWaiting(roomId: roomId, isHost: false)));
        },
        onDecline: () async {
          await FirebaseDatabase.instance.ref('ludoRooms/$roomId/players/$uid/status').set('declined');
          await FirebaseDatabase.instance.ref('ludoInvites/$uid/$roomId').remove();
        });
    });

    // Race invites
    FirebaseDatabase.instance.ref('raceInvites/$uid').onChildAdded.listen((e) {
      if (!e.snapshot.exists || !mounted) return;
      final inv = Map<String, dynamic>.from(e.snapshot.value as Map);
      final roomId = inv['roomId'] as String? ?? e.snapshot.key ?? '';
      _showInviteDialog('🏃', inv['hostName'] ?? 'Cousin', 'Cousin Racer 🏁',
        onAccept: () async {
          final p = await AuthService().getProfile(uid);
          await FirebaseDatabase.instance.ref('raceRooms/$roomId/players/$uid').update({
            'status': 'ready', 'name': p?['nickname']??p?['name']??'Cousin', 'photo': p?['photoUrl']??'',
          });
          await FirebaseDatabase.instance.ref('raceInvites/$uid/$roomId').remove();
          if (mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => RaceWaitingScreen(roomId: roomId, isHost: false)));
        },
        onDecline: () async => FirebaseDatabase.instance.ref('raceInvites/$uid/$roomId').remove());
    });
  }

  void _showInviteDialog(String emoji, String from, String subtitle,
      {required VoidCallback onAccept, required VoidCallback onDecline}) {
    if (!mounted) return;
    showDialog(context: context, builder: (_) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(emoji, style: const TextStyle(fontSize: 56)),
        const SizedBox(height: 10),
        Text('$from invited you!', textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.ink)),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(color: AppTheme.soft, fontSize: 13)),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(child: OutlinedButton(
            onPressed: () { Navigator.pop(context); onDecline(); },
            style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100))),
            child: const Text('Decline', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700)))),
          const SizedBox(width: 10),
          Expanded(child: ElevatedButton(
            onPressed: () { Navigator.pop(context); onAccept(); },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100))),
            child: Text('$emoji Join!', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)))),
        ]),
      ]))));
  }

  void _logout() async {
    await AuthService().signOut();
    await CacheService.clearAll();
    if (mounted) Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    // 5 main screens for IndexedStack
    final screens = [
      _HomeBody(
        name: _name, photo: _photo, role: _role,
        memberCount: _memberCount, upcomingEvent: _upcomingEvent,
        memories: _memories, cousins: _cousins, offline: _offline,
        onLogout: _logout, onNav: (i) => setState(() => _navIdx = i),
      ),
      const ChatScreen(),
      const StoryScreen(),
      const MemoryScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: IndexedStack(index: _navIdx, children: screens),
      bottomNavigationBar: _BottomNav(current: _navIdx, onTap: (i) => setState(() => _navIdx = i)),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  HOME BODY — 3 sections of action cards
// ══════════════════════════════════════════════════════════
class _HomeBody extends StatelessWidget {
  final String name, photo, role, upcomingEvent;
  final int memberCount;
  final List<Map<String, dynamic>> memories, cousins;
  final bool offline;
  final VoidCallback onLogout;
  final Function(int) onNav;

  const _HomeBody({
    required this.name, required this.photo, required this.role,
    required this.memberCount, required this.upcomingEvent,
    required this.memories, required this.cousins,
    required this.offline, required this.onLogout, required this.onNav,
  });

  void _go(BuildContext ctx, Widget screen) =>
    Navigator.push(ctx, MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    return SafeArea(child: SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Offline banner ──
        if (offline) Container(color: Colors.orange, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: const Row(children: [Icon(Icons.wifi_off, color: Colors.white, size: 14), SizedBox(width: 8),
            Text('Offline — cached data', style: TextStyle(color: Colors.white, fontSize: 12))])),

        // ── Top bar ──
        Padding(padding: const EdgeInsets.fromLTRB(20,16,20,0), child: Row(children: [
          GestureDetector(onTap: () => onNav(4),
            child: Container(width: 46, height: 46,
              decoration: BoxDecoration(shape: BoxShape.circle, gradient: AppTheme.mainGradient,
                border: Border.all(color: Colors.white, width: 2.5),
                boxShadow: [BoxShadow(color: AppTheme.primary.withOpacity(0.3), blurRadius: 8)]),
              child: photo.isNotEmpty
                ? ClipOval(child: Image.network(photo, fit: BoxFit.cover, width: 46, height: 46,
                    errorBuilder: (_,__,___) => _av(name)))
                : _av(name))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('COUSIN HUB', style: TextStyle(fontSize: 9, letterSpacing: 2, color: AppTheme.soft, fontWeight: FontWeight.w800)),
            Text('Hi, $name 👋', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppTheme.ink)),
          ])),
          if (role == 'admin') GestureDetector(
            onTap: () => _go(context, const AdminScreen()),
            child: Container(margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: const Color(0xFFFFE8D0), borderRadius: BorderRadius.circular(100)),
              child: const Text('👑 Admin', style: TextStyle(fontSize: 11, color: Color(0xFFC4522A), fontWeight: FontWeight.w800)))),
          IconButton(icon: const Icon(Icons.logout_rounded, color: AppTheme.soft, size: 20), onPressed: onLogout),
        ])),

        // Member count badge
        if (memberCount > 0) Padding(padding: const EdgeInsets.fromLTRB(20,8,20,0),
          child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(color: const Color(0xFFEDE9FE), borderRadius: BorderRadius.circular(100)),
            child: Text('👥 $memberCount cousins online', style: const TextStyle(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.w700)))),

        const SizedBox(height: 14),

        // ── Hero banner ──
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(gradient: AppTheme.mainGradient, borderRadius: BorderRadius.circular(22)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(100)),
                child: const Text('🎉 PRIVATE FAMILY SPACE', style: TextStyle(fontSize: 9, color: Colors.white, letterSpacing: 1, fontWeight: FontWeight.w800))),
              const SizedBox(height: 10),
              Text(upcomingEvent.isNotEmpty ? 'Upcoming: $upcomingEvent' : 'Welcome to Cousin Hub! 🎊',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: GestureDetector(onTap: () => onNav(1),
                  child: Container(padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(100)),
                    child: const Center(child: Text('💬 Open Chat', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.primary)))))),
                const SizedBox(width: 10),
                GestureDetector(onTap: () => onNav(2),
                  child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(100)),
                    child: const Text('✨ Stories', style: TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w700)))),
              ]),
            ]))),

        const SizedBox(height: 22),

        // ══ SECTION 1: Social & Communication ══
        _sectionHeader('Social & Communication 💬'),
        const SizedBox(height: 10),
        _grid(context, [
          _Card('💬', 'Chat',     const Color(0xFFEDE9FE), () => onNav(1)),
          _Card('✨', 'Stories',  const Color(0xFFFFF0FA), () => onNav(2)),
          _Card('📸', 'Memories', const Color(0xFFE8F5E9), () => onNav(3)),
          _Card('📍', 'Location', const Color(0xFFE3F2FD), () => _go(context, const LiveLocationScreen())),
          _Card('🎉', 'Events',   const Color(0xFFE8F4FD), () => _go(context, const EventScreen())),
          _Card('🗳️', 'Voting',  const Color(0xFFFFF3E0), () => _go(context, const VotingScreen())),
          _Card('🎁', 'Eidi',     const Color(0xFFFFF8E1), () => _go(context, const EidiScreen())),
          _Card('👥', 'Members',  const Color(0xFFE8F5E9), () => _go(context, const MembersScreen())),
        ]),

        const SizedBox(height: 20),

        // ══ SECTION 2: Games ══
        _sectionHeader('Games Zone 🎮'),
        const SizedBox(height: 10),
        _grid(context, [
          _Card('🎲', 'Ludo',      const Color(0xFF1A0A2E), () => _go(context, const LudoGameScreen(roomId: '')), light: false),
          _Card('🏃', 'Racer',     const Color(0xFF0D1B0D), () => _go(context, const RacerLobbyScreen()), light: false),
          _Card('🏹', 'Archery',   const Color(0xFF1A0808), () => _go(context, const ArcheryGameScreen()), light: false),
          _Card('🧠', 'Quiz',      const Color(0xFFEDE9FE), () => _go(context, const GamesScreen())),
          _Card('🎭', 'T/Dare',   const Color(0xFFE8F5E9), () => _go(context, const GamesScreen())),
          _Card('🎡', 'Spin',      const Color(0xFFFFF0E8), () => _go(context, const GamesScreen())),
          _Card('🤔', 'Who?',      const Color(0xFFFFF8E1), () => _go(context, const GamesScreen())),
          _Card('🎲', 'Dare',      const Color(0xFFFFE8E8), () => _go(context, const GamesScreen())),
        ]),

        const SizedBox(height: 20),

        // ══ SECTION 3: Tools & More ══
        _sectionHeader('More Features 🛠️'),
        const SizedBox(height: 10),
        _grid(context, [
          _Card('🏅', 'Badges',   const Color(0xFFFFF8E1), () => _go(context, const BadgesScreen())),
          _Card('📖', 'StoryBook',const Color(0xFFEDE9FE), () => _go(context, const FamilyStorybookScreen())),
          _Card('💰', 'Expense',  const Color(0xFFE8F4FD), () => _go(context, const ExpenseSplitScreen())),
          _Card('👤', 'Profile',  const Color(0xFFF5EDE4), () => onNav(4)),
        ]),

        const SizedBox(height: 20),

        // ── Birthday widget ──
        if (cousins.isNotEmpty) BirthdayWidget(cousins: cousins),

        // ── Recent Memories strip ──
        if (memories.isNotEmpty) ...[
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              _sectionTitle('Recent Memories'),
              GestureDetector(onTap: () => onNav(3),
                child: const Text('See all', style: TextStyle(fontSize: 13, color: AppTheme.soft))),
            ])),
          const SizedBox(height: 10),
          SizedBox(height: 160, child: ListView.builder(
            scrollDirection: Axis.horizontal, padding: const EdgeInsets.only(left: 16),
            itemCount: memories.length,
            itemBuilder: (_, i) {
              final p = memories[i];
              return GestureDetector(onTap: () => onNav(3),
                child: Container(width: 130, margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), color: Colors.black),
                  child: Stack(fit: StackFit.expand, children: [
                    ClipRRect(borderRadius: BorderRadius.circular(14),
                      child: Image.network(p['url']??'', fit: BoxFit.cover,
                        errorBuilder: (_,__,___) => const Center(child: Text('📷', style: TextStyle(fontSize: 32))))),
                    Positioned(bottom: 0, left: 0, right: 0, child: Container(
                      padding: const EdgeInsets.fromLTRB(8,16,8,8),
                      decoration: BoxDecoration(borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
                        gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter,
                          colors: [Colors.black.withOpacity(0.8), Colors.transparent])),
                      child: Text('By ${p['uploaderName']??'Cousin'}',
                        style: const TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.w600)))),
                  ])));
            })),
        ],

        const SizedBox(height: 90),
      ]),
    ));
  }

  Widget _av(String n) => Center(child: Text(n.isNotEmpty ? n[0].toUpperCase() : '?',
    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)));

  Widget _sectionHeader(String title) => Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Row(children: [
      Container(width: 4, height: 18, decoration: BoxDecoration(gradient: AppTheme.mainGradient, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 8),
      Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppTheme.ink)),
    ]));

  Widget _sectionTitle(String t) => Text(t, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.ink));

  Widget _grid(BuildContext ctx, List<_Card> cards) =>
    Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 4, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 0.88,
        children: cards.map((c) => _CardWidget(card: c)).toList()));
}

class _Card {
  final String icon, label;
  final Color bg;
  final VoidCallback onTap;
  final bool light;
  const _Card(this.icon, this.label, this.bg, this.onTap, {this.light = true});
}

class _CardWidget extends StatelessWidget {
  final _Card card;
  const _CardWidget({super.key, required this.card});
  @override
  Widget build(BuildContext ctx) => GestureDetector(
    onTap: card.onTap,
    child: Container(
      decoration: BoxDecoration(color: card.bg, borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0,2))]),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(card.icon, style: const TextStyle(fontSize: 26)),
        const SizedBox(height: 5),
        Text(card.label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800,
          color: card.light ? AppTheme.ink : Colors.white),
          textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
      ])));
}

// ══════════════════════════════════════════════════════════
//  BOTTOM NAV — 5 tabs including Stories
// ══════════════════════════════════════════════════════════
class _BottomNav extends StatelessWidget {
  final int current;
  final Function(int) onTap;
  const _BottomNav({required this.current, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12, offset: const Offset(0,-2))],
        border: const Border(top: BorderSide(color: Color(0xFFEEE0D0), width: 0.5))),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        _tab(0, Icons.home_rounded, 'HOME'),
        _tab(1, Icons.chat_bubble_outline_rounded, 'CHAT'),
        _tab(2, Icons.auto_awesome_outlined, 'STORIES'),  // ← Stories tab
        _tab(3, Icons.photo_library_outlined, 'ALBUM'),
        _tab(4, Icons.person_outline_rounded, 'ME'),
      ]));
  }

  Widget _tab(int i, IconData icon, String lbl) => GestureDetector(
    onTap: () => onTap(i),
    behavior: HitTestBehavior.opaque,
    child: SizedBox(width: 64, child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      AnimatedContainer(duration: const Duration(milliseconds: 200),
        width: 42, height: 36,
        decoration: current == i ? BoxDecoration(
          color: AppTheme.primary, borderRadius: BorderRadius.circular(100)) : null,
        child: Icon(icon, size: 22, color: current == i ? Colors.white : AppTheme.soft)),
      if (current != i) Padding(padding: const EdgeInsets.only(top: 1),
        child: Text(lbl, style: const TextStyle(fontSize: 8.5, color: AppTheme.soft,
          fontWeight: FontWeight.w700, letterSpacing: 0.3))),
    ])));
}