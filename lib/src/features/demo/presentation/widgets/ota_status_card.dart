import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../core/error/failure.dart';
import '../../../../presentation/theme/spacing.dart';
import '../../../ota_translations/presentation/cubit/ota_translations_cubit.dart';
import '../../../ota_translations/presentation/cubit/ota_translations_state.dart';

/// Shows where strings currently come from and lets the tester switch
/// language or force a CDN fetch.
class OtaStatusCard extends StatelessWidget {
  const OtaStatusCard({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return BlocBuilder<OtaTranslationsCubit, OtaTranslationsState>(
      builder: (context, state) {
        final cubit = context.read<OtaTranslationsCubit>();
        final bundle = state.bundle;
        final failure = state.failure;
        return Card(
          child: Padding(
            padding: paddingMd,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _sourceLabel(l10n, state.source),
                  style: theme.textTheme.titleMedium,
                ),
                if (bundle != null) ...[
                  gapSm,
                  Text(l10n.pocOverriddenKeys(bundle.messages.length)),
                  Text(
                    DateFormat.yMd(l10n.localeName)
                        .add_Hms()
                        .format(bundle.fetchedAt),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
                if (failure != null) ...[
                  gapSm,
                  Text(
                    failure is NotConfiguredFailure
                        ? l10n.pocCdnNotConfigured
                        : l10n.pocRefreshFailed(failure.message),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],
                gapMd,
                Text(l10n.pocLanguage, style: theme.textTheme.labelLarge),
                gapSm,
                SegmentedButton<Locale>(
                  segments: [
                    for (final locale in AppLocalizations.supportedLocales)
                      ButtonSegment(
                        value: locale,
                        label: Text(locale.languageCode.toUpperCase()),
                      ),
                  ],
                  selected: {state.locale},
                  onSelectionChanged: (selection) =>
                      cubit.changeLocale(selection.first),
                ),
                gapMd,
                FilledButton.icon(
                  onPressed: state.isRefreshing ? null : cubit.refresh,
                  icon: state.isRefreshing
                      ? const SizedBox.square(
                          dimension: Spacing.md,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cloud_download_outlined),
                  label: Text(l10n.pocRefresh),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static String _sourceLabel(AppLocalizations l10n, OtaSource source) =>
      switch (source) {
        OtaSource.bundled => l10n.pocSourceBundled,
        OtaSource.cache => l10n.pocSourceCache,
        OtaSource.network => l10n.pocSourceNetwork,
      };
}
