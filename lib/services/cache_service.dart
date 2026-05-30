import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/message_model.dart';

class CacheService {
  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ── Messages ──────────────────────────────────────────────────────────────
  static Future<void> saveMessages(String group, List<MessageModel> messages) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    final trimmed = messages.length > 200 ? messages.sublist(messages.length - 200) : messages;
    final json = trimmed.map((m) {
      final map = m.toMap();
      map['id'] = m.id;
      return jsonEncode(map);
    }).toList();
    await prefs.setStringList('chat_$group', json);
    if (messages.isNotEmpty) {
      final last = messages.map((m) => m.timestamp).reduce((a, b) => a > b ? a : b);
      await prefs.setInt('last_ts_$group', last);
    }
  }

  static List<MessageModel> loadMessages(String group) {
    final prefs = _prefs;
    if (prefs == null) return [];
    final json = prefs.getStringList('chat_$group') ?? [];
    return json.map((j) {
      try {
        final map = jsonDecode(j) as Map;
        return MessageModel.fromMap(map['id']?.toString() ?? '', map);
      } catch (_) { return null; }
    }).whereType<MessageModel>().toList();
  }

  static int getLastTimestamp(String group) => _prefs?.getInt('last_ts_$group') ?? 0;

  static Future<void> appendMessages(String group, List<MessageModel> newMsgs) async {
    if (newMsgs.isEmpty) return;
    final existing = loadMessages(group);
    final existingIds = existing.map((m) => m.id).toSet();
    final toAdd = newMsgs.where((m) => !existingIds.contains(m.id)).toList();
    if (toAdd.isEmpty) return;
    final all = [...existing, ...toAdd];
    all.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    await saveMessages(group, all);
  }

  // ── User profiles ─────────────────────────────────────────────────────────
  static Future<void> saveUserProfile(String uid, Map<String, dynamic> data) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    await prefs.setString('user_$uid', jsonEncode(data));
  }

  static Map<String, dynamic>? loadUserProfile(String uid) {
    final json = _prefs?.getString('user_$uid');
    if (json == null) return null;
    return Map<String, dynamic>.from(jsonDecode(json) as Map);
  }

  // ── All users cache ───────────────────────────────────────────────────────
  static Future<void> saveAllUsers(Map<String, dynamic> users) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    await prefs.setString('all_users', jsonEncode(users));
  }

  static Map<String, dynamic>? loadAllUsers() {
    final json = _prefs?.getString('all_users');
    if (json == null) return null;
    return Map<String, dynamic>.from(jsonDecode(json) as Map);
  }

  // ── Photos cache ──────────────────────────────────────────────────────────
  static Future<void> savePhotos(List<Map<String, dynamic>> photos) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    await prefs.setString('photos_cache', jsonEncode(photos));
  }

  static List<Map<String, dynamic>> loadPhotos() {
    final json = _prefs?.getString('photos_cache');
    if (json == null) return [];
    return (jsonDecode(json) as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  // ── Events cache ──────────────────────────────────────────────────────────
  static Future<void> saveEvents(List<Map<String, dynamic>> events) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    await prefs.setString('events_cache', jsonEncode(events));
  }

  static List<Map<String, dynamic>> loadEvents() {
    final json = _prefs?.getString('events_cache');
    if (json == null) return [];
    return (jsonDecode(json) as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  static Future<void> clearAll() async => await _prefs?.clear();
}
