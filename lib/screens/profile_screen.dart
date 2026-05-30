import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../app_theme.dart';
import '../services/auth_service.dart';
import '../services/cloudinary_service.dart';
import '../services/cache_service.dart';
import 'login_screen.dart';
import 'admin_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _db = FirebaseDatabase.instance;
  final _picker = ImagePicker();
  Map<String, dynamic>? _profile;
  int _memoriesCount = 0, _eventsCount = 0;
  bool _uploadingPhoto = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final uid = AuthService().currentUid;
    if (uid == null) { setState(() => _loading = false); return; }

    // Load from cache first (instant)
    final cached = CacheService.loadUserProfile(uid);
    if (cached != null && mounted) {
      setState(() { _profile = cached; _loading = false; });
    }

    // Then load from Firebase
    try {
      final data = await AuthService().getProfile(uid);
      if (data != null) {
        await CacheService.saveUserProfile(uid, data);
        if (mounted) setState(() { _profile = data; _loading = false; });
      }

      // Stats
      final memSnap = await _db.ref('photos').orderByChild('uploadedBy').equalTo(uid).get();
      final evSnap = await _db.ref('events').get();
      int evCount = 0;
      if (evSnap.exists) {
        final map = evSnap.value as Map;
        evCount = map.values.where((v) {
          final e = Map<String, dynamic>.from(v as Map);
          final att = e['attendees'] != null ? Map<String, dynamic>.from(e['attendees'] as Map) : {};
          return att[uid] == 'going';
        }).length;
      }
      if (mounted) setState(() {
        _memoriesCount = memSnap.exists ? (memSnap.value as Map).length : 0;
        _eventsCount = evCount;
      });
    } catch (e) {
      // Use cached data if available
      setState(() => _loading = false);
    }
  }

  Future<void> _pickProfilePhoto() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;
    setState(() => _uploadingPhoto = true);
    try {
      final url = await CloudinaryService.uploadImage(File(picked.path), folder: 'cousin_hub/avatars');
      if (url != null) {
        final uid = AuthService().currentUid!;
        await AuthService().updateProfile(uid, {'photoUrl': url});
        // Update cache
        if (_profile != null) {
          _profile!['photoUrl'] = url;
          await CacheService.saveUserProfile(uid, _profile!);
        }
        setState(() { _profile?['photoUrl'] = url; });
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Profile photo updated!'), backgroundColor: AppTheme.primary));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e')));
    }
    setState(() => _uploadingPhoto = false);
  }

  void _editProfile() {
    final nameCtrl = TextEditingController(text: _profile?['name'] ?? '');
    final nickCtrl = TextEditingController(text: _profile?['nickname'] ?? '');
    final bdCtrl = TextEditingController(text: _profile?['birthday'] ?? '');
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
        decoration: const BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Edit Profile', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.ink)),
          const SizedBox(height: 16),
          _fld(nameCtrl, 'Full Name', Icons.person_outline),
          const SizedBox(height: 12),
          _fld(nickCtrl, 'Nickname', Icons.tag),
          const SizedBox(height: 12),
          _fld(bdCtrl, 'Birthday (DD/MM/YYYY)', Icons.cake_outlined),
          const SizedBox(height: 20),
          AppTheme.gradientButton(label: 'Save Changes', onTap: () async {
            final uid = AuthService().currentUid;
            if (uid == null) return;
            final updated = {
              'name': nameCtrl.text.trim(),
              'nickname': nickCtrl.text.trim(),
              'birthday': bdCtrl.text.trim(),
            };
            await AuthService().updateProfile(uid, updated);
            if (_profile != null) {
              _profile!.addAll(updated);
              await CacheService.saveUserProfile(uid, _profile!);
            }
            if (mounted) { Navigator.pop(context); _loadProfile(); }
          }),
        ])));
  }

  void _logout() async {
    await AuthService().signOut();
    if (mounted) Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
  }

  Widget _fld(TextEditingController c, String h, IconData icon) => TextField(
    controller: c,
    decoration: InputDecoration(
      prefixIcon: Icon(icon, size: 18, color: AppTheme.muted),
      hintText: h, filled: true, fillColor: AppTheme.bg,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)));

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(
      backgroundColor: AppTheme.bg,
      body: Center(child: CircularProgressIndicator(color: AppTheme.primary)));

    if (_profile == null) return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Text('⚠️', style: TextStyle(fontSize: 50)),
        const SizedBox(height: 16),
        const Text('Could not load profile', style: TextStyle(color: AppTheme.ink, fontSize: 16)),
        const SizedBox(height: 16),
        AppTheme.gradientButton(label: 'Retry', onTap: _loadProfile),
      ])));

    final name = _profile?['name'] ?? 'Cousin';
    final nick = _profile?['nickname'] ?? '';
    final relation = _profile?['relation'] ?? 'Member';
    final email = _profile?['email'] ?? '';
    final birthday = _profile?['birthday'] ?? '';
    final role = _profile?['role'] ?? 'member';
    final photoUrl = _profile?['photoUrl'] ?? '';
    final gamesWon = (_profile?['gamesWon'] ?? 0) as int;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0, automaticallyImplyLeading: false,
        title: const Text('My Profile', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.ink)),
        actions: [
          if (role == 'admin') IconButton(
            icon: const Text('👑', style: TextStyle(fontSize: 20)),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminScreen()))),
          IconButton(icon: const Icon(Icons.edit_outlined, color: AppTheme.muted), onPressed: _editProfile),
        ]),
      body: SingleChildScrollView(child: Column(children: [
        // Profile card
        Container(margin: const EdgeInsets.all(16), padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
          child: Column(children: [
            // Avatar with upload
            GestureDetector(
              onTap: _uploadingPhoto ? null : _pickProfilePhoto,
              child: Stack(children: [
                Container(width: 90, height: 90,
                  decoration: BoxDecoration(shape: BoxShape.circle, gradient: AppTheme.mainGradient,
                    border: Border.all(color: Colors.white, width: 3)),
                  child: _uploadingPhoto
                    ? const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : photoUrl.isNotEmpty
                      ? ClipOval(child: Image.network(photoUrl, fit: BoxFit.cover, width: 90, height: 90,
                          errorBuilder: (_, __, ___) => _initAvatar(name)))
                      : _initAvatar(name)),
                Positioned(bottom: 0, right: 0,
                  child: Container(width: 28, height: 28,
                    decoration: BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2)),
                    child: const Icon(Icons.camera_alt, size: 14, color: Colors.white))),
              ])),
            const SizedBox(height: 12),
            Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.ink)),
            if (nick.isNotEmpty) Text('"$nick"', style: const TextStyle(fontSize: 14, color: AppTheme.muted)),
            const SizedBox(height: 8),
            Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(color: const Color(0xFFEDE9FE), borderRadius: BorderRadius.circular(100)),
              child: Text('$relation${role == 'admin' ? ' • 👑 Admin' : ''}',
                style: const TextStyle(fontSize: 13, color: AppTheme.primary, fontWeight: FontWeight.w600))),
          ])),

        // Stats
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            _stat('📸', '$_memoriesCount', 'Photos'),
            const SizedBox(width: 12),
            _stat('🎮', '$gamesWon', 'Games Won'),
            const SizedBox(width: 12),
            _stat('🎉', '$_eventsCount', 'Events'),
          ])),

        const SizedBox(height: 16),

        // Info
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)]),
            child: Column(children: [
              _infoRow('📧', 'Email', email),
              if (birthday.isNotEmpty) ...[const Divider(height: 1), _infoRow('🎂', 'Birthday', birthday)],
              const Divider(height: 1),
              _infoRow('🔗', 'Relation', relation),
            ]))),

        const SizedBox(height: 16),

        // Settings
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)]),
            child: Column(children: [
              _tile(Icons.edit_outlined, 'Edit Profile', onTap: _editProfile),
              _tile(Icons.notifications_outlined, 'Notifications', onTap: () {}),
              _tile(Icons.privacy_tip_outlined, 'Privacy Policy', onTap: () => _showPrivacy()),
              _tile(Icons.info_outline, 'About Cousin Hub', onTap: () => _showAbout()),
            ]))),

        const SizedBox(height: 16),

        // Logout
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GestureDetector(onTap: _logout,
            child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(color: const Color(0xFFFFE8E8), borderRadius: BorderRadius.circular(16)),
              child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.logout_rounded, color: Color(0xFFCC0000)),
                SizedBox(width: 8),
                Text('Log Out', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFFCC0000))),
              ])))),
        const SizedBox(height: 40),
      ])),
    );
  }

  Widget _initAvatar(String name) => Center(child: Text(
    name.isNotEmpty ? name[0].toUpperCase() : '?',
    style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: Colors.white)));

  Widget _stat(String icon, String val, String lbl) => Expanded(child: Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)]),
    child: Column(children: [
      Text(icon, style: const TextStyle(fontSize: 22)),
      const SizedBox(height: 4),
      Text(val, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.ink)),
      Text(lbl, style: const TextStyle(fontSize: 10, color: AppTheme.soft)),
    ])));

  Widget _infoRow(String icon, String label, String val) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
    child: Row(children: [
      Text(icon, style: const TextStyle(fontSize: 18)),
      const SizedBox(width: 12),
      Text('$label:', style: const TextStyle(fontSize: 13, color: AppTheme.soft)),
      const SizedBox(width: 8),
      Expanded(child: Text(val, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.ink),
        overflow: TextOverflow.ellipsis)),
    ]));

  Widget _tile(IconData icon, String label, {required VoidCallback onTap}) =>
    InkWell(onTap: onTap, child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(children: [
        Icon(icon, size: 20, color: AppTheme.muted),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.ink))),
        const Icon(Icons.chevron_right, size: 18, color: AppTheme.soft),
      ])));

  void _showPrivacy() => showDialog(context: context, builder: (_) => AlertDialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    title: const Text('🔒 Privacy Policy', style: TextStyle(fontWeight: FontWeight.w800)),
    content: const SingleChildScrollView(child: Text(
      'Cousin Hub is a private, invite-only app.\n\n'
      '• Your data is never shared with third parties\n'
      '• Photos are visible only to group members\n'
      '• Messages are private and encrypted\n'
      '• Email is never shown to others\n'
      '• You can delete your account anytime\n\n'
      '© 2026 JroNex — Built with ❤️',
      style: TextStyle(fontSize: 13, height: 1.6))),
    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
  ));

  void _showAbout() => showDialog(context: context, builder: (_) => AlertDialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    title: const Text('👨‍👩‍👧‍👦 About Cousin Hub', style: TextStyle(fontWeight: FontWeight.w800)),
    content: const Text(
      'Cousin Hub v1.0.0\n\n'
      'A Private Digital Space Only for Cousins.\n\n'
      '📸 Photo Album\n'
      '💬 Private Chat\n'
      '🎉 Event Planner\n'
      '🎮 Games Zone\n'
      '🗳️ Family Votes\n'
      '🎁 Eidi Tracker\n'
      '🎲 Ludo Multiplayer\n'
      '📞 Video/Voice Calls\n\n'
      'Built by JroNex © 2026',
      style: TextStyle(fontSize: 13, height: 1.6)),
    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
  ));
}
