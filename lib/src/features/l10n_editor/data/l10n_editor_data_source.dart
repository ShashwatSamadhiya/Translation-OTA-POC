import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/firebase/translations_firestore.dart';

class EditorUser extends Equatable {
  const EditorUser({required this.uid, required this.email});

  final String uid;
  final String email;

  @override
  List<Object?> get props => [uid, email];
}

/// `languageCode -> key -> message`.
typedef MessagesByLanguage = Map<String, Map<String, String>>;

/// Everything the in-context editor reads and writes. Methods throw
/// [FirebaseException] (including [FirebaseAuthException]) on failure.
abstract interface class L10nEditorDataSource {
  /// The user signed in from an earlier session, if any.
  Future<EditorUser?> restoreUser();

  Future<EditorUser> signIn({required String email, required String password});

  Future<void> signOut();

  /// True when an `editors/{uid}` document exists.
  Future<bool> isEditor(String uid);

  /// Live drafts of every language. Only editors may read them.
  Stream<MessagesByLanguage> watchDrafts();

  /// Live published messages of every language.
  Stream<MessagesByLanguage> watchPublished();

  /// Sets one draft message and logs the change, in one batch.
  Future<void> saveDraft({
    required EditorUser editor,
    required String languageCode,
    required String key,
    required String value,
    required String? oldValue,
  });

  /// Adds [messages] to the drafts and logs one `import` entry.
  Future<void> importDrafts({
    required EditorUser editor,
    required MessagesByLanguage messages,
  });

  /// Replaces the published messages of each language in [messages] and logs
  /// one `publish` entry listing [changedKeys] (`lang:key`).
  Future<void> publish({
    required EditorUser editor,
    required MessagesByLanguage messages,
    required List<String> changedKeys,
  });
}

class FirebaseL10nEditorDataSource implements L10nEditorDataSource {
  const FirebaseL10nEditorDataSource({
    required this._auth,
    required this._firestore,
  });

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _drafts =>
      _firestore.collection(TranslationsFirestore.draft);
  CollectionReference<Map<String, dynamic>> get _published =>
      _firestore.collection(TranslationsFirestore.published);
  CollectionReference<Map<String, dynamic>> get _history =>
      _firestore.collection(TranslationsFirestore.history);

  @override
  Future<EditorUser?> restoreUser() async {
    // On Web the persisted session is restored asynchronously, so
    // `currentUser` is still null right after start-up.
    final user = await _auth.authStateChanges().first;
    return user == null ? null : _toEditorUser(user);
  }

  @override
  Future<EditorUser> signIn({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return _toEditorUser(credential.user!);
  }

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<bool> isEditor(String uid) async {
    final doc = await _firestore
        .collection(TranslationsFirestore.editors)
        .doc(uid)
        .get();
    return doc.exists;
  }

  @override
  Stream<MessagesByLanguage> watchDrafts() => _watch(_drafts);

  @override
  Stream<MessagesByLanguage> watchPublished() => _watch(_published);

  Stream<MessagesByLanguage> _watch(
    CollectionReference<Map<String, dynamic>> collection,
  ) => collection.snapshots().map(
    (snapshot) => {
      for (final doc in snapshot.docs) doc.id: parseMessages(doc.data()),
    },
  );

  @override
  Future<void> saveDraft({
    required EditorUser editor,
    required String languageCode,
    required String key,
    required String value,
    required String? oldValue,
  }) {
    final batch = _firestore.batch()
      // Merge so editors working on other keys never overwrite each other.
      ..set(_drafts.doc(languageCode), {
        TranslationsFirestore.messagesField: {key: value},
        ..._stamp('updated', editor),
      }, SetOptions(merge: true))
      ..set(_history.doc(), {
        'type': 'edit',
        'lang': languageCode,
        'key': key,
        'oldValue': oldValue,
        'newValue': value,
        ..._author(editor),
      });
    return batch.commit();
  }

  @override
  Future<void> importDrafts({
    required EditorUser editor,
    required MessagesByLanguage messages,
  }) {
    final batch = _firestore.batch();
    for (final MapEntry(key: lang, value: entries) in messages.entries) {
      batch.set(_drafts.doc(lang), {
        TranslationsFirestore.messagesField: entries,
        ..._stamp('updated', editor),
      }, SetOptions(merge: true));
    }
    batch.set(_history.doc(), {
      'type': 'import',
      'changedKeys': [
        for (final MapEntry(key: lang, value: entries) in messages.entries)
          for (final key in entries.keys) '$lang:$key',
      ],
      ..._author(editor),
    });
    return batch.commit();
  }

  @override
  Future<void> publish({
    required EditorUser editor,
    required MessagesByLanguage messages,
    required List<String> changedKeys,
  }) {
    final batch = _firestore.batch();
    for (final MapEntry(key: lang, value: entries) in messages.entries) {
      batch.set(_published.doc(lang), {
        TranslationsFirestore.messagesField: entries,
        ..._stamp('published', editor),
      });
    }
    batch.set(_history.doc(), {
      'type': 'publish',
      'changedKeys': changedKeys,
      ..._author(editor),
    });
    return batch.commit();
  }

  static Map<String, Object> _stamp(String prefix, EditorUser editor) => {
    '${prefix}At': FieldValue.serverTimestamp(),
    '${prefix}By': editor.uid,
  };

  static Map<String, Object> _author(EditorUser editor) => {
    'editorUid': editor.uid,
    'editorEmail': editor.email,
    'at': FieldValue.serverTimestamp(),
  };

  static EditorUser _toEditorUser(User user) =>
      EditorUser(uid: user.uid, email: user.email ?? '');
}
