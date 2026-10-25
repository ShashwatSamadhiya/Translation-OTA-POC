import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:l10n_in_context/l10n_in_context.dart';

import '../l10n/app_localizations.dart';
import '../l10n/app_localizations_override.dart';
import 'core/config/env.dart';
import 'features/demo/presentation/pages/ota_demo_page.dart';
import 'features/l10n_editor/data/firebase_l10n_access_data_source.dart';
import 'features/l10n_editor/data/firestore_l10n_translation_data_source.dart';
import 'features/ota_translations/presentation/cubit/ota_translations_cubit.dart';
import 'features/ota_translations/presentation/cubit/ota_translations_state.dart';
import 'features/ota_translations/presentation/widgets/ota_refresh_on_resume.dart';
import 'presentation/theme/app_theme.dart';

class OtaPocApp extends StatelessWidget {
  /// Pass both data sources to turn on in-context editing.
  const OtaPocApp({this.editorAccess, this.editorTranslations, super.key});

  final FirebaseL10nAccessDataSource? editorAccess;
  final FirestoreL10nTranslationDataSource? editorTranslations;

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
          final bundle = state.bundle;
          final delegate = AppLocalizationsOverrideDelegate(
            messages: {
              if (bundle != null) bundle.languageCode: bundle.messages,
            },
          );
          final access = editorAccess;
          final translations = editorTranslations;
          // `Env.l10nEditMode` is a compile-time constant, so builds without
          // it tree-shake the whole editor.
          if (!Env.l10nEditMode || access == null || translations == null) {
            return _materialApp(locale: state.locale, delegate: delegate);
          }
          return InContextEditor(
            delegate: delegate,
            accessDataSource: access,
            translationDataSource: translations,
            label: Env.firebaseProjectId,
            onRequestAccess: (context) => showEmailPasswordSignInDialog(
              context,
              signIn: access.signIn,
              subtitle: 'Firebase project: ${Env.firebaseProjectId}',
            ),
            onSignOut: access.signOut,
            builder: (context, l10n) => _materialApp(
              locale: state.locale,
              delegate: l10n.delegate,
              builder: l10n.overlay,
            ),
          );
        },
      ),
    );
  }

  Widget _materialApp({
    required Locale locale,
    required LocalizationsDelegate<Object?> delegate,
    TransitionBuilder? builder,
  }) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).pocTitle,
      theme: AppTheme.light,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: [
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      builder: builder,
      home: const OtaDemoPage(),
    );
  }
}
