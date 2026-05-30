import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/foundation.dart' as foundation;
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../app_theme.dart';
import '../services/auth_service.dart';
import '../services/cloudinary_service.dart';
import '../services/cache_service.dart';
import 'call_screen.dart';
import '../models/message_model.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _db = FirebaseDatabase.instance;
  final _msgCtrl = TextEditingController();
  final _scroll = ScrollController();
  final _picker = ImagePicker();
  final _recorder = AudioRecorder();
  final _player = AudioPlayer();

  String _activeGroup = 'main';
  String _myUid = '';
  String _myName = 'Cousin';
  String _myPhoto = '';

  List<MessageModel> _messages = [];
  Map<String, Map<String, dynamic>> _userCache = {};

  bool _showEmoji = false;
  bool _isRecording = false;
  bool _uploading = false;
  bool _hasText = false;
  String _typingText = '';
  String? _currentlyPlayingId;
  String? _recordingPath;

  final List<Map<String, String>> _groups = [
    {'id': 'main', 'label': 'Main', 'icon': '💬'},
    {'id': 'gaming', 'label': 'Gaming', 'icon': '🎮'},
    {'id': 'travel', 'label': 'Travel', 'icon': '✈️'},
    {'id': 'study', 'label': 'Study', 'icon': '📚'},
    {'id': 'foodies', 'label': 'Foodies', 'icon': '🍕'},
  ];

  @override
  void initState() {
    super.initState();
    _init();
    _msgCtrl.addListener(() {
      setState(() => _hasText = _msgCtrl.text.trim().isNotEmpty);
    });
  }

  Future<void> _init() async {
    await CacheService.init();
    final uid = AuthService().currentUid ?? '';
    _myUid = uid;
    final profile = await AuthService().getProfile(uid);
    if (profile != null && mounted) {
      setState(() {
        _myName = profile['nickname'] ?? profile['name'] ?? 'Cousin';
        _myPhoto = profile['photoUrl'] ?? '';
      });
    }
    final cached = CacheService.loadMessages(_activeGroup);
    if (cached.isNotEmpty && mounted) {
      setState(() => _messages = cached);
      _scrollToBottom();
    }
    _listenMessages();
    _loadUserProfiles();
  }

  void _loadUserProfiles() {
    _db.ref('users').get().then((snap) {
      if (!snap.exists || !mounted) return;
      final map = snap.value as Map;
      setState(() {
        _userCache = Map.fromEntries(map.entries.map((e) =>
          MapEntry(e.key as String, Map<String, dynamic>.from(e.value as Map))));
      });
    });
  }

  void _listenMessages() {
    final lastTs = CacheService.getLastTimestamp(_activeGroup);
    _db.ref('chats/$_activeGroup')
      .orderByChild('timestamp')
      .startAt(lastTs > 0 ? lastTs + 1 : 0)
      .onValue.listen((e) async {
        if (!e.snapshot.exists || !mounted) return;
        final map = e.snapshot.value as Map;
        final newMsgs = map.entries.map((en) =>
          MessageModel.fromMap(en.key as String, en.value as Map)).toList();
        newMsgs.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        final cached = CacheService.loadMessages(_activeGroup);
        final allIds = cached.map((m) => m.id).toSet();
        final toAdd = newMsgs.where((m) => !allIds.contains(m.id)).toList();
        final all = [...cached, ...toAdd];
        all.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        await CacheService.appendMessages(_activeGroup, newMsgs);
        if (mounted) {
          setState(() => _messages = all);
          _scrollToBottom();
          _markSeen(newMsgs);
        }
      });

    _db.ref('typing/$_activeGroup').onValue.listen((e) {
      if (!e.snapshot.exists || !mounted) {
        setState(() => _typingText = ''); return;
      }
      final map = Map<String, dynamic>.from(e.snapshot.value as Map);
      final typers = map.entries
        .where((en) => en.key != _myUid && en.value == true)
        .map((en) => _userCache[en.key]?['nickname'] ?? _userCache[en.key]?['name'] ?? 'Someone')
        .toList();
      setState(() => _typingText = typers.isEmpty ? '' :
        typers.length == 1 ? '${typers[0]} typing...' : '${typers.join(', ')} typing...');
    });
  }

  void _markSeen(List<MessageModel> msgs) async {
    for (final msg in msgs) {
      if (msg.senderUid != _myUid && !msg.seenBy.containsKey(_myUid)) {
        await _db.ref('chats/$_activeGroup/${msg.id}/seenBy/$_myUid')
          .set(DateTime.now().millisecondsSinceEpoch.toString());
      }
    }
  }

  void _onTyping(String val) {
    _db.ref('typing/$_activeGroup/$_myUid').set(val.isNotEmpty);
  }

  void _switchGroup(String gid) {
    setState(() { _activeGroup = gid; _messages = []; _typingText = ''; });
    final cached = CacheService.loadMessages(gid);
    if (cached.isNotEmpty) setState(() => _messages = cached);
    _listenMessages();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 150), () {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  // ── Send text ──────────────────────────────────────────────────────────────
  Future<void> _sendText() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    _msgCtrl.clear();
    setState(() => _hasText = false);
    _db.ref('typing/$_activeGroup/$_myUid').set(false);
    await _db.ref('chats/$_activeGroup').push().set({
      'text': text, 'type': 'text',
      'senderUid': _myUid, 'senderName': _myName, 'senderPhoto': _myPhoto,
      'timestamp': ServerValue.timestamp, 'seenBy': {}, 'delivered': true,
    });
  }

  // ── Send image or video from gallery ──────────────────────────────────────
  Future<void> _pickMedia() async {
    final result = await showModalBottomSheet<String>(
      context: context, backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Share Media', style: TextStyle(fontSize: 16,
            fontWeight: FontWeight.w800, color: AppTheme.ink)),
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            _mediaOption('📷', 'Photo\nGallery', 'photo_gallery'),
            _mediaOption('📸', 'Camera', 'camera'),
            _mediaOption('🎥', 'Video\nGallery', 'video_gallery'),
            _mediaOption('📎', 'File', 'file'),
          ]),
          const SizedBox(height: 8),
        ])));
    if (result == null) return;
    if (result == 'photo_gallery') await _sendImage(ImageSource.gallery);
    else if (result == 'camera') await _sendImage(ImageSource.camera);
    else if (result == 'video_gallery') await _sendVideo();
    else if (result == 'file') await _sendFile();
  }

  Widget _mediaOption(String emoji, String label, String value) =>
    GestureDetector(onTap: () => Navigator.pop(context, value),
      child: Column(children: [
        Container(width: 56, height: 56,
          decoration: BoxDecoration(color: AppTheme.bg, borderRadius: BorderRadius.circular(16)),
          child: Center(child: Text(emoji, style: const TextStyle(fontSize: 26)))),
        const SizedBox(height: 6),
        Text(label, textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11, color: AppTheme.muted)),
      ]));

  Future<void> _sendImage(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, imageQuality: 60);
    if (picked == null) return;
    setState(() => _uploading = true);
    final url = await CloudinaryService.uploadImage(File(picked.path), folder: 'cousin_hub/chat');
    setState(() => _uploading = false);
    if (url == null) return;
    await _db.ref('chats/$_activeGroup').push().set({
      'text': '📷 Photo', 'type': 'image', 'mediaUrl': url,
      'senderUid': _myUid, 'senderName': _myName, 'senderPhoto': _myPhoto,
      'timestamp': ServerValue.timestamp, 'seenBy': {}, 'delivered': true,
    });
  }

  Future<void> _sendVideo() async {
    final picked = await _picker.pickVideo(source: ImageSource.gallery,
      maxDuration: const Duration(seconds: 60));
    if (picked == null) return;
    setState(() => _uploading = true);
    final url = await CloudinaryService.uploadVideo(File(picked.path), folder: 'cousin_hub/chat_videos');
    setState(() => _uploading = false);
    if (url == null) return;
    await _db.ref('chats/$_activeGroup').push().set({
      'text': '🎥 Video', 'type': 'video', 'mediaUrl': url,
      'senderUid': _myUid, 'senderName': _myName, 'senderPhoto': _myPhoto,
      'timestamp': ServerValue.timestamp, 'seenBy': {}, 'delivered': true,
    });
  }

  Future<void> _sendFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.any);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.path == null) return;
    setState(() => _uploading = true);
    final url = await CloudinaryService.uploadFile(File(file.path!), folder: 'cousin_hub/files');
    setState(() => _uploading = false);
    if (url == null) return;
    await _db.ref('chats/$_activeGroup').push().set({
      'text': '📎 ${file.name}', 'type': 'file', 'mediaUrl': url,
      'fileName': file.name, 'fileSize': file.size,
      'senderUid': _myUid, 'senderName': _myName, 'senderPhoto': _myPhoto,
      'timestamp': ServerValue.timestamp, 'seenBy': {}, 'delivered': true,
    });
  }

  // ── Voice message record & send ────────────────────────────────────────────
  Future<void> _startRecording() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) return;
    final dir = await getTemporaryDirectory();
    _recordingPath = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: _recordingPath!);
    setState(() => _isRecording = true);
    HapticFeedback.mediumImpact();
  }

  Future<void> _stopAndSendRecording() async {
    if (!_isRecording) return;
    final path = await _recorder.stop();
    setState(() => _isRecording = false);
    if (path == null) return;
    HapticFeedback.lightImpact();
    setState(() => _uploading = true);
    final url = await CloudinaryService.uploadFile(File(path), folder: 'cousin_hub/voice');
    setState(() => _uploading = false);
    if (url == null) return;
    await _db.ref('chats/$_activeGroup').push().set({
      'text': '🎙️ Voice message', 'type': 'voice', 'mediaUrl': url,
      'senderUid': _myUid, 'senderName': _myName, 'senderPhoto': _myPhoto,
      'timestamp': ServerValue.timestamp, 'seenBy': {}, 'delivered': true,
    });
  }

  Future<void> _cancelRecording() async {
    await _recorder.cancel();
    setState(() => _isRecording = false);
  }

  // ── Play voice ─────────────────────────────────────────────────────────────
  Future<void> _playVoice(String msgId, String url) async {
    if (_currentlyPlayingId == msgId) {
      await _player.stop();
      setState(() => _currentlyPlayingId = null);
    } else {
      setState(() => _currentlyPlayingId = msgId);
      await _player.play(UrlSource(url));
      _player.onPlayerComplete.listen((_) {
        if (mounted) setState(() => _currentlyPlayingId = null);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () { if (_showEmoji) setState(() => _showEmoji = false); },
      child: Scaffold(
        backgroundColor: const Color(0xFFEBE4DB), // WhatsApp bg color
        appBar: _buildAppBar(),
        body: Column(children: [
          // Group tabs
          Container(color: Colors.white,
            child: SizedBox(height: 44, child: ListView(scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              children: _groups.map((g) {
                final active = g['id'] == _activeGroup;
                return GestureDetector(onTap: () => _switchGroup(g['id']!),
                  child: Container(margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: active ? AppTheme.primary : const Color(0xFFF0EBE5),
                      borderRadius: BorderRadius.circular(100)),
                    child: Row(children: [
                      Text(g['icon']!, style: const TextStyle(fontSize: 13)),
                      const SizedBox(width: 5),
                      Text(g['label']!, style: TextStyle(fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: active ? Colors.white : AppTheme.muted)),
                    ])));
              }).toList()))),

          // Upload indicator
          if (_uploading) Container(color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(children: [
              const SizedBox(width: 14, height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF25D366))),
              const SizedBox(width: 10),
              const Text('Uploading...', style: TextStyle(fontSize: 12, color: AppTheme.muted)),
            ])),

          // Typing indicator
          if (_typingText.isNotEmpty) Container(
            color: const Color(0xFFEBE4DB),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Align(alignment: Alignment.centerLeft,
              child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  _TypingDots(),
                  const SizedBox(width: 8),
                  Text(_typingText, style: const TextStyle(fontSize: 12, color: AppTheme.muted,
                    fontStyle: FontStyle.italic)),
                ])))),

          // Messages
          Expanded(child: _messages.isEmpty
            ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(12)),
                  child: Column(children: [
                    Text(_groups.firstWhere((g) => g['id'] == _activeGroup)['icon']!,
                      style: const TextStyle(fontSize: 40)),
                    const SizedBox(height: 8),
                    Text('${_groups.firstWhere((g) => g['id'] == _activeGroup)['label']} chat',
                      style: const TextStyle(fontSize: 14, color: AppTheme.muted)),
                    const Text('Messages are end-to-end private',
                      style: TextStyle(fontSize: 11, color: AppTheme.soft)),
                  ])),
              ]))
            : ListView.builder(controller: _scroll,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                itemCount: _messages.length,
                itemBuilder: (_, i) {
                  final msg = _messages[i];
                  final showDate = i == 0 || !_isSameDay(_messages[i-1].timestamp, msg.timestamp);
                  return Column(children: [
                    if (showDate) _DateDivider(timestamp: msg.timestamp),
                    _MessageBubble(
                      msg: msg, isMe: msg.senderUid == _myUid,
                      myUid: _myUid, userCache: _userCache,
                      isPlaying: _currentlyPlayingId == msg.id,
                      onPlayVoice: (url) => _playVoice(msg.id, url),
                      onVote: (opt) => _votePoll(msg.id, opt),
                    ),
                  ]);
                })),

          // Emoji picker
          if (_showEmoji) SizedBox(height: 280,
            child: EmojiPicker(
              onEmojiSelected: (_, emoji) {
                _msgCtrl.text += emoji.emoji;
                _msgCtrl.selection = TextSelection.fromPosition(
                  TextPosition(offset: _msgCtrl.text.length));
              },
              config: Config(
                emojiViewConfig: EmojiViewConfig(
                  emojiSizeMax: 28 * (foundation.defaultTargetPlatform == TargetPlatform.iOS ? 1.2 : 1.0),
                ),
              ),
            )),

          // ── WhatsApp-style input bar ──────────────────────────────────────
          _buildInputBar(),
        ]),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF075E54),
      elevation: 0,
      automaticallyImplyLeading: false,
      title: Row(children: [
        Stack(children: [
          Container(width: 36, height: 36,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF25D366)),
            child: const Center(child: Text('👨‍👩‍👧‍👦', style: TextStyle(fontSize: 18)))),
        ]),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Cousin Hub', style: TextStyle(fontSize: 16,
            fontWeight: FontWeight.w700, color: Colors.white)),
          Text('${_messages.length} messages', style: const TextStyle(
            fontSize: 12, color: Colors.white70)),
        ]),
      ]),
      actions: [
        IconButton(icon: const Icon(Icons.videocam_outlined, color: Colors.white), onPressed: () {}),
        IconButton(icon: const Icon(Icons.call_outlined, color: Colors.white), onPressed: () {}),
        IconButton(icon: const Icon(Icons.more_vert, color: Colors.white), onPressed: () {}),

      ],
    );
  }

  Widget _buildInputBar() {
    return Container(
      color: const Color(0xFFEBE4DB),
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
      child: _isRecording ? _buildRecordingBar() : _buildNormalBar(),
    );
  }

  Widget _buildNormalBar() {
    return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
      // Main input box
      Expanded(child: Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)]),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          // Emoji
          Padding(padding: const EdgeInsets.only(left: 4, bottom: 4),
            child: IconButton(icon: Icon(_showEmoji ? Icons.keyboard_rounded : Icons.emoji_emotions_outlined,
              color: const Color(0xFF8D9E9E)), iconSize: 22,
              onPressed: () => setState(() => _showEmoji = !_showEmoji))),
          // Text field
          Expanded(child: TextField(controller: _msgCtrl, onChanged: _onTyping,
            maxLines: 5, minLines: 1,
            style: const TextStyle(fontSize: 15, color: Color(0xFF1A1A1A)),
            decoration: const InputDecoration(
              hintText: 'Message', hintStyle: TextStyle(color: Color(0xFFAAAAAA), fontSize: 15),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 10)))),
          // Attach / Gallery
          Padding(padding: const EdgeInsets.only(right: 4, bottom: 4),
            child: IconButton(icon: const Icon(Icons.attach_file_rounded, color: Color(0xFF8D9E9E)),
              iconSize: 22, onPressed: _pickMedia)),
          // Camera (always show)
          Padding(padding: const EdgeInsets.only(right: 4, bottom: 4),
            child: IconButton(icon: const Icon(Icons.camera_alt_outlined, color: Color(0xFF8D9E9E)),
              iconSize: 22, onPressed: () => _sendImage(ImageSource.camera))),
        ])),
      ),
      const SizedBox(width: 6),
      // Send / Voice button — WhatsApp style
      GestureDetector(
        onTap: _hasText ? _sendText : null,
        onLongPressStart: _hasText ? null : (_) => _startRecording(),
        onLongPressEnd: _hasText ? null : (_) => _stopAndSendRecording(),
        child: AnimatedContainer(duration: const Duration(milliseconds: 200),
          width: 48, height: 48,
          decoration: const BoxDecoration(color: Color(0xFF25D366), shape: BoxShape.circle),
          child: Icon(_hasText ? Icons.send_rounded : Icons.mic_rounded,
            color: Colors.white, size: 22)),
      ),
    ]);
  }

  Widget _buildRecordingBar() {
    return Row(children: [
      // Cancel
      GestureDetector(onTap: _cancelRecording,
        child: Container(padding: const EdgeInsets.all(10),
          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          child: const Icon(Icons.delete_outline, color: Colors.red, size: 22))),
      const SizedBox(width: 10),
      // Recording indicator
      Expanded(child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
        child: Row(children: [
          Container(width: 10, height: 10, decoration: const BoxDecoration(
            color: Colors.red, shape: BoxShape.circle)),
          const SizedBox(width: 10),
          const Text('Recording...', style: TextStyle(color: Colors.red,
            fontSize: 14, fontWeight: FontWeight.w600)),
          const Spacer(),
          const Icon(Icons.chevron_left, color: Color(0xFFAAAAAA)),
          const Text('Slide to cancel', style: TextStyle(color: Color(0xFFAAAAAA), fontSize: 12)),
        ]))),
      const SizedBox(width: 10),
      // Stop & send
      GestureDetector(onTap: _stopAndSendRecording,
        child: Container(width: 48, height: 48,
          decoration: const BoxDecoration(color: Color(0xFF25D366), shape: BoxShape.circle),
          child: const Icon(Icons.send_rounded, color: Colors.white, size: 22))),
    ]);
  }

  Future<void> _votePoll(String msgId, String option) async {
    await _db.ref('chats/$_activeGroup/$msgId/votes/$_myUid').set(option);
  }

  bool _isSameDay(int ts1, int ts2) {
    if (ts1 == 0 || ts2 == 0) return false;
    final d1 = DateTime.fromMillisecondsSinceEpoch(ts1);
    final d2 = DateTime.fromMillisecondsSinceEpoch(ts2);
    return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
  }

  @override
  void dispose() {
    _msgCtrl.dispose(); _scroll.dispose();
    _recorder.cancel(); _player.dispose();
    _db.ref('typing/$_activeGroup/$_myUid').remove();
    super.dispose();
  }
}

