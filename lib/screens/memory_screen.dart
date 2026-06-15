import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import '../app_theme.dart';
import '../services/auth_service.dart';
import '../services/cloudinary_service.dart';
import '../services/cache_service.dart';
import 'package:image_picker/image_picker.dart';
import '../services/badge_service.dart';

class MemoryScreen extends StatefulWidget {
  const MemoryScreen({super.key});
  @override
  State<MemoryScreen> createState() => _MemoryScreenState();
}

class _MemoryScreenState extends State<MemoryScreen> with SingleTickerProviderStateMixin {
  final _db = FirebaseDatabase.instance;
  final _picker = ImagePicker();
  late TabController _tabCtrl;
  List<Map<String, dynamic>> _photos = [];
  String _selectedYear = 'All';
  List<String> _years = ['All'];
  bool _uploading = false;
  double _uploadProgress = 0;
  bool _offline = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _loadCached();
    _listen();
  }

  void _loadCached() {
    final cached = CacheService.loadPhotos();
    if (cached.isNotEmpty && mounted) {
      final years = {'All', ...cached.map((p) => p['year']?.toString() ?? 'Other')};
      final sorted = years.toList()..sort((a, b) => a == 'All' ? -1 : b == 'All' ? 1 : b.compareTo(a));
      setState(() { _photos = cached; _years = sorted; _offline = false; });
    }
  }

  void _listen() {
    _db.ref('photos').orderByChild('timestamp').onValue.listen((e) async {
      if (!e.snapshot.exists || !mounted) { setState(() => _offline = true); return; }
      final map = e.snapshot.value as Map;
      final list = map.entries.map((en) {
        final p = Map<String, dynamic>.from(en.value as Map);
        p['id'] = en.key; return p;
      }).toList();
      list.sort((a, b) => (b['timestamp'] ?? 0).compareTo(a['timestamp'] ?? 0));
      await CacheService.savePhotos(list);
      final years = {'All', ...list.map((p) => p['year']?.toString() ?? 'Other')};
      final sorted = years.toList()..sort((a, b) => a == 'All' ? -1 : b == 'All' ? 1 : b.compareTo(a));
      setState(() { _photos = list; _years = sorted; _offline = false; });
    }, onError: (_) => setState(() => _offline = true));
  }

  Future<void> _pickAndUpload() async {
    final picked = await _picker.pickMultiImage(imageQuality: 60);
    if (picked.isEmpty) return;

    final captionCtrl = TextEditingController();
    final caption = await showDialog<String>(context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Add Caption', style: TextStyle(fontWeight: FontWeight.w800, color: AppTheme.ink)),
        content: TextField(controller: captionCtrl,
          decoration: InputDecoration(hintText: 'Describe this memory... (optional)',
            filled: true, fillColor: AppTheme.bg,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, ''), child: const Text('Skip')),
          TextButton(onPressed: () => Navigator.pop(context, captionCtrl.text.trim()),
            child: const Text('Add', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700))),
        ])) ?? '';

    setState(() { _uploading = true; _uploadProgress = 0; });
    final uid = AuthService().currentUid ?? '';
    final data = await AuthService().getProfile(uid);
    final name = data?['nickname'] ?? data?['name'] ?? 'Cousin';
    final photoUrl = data?['photoUrl'] ?? '';

    for (int i = 0; i < picked.length; i++) {
      setState(() => _uploadProgress = (i + 1) / picked.length);
      final file = File(picked[i].path);
      final url = await CloudinaryService.uploadImage(file, folder: 'cousin_hub/photos');
      if (url != null) {
        await _db.ref('photos').push().set({
          'url': url, 'uploadedBy': uid, 'uploaderName': name,
          'uploaderPhoto': photoUrl, 'caption': caption,
          'year': DateTime.now().year.toString(),
          'timestamp': ServerValue.timestamp,
        });
      }
    }
    await BadgeService.incrementStat(uid, 'photo');
    setState(() { _uploading = false; _uploadProgress = 0; });
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('📸 Memories uploaded!'), backgroundColor: AppTheme.primary));
  }

  // Save to gallery
  Future<void> _downloadToGallery(String url, String type) async {
    try {
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        final status2 = await Permission.photos.request();
        if (!status2.isGranted) return;
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⬇️ Downloading...'), duration: Duration(seconds: 1)));
      final response = await http.get(Uri.parse(url));
      final dir = await getExternalStorageDirectory();
      final galleryDir = Directory('/storage/emulated/0/DCIM/CousinHub');
      if (!await galleryDir.exists()) await galleryDir.create(recursive: true);
      final ext = type == 'video' ? 'mp4' : 'jpg';
      final file = File('${galleryDir.path}/${DateTime.now().millisecondsSinceEpoch}.$ext');
      await file.writeAsBytes(response.bodyBytes);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Saved to Gallery!'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download failed: $e')));
    }
  }

  List<Map<String, dynamic>> get _filtered => _selectedYear == 'All'
    ? _photos : _photos.where((p) => p['year']?.toString() == _selectedYear).toList();

  // Group photos by year for timeline
  Map<String, List<Map<String, dynamic>>> get _byYear {
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final p in _photos) {
      final year = p['year']?.toString() ?? 'Other';
      grouped.putIfAbsent(year, () => []).add(p);
    }
    return Map.fromEntries(grouped.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(backgroundColor: Colors.white, elevation: 0, automaticallyImplyLeading: false,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Cousin Pro', style: TextStyle(fontSize: 12, color: AppTheme.soft)),
          Text('${_photos.length} Memories', style: const TextStyle(fontSize: 20,
            fontWeight: FontWeight.w800, color: AppTheme.ink)),
        ]),
        bottom: TabBar(controller: _tabCtrl,
          labelColor: AppTheme.primary, unselectedLabelColor: AppTheme.soft,
          indicatorColor: AppTheme.primary, indicatorWeight: 2,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: const [Tab(text: 'Grid'), Tab(text: 'Timeline')]),
        actions: [
          IconButton(icon: const Icon(Icons.add_photo_alternate_outlined, color: AppTheme.primary),
            onPressed: _pickAndUpload),
        ]),
      body: Column(children: [
        if (_offline) Container(color: const Color(0xFFFF6B35),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: const Row(children: [
            Icon(Icons.wifi_off, color: Colors.white, size: 14),
            SizedBox(width: 8),
            Text('Offline — showing cached photos', style: TextStyle(color: Colors.white, fontSize: 12)),
          ])),

        if (_uploading) Container(color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(children: [
            Row(children: [
              const Text('Uploading...', style: TextStyle(fontSize: 13, color: AppTheme.primary, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text('${(_uploadProgress * 100).toInt()}%', style: const TextStyle(fontSize: 12, color: AppTheme.muted)),
            ]),
            const SizedBox(height: 6),
            ClipRRect(borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: _uploadProgress, minHeight: 4,
                backgroundColor: Colors.grey.shade200,
                valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary))),
          ])),

        // Year filter
        if (_tabCtrl.index == 0) SizedBox(height: 48, child: ListView(scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: _years.map((y) {
            final active = y == _selectedYear;
            return GestureDetector(onTap: () => setState(() => _selectedYear = y),
              child: Container(margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: active ? AppTheme.primary : Colors.white,
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: active ? AppTheme.primary : const Color(0xFFE0D0C0))),
                child: Text(y, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                  color: active ? Colors.white : AppTheme.muted))));
          }).toList())),

        Expanded(child: TabBarView(controller: _tabCtrl, children: [
          _buildGrid(),
          _buildTimeline(),
        ])),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _uploading ? null : _pickAndUpload,
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.add_photo_alternate_rounded, color: Colors.white),
        label: const Text('Upload', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildGrid() {
    if (_filtered.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Text('📸', style: TextStyle(fontSize: 60)),
      const SizedBox(height: 16),
      const Text('No photos yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.ink)),
      const SizedBox(height: 8),
      const Text('Upload your first family memory!', style: TextStyle(color: AppTheme.soft)),
    ]));

    return GridView.builder(
      padding: const EdgeInsets.all(3),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, crossAxisSpacing: 3, mainAxisSpacing: 3),
      itemCount: _filtered.length,
      itemBuilder: (_, i) {
        final photo = _filtered[i];
        return GestureDetector(
          onTap: () => _showFullPhoto(context, photo),
          child: Stack(fit: StackFit.expand, children: [
            Image.network(photo['url'] ?? '', fit: BoxFit.cover,
              loadingBuilder: (_, child, prog) => prog == null ? child
                : Container(color: const Color(0xFFE8D9C5),
                  child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary))),
              errorBuilder: (_, __, ___) => Container(color: const Color(0xFFE8D9C5),
                child: const Center(child: Text('📷', style: TextStyle(fontSize: 24))))),
            if ((photo['caption'] ?? '').isNotEmpty) Positioned(bottom: 0, left: 0, right: 0,
              child: Container(padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
                decoration: BoxDecoration(gradient: LinearGradient(
                  begin: Alignment.bottomCenter, end: Alignment.topCenter,
                  colors: [Colors.black.withOpacity(0.7), Colors.transparent])),
                child: Text(photo['caption'], maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 10)))),
          ]));
      });
  }

  Widget _buildTimeline() {
    if (_byYear.isEmpty) return const Center(child: Text('No memories yet',
      style: TextStyle(color: AppTheme.soft, fontSize: 14)));

    // "On This Day" feature
    final today = DateTime.now();
    final todayPhotos = _photos.where((p) {
      final ts = p['timestamp'];
      if (ts == null) return false;
      final dt = DateTime.fromMillisecondsSinceEpoch((ts as num).toInt());
      return dt.day == today.day && dt.month == today.month && dt.year != today.year;
    }).toList();

    return ListView(padding: const EdgeInsets.all(16), children: [
      // On This Day card
      if (todayPhotos.isNotEmpty) Container(margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(gradient: AppTheme.mainGradient, borderRadius: BorderRadius.circular(20)),
        child: Row(children: [
          Expanded(child: Padding(padding: const EdgeInsets.all(16), child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(100)),
              child: const Text('📅 ON THIS DAY', style: TextStyle(fontSize: 10, color: Colors.white, letterSpacing: 1))),
            const SizedBox(height: 8),
            Text('${todayPhotos.length} memory from the past!',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
            const SizedBox(height: 4),
            const Text('Tap to relive', style: TextStyle(fontSize: 12, color: Colors.white70)),
          ]))),
          GestureDetector(onTap: () => _showFullPhoto(context, todayPhotos.first),
            child: ClipRRect(borderRadius: const BorderRadius.only(topRight: Radius.circular(20), bottomRight: Radius.circular(20)),
              child: Image.network(todayPhotos.first['url'] ?? '', width: 100, height: 100, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(width: 100, height: 100,
                  color: Colors.white24, child: const Center(child: Text('📷', style: TextStyle(fontSize: 32))))))),
        ])),

      // Year by year
      ..._byYear.entries.map((entry) {
        final year = entry.key;
        final photos = entry.value;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 12, height: 12, decoration: BoxDecoration(
              gradient: AppTheme.mainGradient, shape: BoxShape.circle)),
            const SizedBox(width: 10),
            Text(year, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.ink)),
            const SizedBox(width: 8),
            Text('${photos.length} photos', style: const TextStyle(fontSize: 12, color: AppTheme.soft)),
          ]),
          const SizedBox(height: 12),
          SizedBox(height: 120, child: ListView.builder(scrollDirection: Axis.horizontal,
            itemCount: photos.length,
            itemBuilder: (_, i) => GestureDetector(
              onTap: () => _showFullPhoto(context, photos[i]),
              child: Container(width: 110, margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
                child: ClipRRect(borderRadius: BorderRadius.circular(12),
                  child: Image.network(photos[i]['url'] ?? '', fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(color: const Color(0xFFE8D9C5),
                      child: const Center(child: Text('📷')))))))),
          ),
          const SizedBox(height: 20),
        ]);
      }),
    ]);
  }

  void _showFullPhoto(BuildContext context, Map<String, dynamic> photo) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => _FullPhotoView(
      photo: photo, onDownload: _downloadToGallery)));
  }

  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }
}

