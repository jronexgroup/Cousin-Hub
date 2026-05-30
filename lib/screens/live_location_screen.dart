import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:async';
import '../app_theme.dart';
import '../services/auth_service.dart';
import '../services/cache_service.dart';

// ═══════════════════════════════════════════════════════════
// LIVE LOCATION SHARING — Eid gathering style
// ═══════════════════════════════════════════════════════════
class LiveLocationScreen extends StatefulWidget {
  const LiveLocationScreen({super.key});
  @override
  State<LiveLocationScreen> createState() => _LiveLocationScreenState();
}

class _LiveLocationScreenState extends State<LiveLocationScreen> {
  final _db = FirebaseDatabase.instance;
  final MapController _mapCtrl = MapController();
  String _myUid = '', _myName = '', _myPhoto = '';
  bool _sharing = false;
  StreamSubscription<Position>? _posSub;
  Map<String, Map<String, dynamic>> _cousins = {};
  LatLng? _myPos;
  Timer? _cleanupTimer;

  @override
  void initState() {
    super.initState();
    _init();
    _listenCousins();
  }

  Future<void> _init() async {
    _myUid = AuthService().currentUid ?? '';
    final p = await AuthService().getProfile(_myUid);
    if (p != null && mounted) setState(() {
      _myName = p['nickname'] ?? p['name'] ?? 'Cousin';
      _myPhoto = p['photoUrl'] ?? '';
    });
  }

  void _listenCousins() {
    _db.ref('liveLocations').onValue.listen((e) {
      if (!e.snapshot.exists || !mounted) return;
      final map = Map<String, dynamic>.from(e.snapshot.value as Map);
      final now = DateTime.now().millisecondsSinceEpoch;
      final active = <String, Map<String, dynamic>>{};

      map.forEach((uid, val) {
        final data = Map<String, dynamic>.from(val as Map);
        final ts = (data['timestamp'] ?? 0) as int;
        // Only show locations updated in last 5 minutes
        if (now - ts < 5 * 60 * 1000) active[uid] = data;
      });

      if (mounted) setState(() => _cousins = active);

      // Auto-center map to show all cousins
      if (active.isNotEmpty && _myPos == null) {
        final first = active.values.first;
        _mapCtrl.move(
          LatLng((first['lat'] as num).toDouble(), (first['lng'] as num).toDouble()), 14);
      }
    });
  }

