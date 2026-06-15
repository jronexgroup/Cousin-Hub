import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'dart:io';
import '../app_theme.dart';
import '../services/auth_service.dart';
import '../services/cloudinary_service.dart';
import '../services/cache_service.dart';
import '../services/badge_service.dart';

// ═══════════════════════════════════════════════════════════
// COUSIN HUB STORIES — Instagram/WhatsApp style
// ═══════════════════════════════════════════════════════════

class StoryScreen extends StatefulWidget {
  const StoryScreen({super.key});
  @override
  State<StoryScreen> createState() => _StoryScreenState();
}

class _StoryScreenState extends State<StoryScreen> {
  final _db = FirebaseDatabase.instance;
  final _picker = ImagePicker();
  List<Map<String, dynamic>> _storyGroups = []; // grouped by user
  bool _uploading = false;
  String _myUid = '';
  String _myName = '';
  String _myPhoto = '';

  @override
  void initState() { super.initState(); _init(); }

  Future<void> _init() async {
    _myUid = AuthService().currentUid ?? '';
    final p = await AuthService().getProfile(_myUid);
    if (p != null && mounted) setState(() {
      _myName = p['nickname'] ?? p['name'] ?? 'Cousin';
      _myPhoto = p['photoUrl'] ?? '';
    });
    _loadStories();
  }

  void _loadStories() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final cutoff = now - (24 * 60 * 60 * 1000); // 24 hours ago

