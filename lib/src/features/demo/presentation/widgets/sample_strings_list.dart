import 'package:flutter/material.dart';
import 'package:l10n_in_context/l10n_in_context.dart';

import '../../../../../l10n/app_localizations.dart';

typedef _Sample = ({String key, String Function(AppLocalizations l10n) read});

/// Sample arguments mirror the ARB `example` values.
final List<_Sample> _samples = [
  (key: 'welcomeTitle', read: (l10n) => l10n.welcomeTitle),
  (key: 'welcomeSubtitle', read: (l10n) => l10n.welcomeSubtitle),
  (key: 'getStarted', read: (l10n) => l10n.getStarted),
  (key: 'chooseLanguage', read: (l10n) => l10n.chooseLanguage),
  (key: 'retry', read: (l10n) => l10n.retry),
  (key: 'resendOtpIn', read: (l10n) => l10n.resendOtpIn('04:59')),
  (key: 'optionalField', read: (l10n) => l10n.optionalField('Pincode')),
  (
    key: 'farmerRegistered',
    read: (l10n) => l10n.farmerRegistered('Ramesh Patil'),
  ),
  (key: 'weatherHumidity', read: (l10n) => l10n.weatherHumidity(72)),
  (key: 'typeToSearchVillage', read: (l10n) => l10n.typeToSearchVillage(3)),
  (
    key: 'launchpadComingSoon',
    read: (l10n) => l10n.launchpadComingSoon('Ponds'),
  ),
  for (final count in [0, 1, 2, 5])
    (key: 'pondCount($count)', read: (l10n) => l10n.pondCount(count)),
];

/// Renders each sample string and tags the ones that differ from the
/// bundled ARB, i.e. the ones actually served over the air.
class SampleStringsList extends StatelessWidget {
  const SampleStringsList({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bundled = lookupAppLocalizations(Localizations.localeOf(context));
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: Column(
        children: [
          for (final sample in _samples)
            ListTile(
              title: Text(sample.read(l10n)),
              subtitle: Text(sample.key),
              // Strip the edit-mode tag so only real text changes count.
              trailing:
                  L10nKeyTag.strip(sample.read(l10n)) == sample.read(bundled)
                  ? null
                  : Icon(Icons.cloud_done_outlined, color: colors.primary),
            ),
        ],
      ),
    );
  }
}
