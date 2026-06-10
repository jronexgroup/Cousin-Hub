import 'package:flutter/material.dart';
import '../app_theme.dart';
import 'home_screen.dart';
import 'truth_or_dare_models.dart';

class TruthOrDareResultScreen extends StatelessWidget {
  final List<PlayerData> players;
  final String myUid, myName, myPhoto;
  final Duration duration;
  final List<Map<String, dynamic>> messages;
  const TruthOrDareResultScreen({
    super.key, required this.players, required this.myUid,
    required this.myName, required this.myPhoto,
    required this.duration, required this.messages});

  @override
  Widget build(BuildContext context) {
    final truths = messages.where((m) => m['type'] == 'truth_result').length;
    final dares = messages.where((m) => m['type'] == 'dare_result').length;
    final photos = messages.where((m) =>
        m['type'] == 'dare_result' && m['text']?.contains('📸') == true).length;
    final videos = messages.where((m) =>
        m['type'] == 'dare_result' && m['text']?.contains('📹') == true).length;
    final chats = messages.where((m) => m['type'] == 'text').length;
    final online = players.where((p) => p.online).length;
    final fmt = duration.toString().split('.').first.padLeft(8, '0');

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A1A), elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text('🎭 Game Over',
          style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white))),

      body: Center(child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2D1B69), Color(0xFF7C3AED)],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(
                color: const Color(0xFF7C3AED).withOpacity(0.4),
                blurRadius: 20, offset: const Offset(0, 8))]),
            child: Column(children: [
              const Text('🎭', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 8),
              const Text('Session Completed',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white)),
              const SizedBox(height: 4),
              Text('${players.length} Players • $fmt',
                style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14)),
            ])),
          const SizedBox(height: 24),
          _statCard('Players Joined', '${players.length}', Icons.people),
          _statCard('Online at End', '$online', Icons.person_pin),
          _statCard('Duration', fmt, Icons.timer),
          _statCard('Truth Questions', '$truths', Icons.record_voice_over),
          _statCard('Truth Answers', '$truths', Icons.check_circle),
          _statCard('Dares Completed', '$dares', Icons.flash_on),
          _statCard('Photos Uploaded', '$photos', Icons.photo_camera),
          _statCard('Videos Uploaded', '$videos', Icons.videocam),
          _statCard('Chat Messages', '$chats', Icons.chat),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.withOpacity(0.3))),
            child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.check_circle, color: Colors.green, size: 18),
              SizedBox(width: 8),
              Text('Session Saved Successfully',
                style: TextStyle(color: Colors.green, fontWeight: FontWeight.w700, fontSize: 14)),
            ])),
          const SizedBox(height: 24),
          AppTheme.gradientButton(
            label: '🏠 Go Home',
            onTap: () => Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const HomeScreen()), (_) => false),
            height: 48),
          const SizedBox(height: 16),
        ]),
      )));
  }

  Widget _statCard(String label, String value, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10)),
      child: Row(children: [
        Icon(icon, color: const Color(0xFF7C3AED), size: 20),
        const SizedBox(width: 12),
        Expanded(child: Text(label,
          style: const TextStyle(color: Colors.white70, fontSize: 14))),
        Text(value,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
      ]));
  }
}
