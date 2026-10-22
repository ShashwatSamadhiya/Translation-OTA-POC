import 'package:equatable/equatable.dart';

/// Translations for one language delivered over the air, keyed by ARB key.
class OtaTranslationBundle extends Equatable {
  const OtaTranslationBundle({
    required this.languageCode,
    required this.messages,
    required this.fetchedAt,
  });

  final String languageCode;
  final Map<String, String> messages;
  final DateTime fetchedAt;

  @override
  List<Object?> get props => [languageCode, messages, fetchedAt];
}
