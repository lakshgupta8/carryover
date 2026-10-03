import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../app_config.dart';

/// Thin wrapper over Firebase Auth + Google Sign-In.
class AuthService {
  AuthService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;
  Future<void>? _googleInit;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<void> signInWithEmail(String email, String password) async {
    await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> signUpWithEmail(
    String email,
    String password, {
    String? displayName,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final name = displayName?.trim();
    if (name != null && name.isNotEmpty) {
      await cred.user?.updateDisplayName(name);
    }
  }

  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email: email.trim());

  Future<void> signInWithGoogle() async {
    final google = GoogleSignIn.instance;
    // With google-services.json present the plugin reads the web client ID
    // itself; an explicit value in app_config.dart takes precedence.
    _googleInit ??= google.initialize(
      serverClientId:
          AppConfig.googleConfigured ? AppConfig.googleServerClientId : null,
    );
    await _googleInit;

    final account = await google.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw StateError('Google did not return an ID token.');
    }
    final credential = GoogleAuthProvider.credential(idToken: idToken);
    await _auth.signInWithCredential(credential);
  }

  Future<void> signOut() async {
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // Not signed in with Google, or plugin not initialised. Ignore.
    }
    await _auth.signOut();
  }

  /// Human-friendly message for auth failures.
  static String describe(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'invalid-email':
          return 'That email address does not look right.';
        case 'user-disabled':
          return 'This account has been disabled.';
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          return 'Email or password is incorrect.';
        case 'email-already-in-use':
          return 'An account with this email already exists. Sign in instead.';
        case 'weak-password':
          return 'Please choose a password with at least 6 characters.';
        case 'network-request-failed':
          return 'No connection. Check your network and try again.';
        case 'too-many-requests':
          return 'Too many attempts. Please wait a moment and try again.';
        case 'operation-not-allowed':
          return 'This sign-in method is not enabled in Firebase.';
        default:
          return error.message ?? 'Sign-in failed (${error.code}).';
      }
    }
    if (error is GoogleSignInException) {
      switch (error.code) {
        case GoogleSignInExceptionCode.canceled:
          return 'Google sign-in was cancelled.';
        case GoogleSignInExceptionCode.clientConfigurationError:
          return 'Google sign-in is misconfigured. Check the SHA-1 and the '
              'web client ID.';
        default:
          return error.description ?? 'Google sign-in failed.';
      }
    }
    if (error is StateError) return error.message;
    return 'Something went wrong. Please try again.';
  }
}
