import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:uuid/uuid.dart';

import '../data/local/settings_dao.dart';

/// The signed-in identity, independent of which backend produced it.
class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    this.isLocal = false,
  });

  final String id;
  final String email;

  /// True for the offline fallback account — no cloud record exists for it.
  final bool isLocal;
}

class AuthFailure implements Exception {
  const AuthFailure(this.message);
  final String message;

  @override
  String toString() => message;
}

/// FR-01. Two implementations: Firebase, and a device-local fallback for when
/// Firebase has not been configured yet.
abstract interface class AuthService {
  Stream<AppUser?> authStateChanges();
  AppUser? get currentUser;
  Future<AppUser> signIn({required String email, required String password});
  Future<AppUser> signUp({required String email, required String password});
  Future<void> signOut();

  /// Whether records from this session can reach the cloud at all.
  bool get supportsSync;
}

class FirebaseAuthService implements AuthService {
  FirebaseAuthService([fb.FirebaseAuth? auth])
      : _auth = auth ?? fb.FirebaseAuth.instance;

  final fb.FirebaseAuth _auth;

  @override
  bool get supportsSync => true;

  static AppUser? _map(fb.User? user) => user == null
      ? null
      : AppUser(id: user.uid, email: user.email ?? '');

  @override
  Stream<AppUser?> authStateChanges() => _auth.authStateChanges().map(_map);

  @override
  AppUser? get currentUser => _map(_auth.currentUser);

  @override
  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return _map(credential.user)!;
    } on fb.FirebaseAuthException catch (e) {
      throw AuthFailure(_readable(e));
    }
  }

  @override
  Future<AppUser> signUp({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return _map(credential.user)!;
    } on fb.FirebaseAuthException catch (e) {
      throw AuthFailure(_readable(e));
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();

  /// Firebase error codes are not something to show a farmer in a field.
  static String _readable(fb.FirebaseAuthException e) => switch (e.code) {
        'invalid-email' => 'That email address is not valid.',
        'user-disabled' => 'This account has been disabled.',
        'user-not-found' ||
        'wrong-password' ||
        'invalid-credential' =>
          'Email or password is incorrect.',
        'email-already-in-use' => 'An account already exists for that email.',
        'weak-password' => 'Choose a password of at least 6 characters.',
        'network-request-failed' =>
          'No connection. Signing in needs internet the first time.',
        'too-many-requests' => 'Too many attempts. Try again shortly.',
        _ => e.message ?? 'Sign-in failed. Please try again.',
      };
}

/// Device-local account used when Firebase is not configured.
///
/// This exists so the offline half of the product — capture, inference, GPS,
/// local persistence, the map — is usable and demonstrable before any backend
/// exists. It is not a security boundary and it never syncs: [supportsSync] is
/// false, so the sync service leaves its records alone rather than queueing
/// uploads that can never succeed.
///
/// The moment `firebase_options.dart` is generated, [FirebaseAuthService]
/// takes over and this class is out of the picture.
class LocalAuthService implements AuthService {
  LocalAuthService(this._settings);

  final SettingsDao _settings;
  static const _userIdKey = 'local_user_id';
  static const _userEmailKey = 'local_user_email';

  final _controller = StreamController<AppUser?>.broadcast();
  AppUser? _current;

  @override
  bool get supportsSync => false;

  @override
  AppUser? get currentUser => _current;

  @override
  Stream<AppUser?> authStateChanges() async* {
    yield _current ??= await _restore();
    yield* _controller.stream;
  }

  Future<AppUser?> _restore() async {
    final id = await _settings.readString(_userIdKey);
    final email = await _settings.readString(_userEmailKey);
    if (id == null || email == null) return null;
    return AppUser(id: id, email: email, isLocal: true);
  }

  @override
  Future<AppUser> signIn({
    required String email,
    required String password,
  }) =>
      signUp(email: email, password: password);

  @override
  Future<AppUser> signUp({
    required String email,
    required String password,
  }) async {
    final trimmed = email.trim();
    if (trimmed.isEmpty) {
      throw const AuthFailure('Enter an email address to continue.');
    }
    // Reuse the existing id when the same person signs back in, so their
    // history is still theirs.
    final existingId = await _settings.readString(_userIdKey);
    final existingEmail = await _settings.readString(_userEmailKey);
    final id = (existingEmail == trimmed && existingId != null)
        ? existingId
        : const Uuid().v4();

    await _settings.writeString(_userIdKey, id);
    await _settings.writeString(_userEmailKey, trimmed);
    final user = AppUser(id: id, email: trimmed, isLocal: true);
    _current = user;
    _controller.add(user);
    return user;
  }

  @override
  Future<void> signOut() async {
    _current = null;
    _controller.add(null);
  }
}
