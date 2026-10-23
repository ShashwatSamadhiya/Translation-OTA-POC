import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Compile-time configuration from `env/<flavor>.json`.
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
  static const String _firebaseAppIdWeb = String.fromEnvironment(
    'FIREBASE_APP_ID_WEB',
  );
  static const String _firebaseAppIdAndroid = String.fromEnvironment(
    'FIREBASE_APP_ID_ANDROID',
  );
  static const String _firebaseAppIdIos = String.fromEnvironment(
    'FIREBASE_APP_ID_IOS',
  );

  /// Turns on in-context editing. Builds without it compile the editor out.
  static const bool l10nEditMode = bool.fromEnvironment('L10N_EDIT_MODE');

  /// Options for the current platform, or null when the env file does not
  /// configure Firebase for it; the app then runs on bundled ARBs.
  static FirebaseOptions? get firebaseOptions {
    final appId = kIsWeb
        ? _firebaseAppIdWeb
        : switch (defaultTargetPlatform) {
            TargetPlatform.android => _firebaseAppIdAndroid,
            TargetPlatform.iOS => _firebaseAppIdIos,
            _ => '',
          };
    if (_firebaseApiKey.isEmpty || firebaseProjectId.isEmpty || appId.isEmpty) {
      return null;
    }
    return FirebaseOptions(
      apiKey: _firebaseApiKey,
      appId: appId,
      messagingSenderId: _firebaseMessagingSenderId,
      projectId: firebaseProjectId,
      authDomain: '$firebaseProjectId.firebaseapp.com',
      storageBucket: '$firebaseProjectId.firebasestorage.app',
    );
  }
}
