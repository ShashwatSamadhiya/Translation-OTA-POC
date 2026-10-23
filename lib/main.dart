import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'l10n/app_localizations.dart';
import 'src/app.dart';
import 'src/core/config/env.dart';
import 'src/features/l10n_editor/data/l10n_editor_data_source.dart';
import 'src/features/l10n_editor/presentation/cubit/l10n_editor_cubit.dart';
import 'src/features/ota_translations/data/datasources/ota_local_data_source.dart';
import 'src/features/ota_translations/data/datasources/ota_remote_data_source.dart';
import 'src/features/ota_translations/data/repositories/ota_translation_repository_impl.dart';
import 'src/features/ota_translations/presentation/cubit/ota_translations_cubit.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  final firebaseOptions = Env.firebaseOptions;
  if (firebaseOptions != null) {
    await Firebase.initializeApp(options: firebaseOptions);
  }
  final firestore = firebaseOptions == null ? null : FirebaseFirestore.instance;

  final repository = OtaTranslationRepositoryImpl(
    remote: firestore == null ? null : FirestoreOtaDataSource(firestore),
    local: OtaLocalDataSource(prefs),
  );

  final deviceLocale = WidgetsBinding.instance.platformDispatcher.locale;
  final initialLocale = AppLocalizations.supportedLocales.firstWhere(
    (locale) => locale.languageCode == deviceLocale.languageCode,
    orElse: () => AppLocalizations.supportedLocales.first,
  );

  // `Env.l10nEditMode` is a compile-time constant, so builds without it
  // tree-shake the whole editor.
  final editMode = Env.l10nEditMode && firestore != null;

  runApp(
    MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => OtaTranslationsCubit(
            repository: repository,
            initialLocale: initialLocale,
          )..load(),
        ),
        if (editMode)
          BlocProvider(
            create: (_) => L10nEditorCubit(
              FirebaseL10nEditorDataSource(
                auth: FirebaseAuth.instance,
                firestore: firestore,
              ),
            )..start(),
          ),
      ],
      child: OtaPocApp(editMode: editMode),
    ),
  );
}