// ── Message Bubble ────────────────────────────────────────────────────────────
class _MessageBubble extends StatelessWidget {
  final MessageModel msg;
  final bool isMe, isPlaying;
  final Map<String, Map<String, dynamic>> userCache;
  final String myUid;
  final Function(String) onPlayVoice;
  final Function(String) onVote;

  const _MessageBubble({
    required this.msg, required this.isMe, required this.isPlaying,
    required this.userCache, required this.myUid,
    required this.onPlayVoice, required this.onVote,
  });

  @override
  Widget build(BuildContext context) {
    if (msg.type == 'poll') return _buildPoll(context);

    return Padding(padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            _Avatar(photo: msg.senderPhoto, name: msg.senderName, size: 28),
            const SizedBox(width: 4),
          ],
          Flexible(child: Column(
            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              // Bubble
              Container(
                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
                padding: msg.type == 'image' || msg.type == 'video'
                  ? EdgeInsets.zero : const EdgeInsets.fromLTRB(10, 6, 10, 6),
                decoration: BoxDecoration(
                  color: isMe ? const Color(0xFFDCF8C6) : Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(12),
                    topRight: const Radius.circular(12),
                    bottomLeft: Radius.circular(isMe ? 12 : 2),
                    bottomRight: Radius.circular(isMe ? 2 : 12)),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 3, offset: const Offset(0, 1))]),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (!isMe) Padding(padding: const EdgeInsets.fromLTRB(2, 2, 2, 2),
                    child: Text(msg.senderName, style: const TextStyle(fontSize: 12,
                      fontWeight: FontWeight.w700, color: Color(0xFF075E54)))),
                  _buildContent(context),
                  // Time + seen
                  Padding(padding: EdgeInsets.fromLTRB(
                    msg.type == 'image' || msg.type == 'video' ? 8 : 2, 2,
                    msg.type == 'image' || msg.type == 'video' ? 6 : 2, 2),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(_formatTime(msg.timestamp),
                        style: TextStyle(fontSize: 11,
                          color: msg.type == 'image' || msg.type == 'video'
                            ? Colors.white : const Color(0xFF8A9AA0))),
                      if (isMe) ...[
                        const SizedBox(width: 3),
                        _SeenIndicator(seenBy: msg.seenBy, delivered: msg.delivered, myUid: myUid),
                      ],
                    ])),
                ])),
            ])),
          if (isMe) const SizedBox(width: 4),
        ]));
  }

  Widget _buildContent(BuildContext context) {
    switch (msg.type) {
      case 'image':
        return GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(backgroundColor: Colors.black,
              leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context))),
            body: Center(child: InteractiveViewer(child: Image.network(msg.mediaUrl ?? '')))))),
          child: ClipRRect(borderRadius: BorderRadius.circular(12),
            child: Image.network(msg.mediaUrl ?? '', width: 220, height: 220, fit: BoxFit.cover,
              loadingBuilder: (_, child, prog) => prog == null ? child
                : Container(width: 220, height: 220, color: const Color(0xFFD9EDCC),
                  child: const Center(child: CircularProgressIndicator(
                    color: Color(0xFF25D366), strokeWidth: 2))),
              errorBuilder: (_, __, ___) => Container(width: 220, height: 120,
                color: const Color(0xFFD9EDCC),
                child: const Center(child: Text('📷', style: TextStyle(fontSize: 40)))))));

      case 'video':
        return ClipRRect(borderRadius: BorderRadius.circular(12),
          child: Container(width: 220, height: 150,
            color: Colors.black87,
            child: Stack(alignment: Alignment.center, children: [
              const Icon(Icons.videocam, color: Colors.white30, size: 60),
              Container(width: 48, height: 48,
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.85), shape: BoxShape.circle),
                child: const Icon(Icons.play_arrow_rounded, color: Color(0xFF25D366), size: 32)),
              Positioned(bottom: 6, right: 8,
                child: Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                  child: const Text('Video', style: TextStyle(color: Colors.white, fontSize: 10)))),
            ])));

      case 'file':
        return Container(
          padding: const EdgeInsets.all(2),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 38, height: 38,
              decoration: BoxDecoration(color: const Color(0xFF25D366).withOpacity(0.15),
                borderRadius: BorderRadius.circular(8)),
              child: const Center(child: Text('📎', style: TextStyle(fontSize: 20)))),
            const SizedBox(width: 8),
            Flexible(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(msg.fileName ?? 'File', maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A))),
              if (msg.fileSize != null) Text(
                msg.fileSize! > 1024 * 1024
                  ? '${(msg.fileSize! / (1024 * 1024)).toStringAsFixed(1)} MB'
                  : '${(msg.fileSize! / 1024).toStringAsFixed(0)} KB',
                style: const TextStyle(fontSize: 11, color: Color(0xFF8A9AA0))),
            ])),
          ]));

      case 'voice':
        return GestureDetector(
          onTap: () => onPlayVoice(msg.mediaUrl ?? ''),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 36, height: 36,
              decoration: BoxDecoration(
                color: isMe ? const Color(0xFF25D366) : const Color(0xFF075E54),
                shape: BoxShape.circle),
              child: Icon(isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white, size: 22)),
            const SizedBox(width: 8),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Waveform visual
              Row(children: List.generate(16, (i) {
                final h = [3.0,6.0,10.0,14.0,8.0,12.0,16.0,10.0,14.0,8.0,12.0,6.0,10.0,14.0,6.0,3.0][i];
                return Container(margin: const EdgeInsets.only(right: 2),
                  width: 2.5, height: h,
                  decoration: BoxDecoration(
                    color: isMe ? const Color(0xFF075E54) : const Color(0xFF25D366),
                    borderRadius: BorderRadius.circular(2)));
              })),
              const SizedBox(height: 2),
              const Text('Voice message', style: TextStyle(fontSize: 11, color: Color(0xFF8A9AA0))),
            ]),
          ]));

      default:
        return Text(msg.text, style: const TextStyle(fontSize: 15, color: Color(0xFF1A1A1A)));
    }
  }

  Widget _buildPoll(BuildContext context) {
    return Container(); // polls handled in chat
  }

  String _formatTime(int ts) {
    if (ts == 0) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(ts);
    return '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
  }
}

