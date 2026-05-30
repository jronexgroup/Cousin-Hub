import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../app_theme.dart';
import '../services/auth_service.dart';

class EidiScreen extends StatefulWidget {
  const EidiScreen({super.key});
  @override
  State<EidiScreen> createState() => _EidiScreenState();
}

class _EidiScreenState extends State<EidiScreen> {
  final _db = FirebaseDatabase.instance;
  List<Map<String, dynamic>> _records = [];
  bool _showReceived = true;
  int _totalGiven = 0, _totalReceived = 0;
  String _selectedYear = DateTime.now().year.toString();

  @override
  void initState() { super.initState(); _listen(); }

  void _listen() {
    final uid = AuthService().currentUid ?? '';
    _db.ref('eidi').orderByChild('timestamp').onValue.listen((e) {
      if (!e.snapshot.exists || !mounted) { setState(() => _records = []); return; }
      final map = e.snapshot.value as Map;
      final list = map.entries.map((en) {
        final r = Map<String, dynamic>.from(en.value as Map);
        r['id'] = en.key;
        return r;
      }).toList();
      list.sort((a, b) => (b['timestamp'] ?? 0).compareTo(a['timestamp'] ?? 0));
      final year = _selectedYear;
      final received = list.where((r) => r['toUid'] == uid && r['year'] == year).toList();
      final given = list.where((r) => r['fromUid'] == uid && r['year'] == year).toList();
      setState(() {
        _records = list;
        _totalReceived = received.fold(0, (s, r) => s + ((r['amount'] ?? 0) as num).toInt());
        _totalGiven = given.fold(0, (s, r) => s + ((r['amount'] ?? 0) as num).toInt());
      });
    });
  }

