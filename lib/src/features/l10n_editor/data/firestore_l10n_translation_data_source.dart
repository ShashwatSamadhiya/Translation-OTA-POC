import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:l10n_in_context/l10n_in_context.dart';

import '../../../core/firebase/translations_firestore.dart';

/// Drafts and published messages as one Firestore document per language.
/// Every write also appends to `translation_history`, in the same batch.
class FirestoreL10nTranslationDataSource implements L10nTranslationDataSource {
  const FirestoreL10nTranslationDataSource(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _drafts =>
      _firestore.collection(TranslationsFirestore.draft);
  CollectionReference<Map<String, dynamic>> get _published =>
      _firestore.collection(TranslationsFirestore.published);
  CollectionReference<Map<String, dynamic>> get _history =>
      _firestore.collection(TranslationsFirestore.history);

  @override
  Stream<MessagesByLanguage> watchDrafts() => _watch(_drafts);

  @override
  Stream<MessagesByLanguage> watchPublished() => _watch(_published);

  Stream<MessagesByLanguage> _watch(
    CollectionReference<Map<String, dynamic>> collection,
  ) => collection
      .snapshots()
      .map(
        (snapshot) => {
          for (final doc in snapshot.docs) doc.id: parseMessages(doc.data()),
        },
      )
      .transform(
        StreamTransformer.fromHandlers(
          handleError: (error, stackTrace, sink) => sink.addError(
            error is FirebaseException ? _toException(error) : error,
            stackTrace,
          ),
        ),
      );

  @override
  Future<void> saveDraft({
    required EditorUser editor,
    required String languageCode,
    required String key,
    required String value,
    String? previousValue,
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
        'oldValue': previousValue,
        'newValue': value,
        ..._author(editor),
      });
    return _commit(batch);
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
    return _commit(batch);
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
    return _commit(batch);
  }

  static Future<void> _commit(WriteBatch batch) async {
    try {
      await batch.commit();
    } on FirebaseException catch (e) {
      throw _toException(e);
    }
  }

  static L10nDataSourceException _toException(FirebaseException e) =>
      L10nDataSourceException(e.message ?? e.code, cause: e);

  static Map<String, Object> _stamp(String prefix, EditorUser editor) => {
    '${prefix}At': FieldValue.serverTimestamp(),
    '${prefix}By': editor.id,
  };

  static Map<String, Object> _author(EditorUser editor) => {
    'editorUid': editor.id,
    'editorEmail': editor.displayName ?? '',
    'at': FieldValue.serverTimestamp(),
  };
}