    _db.ref('stories').orderByChild('timestamp').startAt(cutoff.toDouble())
      .onValue.listen((e) {
      if (!e.snapshot.exists || !mounted) return;
      final map = Map<String, dynamic>.from(e.snapshot.value as Map);
      
      // Group by user
      final grouped = <String, List<Map<String, dynamic>>>{};
      map.forEach((key, val) {
        final story = Map<String, dynamic>.from(val as Map);
        story['id'] = key;
        final uid = story['uploaderUid'] as String? ?? '';
        grouped.putIfAbsent(uid, () => []);
        grouped[uid]!.add(story);
      });

      // Sort: my stories first, then others by latest
      final groups = grouped.entries.map((e) {
        final stories = e.value..sort((a, b) =>
          (b['timestamp'] ?? 0).compareTo(a['timestamp'] ?? 0));
        return {
          'uid': e.key,
          'name': stories.first['uploaderName'] ?? 'Cousin',
          'photo': stories.first['uploaderPhoto'] ?? '',
          'stories': stories,
          'hasUnread': stories.any((s) =>
            !(Map<String, dynamic>.from(s['views'] as Map? ?? {})).containsKey(_myUid)),
        };
      }).toList();

      groups.sort((a, b) {
        if (a['uid'] == _myUid) return -1;
        if (b['uid'] == _myUid) return 1;
        return (b['stories'] as List).first['timestamp']
          .compareTo((a['stories'] as List).first['timestamp']);
      });

      if (mounted) setState(() => _storyGroups = groups);
    });
  }

  Future<void> _addStory() async {
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Add to Your Story', style: TextStyle(fontSize: 18,
            fontWeight: FontWeight.w800, color: AppTheme.ink)),
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            _storyOption('📷', 'Photo\nGallery', () { Navigator.pop(context); _pickMedia(false, false); }),
            _storyOption('📸', 'Camera', () { Navigator.pop(context); _pickMedia(true, false); }),
            _storyOption('🎥', 'Video', () { Navigator.pop(context); _pickMedia(false, true); }),
            _storyOption('✍️', 'Text', () { Navigator.pop(context); _addTextStory(); }),
          ]),
          const SizedBox(height: 8),
        ])));
  }

  Widget _storyOption(String icon, String label, VoidCallback onTap) =>
    GestureDetector(onTap: onTap, child: Column(children: [
      Container(width: 56, height: 56, decoration: BoxDecoration(
        color: const Color(0xFFF5EDE4), borderRadius: BorderRadius.circular(16)),
        child: Center(child: Text(icon, style: const TextStyle(fontSize: 26)))),
      const SizedBox(height: 6),
      Text(label, textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 11, color: AppTheme.muted)),
    ]));

  Future<void> _pickMedia(bool camera, bool video) async {
    dynamic picked;
    if (video) {
      picked = await _picker.pickVideo(source: ImageSource.gallery,
        maxDuration: const Duration(seconds: 15));
    } else {
      picked = await _picker.pickImage(
        source: camera ? ImageSource.camera : ImageSource.gallery,
        imageQuality: 80);
    }
    if (picked == null) return;
    await _uploadStory(File(picked.path), video ? 'video' : 'photo');
  }

  Future<void> _addTextStory() async {
    final textCtrl = TextEditingController();
    Color bgColor = const Color(0xFF7C3AED);
    final colors = [
      const Color(0xFF7C3AED), const Color(0xFFE53935), const Color(0xFF1E88E5),
      const Color(0xFF43A047), const Color(0xFFFF9800), const Color(0xFF000000),
    ];

    await showDialog(context: context, builder: (_) => StatefulBuilder(
      builder: (ctx, setSt) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(height: 200, decoration: BoxDecoration(color: bgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
            child: Center(child: Padding(padding: const EdgeInsets.all(20),
              child: TextField(controller: textCtrl, textAlign: TextAlign.center,
                maxLines: 5, style: const TextStyle(color: Colors.white,
                  fontSize: 20, fontWeight: FontWeight.w800),
                decoration: const InputDecoration(hintText: 'Type your story...',
                  hintStyle: TextStyle(color: Colors.white60), border: InputBorder.none))))),
          Padding(padding: const EdgeInsets.all(12), child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: colors.map((c) => GestureDetector(
              onTap: () => setSt(() => bgColor = c),
              child: Container(width: 32, height: 32, margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(color: c, shape: BoxShape.circle,
                  border: Border.all(color: bgColor == c ? Colors.white : Colors.transparent, width: 3))))).toList())),
          Padding(padding: const EdgeInsets.all(12), child: Row(children: [
            Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'))),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                if (textCtrl.text.trim().isEmpty) return;
                await _postTextStory(textCtrl.text.trim(), bgColor);
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
              child: const Text('Post', style: TextStyle(color: Colors.white)))),
          ])),
        ]))));
  }

  Future<void> _postTextStory(String text, Color bgColor) async {
    setState(() => _uploading = true);
    await _db.ref('stories').push().set({
      'type': 'text',
      'text': text,
      'bgColor': bgColor.value,
      'uploaderUid': _myUid,
      'uploaderName': _myName,
      'uploaderPhoto': _myPhoto,
      'timestamp': ServerValue.timestamp,
      'views': {},
      'likes': {},
    });
    await BadgeService.incrementStat(_myUid, 'story');
    setState(() => _uploading = false);
  }

  Future<void> _uploadStory(File file, String type) async {
    setState(() => _uploading = true);
    final url = type == 'video'
      ? await CloudinaryService.uploadVideo(file, folder: 'cousin_hub/stories')
      : await CloudinaryService.uploadImage(file, folder: 'cousin_hub/stories');
    if (url != null) {
      await _db.ref('stories').push().set({
        'type': type, 'url': url,
        'uploaderUid': _myUid, 'uploaderName': _myName,
        'uploaderPhoto': _myPhoto, 'timestamp': ServerValue.timestamp,
        'views': {}, 'likes': {},
      });
      await BadgeService.incrementStat(_myUid, 'story');
    }
    if (mounted) setState(() => _uploading = false);
  }

  @override
  Widget build(BuildContext context) {
    // Calculate total stories safely
    int totalStories = 0;
    for (var group in _storyGroups) {
      final storiesList = group['stories'] as List?;
      if (storiesList != null) {
        totalStories += storiesList.length;
      }
    }

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(backgroundColor: Colors.white, elevation: 0,
        automaticallyImplyLeading: false,
        title: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Cousin Pro', style: TextStyle(fontSize: 12, color: AppTheme.soft)),
          Text('Stories ✨', style: TextStyle(fontSize: 20,
            fontWeight: FontWeight.w800, color: AppTheme.ink)),
        ])),
      body: Column(children: [
        if (_uploading) Container(color: AppTheme.primary.withOpacity(0.1),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: const Row(children: [
            SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            SizedBox(width: 10),
            Text('Uploading story...', style: TextStyle(fontSize: 13)),
          ])),

        // Stories row
        SizedBox(height: 110, child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          children: [
            // Add My Story button
            GestureDetector(onTap: _addStory,
              child: Container(width: 72, margin: const EdgeInsets.only(right: 12),
                child: Column(children: [
                  Stack(children: [
                    Container(width: 66, height: 66, decoration: BoxDecoration(
                      gradient: AppTheme.mainGradient, shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2)),
                      child: _myPhoto.isNotEmpty
                        ? ClipOval(child: Image.network(_myPhoto, fit: BoxFit.cover))
                        : Center(child: Text(_myName.isNotEmpty ? _myName[0].toUpperCase() : '?',
                            style: const TextStyle(color: Colors.white,
                              fontWeight: FontWeight.w900, fontSize: 24)))),
                    Positioned(bottom: 0, right: 0,
                      child: Container(width: 22, height: 22,
                        decoration: BoxDecoration(color: AppTheme.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2)),
                        child: const Icon(Icons.add, color: Colors.white, size: 14))),
                  ]),
                  const SizedBox(height: 4),
                  const Text('Add Story', style: TextStyle(fontSize: 11,
                    fontWeight: FontWeight.w700, color: AppTheme.ink), overflow: TextOverflow.ellipsis),
                ]))),

            // Other stories
            ..._storyGroups.map((group) {
              final hasUnread = group['hasUnread'] as bool;
              final isMe = group['uid'] == _myUid;
              final name = isMe ? 'You' : (group['name'] as String);
              final photo = group['photo'] as String;
              final stories = group['stories'] as List<Map<String, dynamic>>;

              return GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => StoryViewScreen(
                    stories: stories, viewerUid: _myUid))),
                child: Container(width: 72, margin: const EdgeInsets.only(right: 12),
                  child: Column(children: [
                    Container(width: 66, height: 66, padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        gradient: hasUnread ? AppTheme.mainGradient : null,
                        color: hasUnread ? null : Colors.grey.shade300,
                        shape: BoxShape.circle),
                      child: Container(decoration: const BoxDecoration(
                        color: Colors.white, shape: BoxShape.circle),
                        padding: const EdgeInsets.all(2),
                        child: ClipOval(child: photo.isNotEmpty
                          ? Image.network(photo, fit: BoxFit.cover)
                          : Container(color: AppTheme.primary,
                              child: Center(child: Text(name[0].toUpperCase(),
                                style: const TextStyle(color: Colors.white,
                                  fontWeight: FontWeight.w900, fontSize: 22))))))),
                    const SizedBox(height: 4),
                    Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                        color: hasUnread ? AppTheme.ink : AppTheme.muted)),
                  ])));
            }),
          ])),

        const Divider(height: 1),

        // Story previews grid
        Expanded(child: _storyGroups.isEmpty
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Text('✨', style: TextStyle(fontSize: 60)),
              const SizedBox(height: 16),
              const Text('No stories yet', style: TextStyle(fontSize: 16,
                fontWeight: FontWeight.w700, color: AppTheme.ink)),
              const SizedBox(height: 8),
              const Text('Be the first to share a story!',
                style: TextStyle(color: AppTheme.soft)),
              const SizedBox(height: 20),
              AppTheme.gradientButton(label: '+ Add Story', onTap: _addStory),
            ]))
          : GridView.builder(
              padding: const EdgeInsets.all(2),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3, crossAxisSpacing: 2, mainAxisSpacing: 2),
              itemCount: totalStories,
              itemBuilder: (_, i) {
                // Flatten all stories
                final allStories = <Map<String, dynamic>>[];
                for (var group in _storyGroups) {
                  final storiesList = group['stories'] as List?;
                  if (storiesList != null) {
                    for (var story in storiesList) {
                      allStories.add(story as Map<String, dynamic>);
                    }
                  }
                }
                if (i >= allStories.length) return const SizedBox.shrink();
                final story = allStories[i];
                final type = story['type'] as String;
                final isMe = story['uploaderUid'] == _myUid;

                return GestureDetector(
                  onTap: () {
                    final group = _storyGroups.firstWhere(
                      (g) => g['uid'] == story['uploaderUid']);
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => StoryViewScreen(
                        stories: group['stories'] as List<Map<String, dynamic>>,
                        viewerUid: _myUid,
                        startIndex: (group['stories'] as List).indexOf(story))));
                  },
                  child: Stack(fit: StackFit.expand, children: [
                    type == 'text'
                      ? Container(color: Color(story['bgColor'] ?? AppTheme.primary.value),
                          child: Center(child: Padding(padding: const EdgeInsets.all(4),
                            child: Text(story['text'] ?? '', textAlign: TextAlign.center,
                              maxLines: 4, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white,
                                fontWeight: FontWeight.w700, fontSize: 11)))))
                      : story['url'] != null
                        ? Image.network(story['url'], fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(color: AppTheme.bg,
                              child: const Center(child: Text('📷'))))
                        : Container(color: AppTheme.bg, child: const Center(child: Text('📷'))),
                    // Views count
                    Positioned(bottom: 4, left: 4, child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
                      child: Text('👁 ${(story['views'] as Map?)?.length ?? 0}',
                        style: const TextStyle(color: Colors.white, fontSize: 9)))),
                    if (isMe) Positioned(top: 4, right: 4, child: GestureDetector(
                      onTap: () => _deleteStory(story['id']),
                      child: Container(width: 20, height: 20,
                        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                        child: const Icon(Icons.close, color: Colors.white, size: 12)))),
                  ]));
              })),
      ]),
    );
  }

  Future<void> _deleteStory(String id) async {
    await _db.ref('stories/$id').remove();
  }
}

