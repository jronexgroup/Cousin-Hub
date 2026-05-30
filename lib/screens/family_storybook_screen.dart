import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../app_theme.dart';
import '../services/auth_service.dart';

// ═══════════════════════════════════════════════════════════
// FAMILY STORY BOOK — Collaborative storytelling
// ═══════════════════════════════════════════════════════════
class FamilyStorybookScreen extends StatefulWidget {
  const FamilyStorybookScreen({super.key});
  @override
  State<FamilyStorybookScreen> createState() => _FamilyStorybookScreenState();
}

class _FamilyStorybookScreenState extends State<FamilyStorybookScreen> {
  final _db = FirebaseDatabase.instance;
  List<Map<String, dynamic>> _stories = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _loadStories(); }

  void _loadStories() {
    _db.ref('familyStories').orderByChild('updatedAt').onValue.listen((e) {
      if (!e.snapshot.exists || !mounted) { setState(() => _loading = false); return; }
      final map = e.snapshot.value as Map;
      final list = map.entries.map((en) {
        final s = Map<String, dynamic>.from(en.value as Map);
        s['id'] = en.key; return s;
      }).toList()..sort((a, b) => (b['updatedAt'] ?? 0).compareTo(a['updatedAt'] ?? 0));
      setState(() { _stories = list; _loading = false; });
    });
  }

  void _createStory() {
    final titleCtrl = TextEditingController();
    final firstLineCtrl = TextEditingController();
    final genres = ['🏰 Fantasy', '😂 Comedy', '💕 Romance', '🔍 Mystery', '🌍 Adventure'];
    String selectedGenre = genres[0];

    showModalBottomSheet(context: context, isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(builder: (ctx, setSt) => Container(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
        decoration: const BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('📖 Start a New Story', style: TextStyle(fontSize: 18,
            fontWeight: FontWeight.w800, color: AppTheme.ink)),
          const SizedBox(height: 16),
          TextField(controller: titleCtrl,
            decoration: InputDecoration(hintText: 'Story title...',
              filled: true, fillColor: AppTheme.bg,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.all(14))),
          const SizedBox(height: 10),
          // Genre selector
          SingleChildScrollView(scrollDirection: Axis.horizontal,
            child: Row(children: genres.map((g) => GestureDetector(
              onTap: () => setSt(() => selectedGenre = g),
              child: Container(margin: const EdgeInsets.only(right: 8), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: selectedGenre == g ? AppTheme.primary : AppTheme.bg,
                  borderRadius: BorderRadius.circular(100)),
                child: Text(g, style: TextStyle(fontSize: 13,
                  color: selectedGenre == g ? Colors.white : AppTheme.muted,
                  fontWeight: FontWeight.w700))))).toList())),
          const SizedBox(height: 10),
          TextField(controller: firstLineCtrl, maxLines: 3,
            decoration: InputDecoration(hintText: 'Write the first line of the story...',
              filled: true, fillColor: AppTheme.bg,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.all(14))),
          const SizedBox(height: 16),
          AppTheme.gradientButton(label: '📖 Start Story', onTap: () async {
            if (titleCtrl.text.isEmpty || firstLineCtrl.text.isEmpty) return;
            final uid = AuthService().currentUid ?? '';
            final p = await AuthService().getProfile(uid);
            final name = p?['nickname'] ?? p?['name'] ?? 'Cousin';
            final ref = _db.ref('familyStories').push();
            await ref.set({
              'title': titleCtrl.text.trim(),
              'genre': selectedGenre,
              'lines': [{
                'text': firstLineCtrl.text.trim(),
                'authorUid': uid,
                'authorName': name,
                'timestamp': DateTime.now().millisecondsSinceEpoch,
              }],
              'lastAuthorUid': uid,
              'lastAuthorName': name,
              'createdAt': ServerValue.timestamp,
              'updatedAt': ServerValue.timestamp,
              'lineCount': 1,
            });
            if (ctx.mounted) Navigator.pop(ctx);
          }),
        ]))));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(backgroundColor: Colors.white, elevation: 0,
        title: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Cousin Pro', style: TextStyle(fontSize: 12, color: AppTheme.soft)),
          Text('Family Story Book 📖', style: TextStyle(fontSize: 20,
            fontWeight: FontWeight.w800, color: AppTheme.ink)),
        ]),
        actions: [IconButton(icon: const Icon(Icons.add, color: AppTheme.primary),
          onPressed: _createStory)]),
      body: _loading
        ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
        : _stories.isEmpty
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Text('📖', style: TextStyle(fontSize: 64)),
              const SizedBox(height: 16),
              const Text('No stories yet!', style: TextStyle(fontSize: 18,
                fontWeight: FontWeight.w800, color: AppTheme.ink)),
              const SizedBox(height: 8),
              const Text('Start a story — cousins continue it!',
                style: TextStyle(color: AppTheme.soft)),
              const SizedBox(height: 24),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 32),
                child: AppTheme.gradientButton(label: '📖 Write First Story', onTap: _createStory)),
            ]))
          : ListView.builder(padding: const EdgeInsets.all(16), itemCount: _stories.length,
              itemBuilder: (_, i) {
                final s = _stories[i];
                final lines = (s['lines'] as List?)?.cast<Map>() ?? [];
                final preview = lines.isNotEmpty ? (lines.first['text'] ?? '') : '';
                final lastLine = lines.isNotEmpty ? (lines.last['text'] ?? '') : '';

                return GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => StoryDetailScreen(storyId: s['id'], story: s))),
                  child: Container(margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)]),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      // Header
                      Container(padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(gradient: AppTheme.mainGradient,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
                        child: Row(children: [
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(s['genre'] ?? '📖', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                            const SizedBox(height: 2),
                            Text(s['title'] ?? 'Untitled', style: const TextStyle(color: Colors.white,
                              fontSize: 16, fontWeight: FontWeight.w800)),
                          ])),
                          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(100)),
                            child: Text('${s['lineCount'] ?? lines.length} lines',
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700))),
                        ])),
                      // Preview
                      Padding(padding: const EdgeInsets.all(16), child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('"$preview..."', maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, color: AppTheme.ink,
                            fontStyle: FontStyle.italic, height: 1.5)),
                        const SizedBox(height: 10),
                        Row(children: [
                          const Icon(Icons.edit, size: 14, color: AppTheme.soft),
                          const SizedBox(width: 4),
                          Expanded(child: Text('Last: ${s['lastAuthorName'] ?? 'Cousin'}',
                            style: const TextStyle(fontSize: 12, color: AppTheme.soft))),
                          Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(gradient: AppTheme.mainGradient,
                              borderRadius: BorderRadius.circular(100)),
                            child: const Text('Continue ✍️', style: TextStyle(color: Colors.white,
                              fontSize: 11, fontWeight: FontWeight.w700))),
                        ]),
                      ])),
                    ])));
              }),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createStory, backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('New Story', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
    );
  }
}

