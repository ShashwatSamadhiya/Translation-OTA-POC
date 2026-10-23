import 'package:equatable/equatable.dart';

import '../../../../core/l10n/l10n_key_catalog.dart';
import '../../data/l10n_editor_data_source.dart';

enum EditorStatus { restoring, signedOut, signingIn, editor }

class L10nEditorState extends Equatable {
  const L10nEditorState({
    this.status = EditorStatus.restoring,
    this.user,
    this.error,
    this.pickMode = false,
    this.highlight = false,
    this.drafts = const {},
    this.published = const {},
    this.isBusy = false,
  });

  final EditorStatus status;

  /// Set while [status] is [EditorStatus.editor].
  final EditorUser? user;

  /// Last error to show once, e.g. a failed sign-in or save.
  final String? error;

  /// Taps select text on screen instead of reaching the app.
  final bool pickMode;

  /// Outlines every tagged string on screen.
  final bool highlight;

  final MessagesByLanguage drafts;
  final MessagesByLanguage published;

  /// A publish or import is being written.
  final bool isBusy;

  bool get isEditor => status == EditorStatus.editor;

  /// What editors see: drafts layered over the published messages, so an
  /// untouched key shows its published text, not the bundled one.
  Map<String, String> effectiveDraft(String languageCode) => {
    ...?published[languageCode],
    ...?drafts[languageCode],
  };

  /// Every `languageCode -> key` whose draft differs from the published text.
  Map<String, List<String>> get unpublishedKeys {
    final languages = {...drafts.keys, ...published.keys};
    return {
      for (final lang in languages)
        if (_unpublishedIn(lang) case final keys when keys.isNotEmpty)
          lang: keys,
    };
  }

  List<String> _unpublishedIn(String lang) {
    final draft = effectiveDraft(lang);
    final live = published[lang] ?? const {};
    return [
      for (final key in l10nKeyCatalog)
        if (draft[key.name] != live[key.name]) key.name,
    ];
  }

  L10nEditorState copyWith({
    EditorStatus? status,
    String? error,
    bool clearError = false,
    bool? pickMode,
    bool? highlight,
    MessagesByLanguage? drafts,
    MessagesByLanguage? published,
    bool? isBusy,
  }) {
    return L10nEditorState(
      status: status ?? this.status,
      user: user,
      error: clearError ? null : error ?? this.error,
      pickMode: pickMode ?? this.pickMode,
      highlight: highlight ?? this.highlight,
      drafts: drafts ?? this.drafts,
      published: published ?? this.published,
      isBusy: isBusy ?? this.isBusy,
    );
  }

  @override
  List<Object?> get props => [
    status,
    user,
    error,
    pickMode,
    highlight,
    drafts,
    published,
    isBusy,
  ];
}
