import 'package:equatable/equatable.dart';

sealed class Failure extends Equatable {
  const Failure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

/// Firebase options were not provided via `--dart-define-from-file`.
final class NotConfiguredFailure extends Failure {
  const NotConfiguredFailure(super.message);
}

/// Firestore could not be reached or refused the read.
final class NetworkFailure extends Failure {
  const NetworkFailure(super.message);
}

/// Firestore answered, but the document is not a translations document.
final class InvalidPayloadFailure extends Failure {
  const InvalidPayloadFailure(super.message);
}

/// Nothing usable is cached on the device for the requested language.
final class CacheFailure extends Failure {
  const CacheFailure(super.message);
}