// ── Full Photo View ────────────────────────────────────────────────────────────
class _FullPhotoView extends StatelessWidget {
  final Map<String, dynamic> photo;
  final Function(String, String) onDownload;
  const _FullPhotoView({required this.photo, required this.onDownload});

  @override
  Widget build(BuildContext context) {
    final uploaderPhoto = photo['uploaderPhoto'] ?? '';
    final uploaderName = photo['uploaderName'] ?? 'Cousin';
    final caption = photo['caption'] ?? '';
    final ts = photo['timestamp'];
    String dateStr = '';
    if (ts != null) {
      final dt = DateTime.fromMillisecondsSinceEpoch((ts as num).toInt());
      dateStr = '${dt.day}/${dt.month}/${dt.year}';
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context)),
        actions: [
          // Download button
          IconButton(
            icon: const Icon(Icons.download_rounded, color: Colors.white),
            onPressed: () => onDownload(photo['url'] ?? '', 'image')),
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: () => _showOptions(context)),
        ]),
      body: Column(children: [
        Expanded(child: Center(child: InteractiveViewer(
          child: Image.network(photo['url'] ?? '', fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Center(child: Text('📷',
              style: TextStyle(fontSize: 60))))))),

        // Bottom info
        Container(padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(gradient: LinearGradient(
            begin: Alignment.bottomCenter, end: Alignment.topCenter,
            colors: [Colors.black.withOpacity(0.9), Colors.transparent])),
          child: Row(children: [
            Container(width: 36, height: 36,
              decoration: BoxDecoration(shape: BoxShape.circle,
                gradient: AppTheme.mainGradient,
                border: Border.all(color: Colors.white, width: 1.5)),
              child: uploaderPhoto.isNotEmpty
                ? ClipOval(child: Image.network(uploaderPhoto, fit: BoxFit.cover))
                : Center(child: Text(uploaderName.isNotEmpty ? uploaderName[0].toUpperCase() : '?',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)))),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(uploaderName, style: const TextStyle(color: Colors.white,
                fontSize: 13, fontWeight: FontWeight.w700)),
              if (caption.isNotEmpty) Text(caption, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              Text(dateStr, style: const TextStyle(color: Colors.white54, fontSize: 11)),
            ])),
            // Save button
            GestureDetector(onTap: () => onDownload(photo['url'] ?? '', 'image'),
              child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(gradient: AppTheme.mainGradient, borderRadius: BorderRadius.circular(100)),
                child: const Row(children: [
                  Icon(Icons.download_rounded, color: Colors.white, size: 16),
                  SizedBox(width: 4),
                  Text('Save', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                ]))),
          ])),
      ]),
    );
  }

  void _showOptions(BuildContext context) {
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.download_rounded, color: AppTheme.primary),
            title: const Text('Save to Gallery'),
            onTap: () { Navigator.pop(context); onDownload(photo['url'] ?? '', 'image'); }),
          ListTile(leading: const Icon(Icons.share_outlined, color: AppTheme.primary),
            title: const Text('Share'),
            onTap: () => Navigator.pop(context)),
        ])));
  }
}
