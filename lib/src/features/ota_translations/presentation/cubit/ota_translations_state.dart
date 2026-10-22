import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/ota_translation_bundle.dart';

enum OtaSource { bundled, cache, network }

class OtaTranslationsState extends Equatable {
  const OtaTranslationsState({
    required this.locale,
    this.bundle,
    this.source = OtaSource.bundled,
    this.isRefreshing = false,
    this.failure,
  });

  final Locale locale;

  /// Null until a cached or fetched bundle exists for [locale].
  final OtaTranslationBundle? bundle;
  final OtaSource source;
  final bool isRefreshing;

  /// Last refresh error. Strings keep using [bundle] or the bundled ARB.
  final Failure? failure;

  OtaTranslationsState copyWith({
    OtaTranslationBundle? bundle,
    OtaSource? source,
    bool? isRefreshing,
    Failure? failure,
    bool clearFailure = false,
  }) {
    return OtaTranslationsState(
      locale: locale,
      bundle: bundle ?? this.bundle,
      source: source ?? this.source,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      failure: clearFailure ? null : failure ?? this.failure,
    );
  }

  @override
  List<Object?> get props => [locale, bundle, source, isRefreshing, failure];
}