  Future<void> _toggleSharing() async {
    if (_sharing) {
      // Stop sharing
      await _posSub?.cancel();
      await _db.ref('liveLocations/$_myUid').remove();
      setState(() { _sharing = false; _myPos = null; });
      return;
    }

    // Request permission
    final perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      final req = await Geolocator.requestPermission();
      if (req == LocationPermission.denied) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission denied')));
        return;
      }
    }

    setState(() => _sharing = true);

    // Start streaming location
    _posSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // update every 10m
      )).listen((pos) async {
      if (!mounted) return;
      final latLng = LatLng(pos.latitude, pos.longitude);
      setState(() => _myPos = latLng);

      await _db.ref('liveLocations/$_myUid').set({
        'lat': pos.latitude,
        'lng': pos.longitude,
        'name': _myName,
        'photo': _myPhoto,
        'accuracy': pos.accuracy,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    });

    // Auto-stop after 2 hours
    _cleanupTimer = Timer(const Duration(hours: 2), () => _toggleSharing());
  }

  List<Marker> _buildMarkers() {
    final markers = <Marker>[];
    _cousins.forEach((uid, data) {
      final lat = (data['lat'] as num).toDouble();
      final lng = (data['lng'] as num).toDouble();
      final name = data['name'] ?? 'Cousin';
      final photo = data['photo'] ?? '';
      final isMe = uid == _myUid;

      markers.add(Marker(
        point: LatLng(lat, lng),
        width: 60,
        height: 70,
        child: GestureDetector(
          onTap: () => _showCousinInfo(data),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: isMe ? AppTheme.mainGradient : null,
                  color: isMe ? null : const Color(0xFF1E88E5),
                  border: Border.all(color: Colors.white, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: photo.isNotEmpty
                    ? ClipOval(
                        child: Image.network(
                          photo,
                          fit: BoxFit.cover,
                        ),
                      )
                    : Center(
                        child: Text(
                          name[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                          ),
                        ),
                      ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isMe ? AppTheme.primary : const Color(0xFF1E88E5),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  isMe ? 'You' : name.split(' ').first,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ));
    });
    return markers;
  }

  void _showCousinInfo(Map<String, dynamic> data) {
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
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: AppTheme.mainGradient,
                shape: BoxShape.circle,
              ),
              child: (data['photo'] ?? '').isNotEmpty
                  ? ClipOval(
                      child: Image.network(
                        data['photo'],
                        fit: BoxFit.cover,
                      ),
                    )
                  : Center(
                      child: Text(
                        name[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 22,
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.ink,
                    ),
                  ),
                  Text(
                    'Updated $ago min ago',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.soft,
                    ),
                  ),
                  Text(
                    'Accuracy: ±${(data['accuracy'] ?? 0).toStringAsFixed(0)}m',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.soft,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _fitAllMarkers() {
    if (_cousins.isEmpty) return;
    final lats = _cousins.values.map((d) => (d['lat'] as num).toDouble()).toList();
    final lngs = _cousins.values.map((d) => (d['lng'] as num).toDouble()).toList();
    final center = LatLng(
      (lats.reduce((a, b) => a + b)) / lats.length,
      (lngs.reduce((a, b) => a + b)) / lngs.length,
    );
    _mapCtrl.move(center, 13);
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _cleanupTimer?.cancel();
    if (_sharing) _db.ref('liveLocations/$_myUid').remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = _cousins.length;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cousin Pro',
              style: TextStyle(fontSize: 12, color: AppTheme.soft),
            ),
            Text(
              'Live Location 📍 ($activeCount online)',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppTheme.ink,
              ),
            ),
          ],
        ),
        actions: [
          if (_cousins.length > 1)
            IconButton(
              icon: const Icon(Icons.fit_screen, color: AppTheme.primary),
              onPressed: _fitAllMarkers,
            ),
        ],
      ),
      body: Stack(
        children: [
          // Map
          FlutterMap(
            mapController: _mapCtrl,
            options: MapOptions(
              initialCenter: _myPos ?? const LatLng(23.8103, 90.4125), // Dhaka
              initialZoom: 13,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.jronex.cousinhub',
              ),
              MarkerLayer(markers: _buildMarkers()),
            ],
          ),

          // Bottom panel
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 12,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Online cousins avatars
                    if (_cousins.isNotEmpty) ...[
                      Row(
                        children: [
                          const Text(
                            'Online now:',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.muted,
                            ),
                          ),
                          const SizedBox(width: 10),
                          ..._cousins.entries.take(6).map((e) {
                            final d = e.value;
                            final photo = d['photo'] ?? '';
                            final name = d['name'] ?? 'Cousin';
                            return Container(
                              width: 34,
                              height: 34,
                              margin: const EdgeInsets.only(right: 6),
                              decoration: BoxDecoration(
                                gradient: AppTheme.mainGradient,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                              child: photo.isNotEmpty
                                  ? ClipOval(
                                      child: Image.network(
                                        photo,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : Center(
                                      child: Text(
                                        name[0].toUpperCase(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                            );
                          }),
                          if (_cousins.length > 6)
                            Text(
                              '+${_cousins.length - 6}',
                              style: const TextStyle(
                                color: AppTheme.muted,
                                fontSize: 13,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Share toggle
                    GestureDetector(
                      onTap: _toggleSharing,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          gradient: _sharing
                              ? const LinearGradient(
                                  colors: [Color(0xFFE53935), Color(0xFFFF5722)],
                                )
                              : AppTheme.mainGradient,
                          borderRadius: BorderRadius.circular(100),
                          boxShadow: [
                            BoxShadow(
                              color: (_sharing ? Colors.red : AppTheme.primary)
                                  .withOpacity(0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _sharing ? Icons.location_off : Icons.my_location,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _sharing ? '🔴 Stop Sharing' : '📍 Share My Location',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    if (_sharing)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Auto-stops after 2 hours • ${_myPos != null ? "GPS active" : "Getting location..."}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.soft,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}