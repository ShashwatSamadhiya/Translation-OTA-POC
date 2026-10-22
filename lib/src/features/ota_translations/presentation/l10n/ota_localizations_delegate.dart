import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../domain/entities/ota_translation_bundle.dart';
import 'ota_app_localizations.dart';

/// Replaces `AppLocalizations.delegate`, so `AppLocalizations.of(context)`
/// keeps working everywhere and transparently returns OTA strings.
class OtaLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const OtaLocalizationsDelegate(this.bundle);

  final OtaTranslationBundle? bundle;

  @override
  bool isSupported(Locale locale) =>
      AppLocalizations.delegate.isSupported(locale);

  /// Synchronous, like the generated delegate, so the first frame never
  /// renders without localizations.
  @override
  Future<AppLocalizations> load(Locale locale) {
    final bundled = lookupAppLocalizations(locale);
    final current = bundle;
    if (current == null || current.languageCode != locale.languageCode) {
      return SynchronousFuture(bundled);
    }
    return SynchronousFuture(
      OtaAppLocalizations(bundled: bundled, messages: current.messages),
    );
  }

  /// A new bundle rebuilds every widget that reads [AppLocalizations].
  @override
  bool shouldReload(OtaLocalizationsDelegate old) => old.bundle != bundle;
}
