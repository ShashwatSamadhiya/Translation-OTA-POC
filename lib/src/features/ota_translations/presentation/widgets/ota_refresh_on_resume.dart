import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cubit/ota_translations_cubit.dart';

/// Re-fetches OTA strings whenever the app returns to the foreground, so a
/// fix published in Tolgee reaches users without a cold start.
class OtaRefreshOnResume extends StatefulWidget {
  const OtaRefreshOnResume({required this.child, super.key});

  final Widget child;

  @override
  State<OtaRefreshOnResume> createState() => _OtaRefreshOnResumeState();
}

class _OtaRefreshOnResumeState extends State<OtaRefreshOnResume> {
  late final AppLifecycleListener _listener;

  @override
  void initState() {
    super.initState();
    _listener = AppLifecycleListener(
      onResume: () => context.read<OtaTranslationsCubit>().refresh(),
    );
  }

  @override
  void dispose() {
    _listener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
