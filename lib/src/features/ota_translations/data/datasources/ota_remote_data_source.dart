import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/firebase/translations_firestore.dart';

abstract interface class OtaRemoteDataSource {
  /// Published `key -> message` for [languageCode].
  ///
  /// Throws [FirebaseException] or [TimeoutException] when the messages
  /// can't be read, and [FormatException] when the document is malformed.
  Future<Map<String, String>> fetch(String languageCode);
}

/// Reads `translations_published/{lang}` once per call. App users don't keep
/// a listener open: every change would cost one read per connected client.
class FirestoreOtaDataSource implements OtaRemoteDataSource {
  const FirestoreOtaDataSource(this._firestore);

  final FirebaseFirestore _firestore;

  static const Duration _timeout = Duration(seconds: 10);

  @override
  Future<Map<String, String>> fetch(String languageCode) async {
    final snapshot = await _firestore
        .collection(TranslationsFirestore.published)
        .doc(languageCode)
        .get()
        .timeout(_timeout);
    return parseMessages(snapshot.data());
  }
}
