import 'package:flutter/material.dart';
import 'package:ivr_frontend/config/app_theme.dart';
import 'package:ivr_frontend/core/api/api_exceptions.dart';
import 'package:ivr_frontend/core/models/panchayat_model.dart';
import 'package:ivr_frontend/core/widgets/app_error_state.dart';
import 'package:ivr_frontend/core/widgets/app_loading_state.dart';
import 'package:ivr_frontend/features/roles/super_admin/data/super_admin_repository.dart';

/// Which modules a branch has switched on.
///
/// Distinct from role access, and both have to agree for a screen to be
/// usable: this decides whether the branch bought the module at all, while the
/// Roles tab decides which of its staff may open it. A screen granted to a
/// role stays dark if the branch has the module off.
///
/// The keys below are the boolean columns of `BranchFeatureConfig` — adding a
/// module means adding a column there first.
class BranchModulesPane extends StatefulWidget {
  const BranchModulesPane({super.key});

  @override
  State<BranchModulesPane> createState() => _BranchModulesPaneState();
}

class _BranchModulesPaneState extends State<BranchModulesPane> {
  final _repo = SuperAdminRepository();

  bool _loading = true;
  String? _error;
  bool _saving = false;

  List<PanchayatModel> _branches = const [];
  PanchayatModel? _selected;
  Map<String, dynamic> _config = {};

