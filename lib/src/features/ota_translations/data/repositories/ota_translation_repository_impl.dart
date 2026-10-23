import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/ota_translation_bundle.dart';
import '../../domain/repositories/ota_translation_repository.dart';
import '../datasources/ota_local_data_source.dart';
import '../datasources/ota_remote_data_source.dart';

class OtaTranslationRepositoryImpl implements OtaTranslationRepository {
  const OtaTranslationRepositoryImpl({
    required this._remote,
    required this._local,
    this._now = DateTime.now,
  });

  /// Null when Firebase is not configured; the app then runs on bundled ARBs.
  final OtaRemoteDataSource? _remote;
  final OtaLocalDataSource _local;
  final DateTime Function() _now;

  @override
  Future<Either<Failure, OtaTranslationBundle>> getCached(
    String languageCode,
  ) async {
    final bundle = await _local.read(languageCode);
    return bundle == null
        ? Left(CacheFailure('No cached translations for $languageCode'))
        : Right(bundle);
  }

  @override
  Future<Either<Failure, OtaTranslationBundle>> fetchLatest(
    String languageCode,
  ) async {
    final remote = _remote;
    if (remote == null) {
      return const Left(NotConfiguredFailure('Firebase options are not set'));
    }
    final Map<String, String> messages;
    try {
      messages = await remote.fetch(languageCode);
    } on FirebaseException catch (e) {
      return Left(NetworkFailure(e.message ?? e.code));
    } on TimeoutException {
      return const Left(NetworkFailure('Firestore did not answer in time'));
    } on FormatException catch (e) {
      return Left(InvalidPayloadFailure(e.message));
    }
    final bundle = OtaTranslationBundle(
      languageCode: languageCode,
      messages: messages,
      fetchedAt: _now(),
    );
    // A failed cache write must not hide fresh strings from this session.
    try {
      await _local.write(bundle);
    } on Object {
      // Next launch falls back to the previous cache or the bundled ARB.
    }
    return Right(bundle);
  }
}