// ── Seen indicator ─────────────────────────────────────────────────────────────
class _SeenIndicator extends StatelessWidget {
  final Map<String, String> seenBy;
  final bool delivered;
  final String myUid;
  const _SeenIndicator({required this.seenBy, required this.delivered, required this.myUid});

  @override
  Widget build(BuildContext context) {
    final others = seenBy.keys.where((k) => k != myUid).toList();
    if (others.isNotEmpty) return const Icon(Icons.done_all, size: 14, color: Color(0xFF53BDEB));
    if (delivered) return const Icon(Icons.done_all, size: 14, color: Color(0xFF8A9AA0));
    return const Icon(Icons.done, size: 14, color: Color(0xFF8A9AA0));
  }
}

// ── Avatar ─────────────────────────────────────────────────────────────────────
class _Avatar extends StatelessWidget {
  final String photo, name;
  final double size;
  const _Avatar({required this.photo, required this.name, required this.size});

  @override
  Widget build(BuildContext context) => Container(width: size, height: size,
    decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF25D366)),
    child: photo.isNotEmpty
      ? ClipOval(child: Image.network(photo, fit: BoxFit.cover, width: size, height: size,
          errorBuilder: (_, __, ___) => _initial()))
      : _initial());

  Widget _initial() => Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: size * 0.4)));
}

