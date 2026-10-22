import 'package:equatable/equatable.dart';

sealed class Failure extends Equatable {
  const Failure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

/// The Tolgee CDN URL was not provided via `--dart-define-from-file`.
final class NotConfiguredFailure extends Failure {
  const NotConfiguredFailure(super.message);
}

/// The CDN could not be reached or answered with a non-2xx status.
final class NetworkFailure extends Failure {
  const NetworkFailure(super.message);
}

/// The CDN answered, but the body is not a Tolgee JSON export.
final class InvalidPayloadFailure extends Failure {
  const InvalidPayloadFailure(super.message);
}

/// Nothing usable is cached on the device for the requested language.
final class CacheFailure extends Failure {
  const CacheFailure(super.message);
}
