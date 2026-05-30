import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../app_theme.dart';
import 'home_screen.dart';

class RegisterScreen extends StatefulWidget {
  final String inviteCode;
  const RegisterScreen({super.key, required this.inviteCode});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameCtrl = TextEditingController();
  final _nickCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  String _relation = 'Cousin';
  bool _loading = false;
  String _error = '';

  Future<void> _register() async {
    if (_nameCtrl.text.isEmpty || _emailCtrl.text.isEmpty || _passCtrl.text.isEmpty) {
      setState(() => _error = 'Please fill all required fields'); return;
    }
    setState(() { _loading = true; _error = ''; });
    final r = await AuthService().register(
      inviteCode: widget.inviteCode, email: _emailCtrl.text.trim(),
      password: _passCtrl.text.trim(), name: _nameCtrl.text.trim(),
      nickname: _nickCtrl.text.trim(), relation: _relation);
    setState(() => _loading = false);
    if (r['success']) {
      if (mounted) Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()), (_) => false);
    } else { setState(() => _error = r['error']); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: AppTheme.ink),
          onPressed: () => Navigator.pop(context))),
      body: SafeArea(child: SingleChildScrollView(padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Welcome home!', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: AppTheme.ink)),
          const SizedBox(height: 6),
          Text('Code: ${widget.inviteCode} ✅', style: const TextStyle(fontSize: 13,
            color: AppTheme.primary, fontWeight: FontWeight.w600)),
          const SizedBox(height: 24),
          if (_error.isNotEmpty) ...[AppTheme.errorBox(_error), const SizedBox(height: 14)],
          AppTheme.label('Full Name *'),
          _fld(_nameCtrl, 'Your full name'),
          const SizedBox(height: 14),
          AppTheme.label('Nickname (optional)'),
          _fld(_nickCtrl, 'What cousins call you'),
          const SizedBox(height: 14),
          AppTheme.label('Email *'),
          _fld(_emailCtrl, 'your@email.com', type: TextInputType.emailAddress),
          const SizedBox(height: 14),
          AppTheme.label('Password *'),
          _fld(_passCtrl, 'Min 6 characters', obscure: true),
          const SizedBox(height: 14),
          AppTheme.label('Relation'),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: ['Cousin', 'Elder', 'Younger', 'Mama/Khala', 'Chacha/Fufu'].map((r) {
            final sel = _relation == r;
            return GestureDetector(onTap: () => setState(() => _relation = r),
              child: Container(margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: sel ? AppTheme.primary : AppTheme.card,
                  borderRadius: BorderRadius.circular(100)),
                child: Text(r, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                  color: sel ? Colors.white : AppTheme.muted))));
          }).toList()),
          const SizedBox(height: 28),
          AppTheme.gradientButton(label: 'Create Account  →', onTap: _register, loading: _loading),
          const SizedBox(height: 32),
        ]))),
    );
  }

  Widget _fld(TextEditingController c, String h, {TextInputType? type, bool obscure = false}) =>
    TextField(controller: c, keyboardType: type, obscureText: obscure,
      style: const TextStyle(fontSize: 14, color: AppTheme.ink),
      decoration: InputDecoration(hintText: h, hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
        filled: true, fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)));
}
