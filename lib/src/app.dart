import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../l10n/app_localizations.dart';
import 'features/demo/presentation/pages/ota_demo_page.dart';
import 'features/ota_translations/presentation/cubit/ota_translations_cubit.dart';
import 'features/ota_translations/presentation/cubit/ota_translations_state.dart';
import 'features/ota_translations/presentation/l10n/ota_localizations_delegate.dart';
import 'features/ota_translations/presentation/widgets/ota_refresh_on_resume.dart';
import 'presentation/theme/app_theme.dart';

class TolgeePocApp extends StatelessWidget {
  const TolgeePocApp({super.key});

  @override
  Widget build(BuildContext context) {
    return OtaRefreshOnResume(
      child: BlocBuilder<OtaTranslationsCubit, OtaTranslationsState>(
        // Only a new locale or bundle changes the delegate; refresh status
        // and failures are rendered inside the page.
        buildWhen: (previous, current) =>
            previous.locale != current.locale ||
            previous.bundle != current.bundle,
        builder: (context, state) => MaterialApp(
          onGenerateTitle: (context) => AppLocalizations.of(context).pocTitle,
          theme: AppTheme.light,
          locale: state.locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: [
            OtaLocalizationsDelegate(state.bundle),
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          home: const OtaDemoPage(),
        ),
      ),
    );
  }
}
