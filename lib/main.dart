import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'l10n/app_localizations.dart';
import 'src/app.dart';
import 'src/core/config/env.dart';
import 'src/features/ota_translations/data/datasources/ota_local_data_source.dart';
import 'src/features/ota_translations/data/datasources/ota_remote_data_source.dart';
import 'src/features/ota_translations/data/repositories/ota_translation_repository_impl.dart';
import 'src/features/ota_translations/presentation/cubit/ota_translations_cubit.dart';

const Duration _cdnTimeout = Duration(seconds: 10);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  // Separate Dio: the CDN is public and must not receive app auth headers.
  final cdnDio = Dio(
    BaseOptions(connectTimeout: _cdnTimeout, receiveTimeout: _cdnTimeout),
  );
  final repository = OtaTranslationRepositoryImpl(
    remote: Env.tolgeeCdnUrl.isEmpty
        ? null
        : OtaRemoteDataSource(dio: cdnDio, baseUrl: Env.tolgeeCdnUrl),
    local: OtaLocalDataSource(prefs),
  );

  final deviceLocale = WidgetsBinding.instance.platformDispatcher.locale;
  final initialLocale = AppLocalizations.supportedLocales.firstWhere(
    (locale) => locale.languageCode == deviceLocale.languageCode,
    orElse: () => AppLocalizations.supportedLocales.first,
  );

  runApp(
    BlocProvider(
      create: (_) => OtaTranslationsCubit(
        repository: repository,
        initialLocale: initialLocale,
      )..load(),
      child: const TolgeePocApp(),
    ),
  );
}
