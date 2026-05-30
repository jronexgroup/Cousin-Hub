import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../app_theme.dart';
import '../services/auth_service.dart';
import '../services/cache_service.dart';

// ═══════════════════════════════════════════════════════════
// BIRTHDAY COUNTDOWN
// ═══════════════════════════════════════════════════════════
class BirthdayWidget extends StatelessWidget {
  final List<Map<String, dynamic>> cousins;
  const BirthdayWidget({super.key, required this.cousins});

  @override
  Widget build(BuildContext context) {
    final upcoming = _getUpcoming();
    if (upcoming.isEmpty) return const SizedBox.shrink();

    return Container(margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(16), decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)]),
        borderRadius: BorderRadius.circular(20)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Text('🎂 ', style: TextStyle(fontSize: 20)),
          Text('Upcoming Birthdays', style: TextStyle(fontSize: 16,
            fontWeight: FontWeight.w800, color: Colors.white)),
        ]),
        const SizedBox(height: 12),
        ...upcoming.take(3).map((b) {
          final daysLeft = b['daysLeft'] as int;
          return Padding(padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              Container(width: 40, height: 40, decoration: const BoxDecoration(
                color: Colors.white24, shape: BoxShape.circle),
                child: Center(child: Text(b['name'].substring(0,1),
                  style: const TextStyle(color: Colors.white,
                    fontWeight: FontWeight.w900, fontSize: 18)))),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(b['name'], style: const TextStyle(color: Colors.white,
                  fontWeight: FontWeight.w700, fontSize: 13)),
                Text(daysLeft == 0 ? '🎉 TODAY!' : '$daysLeft days left',
                  style: TextStyle(color: daysLeft == 0
                    ? Colors.yellow : Colors.white70, fontSize: 11)),
              ])),
              if (daysLeft == 0) GestureDetector(
                onTap: () {/* open chat */},
                child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(100)),
                  child: const Text('Wish 🎉', style: TextStyle(color: Colors.white,
                    fontSize: 11, fontWeight: FontWeight.w700)))),
            ]));
        }),
      ]));
  }

  List<Map<String, dynamic>> _getUpcoming() {
    final now = DateTime.now();
    final result = <Map<String, dynamic>>[];
    for (final c in cousins) {
      final bday = c['birthday'] as String?;
      if (bday == null || bday.isEmpty) continue;
      try {
        final parts = bday.split('/');
        if (parts.length < 2) continue;
        final day = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        var next = DateTime(now.year, month, day);
        if (next.isBefore(now)) next = DateTime(now.year + 1, month, day);
        final daysLeft = next.difference(now).inDays;
        if (daysLeft <= 30) {
          result.add({'name': c['nickname'] ?? c['name'] ?? 'Cousin',
            'daysLeft': daysLeft});
        }
      } catch (_) {}
    }
    result.sort((a, b) => (a['daysLeft'] as int).compareTo(b['daysLeft'] as int));
    return result;
  }
}

// ═══════════════════════════════════════════════════════════
// EXPENSE SPLIT
// ═══════════════════════════════════════════════════════════
class ExpenseSplitScreen extends StatefulWidget {
  const ExpenseSplitScreen({super.key});
  @override
  State<ExpenseSplitScreen> createState() => _ExpenseSplitScreenState();
}

class _ExpenseSplitScreenState extends State<ExpenseSplitScreen> {
  final _db = FirebaseDatabase.instance;
  List<Map<String, dynamic>> _expenses = [];
  List<Map<String, dynamic>> _members = [];
  String _myUid = '';

  @override
  void initState() { super.initState(); _init(); }

  Future<void> _init() async {
    _myUid = AuthService().currentUid ?? '';
    final cached = CacheService.loadAllUsers();
    if (cached != null) {
      setState(() => _members = cached.entries.map((e) {
        final u = Map<String, dynamic>.from(e.value as Map);
        u['uid'] = e.key; return u;
      }).toList());
    }
    _db.ref('expenses').orderByChild('timestamp').limitToLast(20)
      .onValue.listen((e) {
      if (!e.snapshot.exists || !mounted) return;
      final map = e.snapshot.value as Map;
      final list = map.entries.map((en) {
        final ex = Map<String, dynamic>.from(en.value as Map);
        ex['id'] = en.key; return ex;
      }).toList()..sort((a,b) => (b['timestamp']??0).compareTo(a['timestamp']??0));
      setState(() => _expenses = list);
    });
  }

