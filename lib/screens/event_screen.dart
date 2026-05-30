import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../app_theme.dart';
import '../services/auth_service.dart';

class EventScreen extends StatefulWidget {
  const EventScreen({super.key});
  @override
  State<EventScreen> createState() => _EventScreenState();
}

class _EventScreenState extends State<EventScreen> {
  final _db = FirebaseDatabase.instance;
  List<Map<String, dynamic>> _events = [];

  @override
  void initState() { super.initState(); _listenEvents(); }

  void _listenEvents() {
    _db.ref('events').orderByChild('date').onValue.listen((e) {
      if (!e.snapshot.exists || !mounted) { setState(() => _events = []); return; }
      final map = e.snapshot.value as Map;
      final list = map.entries.map((en) {
        final ev = Map<String, dynamic>.from(en.value as Map);
        ev['id'] = en.key;
        return ev;
      }).toList();
      list.sort((a, b) => (a['date'] ?? '').compareTo(b['date'] ?? ''));
      setState(() => _events = list);
    });
  }

  Future<void> _rsvp(String eventId, String status) async {
    final uid = AuthService().currentUid;
    if (uid == null) return;
    await _db.ref('events/$eventId/attendees/$uid').set(status);
  }

  void _showCreateEvent(BuildContext ctx) {
    final titleCtrl = TextEditingController();
    final dateCtrl = TextEditingController();
    final timeCtrl = TextEditingController();
    final placeCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String selectedType = 'meetup';

    showModalBottomSheet(context: ctx, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(builder: (ctx2, setSt) => Container(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx2).viewInsets.bottom + 20),
        decoration: const BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Create Event', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.ink)),
          const SizedBox(height: 16),
          _inp(titleCtrl, 'Event title', Icons.celebration_outlined),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _inp(dateCtrl, 'Date (DD/MM/YYYY)', Icons.calendar_today_outlined)),
            const SizedBox(width: 12),
            Expanded(child: _inp(timeCtrl, 'Time (HH:MM)', Icons.access_time_outlined)),
          ]),
          const SizedBox(height: 12),
          _inp(placeCtrl, 'Location', Icons.location_on_outlined),
          const SizedBox(height: 12),
          _inp(descCtrl, 'Description (optional)', Icons.description_outlined),
          const SizedBox(height: 12),
          Wrap(spacing: 8, children: [
            {'id': 'meetup', 'label': '👥 Meetup'},
            {'id': 'birthday', 'label': '🎂 Birthday'},
            {'id': 'eid', 'label': '🌙 Eid'},
            {'id': 'wedding', 'label': '💍 Wedding'},
          ].map((t) {
            final sel = selectedType == t['id'];
            return GestureDetector(onTap: () => setSt(() => selectedType = t['id']!),
              child: Container(margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: sel ? AppTheme.primary : AppTheme.bg,
                  borderRadius: BorderRadius.circular(100)),
                child: Text(t['label']!, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                  color: sel ? Colors.white : AppTheme.muted))));
          }).toList()),
          const SizedBox(height: 16),
          AppTheme.gradientButton(label: 'Create Event', onTap: () async {
            if (titleCtrl.text.isEmpty || dateCtrl.text.isEmpty) return;
            final uid = AuthService().currentUid ?? '';
            final data = await AuthService().getProfile(uid);
            await _db.ref('events').push().set({
              'title': titleCtrl.text.trim(), 'date': dateCtrl.text.trim(),
              'time': timeCtrl.text.trim(), 'place': placeCtrl.text.trim(),
              'description': descCtrl.text.trim(), 'type': selectedType,
              'createdBy': uid, 'creatorName': data?['name'] ?? 'Cousin',
              'timestamp': ServerValue.timestamp, 'attendees': {},
              'tasks': {}, 'budget': 0,
            });
            if (ctx.mounted) Navigator.pop(ctx);
          }),
        ])))));
  }

  Widget _inp(TextEditingController c, String h, IconData icon) => TextField(
    controller: c,
    style: const TextStyle(fontSize: 14, color: AppTheme.ink),
    decoration: InputDecoration(prefixIcon: Icon(icon, size: 18, color: AppTheme.muted),
      hintText: h, hintStyle: const TextStyle(color: Color(0xFFBBAA99), fontSize: 13),
      filled: true, fillColor: AppTheme.bg,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(backgroundColor: Colors.white, elevation: 0, automaticallyImplyLeading: false,
        title: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('FAMILY HUB', style: TextStyle(fontSize: 10, letterSpacing: 2, color: AppTheme.soft)),
          Text('Our Calendar', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.ink)),
        ])),
      body: _events.isEmpty
        ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Text('🎉', style: TextStyle(fontSize: 60)),
            const SizedBox(height: 16),
            const Text('No events yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.ink)),
            const SizedBox(height: 8),
            const Text('Plan your first family event!', style: TextStyle(color: AppTheme.soft)),
            const SizedBox(height: 24),
            AppTheme.gradientButton(label: '+ Create Event', onTap: () => _showCreateEvent(context)),
          ]))
        : ListView.builder(padding: const EdgeInsets.all(16), itemCount: _events.length,
            itemBuilder: (_, i) => _EventCard(event: _events[i], onRsvp: _rsvp)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateEvent(context),
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Create Event', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final Map<String, dynamic> event;
  final Function(String, String) onRsvp;
  const _EventCard({required this.event, required this.onRsvp});

  @override
  Widget build(BuildContext context) {
    final uid = AuthService().currentUid ?? '';
    final attendees = event['attendees'] != null ? Map<String, dynamic>.from(event['attendees'] as Map) : <String, dynamic>{};
    final myStatus = attendees[uid];
    final goingCount = attendees.values.where((v) => v == 'going').length;
    final notGoingCount = attendees.values.where((v) => v == 'not_going').length;

    final typeIcons = {'birthday': '🎂', 'eid': '🌙', 'wedding': '💍', 'meetup': '👥'};
    final icon = typeIcons[event['type']] ?? '🎉';

    return Container(margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(height: 8, decoration: BoxDecoration(
          gradient: AppTheme.mainGradient,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)))),
        Padding(padding: const EdgeInsets.all(16), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(icon, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(event['title'] ?? '', style: const TextStyle(fontSize: 16,
                fontWeight: FontWeight.w800, color: AppTheme.ink)),
              const SizedBox(height: 2),
              Text('${event['date'] ?? ''} ${event['time'] ?? ''}',
                style: const TextStyle(fontSize: 12, color: AppTheme.muted)),
            ])),
          ]),
          if ((event['place'] ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.location_on_outlined, size: 14, color: AppTheme.soft),
              const SizedBox(width: 4),
              Text(event['place'] ?? '', style: const TextStyle(fontSize: 13, color: AppTheme.muted)),
            ]),
          ],
          if ((event['description'] ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(event['description'] ?? '', style: const TextStyle(fontSize: 13, color: AppTheme.muted)),
          ],
          const SizedBox(height: 12),
          Text('✅ $goingCount Going  ❌ $notGoingCount Not going',
            style: const TextStyle(fontSize: 12, color: AppTheme.soft)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _rsvpBtn("I'm Going", 'going', myStatus == 'going', () => onRsvp(event['id'], 'going'))),
            const SizedBox(width: 12),
            Expanded(child: _rsvpBtn('Not Going', 'not_going', myStatus == 'not_going', () => onRsvp(event['id'], 'not_going'))),
          ]),
        ])),
      ]));
  }

  Widget _rsvpBtn(String label, String val, bool active, VoidCallback onTap) =>
    GestureDetector(onTap: onTap,
      child: Container(padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          gradient: active ? AppTheme.mainGradient : null,
          color: active ? null : AppTheme.bg,
          borderRadius: BorderRadius.circular(100)),
        child: Center(child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
          color: active ? Colors.white : AppTheme.muted)))));
}
