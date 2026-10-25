import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/repositories/ota_translation_repository.dart';
import 'ota_translations_state.dart';

class OtaTranslationsCubit extends Cubit<OtaTranslationsState> {
  OtaTranslationsCubit({
    required this._repository,
    required Locale initialLocale,
  }) : super(OtaTranslationsState(locale: initialLocale));

  final OtaTranslationRepository _repository;

  /// Shows cached strings immediately, then refreshes from Firestore.
  Future<void> load() async {
    final languageCode = state.locale.languageCode;
    final cached = await _repository.getCached(languageCode);
    if (_isStale(languageCode)) return;
    cached.fold(
      // No cache yet is expected on first launch; the bundled ARB is used.
      (_) {},
      (bundle) => emit(state.copyWith(bundle: bundle, source: OtaSource.cache)),
    );
    await refresh();
  }

  Future<void> changeLocale(Locale locale) async {
    if (locale == state.locale) return;
    emit(OtaTranslationsState(locale: locale));
    await load();
  }

  Future<void> refresh() async {
    if (state.isRefreshing) return;
    final languageCode = state.locale.languageCode;
    emit(state.copyWith(isRefreshing: true, clearFailure: true));
    final result = await _repository.fetchLatest(languageCode);
    if (_isStale(languageCode)) return;
    result.fold(
      (failure) => emit(state.copyWith(isRefreshing: false, failure: failure)),
      (bundle) => emit(
        state.copyWith(
          bundle: bundle,
          source: OtaSource.network,
          isRefreshing: false,
        ),
      ),
    );
  }

  /// True when the cubit closed or the locale changed while awaiting, so a
  /// late response for the old language is dropped.
  bool _isStale(String languageCode) =>
      isClosed || state.locale.languageCode != languageCode;
}
