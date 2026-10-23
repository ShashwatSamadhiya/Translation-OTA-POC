import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../core/l10n/l10n_key_catalog.dart';
import '../../../../core/l10n/l10n_key_info.dart';
import '../../../../presentation/theme/spacing.dart';
import '../cubit/l10n_editor_cubit.dart';
import '../cubit/l10n_editor_state.dart';
import '../widgets/edit_key_dialog.dart';

enum _Filter {
  missing('No OTA text'),
  changed('Changed from bundled'),
  unpublished('Not published');

  const _Filter(this.label);
  final String label;
}

/// Every catalog key in every language, including keys that never appear on
/// the current screen. Also hosts Import and Publish.
class L10nKeyTablePage extends StatefulWidget {
  const L10nKeyTablePage({super.key});

  @override
  State<L10nKeyTablePage> createState() => _L10nKeyTablePageState();
}

class _L10nKeyTablePageState extends State<L10nKeyTablePage> {
  static final List<String> _languages = [
    for (final locale in AppLocalizations.supportedLocales) locale.languageCode,
  ];

  String _query = '';
  final Set<_Filter> _filters = {};

  bool _matches(L10nKeyInfo key, L10nEditorState state) {
    final drafts = {for (final l in _languages) l: state.effectiveDraft(l)};
    final query = _query.trim().toLowerCase();
    if (query.isNotEmpty &&
        !key.name.toLowerCase().contains(query) &&
        !_languages.any(
          (l) => (drafts[l]![key.name] ?? key.bundled[l] ?? '')
              .toLowerCase()
              .contains(query),
        )) {
      return false;
    }
    final unpublished = state.unpublishedKeys;
    return _filters.every(
      (filter) => _languages.any(
        (l) => switch (filter) {
          _Filter.missing => !drafts[l]!.containsKey(key.name),
          _Filter.changed =>
            drafts[l]![key.name] != null &&
                drafts[l]![key.name] != key.bundled[l],
          _Filter.unpublished => unpublished[l]?.contains(key.name) ?? false,
        },
      ),
    );
  }

  Future<void> _import(L10nEditorCubit cubit) async {
    final missing = cubit.missingFromBundled;
    final count = missing.values.fold(0, (n, m) => n + m.length);
    final messenger = ScaffoldMessenger.of(context);
    if (count == 0) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Every key already has a draft.')),
      );
      return;
    }
    final confirmed = await _confirm(
      title: 'Import bundled ARB?',
      body: [
        Text(
          'Copies $count bundled messages into the drafts, for keys that '
          'have no draft or published text yet.',
        ),
      ],
      action: 'Import',
    );
    if (!confirmed) return;
    if (await cubit.importBundled()) {
      messenger.showSnackBar(
        SnackBar(content: Text('Imported $count messages.')),
      );
    }
  }

  Future<void> _publish(L10nEditorCubit cubit) async {
    final state = cubit.state;
    final theme = Theme.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await _confirm(
      title: 'Publish to all app users?',
      body: [
        for (final MapEntry(key: lang, value: keys)
            in state.unpublishedKeys.entries)
          for (final key in keys)
            Padding(
              padding: const EdgeInsets.only(bottom: Spacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${lang.toUpperCase()} · $key',
                    style: theme.textTheme.labelLarge,
                  ),
                  Text(
                    state.published[lang]?[key] ?? '(bundled)',
                    style: theme.textTheme.bodySmall?.copyWith(
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                  Text(state.effectiveDraft(lang)[key] ?? ''),
                ],
              ),
            ),
      ],
      action: 'Publish',
    );
    if (!confirmed) return;
    if (await cubit.publish()) {
      messenger.showSnackBar(const SnackBar(content: Text('Published.')));
    }
  }

  Future<bool> _confirm({
    required String title,
    required List<Widget> body,
    required String action,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: body,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<L10nEditorCubit>();
    return BlocBuilder<L10nEditorCubit, L10nEditorState>(
      builder: (context, state) {
        final unpublished = state.unpublishedKeys.values.fold(
          0,
          (n, keys) => n + keys.length,
        );
        final keys = [
          for (final key in l10nKeyCatalog)
            if (_matches(key, state)) key,
        ];
        return Scaffold(
          appBar: AppBar(
            title: const Text('Translation keys'),
            actions: [
              IconButton(
                tooltip: 'Import bundled ARB',
                onPressed: state.isBusy ? null : () => _import(cubit),
                icon: const Icon(Icons.download_outlined),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
                child: FilledButton(
                  onPressed: state.isBusy || unpublished == 0
                      ? null
                      : () => _publish(cubit),
                  child: Text('Publish ($unpublished)'),
                ),
              ),
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Spacing.md,
                  Spacing.sm,
                  Spacing.md,
                  0,
                ),
                child: TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search keys and text',
                  ),
                  onChanged: (value) => setState(() => _query = value),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(Spacing.sm),
                child: Wrap(
                  spacing: Spacing.sm,
                  children: [
                    for (final filter in _Filter.values)
                      FilterChip(
                        label: Text(filter.label),
                        selected: _filters.contains(filter),
                        onSelected: (on) => setState(
                          () => on
                              ? _filters.add(filter)
                              : _filters.remove(filter),
                        ),
                      ),
                  ],
                ),
              ),
              if (state.isBusy) const LinearProgressIndicator(),
              Expanded(
                child: ListView.separated(
                  itemCount: keys.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) => _KeyTile(
                    info: keys[index],
                    state: state,
                    languages: _languages,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _KeyTile extends StatelessWidget {
  const _KeyTile({
    required this.info,
    required this.state,
    required this.languages,
  });

  final L10nKeyInfo info;
  final L10nEditorState state;
  final List<String> languages;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unpublished = state.unpublishedKeys;
    return ListTile(
      title: Text(info.name),
      trailing: info.otaEnabled ? null : const Icon(Icons.lock_outline),
      onTap: () => showEditKeyDialog(context, info.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final lang in languages)
            _LanguageLine(
              lang: lang,
              draft: state.effectiveDraft(lang)[info.name],
              bundled: info.bundled[lang],
              isUnpublished: unpublished[lang]?.contains(info.name) ?? false,
              theme: theme,
            ),
        ],
      ),
    );
  }
}

class _LanguageLine extends StatelessWidget {
  const _LanguageLine({
    required this.lang,
    required this.draft,
    required this.bundled,
    required this.isUnpublished,
    required this.theme,
  });

  final String lang;
  final String? draft;
  final String? bundled;
  final bool isUnpublished;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final draft = this.draft;
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '${lang.toUpperCase()}  ',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isUnpublished ? theme.colorScheme.tertiary : null,
            ),
          ),
          if (draft != null)
            TextSpan(text: draft)
          else
            TextSpan(
              text: bundled ?? '(missing)',
              style: TextStyle(
                fontStyle: FontStyle.italic,
                color: theme.colorScheme.outline,
              ),
            ),
          if (isUnpublished) const TextSpan(text: '  •'),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
