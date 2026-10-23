import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../domain/entities/ota_translation_bundle.dart';
import 'ota_app_localizations.dart';

/// Replaces `AppLocalizations.delegate`, so `AppLocalizations.of(context)`
/// keeps working everywhere and transparently returns OTA strings.
class OtaLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const OtaLocalizationsDelegate(this.bundle, {this.tagKeys = false});

  final OtaTranslationBundle? bundle;

  /// In-context edit mode: every string, bundled ones included, carries an
  /// invisible key tag so it can be picked on screen.
  final bool tagKeys;

  @override
  bool isSupported(Locale locale) =>
      AppLocalizations.delegate.isSupported(locale);

  /// Synchronous, like the generated delegate, so the first frame never
  /// renders without localizations.
  @override
  Future<AppLocalizations> load(Locale locale) {
    final bundled = lookupAppLocalizations(locale);
    final current = bundle;
    final messages = current?.languageCode == locale.languageCode
        ? current!.messages
        : null;
    if (messages == null && !tagKeys) return SynchronousFuture(bundled);
    return SynchronousFuture(
      OtaAppLocalizations(
        bundled: bundled,
        messages: messages ?? const {},
        tagKeys: tagKeys,
      ),
    );
  }

  /// A new bundle rebuilds every widget that reads [AppLocalizations].
  @override
  bool shouldReload(OtaLocalizationsDelegate old) =>
      old.bundle != bundle || old.tagKeys != tagKeys;
}
