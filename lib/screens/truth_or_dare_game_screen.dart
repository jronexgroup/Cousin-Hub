import 'dart:async';
import 'dart:io';

import 'package:emoji_picker_flutter/emoji_picker_flutter.dart' as emoji_picker;
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../services/cloudinary_service.dart';
import '../app_theme.dart';
import 'truth_or_dare_models.dart';
import 'truth_or_dare_result_screen.dart';

class TruthOrDareGameScreen extends StatefulWidget {
  final String roomId, myUid, myName, myPhoto;
  final bool isHost;
  const TruthOrDareGameScreen({
    super.key, required this.roomId, required this.myUid,
    required this.myName, required this.myPhoto, required this.isHost});
  @override
  State<TruthOrDareGameScreen> createState() => _TruthOrDareGameState();
}

class _TruthOrDareGameState extends State<TruthOrDareGameScreen>
    with SingleTickerProviderStateMixin {
  final _db = FirebaseDatabase.instance;
  final _picker = ImagePicker();
  StreamSubscription? _gameSub, _chatSub;

  List<PlayerData> _players = [];
  String? _currentSpinner, _selectedPlayer, _currentQuestion, _currentDare, _dareProofType;
  String _turnPhase = 'spin';
  bool _spinning = false, _navigated = false, _uploading = false;

  late AnimationController _spinCtrl;
  late Animation<double> _spinAnim;
  bool _animDone = false;

  List<Map<String, dynamic>> _messages = [];
  final _chatCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _showEmoji = false;

  @override
  void initState() {
    super.initState();
    _spinCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));
    _spinAnim = Tween<double>(begin: 0, end: 4 * 3.14159).animate(
      CurvedAnimation(parent: _spinCtrl, curve: Curves.easeOutCubic));
    _spinCtrl.addListener(() { if (mounted) setState(() {}); });
    _spinCtrl.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) setState(() => _animDone = true);
    });

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    _listen();
  }

  void _listen() {
    _gameSub = _db.ref('truthOrDareRooms/${widget.roomId}').onValue.listen((e) {
      if (!e.snapshot.exists || !mounted) return;
      final d = Map<String, dynamic>.from(e.snapshot.value as Map);
      final pm = d['players'] as Map? ?? {};
      final list = pm.entries.map((e) {
        final p = Map<String, dynamic>.from(e.value as Map);
        return PlayerData(uid: e.key,
          name: p['name'] as String? ?? 'Cousin',
          photo: p['photo'] as String? ?? '',
          online: p['online'] as bool? ?? true,
          isReady: p['isReady'] as bool? ?? false);
      }).toList();

      final st = d['status'] as String? ?? 'waiting';
      final spinner = d['currentSpinner'] as String?;
      final selected = d['selectedPlayer'] as String?;
      final phase = d['turnPhase'] as String? ?? 'spin';
      final question = d['currentQuestion'] as String?;
      final dare = d['currentDare'] as String?;
      final pt = d['dareProofType'] as String?;

      if (selected != null && selected != _selectedPlayer && phase == 'choose') {
        _startSpin();
      }

      if (st == 'finished' && !_navigated) {
        _navigated = true;
        _goToResult(st, d);
      }

      setState(() {
        _players = list; _currentSpinner = spinner;
        _selectedPlayer = selected; _turnPhase = phase;
        _currentQuestion = question;
        _currentDare = dare; _dareProofType = pt;
      });
    });

    _chatSub = _db.ref('chats/truthOrDare_${widget.roomId}')
        .orderByChild('timestamp').limitToLast(100).onValue.listen((e) {
      if (!e.snapshot.exists || !mounted) return;
      final msgs = <Map<String, dynamic>>[];
      final val = e.snapshot.value as Map? ?? {};
      val.forEach((k, v) {
        final m = Map<String, dynamic>.from(v as Map);
        m['id'] = k;
        msgs.add(m);
      });
      msgs.sort((a, b) => ((a['timestamp'] as num?)?.toInt() ?? 0)
          .compareTo((b['timestamp'] as num?)?.toInt() ?? 0));
      if (mounted) setState(() => _messages = msgs);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollCtrl.hasClients) _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      });
    });
  }

  void _startSpin() {
    _animDone = false;
    _spinCtrl.reset();
    _spinCtrl.forward();
    setState(() => _spinning = true);
  }

  bool get _isSpinner => _currentSpinner == widget.myUid;
  bool get _isSelected => _selectedPlayer == widget.myUid;

  void _spin() {
    _db.ref('truthOrDareRooms/${widget.roomId}/spinRequest').set({
      'by': widget.myUid, 'timestamp': ServerValue.timestamp,
    });
  }

  void _chooseTruth() {
    _db.ref('truthOrDareRooms/${widget.roomId}/turnPhase').set('truth_question');
  }

  void _chooseDare() {
    _db.ref('truthOrDareRooms/${widget.roomId}/turnPhase').set('dare_create');
  }

  void _submitQuestion(String q) {
    _db.ref('truthOrDareRooms/${widget.roomId}').update({
      'currentQuestion': q, 'turnPhase': 'truth_answer',
    });
  }

  void _submitAnswer(String a) {
    _db.ref('truthOrDareRooms/${widget.roomId}').update({
      'currentAnswer': a, 'turnPhase': 'result',
    });
    _postTruthResult(a);
  }

  void _postTruthResult(String answer) {
    final q = _currentQuestion ?? '';
    _postChatMessage('Truth result', '🟨 Truth\nQ: $q\nA: $answer', 'truth_result');
    _transferTurn();
  }

  void _createDare(String dare, String proofType) {
    _db.ref('truthOrDareRooms/${widget.roomId}').update({
      'currentDare': dare, 'dareProofType': proofType, 'turnPhase': 'dare_proof',
    });
  }

  Future<void> _uploadProof() async {
    final type = _dareProofType ?? 'photo';
    final src = await showModalBottomSheet<String>(context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          _srcBtn(Icons.camera_alt, 'Camera', 'camera'),
          _srcBtn(Icons.photo_library, 'Gallery', 'gallery'),
        ])));
    if (src == null || !mounted) return;

    setState(() => _uploading = true);
    try {
      final XFile? picked = src == 'camera'
          ? await _picker.pickImage(source: ImageSource.camera, imageQuality: 80)
          : type == 'photo'
              ? await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80)
              : await _picker.pickVideo(source: ImageSource.gallery);
      if (picked == null) { setState(() => _uploading = false); return; }

      final file = File(picked.path);
      String? url;
      if (type == 'photo') {
        url = await CloudinaryService.uploadImage(file, folder: 'truth_or_dare');
      } else {
        url = await CloudinaryService.uploadVideo(file, folder: 'truth_or_dare');
      }
      if (url == null) { setState(() => _uploading = false); return; }

      await _db.ref('truthOrDareRooms/${widget.roomId}').update({
        'proofUrl': url, 'turnPhase': 'result',
      });
      _postDareResult(url);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Widget _srcBtn(IconData icon, String label, String value) {
    return GestureDetector(
      onTap: () => Navigator.pop(context, value),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Color(0xFF7C3AED), shape: BoxShape.circle),
          child: Icon(icon, color: Colors.white, size: 28)),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
      ]));
  }

  void _postDareResult(String url) {
    final dare = _currentDare ?? '';
    final icon = _dareProofType == 'video' ? '📹' : '📸';
    _postChatMessage('Dare result', '$icon Dare Completed\n$dare', 'dare_result', mediaUrl: url);
    _transferTurn();
  }

  void _transferTurn() {
    if (_selectedPlayer == null) return;
    Future.delayed(const Duration(seconds: 2), () {
      _db.ref('truthOrDareRooms/${widget.roomId}').update({
        'currentSpinner': _selectedPlayer, 'turnPhase': 'spin',
        'selectedPlayer': null, 'currentQuestion': null, 'currentAnswer': null,
        'currentDare': null, 'dareProofType': null, 'proofUrl': null,
      });
      final target = _players.firstWhere(
        (p) => p.uid == _selectedPlayer, orElse: () => PlayerData(uid: '', name: '...', photo: ''));
      _postChatMessage('system', '${target.name} now controls the bottle. 🍾', 'system');
    });
  }

  void _postChatMessage(String sender, String text, String type, {String? mediaUrl}) {
    final ref = _db.ref('chats/truthOrDare_${widget.roomId}').push();
    ref.set({
      'senderUid': widget.myUid, 'senderName': sender,
      'text': text, 'type': type, 'mediaUrl': mediaUrl ?? '',
      'timestamp': ServerValue.timestamp,
    });
  }

  Future<void> _leaveGame() async {
    final isLast = _players.where((p) => p.online && p.uid != widget.myUid).length <= 1;
    if (isLast && _players.where((p) => p.online).length <= 2) {
      final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('End Match?'),
        content: const Text('Leaving now will end the match. All data will be saved.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Stay')),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
            child: const Text('End Match', style: TextStyle(color: Colors.red))),
        ]));
      if (confirmed != true) return;
      await _db.ref('truthOrDareRooms/${widget.roomId}/exitRequest').update({
        'confirmed': true, 'timestamp': ServerValue.timestamp,
      });
    } else {
      final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('Leave Match?'),
        content: const Text('You cannot rejoin.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Stay')),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Exit', style: TextStyle(color: Colors.red))),
        ]));
      if (confirmed != true) return;
    }
    await _db.ref('truthOrDareRooms/${widget.roomId}/players/${widget.myUid}/online').set(false);
    if (mounted) Navigator.pop(context);
  }

  void _goToResult(String st, Map<String, dynamic> d) {
    final ul = int.parse('${d['endedAt'] ?? 0}') - int.parse('${d['createdAt'] ?? 0}');
    final duration = Duration(milliseconds: ul > 0 ? ul : 0);
    Navigator.pushReplacement(context, MaterialPageRoute(
      builder: (_) => TruthOrDareResultScreen(
        players: _players, myUid: widget.myUid, myName: widget.myName,
        myPhoto: widget.myPhoto, duration: duration, messages: _messages)));
  }

  void _sendChat() {
    final t = _chatCtrl.text.trim();
    if (t.isEmpty) return;
    _postChatMessage(widget.myName, t, 'text');
    _chatCtrl.clear();
    setState(() => _showEmoji = false);
  }

  @override
  void dispose() {
    _gameSub?.cancel(); _chatSub?.cancel();
    _spinCtrl.dispose(); _chatCtrl.dispose(); _scrollCtrl.dispose();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final alive = _players.where((p) => p.online).toList();
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A1A), elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: _leaveGame),
        title: const Text('🎭 Truth or Dare',
          style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 15)),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20)),
            child: Text('${alive.length} online',
              style: const TextStyle(color: Colors.white70, fontSize: 11))),
        ]),
      body: Row(children: [
        Expanded(flex: 6, child: _buildGameArea()),
        Container(width: 1, color: Colors.white12),
        Expanded(flex: 4, child: _buildChat()),
      ]));
  }

  Widget _buildGameArea() {
    final alive = _players.where((p) => p.online).toList();
    final mid = (alive.length / 2).ceil();
    final top = alive.take(mid).toList();
    final bot = alive.skip(mid).toList();

    return Stack(children: [
      Column(children: [
        Expanded(child: _playerRow(top)),
        _buildBottle(),
        Expanded(child: _playerRow(bot)),
      ]),
      if (_uploading)
        Container(color: Colors.black54,
          child: const Center(child: CircularProgressIndicator())),
      if (isSelectedPhase) _buildPhaseOverlay(),
    ]);
  }

  Widget _playerRow(List<PlayerData> list) {
    return LayoutBuilder(builder: (_, c) {
      final w = (c.maxWidth - 16) / list.length.clamp(1, 5);
      return Center(
        child: SizedBox(
          height: c.maxHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (_, i) => SizedBox(
              width: w.clamp(60, 90),
              child: _playerCard(list[i])))));
    });
  }

  Widget _playerCard(PlayerData p) {
    final isSpinner = p.uid == _currentSpinner;
    final isSel = p.uid == _selectedPlayer;
    final me = p.uid == widget.myUid;
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isSpinner ? const Color(0xFF7C3AED) : Colors.grey.shade700,
          border: Border.all(
            color: isSel
                ? (_animDone ? Colors.amber : Colors.white24)
                : isSpinner ? Colors.amber : Colors.transparent,
            width: (isSel && _animDone) || isSpinner ? 2.5 : 1),
          boxShadow: isSel && _animDone
              ? [BoxShadow(color: Colors.amber.withOpacity(0.5), blurRadius: 12)]
              : isSpinner
                  ? [BoxShadow(color: const Color(0xFF7C3AED).withOpacity(0.4), blurRadius: 10)]
                  : null,
          image: p.photo.isNotEmpty
              ? DecorationImage(image: NetworkImage(p.photo), fit: BoxFit.cover)
              : null),
        child: p.photo.isEmpty
            ? Center(child: Text(p.name[0].toUpperCase(),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)))
            : null),
      const SizedBox(height: 4),
      if (isSpinner) const Text('🎯', style: TextStyle(fontSize: 14)),
      if (isSel && _animDone) const Text('🎯', style: TextStyle(fontSize: 14)),
      Text(p.name, textAlign: TextAlign.center,
        maxLines: 1, overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: me ? 12 : 11,
          fontWeight: FontWeight.w700,
          color: p.online ? Colors.white : Colors.white38)),
    ]);
  }

  Widget _buildBottle() {
    return GestureDetector(
      onTap: _isSpinner && _turnPhase == 'spin' ? _spin : null,
      child: Container(
        height: 80,
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (_spinning || _animDone)
            RotationTransition(
              turns: _spinAnim.drive(Tween<double>(begin: 0, end: 1)),
              child: const Text('🍾', style: TextStyle(fontSize: 36)))
          else
            const Text('🍾', style: TextStyle(fontSize: 36)),
          if (_isSpinner && _turnPhase == 'spin')
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                gradient: AppTheme.mainGradient,
                borderRadius: BorderRadius.circular(20)),
              child: const Text('SPIN BOTTLE', style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12))),
        ]))));
  }

  bool get isSelectedPhase => _turnPhase == 'choose' && _isSelected && _animDone
      || _turnPhase == 'truth_question' && _isSpinner && _animDone
      || _turnPhase == 'truth_answer' && _isSelected
      || _turnPhase == 'dare_create' && _isSpinner
      || _turnPhase == 'dare_proof' && _isSelected;

  Widget _buildPhaseOverlay() {
    if (_turnPhase == 'choose' && _isSelected) return _chooseOverlay();
    if (_turnPhase == 'truth_question' && _isSpinner) return _questionOverlay();
    if (_turnPhase == 'truth_answer' && _isSelected) return _answerOverlay();
    if (_turnPhase == 'dare_create' && _isSpinner) return _dareCreateOverlay();
    if (_turnPhase == 'dare_proof' && _isSelected) return _dareProofOverlay();
    return const SizedBox();
  }

  Widget _chooseOverlay() {
    return Positioned.fill(child: Container(
      color: Colors.black87,
      child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Text('Choose', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
        const SizedBox(height: 24),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _choiceBtn('TRUTH', const Color(0xFF2D1B69), Icons.record_voice_over, _chooseTruth),
          const SizedBox(width: 20),
          _choiceBtn('DARE', const Color(0xFF1B3A2D), Icons.flash_on, _chooseDare),
        ]),
      ]))));
  }

  Widget _choiceBtn(String label, Color bg, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 120, height: 120,
        decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white24)),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: Colors.white, size: 36),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
        ])));
  }

  Widget _questionOverlay() {
    final ctrl = TextEditingController();
    return _inputOverlay('Ask a question', 'Type your question...', ctrl, (v) {
      _submitQuestion(v); ctrl.dispose();
    });
  }

  Widget _answerOverlay() {
    final ctrl = TextEditingController();
    final question = _currentQuestion ?? '';
    return _inputOverlay('Answer the question', question.isNotEmpty ? 'Question: $question\n\nYour answer...' : 'Type your answer...', ctrl, (v) {
      _submitAnswer(v); ctrl.dispose();
    }, multiline: true);
  }

  Widget _dareCreateOverlay() {
    final ctrl = TextEditingController();
    String proofType = 'photo';
    return StatefulBuilder(builder: (ctx, setInner) => Container(
      color: Colors.black87,
      child: Center(child: Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(20)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Create a Dare', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 12),
          SizedBox(width: 280, child: TextField(
            controller: ctrl, maxLines: 3,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Describe the dare...',
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true, fillColor: Colors.white10,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)))),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _proofTypeBtn('📸 Photo', proofType == 'photo', () => setInner(() => proofType = 'photo')),
            const SizedBox(width: 12),
            _proofTypeBtn('📹 Video', proofType == 'video', () => setInner(() => proofType = 'video')),
          ]),
          const SizedBox(height: 16),
          AppTheme.gradientButton(
            label: 'Submit Dare', height: 44,
            onTap: () { _createDare(ctrl.text, proofType); ctrl.dispose(); Navigator.pop(ctx); }),
        ])))));
  }

  Widget _proofTypeBtn(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF7C3AED) : Colors.white10,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: active ? const Color(0xFF7C3AED) : Colors.white24)),
        child: Text(label, style: TextStyle(
          color: active ? Colors.white : Colors.white54,
          fontWeight: FontWeight.w700, fontSize: 14))));
  }

  Widget _dareProofOverlay() {
    final dare = _currentDare ?? '';
    return Container(
      color: Colors.black87,
      child: Center(child: Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(20)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Dare: $dare', textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 15)),
          const SizedBox(height: 16),
          if (_uploading)
            const CircularProgressIndicator()
          else
            AppTheme.gradientButton(
              label: 'Upload Proof 📸', height: 48,
              onTap: _uploadProof),
        ]))));
  }

  Widget _inputOverlay(String title, String hint, TextEditingController ctrl,
      void Function(String) onSubmit, {bool multiline = false}) {
    return Container(
      color: Colors.black87,
      child: Center(child: Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(20)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 12),
          SizedBox(width: 280, child: TextField(
            controller: ctrl, maxLines: multiline ? 4 : 1,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: hint, hintStyle: const TextStyle(color: Colors.white38),
              filled: true, fillColor: Colors.white10,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)))),
          const SizedBox(height: 16),
          AppTheme.gradientButton(
            label: 'Submit', height: 44,
            onTap: () { final t = ctrl.text.trim(); if (t.isNotEmpty) onSubmit(t); }),
        ]))));
  }

  Widget _buildChat() {
    return Column(children: [
      Expanded(child: ListView.builder(
        controller: _scrollCtrl,
        padding: const EdgeInsets.all(8),
        itemCount: _messages.length,
        itemBuilder: (_, i) => _chatBubble(_messages[i]))),
      if (_showEmoji)
        SizedBox(
          height: 180,
          child: emoji_picker.EmojiPicker(
            onEmojiSelected: (_, e) {
              _chatCtrl.text += e.emoji;
              setState(() {});
            },
            config: const emoji_picker.Config(
              height: 180,
              emojiViewConfig: emoji_picker.EmojiViewConfig(
                columns: 7, verticalSpacing: 0, horizontalSpacing: 0)),
          )),
      Container(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
        decoration: const BoxDecoration(
          color: Color(0xFF111122),
          border: Border(top: BorderSide(color: Colors.white12))),
        child: Row(children: [
          IconButton(
            icon: Icon(_showEmoji ? Icons.keyboard : Icons.emoji_emotions,
              color: Colors.white54, size: 20),
            onPressed: () => setState(() => _showEmoji = !_showEmoji)),
          Expanded(child: TextField(
            controller: _chatCtrl,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: const InputDecoration(
              hintText: 'Chat...', hintStyle: TextStyle(color: Colors.white38),
              border: InputBorder.none, contentPadding: EdgeInsets.symmetric(vertical: 8)),
            onSubmitted: (_) => _sendChat())),
          IconButton(
            icon: const Icon(Icons.send, color: Color(0xFF7C3AED), size: 20),
            onPressed: _sendChat),
        ])),
    ]);
  }

  Widget _chatBubble(Map<String, dynamic> m) {
    final type = m['type'] as String? ?? 'text';
    final text = m['text'] as String? ?? '';
    final sender = m['senderName'] as String? ?? '';
    final media = m['mediaUrl'] as String? ?? '';
    final isMe = m['senderUid'] == widget.myUid;

    if (type == 'system') {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10)),
        child: Text(text, textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white54, fontSize: 11, fontStyle: FontStyle.italic)));
    }

    if (type == 'truth_result') {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF2D1B69).withOpacity(0.4),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF7C3AED).withOpacity(0.4))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('🟨 TRUTH', style: TextStyle(color: Color(0xFF7C3AED), fontWeight: FontWeight.w900, fontSize: 11)),
          const SizedBox(height: 2),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 12)),
        ]));
    }

    if (type == 'dare_result') {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF1B3A2D).withOpacity(0.4),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF4CAF50).withOpacity(0.4))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('📸 DARE', style: TextStyle(color: Color(0xFF4CAF50), fontWeight: FontWeight.w900, fontSize: 11)),
          const SizedBox(height: 2),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 12)),
          if (media.isNotEmpty) ...[
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _dareProofType == 'video'
                  ? Container(
                      height: 60, color: Colors.black,
                      child: Center(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Icon(Icons.play_circle, color: Colors.white, size: 24),
                        const SizedBox(width: 6),
                        Text('View Video', style: TextStyle(color: Colors.white70, fontSize: 11)),
                      ])))
                  : Image.network(media, height: 60, fit: BoxFit.cover)),
          ],
        ]));
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMe) ...[
            Container(width: 22, height: 22,
              decoration: BoxDecoration(
                color: Colors.grey.shade700, shape: BoxShape.circle,
                image: _players.any((p) => p.uid == m['senderUid'] && p.photo.isNotEmpty)
                    ? DecorationImage(image: NetworkImage(
                        _players.firstWhere((p) => p.uid == m['senderUid']).photo), fit: BoxFit.cover)
                    : null),
              child: isMe ? null : Center(child: Text(sender.isNotEmpty ? sender[0].toUpperCase() : '?',
                  style: const TextStyle(color: Colors.white, fontSize: 10)))),
            const SizedBox(width: 4),
          ],
          Flexible(child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isMe ? const Color(0xFF7C3AED).withOpacity(0.3) : Colors.white10,
              borderRadius: BorderRadius.circular(10)),
            child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 12)))),
          if (isMe) const SizedBox(width: 4),
        ]));
  }
}
