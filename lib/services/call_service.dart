import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';

// Call types
enum CallType { voice, video }

class CallService {
  static final _db = FirebaseDatabase.instance;

  // Initiate a call
  static Future<String> initiateCall({
    required String toUid,
    required String toName,
    required String toPhoto,
    required CallType type,
    required String myName,
    required String myPhoto,
  }) async {
    final myUid = AuthService().currentUid ?? '';
    final callId = 'call_${DateTime.now().millisecondsSinceEpoch}';
    final roomName = 'coushinhub_$callId';

    await _db.ref('calls/$toUid/$callId').set({
      'callId': callId,
      'fromUid': myUid,
      'fromName': myName,
      'fromPhoto': myPhoto,
      'toUid': toUid,
      'type': type == CallType.video ? 'video' : 'voice',
      'status': 'ringing',
      'roomName': roomName,
      'timestamp': ServerValue.timestamp,
    });

    // FCM notification
    final tokenSnap = await _db.ref('users/$toUid/fcmToken').get();
    if (tokenSnap.exists) {
      await _db.ref('notifications').push().set({
        'toToken': tokenSnap.value,
        'title': type == CallType.video ? '📹 Video Call' : '📞 Voice Call',
        'body': '$myName is calling you!',
        'sent': false,
        'timestamp': ServerValue.timestamp,
      });
    }

    return roomName;
  }

  // Accept call
  static Future<void> acceptCall(String fromUid, String callId) async {
    final myUid = AuthService().currentUid ?? '';
    await _db.ref('calls/$myUid/$callId/status').set('accepted');
  }

  // Reject call
  static Future<void> rejectCall(String fromUid, String callId) async {
    final myUid = AuthService().currentUid ?? '';
    await _db.ref('calls/$myUid/$callId/status').set('rejected');
  }

  // End call
  static Future<void> endCall(String toUid, String callId) async {
    await _db.ref('calls/$toUid/$callId/status').set('ended');
  }

  // Listen for incoming calls
  static Stream<Map<String, dynamic>?> listenIncomingCalls() {
    final myUid = AuthService().currentUid ?? '';
    return _db.ref('calls/$myUid').onChildAdded.map((e) {
      if (!e.snapshot.exists) return null;
      final call = Map<String, dynamic>.from(e.snapshot.value as Map);
      call['callId'] = e.snapshot.key;
      return call;
    });
  }
}