  void _addEidi(BuildContext ctx) {
    final amtCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    String? selectedUid;
    String selectedName = '';
    List<Map<String, dynamic>> members = [];

    _db.ref('users').get().then((snap) {
      if (!snap.exists) return;
      final map = snap.value as Map;
      members = map.entries.map((en) {
        final u = Map<String, dynamic>.from(en.value as Map);
        u['uid'] = en.key;
        return u;
      }).where((u) => u['uid'] != AuthService().currentUid).toList();
    });

    showModalBottomSheet(context: ctx, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(builder: (ctx2, setSt) {
        return Container(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx2).viewInsets.bottom + 20),
          decoration: const BoxDecoration(color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Add Eidi Record 🎁', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.ink)),
            const SizedBox(height: 16),
            FutureBuilder(future: _db.ref('users').get(), builder: (_, snap) {
              if (!snap.hasData) return const CircularProgressIndicator();
              final map = (snap.data!.value as Map?) ?? {};
              final mems = map.entries.where((en) => en.key != AuthService().currentUid).map((en) {
                final u = Map<String, dynamic>.from(en.value as Map);
                u['uid'] = en.key;
                return u;
              }).toList();
              return DropdownButtonFormField<String>(
                value: selectedUid,
                decoration: InputDecoration(hintText: 'Select cousin',
                  filled: true, fillColor: AppTheme.bg,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                items: mems.map((m) => DropdownMenuItem(value: m['uid'] as String,
                  child: Text(m['nickname'] ?? m['name'] ?? 'Cousin'))).toList(),
                onChanged: (v) { setSt(() { selectedUid = v;
                  selectedName = mems.firstWhere((m) => m['uid'] == v, orElse: () => {})['name'] ?? ''; }); },
              );
            }),
            const SizedBox(height: 12),
            TextField(controller: amtCtrl, keyboardType: TextInputType.number,
              decoration: InputDecoration(hintText: 'Amount (৳)',
                prefixIcon: const Padding(padding: EdgeInsets.only(left: 14, right: 8),
                  child: Text('💰', style: TextStyle(fontSize: 20))),
                prefixIconConstraints: const BoxConstraints(minWidth: 44),
                filled: true, fillColor: AppTheme.bg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12))),
            const SizedBox(height: 12),
            TextField(controller: noteCtrl, decoration: InputDecoration(hintText: 'Note (optional)',
              filled: true, fillColor: AppTheme.bg,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12))),
            const SizedBox(height: 16),
            AppTheme.gradientButton(label: 'Save Record', onTap: () async {
              if (selectedUid == null || amtCtrl.text.isEmpty) return;
              final uid = AuthService().currentUid ?? '';
              final data = await AuthService().getProfile(uid);
              final amt = int.tryParse(amtCtrl.text.trim()) ?? 0;
              await _db.ref('eidi').push().set({
                'fromUid': uid, 'fromName': data?['name'] ?? 'Cousin',
                'toUid': selectedUid, 'toName': selectedName,
                'amount': amt, 'note': noteCtrl.text.trim(),
                'year': _selectedYear, 'timestamp': ServerValue.timestamp,
              });
              if (ctx.mounted) Navigator.pop(ctx);
            }),
          ]));
      }));
  }

  @override
  Widget build(BuildContext context) {
    final uid = AuthService().currentUid ?? '';
    final year = _selectedYear;
    final received = _records.where((r) => r['toUid'] == uid && r['year'] == year).toList();
    final given = _records.where((r) => r['fromUid'] == uid && r['year'] == year).toList();
    final showing = _showReceived ? received : given;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(backgroundColor: Colors.white, elevation: 0,
        title: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('EIDI TRACKER', style: TextStyle(fontSize: 10, letterSpacing: 2, color: AppTheme.soft)),
          Text('Blessings Box 🎁', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.ink)),
        ]),
        actions: [
          DropdownButton<String>(value: _selectedYear, underline: const SizedBox(),
            items: ['2026', '2025', '2024', '2023'].map((y) =>
              DropdownMenuItem(value: y, child: Text(y))).toList(),
            onChanged: (y) { setState(() => _selectedYear = y ?? _selectedYear); _listen(); }),
          const SizedBox(width: 8),
        ]),
      body: SingleChildScrollView(child: Column(children: [
        // Stats
        Padding(padding: const EdgeInsets.all(16),
          child: Row(children: [
            Expanded(child: Container(padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)]),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('💸 TOTAL GIVEN', style: TextStyle(fontSize: 10, letterSpacing: 1, color: AppTheme.soft)),
                const SizedBox(height: 6),
                Text('৳$_totalGiven', style: const TextStyle(fontSize: 26,
                  fontWeight: FontWeight.w800, color: AppTheme.ink)),
              ]))),
            const SizedBox(width: 12),
            Expanded(child: Container(padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(gradient: AppTheme.mainGradient, borderRadius: BorderRadius.circular(16)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('🎁 TOTAL RECEIVED', style: TextStyle(fontSize: 10, letterSpacing: 1, color: Colors.white70)),
                const SizedBox(height: 6),
                Text('৳$_totalReceived', style: const TextStyle(fontSize: 26,
                  fontWeight: FontWeight.w800, color: Colors.white)),
              ]))),
          ])),

        // Toggle
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(decoration: BoxDecoration(color: AppTheme.card, borderRadius: BorderRadius.circular(100)),
            child: Row(children: [
              Expanded(child: GestureDetector(onTap: () => setState(() => _showReceived = true),
                child: Container(padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: _showReceived ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(100),
                    boxShadow: _showReceived ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6)] : []),
                  child: Center(child: Text('Received (${received.length})',
                    style: TextStyle(fontWeight: FontWeight.w600, color: _showReceived ? AppTheme.ink : AppTheme.muted)))))),
              Expanded(child: GestureDetector(onTap: () => setState(() => _showReceived = false),
                child: Container(padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: !_showReceived ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(100),
                    boxShadow: !_showReceived ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6)] : []),
                  child: Center(child: Text('Given (${given.length})',
                    style: TextStyle(fontWeight: FontWeight.w600, color: !_showReceived ? AppTheme.ink : AppTheme.muted)))))),
            ]))),

        const SizedBox(height: 16),

        // Records
        if (showing.isEmpty) Padding(padding: const EdgeInsets.all(32),
          child: Center(child: Text('No ${_showReceived ? 'received' : 'given'} records for $year',
            style: const TextStyle(color: AppTheme.soft, fontSize: 14))))
        else ...showing.map((r) => Container(margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)]),
          child: Row(children: [
            Container(width: 42, height: 42,
              decoration: BoxDecoration(gradient: AppTheme.mainGradient, shape: BoxShape.circle),
              child: const Center(child: Text('🎁', style: TextStyle(fontSize: 20)))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_showReceived ? 'From: ${r['fromName'] ?? '?'}' : 'To: ${r['toName'] ?? '?'}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.ink)),
              if ((r['note'] ?? '').isNotEmpty) Text(r['note'],
                style: const TextStyle(fontSize: 12, color: AppTheme.soft)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('+৳${r['amount'] ?? 0}', style: TextStyle(fontSize: 18,
                fontWeight: FontWeight.w800, color: _showReceived ? Colors.green : AppTheme.primary)),
            ]),
          ]))),
        const SizedBox(height: 80),
      ])),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addEidi(context),
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Record', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
    );
  }
}
