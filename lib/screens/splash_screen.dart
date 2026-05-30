import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _logoCtrl, _fadeCtrl, _progressCtrl;
  late Animation<double> _logoScale, _logoFade, _textFade, _progress;

  @override
  void initState() {
    super.initState();
    _logoCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _progressCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200));
    _logoScale = Tween<double>(begin: 0.5, end: 1.0).animate(CurvedAnimation(parent: _logoCtrl, curve: Curves.elasticOut));
    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(_logoCtrl);
    _textFade = Tween<double>(begin: 0.0, end: 1.0).animate(_fadeCtrl);
    _progress = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _progressCtrl, curve: Curves.easeInOut));
    _logoCtrl.forward();
    Future.delayed(const Duration(milliseconds: 400), () => _fadeCtrl.forward());
    Future.delayed(const Duration(milliseconds: 600), () => _progressCtrl.forward());
    Future.delayed(const Duration(milliseconds: 3000), () {
      if (!mounted) return;
      final user = FirebaseAuth.instance.currentUser;
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => user != null ? const HomeScreen() : const LoginScreen()));
    });
  }

  @override
  void dispose() { _logoCtrl.dispose(); _fadeCtrl.dispose(); _progressCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFFE8D5F5), Color(0xFFD4E8F5), Color(0xFFE5D5F0)])),
        child: SafeArea(child: Column(children: [
          const Spacer(flex: 2),
          AnimatedBuilder(animation: _logoCtrl,
            builder: (_, child) => FadeTransition(opacity: _logoFade,
              child: ScaleTransition(scale: _logoScale, child: child)),
            child: Stack(alignment: Alignment.center, children: [
              Container(width: 110, height: 110,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(28),
                  gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)]),
                  boxShadow: [BoxShadow(color: const Color(0xFF8B5CF6).withOpacity(0.4), blurRadius: 24, offset: const Offset(0, 8))]),
                child: const Center(child: Text('👨\u200d👩\u200d👧\u200d👦', style: TextStyle(fontSize: 48)))),
              Positioned(top: -8, right: -28,
                child: Container(width: 40, height: 40,
                  decoration: const BoxDecoration(color: Color(0xFF38BDF8), shape: BoxShape.circle),
                  child: const Center(child: Text('📖', style: TextStyle(fontSize: 18))))),
              Positioned(bottom: -8, left: -24,
                child: Container(width: 36, height: 36,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                  child: const Center(child: Text('💜', style: TextStyle(fontSize: 18))))),
            ])),
          const SizedBox(height: 48),
          FadeTransition(opacity: _textFade, child: const Column(children: [
            Text('Cousin Pro', style: TextStyle(fontSize: 40, fontWeight: FontWeight.w800,
              color: Color(0xFF3B1F0A), letterSpacing: -1)),
            SizedBox(height: 8),
            Text('Private Digital Space for Cousins', style: TextStyle(fontSize: 15,
              color: Color(0xFF8B6F5E), fontWeight: FontWeight.w500)),
          ])),
          const Spacer(flex: 2),
          FadeTransition(opacity: _textFade, child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 80),
            child: AnimatedBuilder(animation: _progress,
              builder: (_, __) => ClipRRect(borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(value: _progress.value, minHeight: 4,
                  backgroundColor: Colors.white.withOpacity(0.3),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6))))))),
          const SizedBox(height: 40),
          FadeTransition(opacity: _textFade, child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _av('👦', const Color(0xFF8B5CF6)),
              _av('👧', const Color(0xFF6366F1), off: -10),
              _av('🧑', const Color(0xFF8B5CF6), off: -20),
              Transform.translate(offset: const Offset(-30, 0),
                child: Container(width: 44, height: 44,
                  decoration: BoxDecoration(color: const Color(0xFFE8D5F5), shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2)),
                  child: const Center(child: Text('+12', style: TextStyle(fontSize: 12,
                    fontWeight: FontWeight.w700, color: Color(0xFF8B5CF6)))))),
            ]),
            const SizedBox(height: 12),
            const Text('RECONNECTING THE FAMILY TREE', style: TextStyle(fontSize: 11,
              letterSpacing: 3, color: Color(0xFF8B6F9E), fontWeight: FontWeight.w600)),
          ])),
          const SizedBox(height: 48),
        ])),
      ),
    );
  }

  Widget _av(String e, Color bg, {double off = 0}) => Transform.translate(offset: Offset(off, 0),
    child: Container(width: 44, height: 44,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
      child: Center(child: Text(e, style: const TextStyle(fontSize: 22)))));
}
