import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../app_theme.dart';
import '../services/auth_service.dart';

class VotingScreen extends StatefulWidget {
  const VotingScreen({super.key});
  @override
  State<VotingScreen> createState() => _VotingScreenState();
}

class _VotingScreenState extends State<VotingScreen> {
  final _db = FirebaseDatabase.instance;
  List<Map<String, dynamic>> _polls = [];

  @override
  void initState() { super.initState(); _listen(); }

  void _listen() {
    _db.ref('votes').orderByChild('timestamp').onValue.listen((e) {
      if (!e.snapshot.exists || !mounted) { setState(() => _polls = []); return; }
      final map = e.snapshot.value as Map;
      final list = map.entries.map((en) {
        final p = Map<String, dynamic>.from(en.value as Map);
        p['id'] = en.key;
        return p;
      }).toList();
      list.sort((a, b) => (b['timestamp'] ?? 0).compareTo(a['timestamp'] ?? 0));
      setState(() => _polls = list);
    });
  }

  Future<void> _vote(String pollId, String option) async {
    final uid = AuthService().currentUid;
    if (uid == null) return;
    await _db.ref('votes/$pollId/votes/$uid').set(option);
  }

  void _createPoll(BuildContext ctx) {
    final qCtrl = TextEditingController();
    final opts = List.generate(4, (_) => TextEditingController());
    bool isSecret = false;

    showModalBottomSheet(context: ctx, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(builder: (ctx2, setSt) => Container(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx2).viewInsets.bottom + 20),
        decoration: const BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Create Family Vote', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.ink)),
          const SizedBox(height: 16),
          TextField(controller: qCtrl, decoration: InputDecoration(hintText: 'What are we voting on?',
            filled: true, fillColor: AppTheme.bg,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12))),
          const SizedBox(height: 12),
          ...opts.asMap().entries.map((e) => Padding(padding: const EdgeInsets.only(bottom: 10),
            child: TextField(controller: e.value, decoration: InputDecoration(
              hintText: 'Option ${e.key + 1}${e.key >= 2 ? ' (optional)' : ''}',
              filled: true, fillColor: AppTheme.bg,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12))))),
          Row(children: [
            Switch(value: isSecret, onChanged: (v) => setSt(() => isSecret = v),
              activeColor: AppTheme.primary),
            const SizedBox(width: 8),
            const Text('Secret voting (hide who voted what)', style: TextStyle(fontSize: 13, color: AppTheme.muted)),
          ]),
          const SizedBox(height: 12),
          AppTheme.gradientButton(label: 'Create Vote', onTap: () async {
            final options = opts.map((c) => c.text.trim()).where((s) => s.isNotEmpty).toList();
            if (qCtrl.text.isEmpty || options.length < 2) return;
            final uid = AuthService().currentUid ?? '';
            final data = await AuthService().getProfile(uid);
            await _db.ref('votes').push().set({
              'question': qCtrl.text.trim(), 'options': options,
              'votes': {}, 'isSecret': isSecret,
              'createdBy': uid, 'creatorName': data?['name'] ?? 'Cousin',
              'timestamp': ServerValue.timestamp, 'active': true,
            });
            if (ctx.mounted) Navigator.pop(ctx);
          }),
        ])))));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(backgroundColor: Colors.white, elevation: 0,
        title: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Cousin Pro', style: TextStyle(fontSize: 12, color: AppTheme.soft)),
          Text('Family Votes', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.ink)),
        ])),
      body: _polls.isEmpty
        ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Text('🗳️', style: TextStyle(fontSize: 60)),
            const SizedBox(height: 16),
            const Text('No votes yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.ink)),
            const SizedBox(height: 8),
            const Text('Start a family vote!', style: TextStyle(color: AppTheme.soft)),
          ]))
        : ListView.builder(padding: const EdgeInsets.all(16), itemCount: _polls.length,
            itemBuilder: (_, i) {
              final poll = _polls[i];
              final uid = AuthService().currentUid ?? '';
              final votes = poll['votes'] != null ? Map<String, dynamic>.from(poll['votes'] as Map) : <String, dynamic>{};
              final myVote = votes[uid];
              final options = List<String>.from(poll['options'] ?? []);
              final totalVotes = votes.length;
              final isSecret = poll['isSecret'] == true;
              final winnerOpt = totalVotes > 0 ? options.reduce((a, b) =>
                votes.values.where((v) => v == a).length >= votes.values.where((v) => v == b).length ? a : b) : null;

              return Container(margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
                child: Padding(padding: const EdgeInsets.all(16), child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Text('🗳️', style: TextStyle(fontSize: 20)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(poll['question'] ?? '', style: const TextStyle(fontSize: 15,
                      fontWeight: FontWeight.w700, color: AppTheme.ink))),
                    if (isSecret) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: const Color(0xFFEDE9FE), borderRadius: BorderRadius.circular(100)),
                      child: const Text('SECRET', style: TextStyle(fontSize: 10, color: AppTheme.primary,
                        fontWeight: FontWeight.w600, letterSpacing: 1))),
                  ]),
                  const SizedBox(height: 4),
                  Text('By ${poll['creatorName'] ?? 'Cousin'}',
                    style: const TextStyle(fontSize: 12, color: AppTheme.soft)),
                  const SizedBox(height: 14),
                  ...options.map((opt) {
                    final voteCount = votes.values.where((v) => v == opt).length;
                    final pct = totalVotes > 0 ? voteCount / totalVotes : 0.0;
                    final voted = myVote == opt;
                    final isWinner = opt == winnerOpt && totalVotes > 0;
                    return GestureDetector(onTap: () => _vote(poll['id'], opt),
                      child: Container(margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: isWinner ? const Color(0xFFF0FFF4) : voted ? const Color(0xFFEDE9FE) : AppTheme.bg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isWinner ? Colors.green : voted ? AppTheme.primary : Colors.transparent)),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            if (isWinner) const Text('👑 ', style: TextStyle(fontSize: 14)),
                            Expanded(child: Text(opt, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                              color: voted ? AppTheme.primary : AppTheme.ink))),
                            if (!isSecret) Text('$voteCount', style: const TextStyle(fontSize: 12, color: AppTheme.soft)),
                          ]),
                          const SizedBox(height: 6),
                          ClipRRect(borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(value: pct, minHeight: 4,
                              backgroundColor: Colors.grey.shade200,
                              valueColor: AlwaysStoppedAnimation<Color>(isWinner ? Colors.green : AppTheme.primary))),
                        ])));
                  }),
                  const SizedBox(height: 4),
                  Text('$totalVotes total votes', style: const TextStyle(fontSize: 12, color: AppTheme.soft)),
                ])));
            }),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createPoll(context),
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.how_to_vote_outlined, color: Colors.white),
        label: const Text('New Vote', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
    );
  }
}
