import 'package:firebase_core/firebase_core.dart';

/// Compile-time configuration from `env/<platform>.json`.
///
/// Firebase registers one app per platform, each with its own API key and
/// App ID, so every platform has its own env file (see `.vscode/launch.json`).
abstract final class Env {
  static const String _firebaseApiKey = String.fromEnvironment(
    'FIREBASE_API_KEY',
  );
  static const String firebaseProjectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
  );
  static const String _firebaseMessagingSenderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
  );
  static const String _firebaseAppId = String.fromEnvironment(
    'FIREBASE_APP_ID',
  );

  /// Turns on in-context editing. Builds without it compile the editor out.
  static const bool l10nEditMode = bool.fromEnvironment('L10N_EDIT_MODE');

  /// Null when the env file does not configure Firebase; the app then runs
  /// on bundled ARBs.
  static FirebaseOptions? get firebaseOptions {
    if (_firebaseApiKey.isEmpty ||
        firebaseProjectId.isEmpty ||
        _firebaseAppId.isEmpty) {
      return null;
    }
    return const FirebaseOptions(
      apiKey: _firebaseApiKey,
      appId: _firebaseAppId,
      messagingSenderId: _firebaseMessagingSenderId,
      projectId: firebaseProjectId,
      authDomain: '$firebaseProjectId.firebaseapp.com',
      storageBucket: '$firebaseProjectId.firebasestorage.app',
    );
  }
}
