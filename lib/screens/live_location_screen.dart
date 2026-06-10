import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import '../app_theme.dart';
import '../services/auth_service.dart';
import '../services/live_location_service.dart';

class LiveLocationScreen extends StatefulWidget {
  const LiveLocationScreen({super.key});
  @override
  State<LiveLocationScreen> createState() => _LiveLocationScreenState();
}

class _LiveLocationScreenState extends State<LiveLocationScreen> {
  final _db = FirebaseDatabase.instance;
  final MapController _mapCtrl = MapController();
  String _myUid = '', _myName = '', _myPhoto = '';
  final _service = LiveLocationService.instance;
  Map<String, Map<String, dynamic>> _cousins = {};
  LatLng? _myPos;
  String? _selectedUid;
  bool _gpsError = false;

  @override
  void initState() {
    super.initState();
    _init();
    _listenLocations();
    _service.locationStream.listen((pos) {
      if (mounted) setState(() {
        _myPos = LatLng(pos.latitude, pos.longitude);
        _gpsError = false;
      });
    });
  }

  Future<void> _init() async {
    _myUid = AuthService().currentUid ?? '';
    final p = await AuthService().getProfile(_myUid);
    if (p != null && mounted) setState(() {
      _myName = p['nickname'] ?? p['name'] ?? 'Cousin';
      _myPhoto = p['photoUrl'] ?? '';
    });
    _service.init(uid: _myUid, name: _myName, photo: _myPhoto);
  }

  void _listenLocations() {
    _db.ref('liveLocations').onValue.listen((e) {
      if (!e.snapshot.exists || !mounted) return;
      final map = Map<String, dynamic>.from(e.snapshot.value as Map);
      final now = DateTime.now().millisecondsSinceEpoch;
      final active = <String, Map<String, dynamic>>{};

      map.forEach((uid, val) {
        final data = Map<String, dynamic>.from(val as Map);
        final ts = (data['timestamp'] ?? 0) as int;
        if (now - ts > 5 * 60 * 1000) return;
        active[uid] = data;
      });

      if (mounted) setState(() => _cousins = active);

      if (_selectedUid != null && active.containsKey(_selectedUid)) {
        final d = active[_selectedUid]!;
        _mapCtrl.move(
          LatLng((d['lat'] as num).toDouble(), (d['lng'] as num).toDouble()), 15);
      } else if (_myPos != null && _selectedUid == null) {
        _mapCtrl.move(_myPos!, 14);
      } else if (active.isNotEmpty && _selectedUid == null) {
        final first = active.values.first;
        _mapCtrl.move(
          LatLng((first['lat'] as num).toDouble(), (first['lng'] as num).toDouble()), 14);
      }
    });
  }