// ═══════════════════════════════════════════════════════════
// STORY VIEWER — Full screen with timer
// ═══════════════════════════════════════════════════════════
class StoryViewScreen extends StatefulWidget {
  final List<Map<String, dynamic>> stories;
  final String viewerUid;
  final int startIndex;
  const StoryViewScreen({super.key, required this.stories,
    required this.viewerUid, this.startIndex = 0});
  @override
  State<StoryViewScreen> createState() => _StoryViewScreenState();
}

class _StoryViewScreenState extends State<StoryViewScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _progress;
  int _idx = 0;
  final _db = FirebaseDatabase.instance;

  @override
  void initState() {
    super.initState();
    _idx = widget.startIndex;
    _progress = AnimationController(vsync: this,
      duration: const Duration(seconds: 5));
    _progress.addStatusListener((s) {
      if (s == AnimationStatus.completed) _next();
    });
    _startStory();
  }

  void _startStory() {
    _progress.reset();
    _progress.forward();
    _markViewed();
  }

  void _markViewed() {
    final story = widget.stories[_idx];
    _db.ref('stories/${story['id']}/views/${widget.viewerUid}')
      .set(DateTime.now().millisecondsSinceEpoch);
  }

  void _next() {
    if (_idx < widget.stories.length - 1) {
      setState(() => _idx++);
      _startStory();
    } else {
      Navigator.pop(context);
    }
  }

  void _prev() {
    if (_idx > 0) {
      setState(() => _idx--);
      _startStory();
    }
  }

  Future<void> _react(String emoji) async {
    final story = widget.stories[_idx];
    await _db.ref('stories/${story['id']}/reactions/${widget.viewerUid}')
      .set({'emoji': emoji, 'time': ServerValue.timestamp});
  }

  @override
  void dispose() { _progress.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final story = widget.stories[_idx];
    final type = story['type'] as String;
    final uploaderName = story['uploaderName'] ?? 'Cousin';
    final uploaderPhoto = story['uploaderPhoto'] ?? '';
    final views = (story['views'] as Map?)?.length ?? 0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapDown: (d) {
          final hw = MediaQuery.of(context).size.width / 2;
          if (d.globalPosition.dx < hw) {
            _prev();
          } else {
            _next();
          }
        },
        child: Stack(
          children: [
            // Story content
            Positioned.fill(
              child: type == 'text'
                ? Container(
                    color: Color(story['bgColor'] ?? 0xFF7C3AED),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          story['text'] ?? '',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ),
                  )
                : story['url'] != null
                  ? Image.network(
                      story['url'],
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Center(
                        child: Text('📷', style: TextStyle(fontSize: 60)),
                      ),
                    )
                  : const Center(
                      child: Text('📷', style: TextStyle(fontSize: 60)),
                    ),
            ),
            // Top: progress bars + header
            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Progress bars
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      children: widget.stories.asMap().entries.map((e) {
                        return Expanded(
                          child: Container(
                            height: 3,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            child: AnimatedBuilder(
                              animation: _progress,
                              builder: (_, __) => LinearProgressIndicator(
                                value: e.key < _idx
                                    ? 1.0
                                    : e.key == _idx
                                        ? _progress.value
                                        : 0.0,
                                backgroundColor: Colors.white30,
                                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            gradient: AppTheme.mainGradient,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: uploaderPhoto.isNotEmpty
                            ? ClipOval(child: Image.network(uploaderPhoto, fit: BoxFit.cover))
                            : Center(
                                child: Text(
                                  uploaderName[0],
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              uploaderName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              '👁 $views views',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Bottom: reactions
            Positioned(
              bottom: 30,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: ['❤️', '😂', '😮', '😢', '👏'].map((e) {
                  return GestureDetector(
                    onTap: () => _react(e),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          e,
                          style: const TextStyle(fontSize: 22),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}