  void _addExpense() {
    final nameCtrl = TextEditingController();
    final amtCtrl = TextEditingController();
    String paidBy = _myUid;
    final List<String> splitWith = [_myUid];

    showModalBottomSheet(context: context, isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(builder: (ctx, setSt) => Container(
        padding: EdgeInsets.fromLTRB(20, 20, 20,
          MediaQuery.of(context).viewInsets.bottom + 20),
        decoration: const BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Add Expense', style: TextStyle(fontSize: 18,
            fontWeight: FontWeight.w800, color: AppTheme.ink)),
          const SizedBox(height: 16),
          TextField(controller: nameCtrl,
            decoration: _inp('Description (e.g. Pizza)', Icons.receipt_outlined)),
          const SizedBox(height: 10),
          TextField(controller: amtCtrl, keyboardType: TextInputType.number,
            decoration: _inp('Amount (৳)', Icons.currency_rupee)),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: paidBy,
            decoration: _inp('Paid by', Icons.person_outline),
            items: _members.map((m) => DropdownMenuItem(
              value: m['uid'] as String,
              child: Text(m['nickname'] ?? m['name'] ?? 'Cousin'))).toList(),
            onChanged: (v) => setSt(() => paidBy = v!)),
          const SizedBox(height: 10),
          const Align(alignment: Alignment.centerLeft,
            child: Text('Split with:', style: TextStyle(fontWeight: FontWeight.w700,
              color: AppTheme.muted, fontSize: 13))),
          Wrap(spacing: 8, children: _members.map((m) {
            final uid = m['uid'] as String;
            final sel = splitWith.contains(uid);
            return FilterChip(
              label: Text(m['nickname'] ?? m['name'] ?? 'Cousin'),
              selected: sel,
              onSelected: (v) => setSt(() {
                if (v) splitWith.add(uid); else splitWith.remove(uid);
              }));
          }).toList()),
          const SizedBox(height: 16),
          AppTheme.gradientButton(label: 'Add Expense', onTap: () async {
            if (nameCtrl.text.isEmpty || amtCtrl.text.isEmpty) return;
            final amt = double.tryParse(amtCtrl.text) ?? 0;
            await _db.ref('expenses').push().set({
              'name': nameCtrl.text.trim(),
              'amount': amt,
              'paidBy': paidBy,
              'paidByName': _members.firstWhere(
                (m) => m['uid'] == paidBy, orElse: () => {'name': 'Cousin'})['name'],
              'splitWith': splitWith,
              'perPerson': splitWith.isEmpty ? amt : amt / splitWith.length,
              'timestamp': ServerValue.timestamp,
            });
            Navigator.pop(ctx);
          }),
        ]))));
  }

  InputDecoration _inp(String hint, IconData icon) => InputDecoration(
    hintText: hint, prefixIcon: Icon(icon, size: 18, color: AppTheme.muted),
    filled: true, fillColor: AppTheme.bg,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12));

  // Calculate balances
  Map<String, double> _getBalances() {
    final balances = <String, double>{};
    for (final m in _members) { balances[m['uid'] as String] = 0.0; }
    for (final ex in _expenses) {
      final paidBy = ex['paidBy'] as String;
      final amount = (ex['amount'] as num).toDouble();
      final split = List<String>.from(ex['splitWith'] as List);
      if (split.isEmpty) continue;
      final perPerson = amount / split.length;
      balances[paidBy] = (balances[paidBy] ?? 0) + amount;
      for (final uid in split) {
        balances[uid] = (balances[uid] ?? 0) - perPerson;
      }
    }
    return balances;
  }

  @override
  Widget build(BuildContext context) {
    final balances = _getBalances();
    final totalSpend = _expenses.fold(0.0, (s, e) => s + (e['amount'] as num).toDouble());

    return Scaffold(backgroundColor: AppTheme.bg,
      appBar: AppBar(backgroundColor: Colors.white, elevation: 0,
        title: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Cousin Pro', style: TextStyle(fontSize: 12, color: AppTheme.soft)),
          Text('Expense Split 💰', style: TextStyle(fontSize: 20,
            fontWeight: FontWeight.w800, color: AppTheme.ink)),
        ]),
        actions: [IconButton(icon: const Icon(Icons.add_circle_outline, color: AppTheme.primary),
          onPressed: _addExpense)]),
      body: SingleChildScrollView(child: Column(children: [
        // Summary card
        Container(margin: const EdgeInsets.all(16), padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(gradient: AppTheme.mainGradient,
            borderRadius: BorderRadius.circular(20)),
          child: Column(children: [
            const Text('Total Group Spend', style: TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 4),
            Text('৳${totalSpend.toStringAsFixed(0)}', style: const TextStyle(
              color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: balances.entries.map((e) {
                final member = _members.firstWhere((m) => m['uid'] == e.key, orElse: () => {});
                final name = member['nickname'] ?? member['name'] ?? 'Cousin';
                final bal = e.value;
                return Column(children: [
                  Text(bal >= 0 ? '+৳${bal.toStringAsFixed(0)}' : '-৳${(-bal).toStringAsFixed(0)}',
                    style: TextStyle(color: bal >= 0 ? Colors.greenAccent : Colors.redAccent,
                      fontWeight: FontWeight.w900, fontSize: 14)),
                  Text(name.length > 6 ? name.substring(0,5)+'…' : name,
                    style: const TextStyle(color: Colors.white70, fontSize: 10)),
                ]);
              }).toList()),
          ])),

        // Expense list
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
          child: AppTheme.sectionTitle('Expenses')),
        ..._expenses.map((ex) {
          final paid = ex['paidByName'] ?? 'Cousin';
          final amt = (ex['amount'] as num).toDouble();
          final split = List<String>.from(ex['splitWith'] as List);
          final isMyExpense = ex['paidBy'] == _myUid;
          return Container(margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)]),
            child: Row(children: [
              Container(width: 44, height: 44, decoration: BoxDecoration(
                color: isMyExpense ? const Color(0xFFEDE9FE) : AppTheme.bg,
                borderRadius: BorderRadius.circular(12)),
                child: const Center(child: Text('💳', style: TextStyle(fontSize: 22)))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(ex['name'] ?? 'Expense', style: const TextStyle(fontSize: 14,
                  fontWeight: FontWeight.w700, color: AppTheme.ink)),
                Text('Paid by $paid • Split ${split.length} ways',
                  style: const TextStyle(fontSize: 12, color: AppTheme.soft)),
              ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('৳${amt.toStringAsFixed(0)}', style: const TextStyle(fontSize: 16,
                  fontWeight: FontWeight.w900, color: AppTheme.ink)),
                Text('৳${(amt/max(split.length,1)).toStringAsFixed(0)}/person',
                  style: const TextStyle(fontSize: 10, color: AppTheme.soft)),
              ]),
            ]));
        }),
        const SizedBox(height: 80),
      ])),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addExpense, backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Expense', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
    );
  }
}