  static const List<({String key, String name, IconData icon, String category})>
      _modules = [
    // Core infrastructure
    (key: 'street_light_mgmt', name: 'Street Light Management', icon: Icons.lightbulb_rounded, category: 'Core Infrastructure'),
    (key: 'water_supply_mgmt', name: 'Water Supply & Pipelines', icon: Icons.water_drop_rounded, category: 'Core Infrastructure'),
    (key: 'complaint_mgmt', name: 'IVR & Citizen Complaints', icon: Icons.report_problem_rounded, category: 'Core Infrastructure'),
    (key: 'zone_management', name: 'GIS Zone Management', icon: Icons.map_rounded, category: 'Core Infrastructure'),

    // Revenue and governance
    (key: 'tender_mgmt', name: 'E-Tendering & Bidding', icon: Icons.assignment_rounded, category: 'Revenue & Governance'),
    (key: 'certificate_mgmt', name: 'Civic Certificates', icon: Icons.task_rounded, category: 'Revenue & Governance'),
    (key: 'market_mgmt', name: 'Weekly Shandy Market Fees', icon: Icons.storefront_rounded, category: 'Revenue & Governance'),
    (key: 'asset_booking', name: 'Community Asset Rental', icon: Icons.domain_rounded, category: 'Revenue & Governance'),
    (key: 'ad_campaign', name: 'Hoarding & Ad Campaigns', icon: Icons.ad_units_rounded, category: 'Revenue & Governance'),
    (key: 'penalty_mgmt', name: 'Technician SLA Penalties', icon: Icons.warning_rounded, category: 'Revenue & Governance'),
    (key: 'ivr_system', name: 'Voice Call IVR Dispatch', icon: Icons.call_rounded, category: 'Revenue & Governance'),

    // Municipality services
    (key: 'parks_mgmt', name: 'Parks & Recreation', icon: Icons.park_rounded, category: 'Municipality Services'),
    (key: 'solid_waste_mgmt', name: 'Solid Waste Management', icon: Icons.delete_sweep_rounded, category: 'Municipality Services'),
    (key: 'drainage_mgmt', name: 'Storm Water & Drainage', icon: Icons.waves_rounded, category: 'Municipality Services'),
    (key: 'road_mgmt', name: 'Roads & Footpaths', icon: Icons.add_road_rounded, category: 'Municipality Services'),
    (key: 'public_health', name: 'Public Health & Sanitation', icon: Icons.health_and_safety_rounded, category: 'Municipality Services'),
    (key: 'building_permit', name: 'Building Plan Permits', icon: Icons.apartment_rounded, category: 'Municipality Services'),
    (key: 'birth_death_reg', name: 'Birth & Death Registry', icon: Icons.badge_rounded, category: 'Municipality Services'),
    (key: 'vehicle_fleet_mgmt', name: 'Municipal Vehicle Fleet', icon: Icons.local_shipping_rounded, category: 'Municipality Services'),
    (key: 'cemetery_mgmt', name: 'Cemetery & Burial Grounds', icon: Icons.nature_people_rounded, category: 'Municipality Services'),
    (key: 'encroachment_mgmt', name: 'Encroachment Eviction', icon: Icons.gavel_rounded, category: 'Municipality Services'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  static String _msg(Object e) => e is ApiException ? e.message : e.toString();

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final branches = await _repo.listPanchayats();
      if (!mounted) return;
      setState(() {
        _branches = branches;
        _selected = branches.isEmpty ? null : branches.first;
        _loading = false;
      });
      if (_selected != null) await _loadConfig(_selected!.id);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _msg(e);
        _loading = false;
      });
    }
  }

  Future<void> _loadConfig(int orgUnitId) async {
    try {
      final cfg = await _repo.getFeatureConfig(orgUnitId);
      if (!mounted) return;
      setState(() => _config = cfg);
    } catch (e) {
      if (!mounted) return;
      setState(() => _config = {});
      _toast('Could not load this branch\'s modules: ${_msg(e)}', isError: true);
    }
  }

  void _toast(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppTheme.error : AppTheme.accent,
      ),
    );
  }

  Future<void> _toggle(String key, bool value) async {
    final branch = _selected;
    if (branch == null) return;

    setState(() {
      _config[key] = value;
      _saving = true;
    });
    try {
      await _repo.updateFeatureConfig(branch.id, {key: value});
      if (!mounted) return;
      setState(() => _saving = false);
    } catch (e) {
      if (!mounted) return;
      // Put the switch back where it was: leaving it showing the value we
      // failed to save would misreport what the branch actually has.
      setState(() {
        _config[key] = !value;
        _saving = false;
      });
      _toast('Could not update that module: ${_msg(e)}', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const AppLoadingState(message: 'Loading branch modules...');
    }
    if (_error != null) {
      return AppErrorState(message: _error!, onRetry: _load);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: DropdownButtonFormField<int>(
            initialValue: _selected?.id,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Branch',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: _branches
                .map((b) => DropdownMenuItem(
                      value: b.id,
                      child: Text(b.name, overflow: TextOverflow.ellipsis),
                    ))
                .toList(),
            onChanged: (id) {
              if (id == null) return;
              final match = _branches.where((b) => b.id == id);
              if (match.isEmpty) return;
              setState(() => _selected = match.first);
              _loadConfig(match.first.id);
            },
          ),
        ),
        if (_saving) const LinearProgressIndicator(minHeight: 2),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Text(
            'Switching a module off hides it for everyone at this branch, '
            'whatever their role allows.',
            style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final cols = constraints.maxWidth > 1100
                  ? 3
                  : (constraints.maxWidth > 700 ? 2 : 1);
              return GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  mainAxisExtent: 78,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: _modules.length,
                itemBuilder: (context, i) => _moduleCard(_modules[i]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _moduleCard(
    ({String key, String name, IconData icon, String category}) mod,
  ) {
    final on = _config[mod.key] == true;
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: on ? AppTheme.primary.withValues(alpha: 0.4) : AppTheme.stroke,
          width: on ? 1.5 : 1,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: on
                ? AppTheme.primary.withValues(alpha: 0.15)
                : AppTheme.stroke.withValues(alpha: 0.5),
            child: Icon(
              mod.icon,
              size: 18,
              color: on ? AppTheme.primary : AppTheme.textMuted,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mod.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                    color: on ? AppTheme.textPrimary : AppTheme.textMuted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  mod.category,
                  style: TextStyle(fontSize: 10.5, color: AppTheme.textMuted),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Switch(
            value: on,
            onChanged: _selected == null ? null : (v) => _toggle(mod.key, v),
          ),
        ],
      ),
    );
  }
}
