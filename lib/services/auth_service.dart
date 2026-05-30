import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseDatabase _db = FirebaseDatabase.instance;

  User? get currentUser => _auth.currentUser;
  String? get currentUid => _auth.currentUser?.uid;

  Future<bool> validateInviteCode(String code) async {
    try {
      final ref = _db.ref('inviteCodes/${code.toUpperCase()}');
      final snapshot = await ref.get();
      print('=== INVITE CODE CHECK ===');
      print('Code: ${code.toUpperCase()}');
      print('Exists: ${snapshot.exists}');
      print('Value: ${snapshot.value}');
      if (snapshot.exists) {
        final data = snapshot.value as Map?;
        final active = data?['active'] == true;
        print('Active: $active');
        return active;
      }
      return false;
    } catch (e) {
      print('ERROR in validateInviteCode: $e');
      return false;
    }
  }

  // login() — used by new login_screen.dart
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return {'success': true};
    } on FirebaseAuthException catch (e) {
      String msg = 'Login failed';
      if (e.code == 'user-not-found') msg = 'No account with this email';
      else if (e.code == 'wrong-password' || e.code == 'invalid-credential') msg = 'Wrong email or password';
      return {'success': false, 'error': msg};
    }
  }

  // loginWithEmail() — backward compat for old screens.dart
  Future<Map<String, dynamic>> loginWithEmail({
    required String email,
    required String password,
  }) => login(email: email, password: password);

  // register() — used by new register_screen.dart
  Future<Map<String, dynamic>> register({
    required String inviteCode,
    required String email,
    required String password,
    required String name,
    required String nickname,
    required String relation,
  }) async {
    try {
      final valid = await validateInviteCode(inviteCode);
      if (!valid) return {'success': false, 'error': 'Invalid invite code!'};

      final cred = await _auth.createUserWithEmailAndPassword(
        email: email, password: password);
      final uid = cred.user!.uid;

      await _db.ref('users/$uid').set({
        'name': name,
        'nickname': nickname.isEmpty ? name : nickname,
        'relation': relation,
        'email': email,
        'inviteCode': inviteCode.toUpperCase(),
        'joinedAt': DateTime.now().toIso8601String(),
        'role': 'member',
        'photoUrl': '',
        'birthday': '',
        'gamesWon': 0,
      });

      await cred.user!.updateDisplayName(name);
      return {'success': true};
    } on FirebaseAuthException catch (e) {
      String msg = 'Something went wrong';
      if (e.code == 'email-already-in-use') msg = 'Email already registered!';
      else if (e.code == 'weak-password') msg = 'Password must be at least 6 characters';
      else if (e.code == 'invalid-email') msg = 'Invalid email address';
      return {'success': false, 'error': msg};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // registerWithEmail() — backward compat
  Future<Map<String, dynamic>> registerWithEmail({
    required String inviteCode,
    required String email,
    required String password,
    required String name,
    required String nickname,
    required String relation,
    required String birthday,
  }) => register(
    inviteCode: inviteCode, email: email, password: password,
    name: name, nickname: nickname, relation: relation,
  );

  Future<void> signOut() async => await _auth.signOut();

  Future<Map<String, dynamic>?> getProfile(String uid) async {
    try {
      final snap = await _db.ref('users/$uid').get();
      if (snap.exists) return Map<String, dynamic>.from(snap.value as Map);
      return null;
    } catch (_) { return null; }
  }

  // backward compat
  Future<Map<String, dynamic>?> getUserProfile(String uid) => getProfile(uid);

  Future<void> updateProfile(String uid, Map<String, dynamic> data) async {
    await _db.ref('users/$uid').update(data);
  }
}
