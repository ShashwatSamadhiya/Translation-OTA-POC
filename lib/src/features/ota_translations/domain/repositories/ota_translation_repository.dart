import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../entities/ota_translation_bundle.dart';

abstract interface class OtaTranslationRepository {
  /// Last bundle stored on the device, available offline.
  Future<Either<Failure, OtaTranslationBundle>> getCached(String languageCode);

  /// Reads the latest published bundle and caches it on success.
  Future<Either<Failure, OtaTranslationBundle>> fetchLatest(
    String languageCode,
  );
}
