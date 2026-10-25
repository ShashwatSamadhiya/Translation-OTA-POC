import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:l10n_in_context/l10n_in_context.dart';

import '../../../core/firebase/translations_firestore.dart';

/// Editors are Firebase Auth users with an `editors/{uid}` document, created
/// by hand in the console. A valid password alone never grants edit access.
class FirebaseL10nAccessDataSource implements L10nAccessDataSource {
  const FirebaseL10nAccessDataSource({
    required this._auth,
    required this._firestore,
  });

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  /// Also restores the session of an editor who signed in earlier; on Web
  /// the persisted session arrives asynchronously.
  @override
  Stream<EditorUser?> watchEditor() =>
      _auth.authStateChanges().asyncMap((user) async {
        if (user == null) return null;
        final allowed = await _guard(() => _isEditor(user.uid));
        return allowed
            ? EditorUser(id: user.uid, displayName: user.email ?? '')
            : null;
      });

  /// Signs in with email and password. Returns null on success, or why it
  /// failed. Accounts that aren't editors are signed out again.
  Future<String?> signIn(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = credential.user!;
      if (await _isEditor(user.uid)) return null;
      await _auth.signOut();
      return '${user.email} is not an editor.';
    } on FirebaseException catch (e) {
      return e.message ?? e.code;
    }
  }

  Future<void> signOut() => _auth.signOut();

  Future<bool> _isEditor(String uid) async {
    final doc = await _firestore
        .collection(TranslationsFirestore.editors)
        .doc(uid)
        .get();
    return doc.exists;
  }

  static Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on FirebaseException catch (e) {
      throw L10nDataSourceException(e.message ?? e.code, cause: e);
    }
  }
}
