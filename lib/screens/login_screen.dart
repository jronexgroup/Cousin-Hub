import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../app_theme.dart';
import 'home_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  late TabController _tab;
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _inviteCtrl = TextEditingController();
  bool _loading = false;
  String _error = '';

  @override
  void initState() { super.initState(); _tab = TabController(length: 2, vsync: this); }
  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  void _showErr(String m) {
    setState(() => _error = m);
    Future.delayed(const Duration(seconds: 4), () { if (mounted) setState(() => _error = ''); });
  }

  Future<void> _login() async {
    if (_emailCtrl.text.isEmpty || _passCtrl.text.isEmpty) { _showErr('Please fill all fields'); return; }
    setState(() { _loading = true; _error = ''; });
    final r = await AuthService().login(email: _emailCtrl.text.trim(), password: _passCtrl.text.trim());
    setState(() => _loading = false);
    if (r['success']) {
      if (mounted) Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
    } else { _showErr(r['error']); }
  }

  Future<void> _verifyCode() async {
    if (_inviteCtrl.text.isEmpty) { _showErr('Enter invite code'); return; }
    setState(() { _loading = true; _error = ''; });
    final valid = await AuthService().validateInviteCode(_inviteCtrl.text.trim());
    setState(() => _loading = false);
    if (valid) {
      if (mounted) Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => RegisterScreen(inviteCode: _inviteCtrl.text.trim().toUpperCase())));
    } else { _showErr('Invalid invite code! Ask your cousin for the correct code.'); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(child: SingleChildScrollView(child: Column(children: [
        Container(margin: const EdgeInsets.all(24), height: 190,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), color: const Color(0xFFE8D5C4)),
          child: const Center(child: Text('👨\u200d👩\u200d👧\u200d👦', style: TextStyle(fontSize: 80)))),
        const Text('Cousin Pro', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: AppTheme.ink)),
        const SizedBox(height: 6),
        const Text('Your private space for family memories.', style: TextStyle(fontSize: 13, color: AppTheme.muted)),
        const SizedBox(height: 20),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            decoration: BoxDecoration(color: const Color(0xFFF0E6D8), borderRadius: BorderRadius.circular(100)),
            child: TabBar(controller: _tab, labelColor: Colors.white, unselectedLabelColor: AppTheme.muted,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              indicator: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(100)),
              indicatorSize: TabBarIndicatorSize.tab, dividerColor: Colors.transparent,
              tabs: const [Tab(text: 'Login'), Tab(text: 'Join with Code')]))),
        const SizedBox(height: 16),
        if (_error.isNotEmpty) Padding(padding: const EdgeInsets.symmetric(horizontal: 24),
          child: AppTheme.errorBox(_error)),
        if (_error.isNotEmpty) const SizedBox(height: 8),
        SizedBox(height: 290, child: TabBarView(controller: _tab, children: [
          // LOGIN TAB
          Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: Column(children: [
            TextField(controller: _emailCtrl, keyboardType: TextInputType.emailAddress,
              decoration: AppTheme.inputDeco('Email address', '📧')),
            const SizedBox(height: 14),
            TextField(controller: _passCtrl, obscureText: true, decoration: AppTheme.inputDeco('Password', '🔒')),
            const SizedBox(height: 20),
            AppTheme.gradientButton(label: 'Login  →', onTap: _login, loading: _loading),
          ])),
          // JOIN TAB
          Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: Column(children: [
            TextField(controller: _inviteCtrl, textCapitalization: TextCapitalization.characters,
              decoration: AppTheme.inputDeco('COUSIN-2026 / FAMILY-2026', '🔗')),
            const SizedBox(height: 6),
            const Text('Ask your cousin for the invite code', style: TextStyle(fontSize: 12, color: AppTheme.soft)),
            const SizedBox(height: 20),
            AppTheme.gradientButton(label: 'Verify Code  →', onTap: _verifyCode, loading: _loading),
            const SizedBox(height: 14),
            Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(color: const Color(0xFFEDE9FE), borderRadius: BorderRadius.circular(100)),
              child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('🛡️', style: TextStyle(fontSize: 16)), SizedBox(width: 8),
                Text('Your family data is safe and private',
                  style: TextStyle(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.w600)),
              ])),
          ])),
        ])),
        const SizedBox(height: 32),
      ]))),
    );
  }
}
