import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';

class LiveLocationService {
  LiveLocationService._();
  static final LiveLocationService _instance = LiveLocationService._();
  static LiveLocationService get instance => _instance;

  StreamSubscription<Position>? _posSub;
  String _uid = '';
  String _name = '';
  String _photo = '';
  bool _sharing = false;
  Timer? _cleanupTimer;

  bool get isSharing => _sharing;

  final _locationCtrl = StreamController<Position>.broadcast();
  Stream<Position> get locationStream => _locationCtrl.stream;

  void init({required String uid, required String name, required String photo}) {
    _uid = uid;
    _name = name;
    _photo = photo;
  }

  Future<bool> toggle() async {
    if (_sharing) {
      await stop();
      return false;
    }
    return start();
  }

  Future<bool> start() async {
    final perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      final req = await Geolocator.requestPermission();
      if (req == LocationPermission.denied || req == LocationPermission.deniedForever) {
        return false;
      }
    }

    if (!await Geolocator.isLocationServiceEnabled()) {
      return false;
    }

    _sharing = true;
    _posSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      )).listen((pos) {
      _locationCtrl.add(pos);
      FirebaseDatabase.instance.ref('liveLocations/$_uid').set({
        'lat': pos.latitude,
        'lng': pos.longitude,
        'name': _name,
        'photo': _photo,
        'accuracy': pos.accuracy,
        'visibleToAll': true,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    }, onError: (_) {});

    _cleanupTimer = Timer(const Duration(hours: 2), () => stop());
    return true;
  }

  Future<void> stop() async {
    _sharing = false;
    await _posSub?.cancel();
    _posSub = null;
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
    if (_uid.isNotEmpty) {
      await FirebaseDatabase.instance.ref('liveLocations/$_uid').remove();
    }
  }
}
