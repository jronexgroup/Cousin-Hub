import 'package:firebase_database/firebase_database.dart';
import '../screens/badges_screen.dart';

class BadgeService {
  static final _db = FirebaseDatabase.instance;

  static Future<void> incrementStat(String uid, String type) async {
    await _db.ref('userStats/$uid/$type')
        .set(ServerValue.increment(1));
    await checkAndAward(uid);
  }

  static Future<List<String>> checkAndAward(String uid) async {
    final statsSnap = await _db.ref('userStats/$uid').get();
    final stats = statsSnap.exists
        ? Map<String, int>.from(
            (statsSnap.value as Map).map((k, v) => MapEntry(k.toString(), (v as num).toInt())))
        : <String, int>{};

    final badgesSnap = await _db.ref('users/$uid/badges').get();
    final earned = badgesSnap.exists
        ? Set<String>.from((badgesSnap.value as Map).keys)
        : <String>{};

    final newBadges = <String>[];
    for (final badge in kAllBadges) {
      if (earned.contains(badge.id)) continue;
      final stat = stats[badge.type] ?? 0;
      if (stat >= badge.requirement) {
        newBadges.add(badge.id);
        await _db.ref('users/$uid/badges/${badge.id}')
            .set(DateTime.now().millisecondsSinceEpoch);
      }
    }
    return newBadges;
  }

  static Future<void> awardBadge(String uid, String badgeId) async {
    await _db.ref('users/$uid/badges/$badgeId')
        .set(DateTime.now().millisecondsSinceEpoch);
  }

  static Future<void> removeBadge(String uid, String badgeId) async {
    await _db.ref('users/$uid/badges/$badgeId').remove();
  }

  static Future<Map<String, int>> getStats(String uid) async {
    final snap = await _db.ref('userStats/$uid').get();
    if (!snap.exists) return {};
    return Map<String, int>.from(
        (snap.value as Map).map((k, v) => MapEntry(k.toString(), (v as num).toInt())));
  }

  static Future<Set<String>> getEarnedBadges(String uid) async {
    final snap = await _db.ref('users/$uid/badges').get();
    if (!snap.exists) return {};
    return Set<String>.from((snap.value as Map).keys);
  }
}
