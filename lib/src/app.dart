import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../l10n/app_localizations.dart';
import 'features/demo/presentation/pages/ota_demo_page.dart';
import 'features/l10n_editor/presentation/cubit/l10n_editor_cubit.dart';
import 'features/l10n_editor/presentation/cubit/l10n_editor_state.dart';
import 'features/l10n_editor/presentation/widgets/l10n_edit_overlay.dart';
import 'features/ota_translations/domain/entities/ota_translation_bundle.dart';
import 'features/ota_translations/presentation/cubit/ota_translations_cubit.dart';
import 'features/ota_translations/presentation/cubit/ota_translations_state.dart';
import 'features/ota_translations/presentation/l10n/ota_localizations_delegate.dart';
import 'features/ota_translations/presentation/widgets/ota_refresh_on_resume.dart';
import 'presentation/theme/app_theme.dart';

class OtaPocApp extends StatefulWidget {
  /// [editMode] needs an [L10nEditorCubit] above this widget.
  const OtaPocApp({required this.editMode, super.key});

  final bool editMode;

  @override
  State<OtaPocApp> createState() => _OtaPocAppState();
}

class _OtaPocAppState extends State<OtaPocApp> {
  /// The edit overlay sits above the Navigator and opens dialogs through it.
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return OtaRefreshOnResume(
      child: BlocBuilder<OtaTranslationsCubit, OtaTranslationsState>(
        // Only a new locale or bundle changes the delegate; refresh status
        // and failures are rendered inside the page.
        buildWhen: (previous, current) =>
            previous.locale != current.locale ||
            previous.bundle != current.bundle,
        builder: (context, state) {
          if (!widget.editMode) {
            return _materialApp(locale: state.locale, bundle: state.bundle);
          }
          return BlocBuilder<L10nEditorCubit, L10nEditorState>(
            buildWhen: (previous, current) =>
                previous.isEditor != current.isEditor ||
                previous.drafts != current.drafts ||
                previous.published != current.published,
            builder: (context, editor) {
              final lang = state.locale.languageCode;
              return _materialApp(
                locale: state.locale,
                // Signed-in editors see their drafts live; everyone else
                // sees what is published.
                bundle: editor.isEditor
                    ? OtaTranslationBundle(
                        languageCode: lang,
                        messages: editor.effectiveDraft(lang),
                        fetchedAt: _draftTimestamp,
                      )
                    : state.bundle,
                tagKeys: editor.isEditor,
                builder: (context, child) => L10nEditOverlay(
                  navigatorKey: _navigatorKey,
                  child: child ?? const SizedBox.shrink(),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _materialApp({
    required Locale locale,
    required OtaTranslationBundle? bundle,
    bool tagKeys = false,
    TransitionBuilder? builder,
  }) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      onGenerateTitle: (context) => AppLocalizations.of(context).pocTitle,
      theme: AppTheme.light,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: [
        OtaLocalizationsDelegate(bundle, tagKeys: tagKeys),
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      builder: builder,
      home: const OtaDemoPage(),
    );
  }
}

/// Draft bundles compare by messages only, so the delegate reloads exactly
/// when a draft changes.
final DateTime _draftTimestamp = DateTime.fromMillisecondsSinceEpoch(0);
