import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tolgee_poc/src/core/error/failure.dart';
import 'package:tolgee_poc/src/features/ota_translations/domain/entities/ota_translation_bundle.dart';
import 'package:tolgee_poc/src/features/ota_translations/domain/repositories/ota_translation_repository.dart';
import 'package:tolgee_poc/src/features/ota_translations/presentation/cubit/ota_translations_cubit.dart';
import 'package:tolgee_poc/src/features/ota_translations/presentation/cubit/ota_translations_state.dart';

typedef _Result = Either<Failure, OtaTranslationBundle>;

class _FakeRepository implements OtaTranslationRepository {
  final Map<String, _Result> cached = {};
  final Map<String, Future<_Result> Function()> remote = {};

  @override
  Future<_Result> getCached(String languageCode) async =>
      cached[languageCode] ?? const Left(CacheFailure('none'));

  @override
  Future<_Result> fetchLatest(String languageCode) =>
      remote[languageCode]?.call() ??
      Future.value(const Left(NetworkFailure('offline')));
}

OtaTranslationBundle _bundle(String lang, String retry) => OtaTranslationBundle(
  languageCode: lang,
  messages: {'retry': retry},
  fetchedAt: DateTime(2026, 10, 22),
);

void main() {
  const en = Locale('en');
  const hi = Locale('hi');
  late _FakeRepository repository;

  setUp(() => repository = _FakeRepository());

  OtaTranslationsCubit build() =>
      OtaTranslationsCubit(repository: repository, initialLocale: en);

  blocTest<OtaTranslationsCubit, OtaTranslationsState>(
    'emits cache first, then network',
    setUp: () {
      repository.cached['en'] = Right(_bundle('en', 'cached'));
      repository.remote['en'] = () async => Right(_bundle('en', 'fresh'));
    },
    build: build,
    act: (cubit) => cubit.load(),
    expect: () => [
      OtaTranslationsState(
        locale: en,
        bundle: _bundle('en', 'cached'),
        source: OtaSource.cache,
      ),
      OtaTranslationsState(
        locale: en,
        bundle: _bundle('en', 'cached'),
        source: OtaSource.cache,
        isRefreshing: true,
      ),
      OtaTranslationsState(
        locale: en,
        bundle: _bundle('en', 'fresh'),
        source: OtaSource.network,
      ),
    ],
  );

  blocTest<OtaTranslationsCubit, OtaTranslationsState>(
    'keeps the cached bundle when the network fails',
    setUp: () => repository.cached['en'] = Right(_bundle('en', 'cached')),
    build: build,
    act: (cubit) => cubit.load(),
    verify: (cubit) {
      expect(cubit.state.bundle, _bundle('en', 'cached'));
      expect(cubit.state.source, OtaSource.cache);
      expect(cubit.state.failure, const NetworkFailure('offline'));
      expect(cubit.state.isRefreshing, isFalse);
    },
  );

  blocTest<OtaTranslationsCubit, OtaTranslationsState>(
    'stays on bundled strings on first launch offline',
    build: build,
    act: (cubit) => cubit.load(),
    verify: (cubit) {
      expect(cubit.state.bundle, isNull);
      expect(cubit.state.source, OtaSource.bundled);
    },
  );

  test('drops a late response for the previous locale', () async {
    final slowEnglish = Completer<_Result>();
    repository.remote['en'] = () => slowEnglish.future;
    repository.remote['hi'] = () async => Right(_bundle('hi', 'हिंदी'));
    final cubit = build();

    unawaited(cubit.refresh());
    await cubit.changeLocale(hi);
    slowEnglish.complete(Right(_bundle('en', 'late')));
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state.locale, hi);
    expect(cubit.state.bundle, _bundle('hi', 'हिंदी'));
    await cubit.close();
  });

  test('ignores a refresh while one is in flight', () async {
    var calls = 0;
    final pending = Completer<_Result>();
    repository.remote['en'] = () {
      calls++;
      return pending.future;
    };
    final cubit = build();

    unawaited(cubit.refresh());
    unawaited(cubit.refresh());
    pending.complete(Right(_bundle('en', 'fresh')));
    await Future<void>.delayed(Duration.zero);

    expect(calls, 1);
    await cubit.close();
  });
}
