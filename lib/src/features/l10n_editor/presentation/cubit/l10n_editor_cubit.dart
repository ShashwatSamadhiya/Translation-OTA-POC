import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/l10n/l10n_key_catalog.dart';
import '../../data/l10n_editor_data_source.dart';
import '../../domain/validate_message.dart';
import 'l10n_editor_state.dart';

class L10nEditorCubit extends Cubit<L10nEditorState> {
  L10nEditorCubit(this._dataSource) : super(const L10nEditorState());

  final L10nEditorDataSource _dataSource;
  final List<StreamSubscription<Object?>> _subscriptions = [];

  /// Resumes the session of an editor who signed in earlier.
  Future<void> start() async {
    try {
      final user = await _dataSource.restoreUser();
      if (isClosed) return;
      if (user == null) {
        emit(const L10nEditorState(status: EditorStatus.signedOut));
        return;
      }
      await _enter(user);
    } on FirebaseException catch (e) {
      if (isClosed) return;
      emit(
        L10nEditorState(status: EditorStatus.signedOut, error: _describe(e)),
      );
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    if (state.status == EditorStatus.signingIn) return;
    emit(const L10nEditorState(status: EditorStatus.signingIn));
    try {
      final user = await _dataSource.signIn(
        email: email.trim(),
        password: password,
      );
      await _enter(user);
    } on FirebaseException catch (e) {
      if (isClosed) return;
      emit(
        L10nEditorState(status: EditorStatus.signedOut, error: _describe(e)),
      );
    }
  }

  /// Signed-in users without an `editors/{uid}` document are signed out
  /// again, so a valid password alone never grants edit access.
  Future<void> _enter(EditorUser user) async {
    final allowed = await _dataSource.isEditor(user.uid);
    if (isClosed) return;
    if (!allowed) {
      await _dataSource.signOut();
      if (isClosed) return;
      emit(
        L10nEditorState(
          status: EditorStatus.signedOut,
          error: '${user.email} is not an editor.',
        ),
      );
      return;
    }
    emit(L10nEditorState(status: EditorStatus.editor, user: user));
    _subscriptions
      ..add(
        _dataSource.watchDrafts().listen(
          (drafts) => emit(state.copyWith(drafts: drafts)),
          onError: _onStreamError,
        ),
      )
      ..add(
        _dataSource.watchPublished().listen(
          (published) => emit(state.copyWith(published: published)),
          onError: _onStreamError,
        ),
      );
  }

  Future<void> signOut() async {
    await _cancelSubscriptions();
    await _dataSource.signOut();
    if (isClosed) return;
    emit(const L10nEditorState(status: EditorStatus.signedOut));
  }

  void togglePickMode() => emit(state.copyWith(pickMode: !state.pickMode));

  void setPickMode(bool value) => emit(state.copyWith(pickMode: value));

  void toggleHighlight() => emit(state.copyWith(highlight: !state.highlight));

  void clearError() => emit(state.copyWith(clearError: true));

  /// Saves one draft message. Returns why it failed, or null on success.
  Future<String?> saveDraft({
    required String languageCode,
    required String key,
    required String value,
  }) async {
    final user = state.user;
    if (user == null) return 'Sign in as an editor first.';
    final info = l10nKeyCatalog.where((k) => k.name == key).firstOrNull;
    if (info == null) return 'Unknown key "$key".';
    final invalid = validateMessage(value, info, locale: languageCode);
    if (invalid != null) return invalid;
    try {
      await _dataSource.saveDraft(
        editor: user,
        languageCode: languageCode,
        key: key,
        value: value,
        oldValue: state.effectiveDraft(languageCode)[key],
      );
      return null;
    } on FirebaseException catch (e) {
      return _describe(e);
    }
  }

  /// Bundled messages for every OTA-enabled key that has no draft or
  /// published text yet, per language.
  MessagesByLanguage get missingFromBundled {
    final result = <String, Map<String, String>>{};
    for (final key in l10nKeyCatalog.where((k) => k.otaEnabled)) {
      for (final MapEntry(key: lang, value: message) in key.bundled.entries) {
        if (!state.effectiveDraft(lang).containsKey(key.name)) {
          result.putIfAbsent(lang, () => {})[key.name] = message;
        }
      }
    }
    return result;
  }

  /// Seeds the drafts with [missingFromBundled].
  Future<bool> importBundled() async {
    final user = state.user;
    final missing = missingFromBundled;
    if (user == null || missing.isEmpty) return true;
    return _write(
      () => _dataSource.importDrafts(editor: user, messages: missing),
    );
  }

  /// Copies the drafts of every language with changes to the published
  /// documents, which is what app users read.
  Future<bool> publish() async {
    final user = state.user;
    final unpublished = state.unpublishedKeys;
    if (user == null || unpublished.isEmpty) return true;
    return _write(
      () => _dataSource.publish(
        editor: user,
        messages: {
          for (final lang in unpublished.keys) lang: state.effectiveDraft(lang),
        },
        changedKeys: [
          for (final MapEntry(key: lang, value: keys) in unpublished.entries)
            for (final key in keys) '$lang:$key',
        ],
      ),
    );
  }

  Future<bool> _write(Future<void> Function() write) async {
    if (state.isBusy) return false;
    emit(state.copyWith(isBusy: true, clearError: true));
    try {
      await write();
      if (!isClosed) emit(state.copyWith(isBusy: false));
      return true;
    } on FirebaseException catch (e) {
      if (!isClosed) emit(state.copyWith(isBusy: false, error: _describe(e)));
      return false;
    }
  }

  void _onStreamError(Object error) {
    if (isClosed) return;
    emit(
      state.copyWith(
        error: error is FirebaseException ? _describe(error) : '$error',
      ),
    );
  }

  static String _describe(FirebaseException e) => e.message ?? e.code;

  Future<void> _cancelSubscriptions() async {
    final subscriptions = [..._subscriptions];
    _subscriptions.clear();
    await Future.wait(subscriptions.map((s) => s.cancel()));
  }

  @override
  Future<void> close() async {
    await _cancelSubscriptions();
    return super.close();
  }
}
