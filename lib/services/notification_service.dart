import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../services/auth_service.dart';

class NotificationService {
  static final _messaging = FirebaseMessaging.instance;
  static final _local = FlutterLocalNotificationsPlugin();
  static final _db = FirebaseDatabase.instance;

  // Call this once at app start (before login)
  static Future<void> init() async {
    await _messaging.requestPermission(alert: true, badge: true, sound: true);

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _local.initialize(
      const InitializationSettings(android: android),
      onDidReceiveNotificationResponse: (details) {},
    );

    // Foreground messages
    FirebaseMessaging.onMessage.listen((message) {
      _showLocal(
        message.notification?.title ?? 'Cousin Hub',
        message.notification?.body ?? '',
      );
    });

    _messaging.onTokenRefresh.listen((token) async {
      await saveTokenForCurrentUser(token);
    });
  }

  // Call this AFTER login — from home_screen or splash
  static Future<void> saveTokenForCurrentUser([String? token]) async {
    final uid = AuthService().currentUid;
    if (uid == null) return;
    token ??= await _messaging.getToken();
    if (token == null) return;
    await _db.ref('users/$uid/fcmToken').set(token);
    print('✅ FCM Token saved for $uid');
  }

  static Future<void> _showLocal(String title, String body) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'cousin_hub_channel', 'Cousin Hub',
        channelDescription: 'Cousin Hub notifications',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
    );
    await _local.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000, title, body, details);
  }

  static Future<void> sendToUser({
    required String toUid,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      final snap = await _db.ref('users/$toUid/fcmToken').get();
      if (!snap.exists) return;
      final token = snap.value as String;
      final notif = <String, dynamic>{
        'toUid': toUid,
        'toToken': token,
        'title': title,
        'body': body,
        'sent': false,
        'timestamp': ServerValue.timestamp,
      };
      if (data != null) notif['data'] = data;
      await _db.ref('notifications').push().set(notif);
    } catch (e) {
      print('Notification error: $e');
    }
  }

  static Future<void> sendToAll({
    required String title,
    required String body,
    String? fromUid,
    Map<String, dynamic>? data,
  }) async {
    final notif = <String, dynamic>{
      'toAll': true,
      'title': title,
      'body': body,
      'fromUid': fromUid ?? '',
      'sent': false,
      'timestamp': ServerValue.timestamp,
    };
    if (data != null) notif['data'] = data;
    await _db.ref('notifications').push().set(notif);
  }
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('Background message: ${message.notification?.title}');
}
