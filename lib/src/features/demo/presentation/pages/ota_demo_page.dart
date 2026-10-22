import 'package:flutter/material.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../presentation/theme/spacing.dart';
import '../widgets/ota_status_card.dart';
import '../widgets/sample_strings_list.dart';

class OtaDemoPage extends StatelessWidget {
  const OtaDemoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).pocTitle)),
      body: ListView(
        padding: paddingMd,
        children: const [OtaStatusCard(), gapMd, SampleStringsList()],
      ),
    );
  }
}