// ── Date divider ───────────────────────────────────────────────────────────────
class _DateDivider extends StatelessWidget {
  final int timestamp;
  const _DateDivider({required this.timestamp});

  @override
  Widget build(BuildContext context) {
    if (timestamp == 0) return const SizedBox.shrink();
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    String label;
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) label = 'Today';
    else if (dt.year == now.year && dt.month == now.month && dt.day == now.day - 1) label = 'Yesterday';
    else label = '${dt.day}/${dt.month}/${dt.year}';
    return Padding(padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(color: const Color(0xFFD1F4CC), borderRadius: BorderRadius.circular(8)),
        child: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF4A4A4A))))));
  }
}

// ── Typing dots ────────────────────────────────────────────────────────────────
class _TypingDots extends StatefulWidget {
  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  void initState() { super.initState(); _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(); }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(animation: _ctrl, builder: (_, __) =>
    Row(children: List.generate(3, (i) {
      final val = ((_ctrl.value - i * 0.3) % 1.0).clamp(0.0, 1.0);
      final opacity = val < 0.5 ? val * 2 : (1 - val) * 2;
      return Container(margin: const EdgeInsets.only(right: 3), width: 6, height: 6,
        decoration: BoxDecoration(shape: BoxShape.circle,
          color: const Color(0xFF25D366).withOpacity(opacity.clamp(0.2, 1.0))));
    })));
}