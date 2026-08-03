import 'package:flutter/material.dart';

import 'package:ivr_frontend/core/widgets/module_hub_scaffold.dart';
import 'package:ivr_frontend/features/roles/super_admin/presentation/screens/ivr_logs_screen.dart';
import 'package:ivr_frontend/features/roles/super_admin/presentation/screens/voice_calls_screen.dart';

/// Voice & IVR operations.
///
/// "Voice Calls" and "IVR Logs" were two sidebar entries onto two views of the
/// same call. Nobody looks at one without the other.
class IvrOperationsHub extends StatelessWidget {
  final int initialIndex;

  const IvrOperationsHub({super.key, this.initialIndex = 0});

  @override
  Widget build(BuildContext context) {
    return ModuleHubScaffold(
      title: 'Voice & IVR',
      subtitle: 'Recorded citizen calls and the IVR interaction log',
      initialIndex: initialIndex,
      tabs: [
        HubTab(
          icon: Icons.call_rounded,
          label: 'Voice calls',
          builder: (_) => const VoiceCallsScreen(),
        ),
        HubTab(
          icon: Icons.receipt_long_rounded,
          label: 'IVR logs',
          builder: (_) => const IvrLogsScreen(),
        ),
      ],
    );
  }
}