// ─── Story Detail + Continue ──────────────────────────────────────────────────
class StoryDetailScreen extends StatefulWidget {
  final String storyId;
  final Map<String, dynamic> story;
  const StoryDetailScreen({super.key, required this.storyId, required this.story});
  @override
  State<StoryDetailScreen> createState() => _StoryDetailScreenState();
}

class _StoryDetailScreenState extends State<StoryDetailScreen> {
  final _db = FirebaseDatabase.instance;
  final _lineCtrl = TextEditingController();
  List<Map<String, dynamic>> _lines = [];
  bool _posting = false;
  String? _lastAuthorUid;

  @override
  void initState() {
    super.initState();
    _db.ref('familyStories/${widget.storyId}').onValue.listen((e) {
      if (!e.snapshot.exists || !mounted) return;
      final data = Map<String, dynamic>.from(e.snapshot.value as Map);
      final lines = (data['lines'] as List?)?.map((l) =>
        Map<String, dynamic>.from(l as Map)).toList() ?? [];
      setState(() {
        _lines = lines;
        _lastAuthorUid = lines.isNotEmpty ? lines.last['authorUid'] : null;
      });
    });
  }

  Future<void> _addLine() async {
    final text = _lineCtrl.text.trim();
    if (text.isEmpty || _posting) return;
    final myUid = AuthService().currentUid ?? '';
    if (_lastAuthorUid == myUid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wait for another cousin to continue first! 😄')));
      return;
    }
    setState(() => _posting = true);
    final p = await AuthService().getProfile(myUid);
    final name = p?['nickname'] ?? p?['name'] ?? 'Cousin';
    final newLine = {
      'text': text, 'authorUid': myUid, 'authorName': name,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    final updatedLines = [..._lines, newLine];
    await _db.ref('familyStories/${widget.storyId}').update({
      'lines': updatedLines,
      'lastAuthorUid': myUid,
      'lastAuthorName': name,
      'lineCount': updatedLines.length,
      'updatedAt': ServerValue.timestamp,
    });
    _lineCtrl.clear();
    setState(() => _posting = false);
  }

  @override
  void dispose() { _lineCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final myUid = AuthService().currentUid ?? '';
    final canAdd = _lastAuthorUid != myUid;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(backgroundColor: Colors.white, elevation: 0,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.story['genre'] ?? '📖', style: const TextStyle(fontSize: 12, color: AppTheme.soft)),
          Text(widget.story['title'] ?? 'Story', style: const TextStyle(fontSize: 16,
            fontWeight: FontWeight.w800, color: AppTheme.ink)),
        ])),
      body: Column(children: [
        Expanded(child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _lines.length,
          itemBuilder: (_, i) {
            final line = _lines[i];
            final isMe = line['authorUid'] == myUid;
            return Container(margin: const EdgeInsets.only(bottom: 14), child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(width: 8, margin: const EdgeInsets.only(top: 6, right: 10),
                  child: Column(children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(
                      gradient: AppTheme.mainGradient, shape: BoxShape.circle)),
                    if (i < _lines.length - 1) Container(width: 1, height: 40,
                      color: AppTheme.primary.withOpacity(0.2)),
                  ])),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text(isMe ? 'You' : (line['authorName'] ?? 'Cousin'),
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
                        color: isMe ? AppTheme.primary : AppTheme.muted)),
                    const Spacer(),
                    Text('Line ${i + 1}', style: const TextStyle(fontSize: 10, color: AppTheme.soft)),
                  ]),
                  const SizedBox(height: 4),
                  Container(padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isMe ? const Color(0xFFEDE9FE) : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4)]),
                    child: Text(line['text'] ?? '', style: const TextStyle(
                      fontSize: 14, color: AppTheme.ink, height: 1.5,
                      fontStyle: FontStyle.italic))),
                ])),
              ]));
          })),

        // Input area
        Container(padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          color: Colors.white,
          child: canAdd ? Column(children: [
            TextField(controller: _lineCtrl, maxLines: 3, maxLength: 200,
              decoration: InputDecoration(
                hintText: 'Continue the story... (your turn!)',
                filled: true, fillColor: AppTheme.bg, counterText: '',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.all(14))),
            const SizedBox(height: 10),
            AppTheme.gradientButton(
              label: _posting ? 'Adding...' : 'Add My Line ✍️',
              loading: _posting, onTap: _addLine),
          ]) : Container(padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: const Color(0xFFFFF8E1),
              borderRadius: BorderRadius.circular(14)),
            child: const Row(children: [
              Text('⏳', style: TextStyle(fontSize: 20)),
              SizedBox(width: 10),
              Expanded(child: Text('Wait for another cousin to continue first!',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.muted))),
            ]))),
      ]));
  }
}