  Future<void> _toggleSharing() async {
    if (_service.isSharing) {
      await _service.stop();
      setState(() => _myPos = null);
      return;
    }

    if (!await Geolocator.isLocationServiceEnabled()) {
      if (!mounted) return;
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('📍', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 12),
            const Text('Turn on Location',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const Text('This app needs location access to share your live location with family.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.black54)),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await openAppSettings();
                  if (mounted) _toggleSharing();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(100)),
                  padding: const EdgeInsets.symmetric(vertical: 14)),
                child: const Text('Turn On', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Not now', style: TextStyle(color: Colors.black54))),
          ])));
      return;
    }

    final started = await _service.start();
    if (!started && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location permission is required.')));
    }
  }

  List<Marker> _buildMarkers() {
    return _cousins.entries.map((e) {
      final uid = e.key;
      final data = e.value;
      final lat = (data['lat'] as num).toDouble();
      final lng = (data['lng'] as num).toDouble();
      final name = data['name'] ?? 'Cousin';
      final photo = data['photo'] ?? '';
      final isMe = uid == _myUid;
      final isSelected = uid == _selectedUid;

      return Marker(
        point: LatLng(lat, lng),
        width: 60,
        height: 70,
        child: GestureDetector(
          onTap: () => _showCousinInfo(data, uid),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: isSelected ? 52 : 46,
              height: isSelected ? 52 : 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: isMe ? AppTheme.mainGradient : null,
                color: isMe ? null : const Color(0xFF1E88E5),
                border: Border.all(
                  color: isSelected ? Colors.amber : Colors.white,
                  width: isSelected ? 3 : 2.5),
                boxShadow: [BoxShadow(
                  color: Colors.black.withOpacity(0.3), blurRadius: 8)]),
              child: photo.isNotEmpty
                  ? ClipOval(child: Image.network(photo, fit: BoxFit.cover))
                  : Center(child: Text(name[0].toUpperCase(),
                      style: const TextStyle(color: Colors.white,
                        fontWeight: FontWeight.w900, fontSize: 18))),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isMe ? AppTheme.primary : const Color(0xFF1E88E5),
                borderRadius: BorderRadius.circular(100)),
              child: Text(isMe ? 'You' : name.split(' ').first,
                style: const TextStyle(color: Colors.white, fontSize: 9,
                  fontWeight: FontWeight.w800)),
            ),
          ])));
    }).toList();
  }

  void _showCousinInfo(Map<String, dynamic> data, String uid) {
    final name = data['name'] ?? 'Cousin';
    final ts = (data['timestamp'] ?? 0) as int;
    final ago = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(ts)).inMinutes;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Container(width: 52, height: 52,
              decoration: BoxDecoration(gradient: AppTheme.mainGradient,
                shape: BoxShape.circle),
              child: (data['photo'] ?? '').isNotEmpty
                  ? ClipOval(child: Image.network(data['photo'], fit: BoxFit.cover))
                  : Center(child: Text(name[0].toUpperCase(),
                      style: const TextStyle(color: Colors.white,
                        fontWeight: FontWeight.w900, fontSize: 22)))),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: const TextStyle(fontSize: 16,
                fontWeight: FontWeight.w800, color: AppTheme.ink)),
              Text('Updated $ago min ago',
                style: const TextStyle(fontSize: 13, color: AppTheme.soft)),
              Text('Accuracy: ±${(data['accuracy'] ?? 0).toStringAsFixed(0)}m',
                style: const TextStyle(fontSize: 12, color: AppTheme.soft)),
            ])),
          ]),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                setState(() => _selectedUid = uid);
                _mapCtrl.move(
                  LatLng((data['lat'] as num).toDouble(),
                         (data['lng'] as num).toDouble()), 16);
              },
              icon: const Icon(Icons.my_location, size: 18),
              label: const Text('Follow this member'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primary,
                side: const BorderSide(color: AppTheme.primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(100)))),
          ),
        ])));
  }

  void _fitAllMarkers() {
    setState(() => _selectedUid = null);
    if (_cousins.isEmpty) return;
    final lats = _cousins.values.map((d) => (d['lat'] as num).toDouble()).toList();
    final lngs = _cousins.values.map((d) => (d['lng'] as num).toDouble()).toList();
    _mapCtrl.move(LatLng(
      lats.reduce((a, b) => a + b) / lats.length,
      lngs.reduce((a, b) => a + b) / lngs.length), 13);
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = _cousins.length;
    final sortedMembers = _cousins.entries.toList()
      ..sort((a, b) => a.value['name']?.toString().compareTo(
             b.value['name']?.toString() ?? '') ?? 0);
    final sharing = _service.isSharing;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Cousin Pro',
            style: TextStyle(fontSize: 12, color: AppTheme.soft)),
          Text('Live Location 📍 ($activeCount online)',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800,
              color: AppTheme.ink)),
        ]),
        actions: [
          if (sortedMembers.length > 1)
            IconButton(
              icon: const Icon(Icons.fit_screen, color: AppTheme.primary),
              onPressed: _fitAllMarkers),
        ],
      ),
      body: Column(children: [
        // ── Member dropdown selector ──
        if (sortedMembers.isNotEmpty)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: DropdownButtonFormField<String>(
              value: _selectedUid,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(100),
                  borderSide: BorderSide.none),
                prefixIcon: const Icon(Icons.people_rounded, size: 20,
                  color: AppTheme.primary)),
              hint: const Text('Track a member...',
                style: TextStyle(fontSize: 13)),
              isExpanded: true,
              dropdownColor: Colors.white,
              items: sortedMembers.map((e) {
                final uid = e.key;
                final d = e.value;
                final name = d['name'] ?? 'Cousin';
                final isMe = uid == _myUid;
                return DropdownMenuItem(
                  value: uid,
                  child: Text(isMe ? '$name (You)' : name,
                    style: TextStyle(fontSize: 13,
                      fontWeight: isMe ? FontWeight.w700 : FontWeight.w400)));
              }).toList(),
              onChanged: (val) {
                setState(() => _selectedUid = val);
                if (val != null && _cousins.containsKey(val)) {
                  final d = _cousins[val]!;
                  _mapCtrl.move(
                    LatLng((d['lat'] as num).toDouble(),
                           (d['lng'] as num).toDouble()), 15);
                }
              }),
          ),

        // ── Map ──
        Expanded(child: Stack(children: [
          FlutterMap(
            mapController: _mapCtrl,
            options: MapOptions(
              initialCenter: _myPos ?? const LatLng(23.8103, 90.4125),
              initialZoom: 13),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.jronex.cousinhub'),
              MarkerLayer(markers: _buildMarkers()),
            ]),

          // GPS error banner
          if (_gpsError && sharing)
            Positioned(top: 8, left: 16, right: 16,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange)),
                child: const Row(children: [
                  Icon(Icons.gps_off, size: 16, color: Colors.orange),
                  SizedBox(width: 8),
                  Expanded(child: Text('GPS signal lost. Make sure you\'re outdoors.',
                    style: TextStyle(fontSize: 12, color: Colors.orange))),
                ]))),
        ])),

        // ── Bottom panel ──
        SafeArea(child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.1), blurRadius: 12,
              offset: const Offset(0, -4))]),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Online avatars
            if (_cousins.isNotEmpty) ...[
              SizedBox(
                height: 38,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    const Text('Online:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                        color: AppTheme.muted)),
                    const SizedBox(width: 10),
                    ..._cousins.entries.map((e) {
                      final d = e.value;
                      final uid = e.key;
                      final isSelected = uid == _selectedUid;
                      return GestureDetector(
                        onTap: () {
                          setState(() => _selectedUid = uid);
                          _mapCtrl.move(
                            LatLng((d['lat'] as num).toDouble(),
                                   (d['lng'] as num).toDouble()), 15);
                        },
                        child: Container(
                          width: 34, height: 34,
                          margin: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(
                            gradient: isSelected ? AppTheme.mainGradient : null,
                            color: isSelected ? null : AppTheme.primary,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? Colors.amber : Colors.white,
                              width: isSelected ? 2.5 : 2)),
                          child: (d['photo'] ?? '').isNotEmpty
                              ? ClipOval(child: Image.network(
                                  d['photo'], fit: BoxFit.cover))
                              : Center(child: Text(
                                  (d['name'] ?? 'C')[0].toUpperCase(),
                                  style: const TextStyle(color: Colors.white,
                                    fontWeight: FontWeight.w700, fontSize: 13)))));
                    }),
                  ])),
              ),
              const SizedBox(height: 12),
            ],

            // Share toggle button
            GestureDetector(
              onTap: _toggleSharing,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: sharing
                      ? const LinearGradient(
                          colors: [Color(0xFFE53935), Color(0xFFFF5722)])
                      : AppTheme.mainGradient,
                  borderRadius: BorderRadius.circular(100),
                  boxShadow: [BoxShadow(
                    color: (sharing ? Colors.red : AppTheme.primary)
                        .withOpacity(0.35),
                    blurRadius: 12, offset: const Offset(0, 4))]),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(sharing ? Icons.location_off : Icons.my_location,
                      color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      sharing ? '🔴 Stop Sharing' : '📍 Share My Location',
                      style: const TextStyle(color: Colors.white,
                        fontWeight: FontWeight.w800, fontSize: 15)),
                  ])),
            ),

            if (sharing)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Sharing until you stop it • ${_myPos != null ? "GPS active" : "Getting location..."}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11, color: AppTheme.soft))),
          ]),
        )),
      ]),
    );
  }
}
