import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tolgee_poc/src/core/l10n/l10n_key_catalog.dart';
import 'package:tolgee_poc/src/features/l10n_editor/data/l10n_editor_data_source.dart';
import 'package:tolgee_poc/src/features/l10n_editor/presentation/cubit/l10n_editor_cubit.dart';
import 'package:tolgee_poc/src/features/l10n_editor/presentation/cubit/l10n_editor_state.dart';

const _editor = EditorUser(uid: 'u1', email: 'editor@example.com');

class _FakeDataSource implements L10nEditorDataSource {
  EditorUser? restored;
  Set<String> editorUids = {'u1'};
  bool signedOut = false;
  final drafts = StreamController<MessagesByLanguage>.broadcast();
  final published = StreamController<MessagesByLanguage>.broadcast();
  final saved = <(String, String, String, String?)>[];
  MessagesByLanguage? imported;
  (MessagesByLanguage, List<String>)? publishedWrite;
  FirebaseException? failWith;

  @override
  Future<EditorUser?> restoreUser() async => restored;

  @override
  Future<EditorUser> signIn({
    required String email,
    required String password,
  }) async {
    if (password != 'secret') {
      throw FirebaseException(plugin: 'auth', message: 'Wrong password');
    }
    return EditorUser(uid: email == _editor.email ? 'u1' : 'u2', email: email);
  }

  @override
  Future<void> signOut() async => signedOut = true;

  @override
  Future<bool> isEditor(String uid) async => editorUids.contains(uid);

  @override
  Stream<MessagesByLanguage> watchDrafts() => drafts.stream;

  @override
  Stream<MessagesByLanguage> watchPublished() => published.stream;

  @override
  Future<void> saveDraft({
    required EditorUser editor,
    required String languageCode,
    required String key,
    required String value,
    required String? oldValue,
  }) async {
    if (failWith case final error?) throw error;
    saved.add((languageCode, key, value, oldValue));
  }

  @override
  Future<void> importDrafts({
    required EditorUser editor,
    required MessagesByLanguage messages,
  }) async => imported = messages;

  @override
  Future<void> publish({
    required EditorUser editor,
    required MessagesByLanguage messages,
    required List<String> changedKeys,
  }) async {
    if (failWith case final error?) throw error;
    publishedWrite = (messages, changedKeys);
  }
}

void main() {
  late _FakeDataSource dataSource;
  late L10nEditorCubit cubit;

  setUp(() {
    dataSource = _FakeDataSource();
    cubit = L10nEditorCubit(dataSource);
  });

  tearDown(() => cubit.close());

  Future<void> signInAsEditor() async {
    await cubit.signIn(email: _editor.email, password: 'secret');
    expect(cubit.state.isEditor, isTrue);
  }

  Future<void> emitDocs({
    MessagesByLanguage drafts = const {},
    MessagesByLanguage published = const {},
  }) async {
    dataSource.drafts.add(drafts);
    dataSource.published.add(published);
    await Future<void>.delayed(Duration.zero);
  }

  group('sign-in', () {
    test('restores an earlier editor session', () async {
      dataSource.restored = _editor;
      await cubit.start();
      expect(cubit.state.status, EditorStatus.editor);
      expect(cubit.state.user, _editor);
    });

    test('starts signed out without a session', () async {
      await cubit.start();
      expect(cubit.state.status, EditorStatus.signedOut);
    });

    test('signs out accounts that are not editors', () async {
      await cubit.signIn(email: 'someone@example.com', password: 'secret');
      expect(cubit.state.status, EditorStatus.signedOut);
      expect(cubit.state.error, contains('not an editor'));
      expect(dataSource.signedOut, isTrue);
    });

    test('reports a failed sign-in', () async {
      await cubit.signIn(email: _editor.email, password: 'wrong');
      expect(cubit.state.status, EditorStatus.signedOut);
      expect(cubit.state.error, 'Wrong password');
    });
  });

  test('drafts overlay published messages', () async {
    await signInAsEditor();
    await emitDocs(
      drafts: {
        'en': {'retry': 'Try again'},
      },
      published: {
        'en': {'retry': 'Retry', 'getStarted': 'Start'},
      },
    );
    expect(cubit.state.effectiveDraft('en'), {
      'retry': 'Try again',
      'getStarted': 'Start',
    });
    expect(cubit.state.unpublishedKeys, {
      'en': ['retry'],
    });
  });

  group('saveDraft', () {
    test('saves a valid message with the previous value', () async {
      await signInAsEditor();
      await emitDocs(
        published: {
          'en': {'retry': 'Retry'},
        },
      );
      final error = await cubit.saveDraft(
        languageCode: 'en',
        key: 'retry',
        value: 'Try again',
      );
      expect(error, isNull);
      expect(dataSource.saved, [('en', 'retry', 'Try again', 'Retry')]);
    });

    test('blocks an invalid message without writing', () async {
      await signInAsEditor();
      final error = await cubit.saveDraft(
        languageCode: 'en',
        key: 'farmerRegistered',
        value: '{nmae} registered',
      );
      expect(error, contains('Unknown placeholder'));
      expect(dataSource.saved, isEmpty);
    });

    test('returns the Firestore error', () async {
      await signInAsEditor();
      dataSource.failWith = FirebaseException(
        plugin: 'firestore',
        message: 'Missing or insufficient permissions.',
      );
      final error = await cubit.saveDraft(
        languageCode: 'en',
        key: 'retry',
        value: 'Again',
      );
      expect(error, 'Missing or insufficient permissions.');
    });
  });

  test('publishes only languages with changes', () async {
    await signInAsEditor();
    await emitDocs(
      drafts: {
        'hi': {'retry': 'फिर से'},
      },
      published: {
        'en': {'retry': 'Retry'},
        'hi': {'getStarted': 'शुरू करें'},
      },
    );
    expect(await cubit.publish(), isTrue);
    final (messages, changedKeys) = dataSource.publishedWrite!;
    expect(messages, {
      'hi': {'getStarted': 'शुरू करें', 'retry': 'फिर से'},
    });
    expect(changedKeys, ['hi:retry']);
  });

  test('a failed publish surfaces the error and clears busy', () async {
    await signInAsEditor();
    await emitDocs(
      drafts: {
        'en': {'retry': 'Again'},
      },
    );
    dataSource.failWith = FirebaseException(plugin: 'firestore', code: 'x');
    expect(await cubit.publish(), isFalse);
    expect(cubit.state.isBusy, isFalse);
    expect(cubit.state.error, 'x');
  });

  test('imports bundled text only for keys without OTA text', () async {
    await signInAsEditor();
    await emitDocs(
      published: {
        'en': {'retry': 'Retry'},
      },
    );
    expect(await cubit.importBundled(), isTrue);
    final imported = dataSource.imported!;
    expect(imported['en']!.containsKey('retry'), isFalse);
    final otaKeys = l10nKeyCatalog.where((k) => k.otaEnabled).length;
    expect(imported['en']!.length, otaKeys - 1);
    expect(imported['hi']!.length, otaKeys);
  });

  test('sign-out stops listening and resets state', () async {
    await signInAsEditor();
    await cubit.signOut();
    expect(cubit.state.status, EditorStatus.signedOut);
    expect(dataSource.drafts.hasListener, isFalse);
  });
}
