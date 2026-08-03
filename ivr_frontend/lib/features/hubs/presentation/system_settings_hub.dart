import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:ivr_frontend/core/widgets/module_hub_scaffold.dart';
import 'package:ivr_frontend/features/customization/presentation/screens/admin_customization_screen.dart';
import 'package:ivr_frontend/features/modules/document_templates/presentation/document_templates_settings_screen.dart';
import 'package:ivr_frontend/features/roles/super_admin/bloc/settings_bloc.dart';
import 'package:ivr_frontend/features/roles/super_admin/presentation/screens/ai_settings_screen.dart';
import 'package:ivr_frontend/features/roles/super_admin/presentation/widgets/branch_modules_pane.dart';

/// System settings.
///
/// Branding, document templates, AI providers and module toggles were four
/// separate sidebar entries. They are all "configure the system", which is one
/// destination with four tabs.
class SystemSettingsHub extends StatelessWidget {
  final bool isSuperAdmin;
  final int initialIndex;

  const SystemSettingsHub({
    super.key,
    required this.isSuperAdmin,
    this.initialIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    return ModuleHubScaffold(
      title: 'Settings',
      subtitle: 'Branding, document templates, integrations and module access',
      initialIndex: initialIndex,
      tabs: [
        HubTab(
          icon: Icons.palette_rounded,
          label: 'Branding',
          builder: (_) => const AdminCustomizationScreen(),
        ),
        HubTab(
          icon: Icons.description_outlined,
          label: 'Document templates',
          builder: (_) =>
              DocumentTemplatesSettingsScreen(isSuperAdmin: isSuperAdmin),
        ),
        HubTab(
          icon: Icons.smart_toy_outlined,
          label: 'AI providers',
          builder: (_) => BlocProvider(
            create: (_) => SettingsBloc()..add(LoadProviders()),
            child: const AiSettingsScreen(),
          ),
        ),
        // Provisioning is a super-admin concern; the tab simply is not there
        // for anyone else rather than being present and refusing.
        if (isSuperAdmin)
          HubTab(
            icon: Icons.tune_rounded,
            label: 'Module access',
            builder: (_) => const BranchModulesPane(),
          ),
      ],
    );
  }
}
