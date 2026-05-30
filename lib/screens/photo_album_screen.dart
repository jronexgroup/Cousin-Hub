import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../app_theme.dart';
import '../services/auth_service.dart';
import '../services/cloudinary_service.dart';

class PhotoAlbumScreen extends StatefulWidget {
  const PhotoAlbumScreen({super.key});
  @override
  State<PhotoAlbumScreen> createState() => _PhotoAlbumScreenState();
}

class _PhotoAlbumScreenState extends State<PhotoAlbumScreen> {
  final _db = FirebaseDatabase.instance;

  final _picker = ImagePicker();
  List<Map<String, dynamic>> _photos = [];
  String _selectedYear = 'All';
  bool _uploading = false;
  double _uploadProgress = 0;
  List<String> _years = ['All'];

  @override
  void initState() { super.initState(); _listenPhotos(); }

  void _listenPhotos() {
    _db.ref('photos').orderByChild('timestamp').onValue.listen((e) {
      if (!e.snapshot.exists || !mounted) { setState(() => _photos = []); return; }
      final map = e.snapshot.value as Map;
      final list = map.entries.map((en) {
        final p = Map<String, dynamic>.from(en.value as Map);
        p['id'] = en.key;
        return p;
      }).toList();
      list.sort((a, b) => (b['timestamp'] ?? 0).compareTo(a['timestamp'] ?? 0));
      final years = {'All', ...list.map((p) => p['year']?.toString() ?? 'Other')};
      setState(() { _photos = list; _years = years.toList(); });
    });
  }

  Future<void> _pickAndUpload() async {
    final picked = await _picker.pickMultiImage(imageQuality: 80);
    if (picked.isEmpty) return;
    setState(() { _uploading = true; _uploadProgress = 0; });
    final uid = AuthService().currentUid ?? 'unknown';
    final data = await AuthService().getProfile(uid);
    final name = data?['nickname'] ?? data?['name'] ?? 'Cousin';
    for (int i = 0; i < picked.length; i++) {
      setState(() => _uploadProgress = i / picked.length);
      final file = File(picked[i].path);
      final url = await CloudinaryService.uploadImage(file, folder: 'cousin_hub/photos');
      if (url != null) {
        await _db.ref('photos').push().set({
          'url': url, 'uploadedBy': uid, 'uploaderName': name,
          'timestamp': ServerValue.timestamp,
          'year': DateTime.now().year.toString(),
          'caption': '',
        });
      }
    }
    setState(() => _uploading = false);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Photos uploaded! 📸'), backgroundColor: AppTheme.primary));
  }

  List<Map<String, dynamic>> get _filtered => _selectedYear == 'All'
    ? _photos : _photos.where((p) => p['year']?.toString() == _selectedYear).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(backgroundColor: Colors.white, elevation: 0, automaticallyImplyLeading: false,
        title: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Cousin Pro', style: TextStyle(fontSize: 12, color: AppTheme.soft)),
          Text('Memories', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.ink)),
        ])),
      body: Column(children: [
        // Year filter
        SizedBox(height: 50, child: ListView(scrollDirection: Axis.horizontal,
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

        // Upload progress
        if (_uploading) Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Uploading... ${(_uploadProgress * 100).toInt()}%',
              style: const TextStyle(fontSize: 13, color: AppTheme.primary, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            ClipRRect(borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: _uploadProgress, minHeight: 4,
                backgroundColor: Colors.grey.shade200,
                valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary))),
          ])),

        // Photos grid
        Expanded(child: _filtered.isEmpty
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Text('📸', style: TextStyle(fontSize: 60)),
              const SizedBox(height: 16),
              const Text('No photos yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.ink)),
              const SizedBox(height: 8),
              const Text('Upload your first family memory!', style: TextStyle(color: AppTheme.soft)),
            ]))
          : GridView.builder(padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3, crossAxisSpacing: 4, mainAxisSpacing: 4),
              itemCount: _filtered.length,
              itemBuilder: (_, i) {
                final photo = _filtered[i];
                return GestureDetector(
                  onTap: () => _showPhoto(context, photo),
                  child: ClipRRect(borderRadius: BorderRadius.circular(8),
                    child: Image.network(photo['url'] ?? '', fit: BoxFit.cover,
                      loadingBuilder: (_, child, prog) => prog == null ? child
                        : Container(color: const Color(0xFFE8D9C5),
                          child: const Center(child: CircularProgressIndicator(strokeWidth: 2))),
                      errorBuilder: (_, __, ___) => Container(color: const Color(0xFFE8D9C5),
                        child: const Center(child: Text('📷', style: TextStyle(fontSize: 24)))))));
              })),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _uploading ? null : _pickAndUpload,
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.add_photo_alternate_rounded, color: Colors.white),
        label: const Text('Upload', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
    );
  }

  void _showPhoto(BuildContext context, Map<String, dynamic> photo) {
    showDialog(context: context, builder: (_) => Dialog(backgroundColor: Colors.transparent,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ClipRRect(borderRadius: BorderRadius.circular(16),
          child: Image.network(photo['url'] ?? '', fit: BoxFit.contain)),
        const SizedBox(height: 12),
        Text('By ${photo['uploaderName'] ?? 'Cousin'}',
          style: const TextStyle(color: Colors.white, fontSize: 13)),
        const SizedBox(height: 8),
        TextButton(onPressed: () => Navigator.pop(context),
          child: const Text('Close', style: TextStyle(color: Colors.white))),
      ])));
  }
}
