import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../core/l10n/icu_message_formatter.dart';
import '../../../../core/l10n/l10n_key_catalog.dart';
import '../../../../core/l10n/l10n_key_info.dart';
import '../../../../presentation/theme/spacing.dart';
import '../../domain/validate_message.dart';
import '../cubit/l10n_editor_cubit.dart';
import '../cubit/l10n_editor_state.dart';

/// Opens the editor for [key], starting on the language shown on screen.
Future<void> showEditKeyDialog(BuildContext context, String key) {
  final info = l10nKeyCatalog.firstWhere((k) => k.name == key);
  return showDialog<void>(
    context: context,
    builder: (_) => EditKeyDialog(
      info: info,
      initialLanguage: Localizations.localeOf(context).languageCode,
    ),
  );
}

class EditKeyDialog extends StatefulWidget {
  const EditKeyDialog({
    required this.info,
    required this.initialLanguage,
    super.key,
  });

  final L10nKeyInfo info;
  final String initialLanguage;

  @override
  State<EditKeyDialog> createState() => _EditKeyDialogState();
}

class _EditKeyDialogState extends State<EditKeyDialog> {
  static final List<String> _languages = [
    for (final locale in AppLocalizations.supportedLocales) locale.languageCode,
  ];

  late final Map<String, TextEditingController> _controllers;
  late String _language = _languages.contains(widget.initialLanguage)
      ? widget.initialLanguage
      : _languages.first;
  bool _saving = false;
  String? _saveError;

  L10nKeyInfo get _info => widget.info;

  @override
  void initState() {
    super.initState();
    final state = context.read<L10nEditorCubit>().state;
    _controllers = {
      for (final lang in _languages)
        lang: TextEditingController(text: _savedValue(state, lang))
          ..addListener(() => setState(() => _saveError = null)),
    };
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  /// What the app shows editors today: the draft, else the bundled text.
  String _savedValue(L10nEditorState state, String lang) =>
      state.effectiveDraft(lang)[_info.name] ?? _info.bundled[lang] ?? '';

  List<String> _changedLanguages(L10nEditorState state) => [
    for (final lang in _languages)
      if (_controllers[lang]!.text != _savedValue(state, lang)) lang,
  ];

  String? _errorFor(String lang) =>
      validateMessage(_controllers[lang]!.text, _info, locale: lang);

  Future<void> _save(List<String> changed) async {
    setState(() => _saving = true);
    final cubit = context.read<L10nEditorCubit>();
    for (final lang in changed) {
      final error = await cubit.saveDraft(
        languageCode: lang,
        key: _info.name,
        value: _controllers[lang]!.text,
      );
      if (!mounted) return;
      if (error != null) {
        setState(() {
          _saving = false;
          _language = lang;
          _saveError = error;
        });
        return;
      }
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocBuilder<L10nEditorCubit, L10nEditorState>(
      builder: (context, state) {
        final changed = _changedLanguages(state);
        final invalid = changed.where((lang) => _errorFor(lang) != null);
        final controller = _controllers[_language]!;
        final error = _saveError ?? _errorFor(_language);
        final published = state.published[_language]?[_info.name];
        final bundled = _info.bundled[_language];
        return AlertDialog(
          title: SelectableText(_info.name),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_info.description.isNotEmpty)
                    Text(_info.description, style: theme.textTheme.bodySmall),
                  if (_info.placeholders.isNotEmpty) ...[
                    gapSm,
                    Wrap(
                      spacing: Spacing.sm,
                      runSpacing: Spacing.xs,
                      children: [
                        for (final p in _info.placeholders)
                          Chip(
                            visualDensity: VisualDensity.compact,
                            label: Text(
                              '{${p.name}} ${p.type} · e.g. ${p.exampleValue}',
                            ),
                          ),
                      ],
                    ),
                  ],
                  if (!_info.otaEnabled) ...[
                    gapSm,
                    Text(
                      'The app always uses the bundled text for this key, '
                      'so edits here have no effect on screen.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ],
                  gapMd,
                  SegmentedButton<String>(
                    showSelectedIcon: false,
                    segments: [
                      for (final lang in _languages)
                        ButtonSegment(
                          value: lang,
                          label: Text(
                            changed.contains(lang)
                                ? '${lang.toUpperCase()} •'
                                : lang.toUpperCase(),
                          ),
                        ),
                    ],
                    selected: {_language},
                    onSelectionChanged: (selection) => setState(() {
                      _language = selection.first;
                      _saveError = null;
                    }),
                  ),
                  gapMd,
                  TextField(
                    // A new key per language resets the cursor and undo.
                    key: ValueKey(_language),
                    controller: controller,
                    enabled: !_saving,
                    minLines: 1,
                    maxLines: 6,
                    decoration: InputDecoration(
                      labelText: 'Draft (${_language.toUpperCase()})',
                      errorText: error,
                      errorMaxLines: 3,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  if (error == null) ...[
                    gapSm,
                    Text('Preview', style: theme.textTheme.labelLarge),
                    for (final line in _previews(controller.text)) Text(line),
                  ],
                  gapMd,
                  _ReferenceValue(
                    label: 'Published',
                    value: published,
                    onUse: published == null
                        ? null
                        : () => controller.text = published,
                  ),
                  gapSm,
                  _ReferenceValue(
                    label: 'Bundled',
                    value: bundled,
                    onUse: bundled == null
                        ? null
                        : () => controller.text = bundled,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: _saving ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: _saving || changed.isEmpty || invalid.isNotEmpty
                  ? null
                  : () => _save(changed),
              child: Text(
                changed.length > 1
                    ? 'Save ${changed.length} languages'
                    : 'Save draft',
              ),
            ),
          ],
        );
      },
    );
  }

  /// The message rendered with the catalog's example values. Plurals are
  /// shown for several counts so every branch can be checked.
  List<String> _previews(String message) {
    final args = _info.exampleArgs;
    final numeric = _info.placeholders.where((p) => p.isNumeric).firstOrNull;
    final variants = numeric == null || !message.contains('plural')
        ? [args]
        : [
            for (final count in const [0, 1, 2, 5])
              {...args, numeric.name: count},
          ];
    return [
      for (final variant in variants)
        IcuMessageFormatter.format(message, locale: _language, args: variant) ??
            '—',
    ];
  }
}

class _ReferenceValue extends StatelessWidget {
  const _ReferenceValue({
    required this.label,
    required this.value,
    required this.onUse,
  });

  final String label;
  final String? value;
  final VoidCallback? onUse;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.labelMedium),
              SelectableText(
                value ?? '(none)',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
        TextButton(onPressed: onUse, child: const Text('Use')),
      ],
    );
  }
}
