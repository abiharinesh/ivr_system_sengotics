import 'package:flutter/material.dart';
import '../../../../config/app_theme.dart';
import '../../../../core/widgets/app_loading_state.dart';
import '../../../../core/models/panchayat_model.dart';
import '../../data/super_admin_repository.dart';

class BranchFeatureToggleScreen extends StatefulWidget {
  const BranchFeatureToggleScreen({super.key});

  @override
  State<BranchFeatureToggleScreen> createState() => _BranchFeatureToggleScreenState();
}

class _BranchFeatureToggleScreenState extends State<BranchFeatureToggleScreen> {
  final _repo = SuperAdminRepository();

  bool _isLoading = true;
  String? _error;

  List<PanchayatModel> _panchayats = [];
  PanchayatModel? _selectedPanchayat;

  Map<String, dynamic> _config = {};
  bool _isSaving = false;

  static const List<Map<String, dynamic>> _modules = [
    // Core Services
    {'key': 'street_light_mgmt', 'name': 'Street Light Management', 'icon': Icons.lightbulb_rounded, 'category': 'Core Infrastructure'},
    {'key': 'water_supply_mgmt', 'name': 'Water Supply & Pipelines', 'icon': Icons.water_drop_rounded, 'category': 'Core Infrastructure'},
    {'key': 'complaint_mgmt', 'name': 'IVR & Citizen Complaints', 'icon': Icons.report_problem_rounded, 'category': 'Core Infrastructure'},
    {'key': 'zone_management', 'name': 'GIS Zone Management', 'icon': Icons.map_rounded, 'category': 'Core Infrastructure'},

    // Governance & Revenue
    {'key': 'tender_mgmt', 'name': 'E-Tendering & Bidding', 'icon': Icons.assignment_rounded, 'category': 'Revenue & Governance'},
    {'key': 'certificate_mgmt', 'name': 'Civic Certificates', 'icon': Icons.task_rounded, 'category': 'Revenue & Governance'},
    {'key': 'market_mgmt', 'name': 'Weekly Shandy Market Fees', 'icon': Icons.storefront_rounded, 'category': 'Revenue & Governance'},
    {'key': 'asset_booking', 'name': 'Community Asset Rental', 'icon': Icons.domain_rounded, 'category': 'Revenue & Governance'},
    {'key': 'ad_campaign', 'name': 'Hoarding & Ad Campaigns', 'icon': Icons.ad_units_rounded, 'category': 'Revenue & Governance'},
    {'key': 'penalty_mgmt', 'name': 'Technician SLA Penalties', 'icon': Icons.warning_rounded, 'category': 'Revenue & Governance'},
    {'key': 'ivr_system', 'name': 'Voice Call IVR Dispatch', 'icon': Icons.call_rounded, 'category': 'Revenue & Governance'},

    // Municipality Modules (Locks shown in screenshot!)
    {'key': 'parks_mgmt', 'name': 'Parks & Recreation', 'icon': Icons.park_rounded, 'category': 'Municipality Services'},
    {'key': 'solid_waste_mgmt', 'name': 'Solid Waste Management', 'icon': Icons.delete_sweep_rounded, 'category': 'Municipality Services'},
    {'key': 'drainage_mgmt', 'name': 'Storm Water & Drainage', 'icon': Icons.waves_rounded, 'category': 'Municipality Services'},
    {'key': 'road_mgmt', 'name': 'Roads & Footpaths', 'icon': Icons.add_road_rounded, 'category': 'Municipality Services'},
    {'key': 'public_health', 'name': 'Public Health & Sanitation', 'icon': Icons.health_and_safety_rounded, 'category': 'Municipality Services'},
    {'key': 'building_permit', 'name': 'Building Plan Permits', 'icon': Icons.apartment_rounded, 'category': 'Municipality Services'},
    {'key': 'birth_death_reg', 'name': 'Birth & Death Registry', 'icon': Icons.badge_rounded, 'category': 'Municipality Services'},
    {'key': 'vehicle_fleet_mgmt', 'name': 'Municipal Vehicle Fleet', 'icon': Icons.local_shipping_rounded, 'category': 'Municipality Services'},
    {'key': 'cemetery_mgmt', 'name': 'Cemetery & Burial Grounds', 'icon': Icons.nature_people_rounded, 'category': 'Municipality Services'},
    {'key': 'encroachment_mgmt', 'name': 'Encroachment Eviction', 'icon': Icons.gavel_rounded, 'category': 'Municipality Services'},
  ];

  @override
  void initState() {
    super.initState();
    _loadPanchayats();
  }

  Future<void> _loadPanchayats() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final list = await _repo.listPanchayats();
      setState(() {
        _panchayats = list;
        if (list.isNotEmpty) {
          _selectedPanchayat = list.first;
        }
      });
      if (_selectedPanchayat != null) {
        await _loadConfig(_selectedPanchayat!.id);
      }
    } catch (e) {
      setState(() { _error = e.toString(); });
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  Future<void> _loadConfig(int panchayatId) async {
    try {
      final cfg = await _repo.getFeatureConfig(panchayatId);
      setState(() { _config = cfg; });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load feature configuration: $e'), backgroundColor: AppTheme.error),
      );
    }
  }

  Future<void> _toggleFeature(String key, bool value) async {
    if (_selectedPanchayat == null) return;
    setState(() {
      _config[key] = value;
      _isSaving = true;
    });

    try {
      await _repo.updateFeatureConfig(_selectedPanchayat!.id, {key: value});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Updated ${key.replaceAll('_', ' ')} toggle successfully.'),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      setState(() { _config[key] = !value; });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update toggle: $e'), backgroundColor: AppTheme.error),
      );
    } finally {
      setState(() { _isSaving = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        title: const Text('Branch Feature & Module Toggles'),
        backgroundColor: AppTheme.bgCard,
      ),
      body: _isLoading
          ? const AppLoadingState(message: 'Loading Branch Feature Matrix...')
          : _error != null
              ? Center(child: Text('Error: $_error', style: const TextStyle(color: AppTheme.error)))
              : Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_isSaving) ...[
                        const LinearProgressIndicator(),
                        const SizedBox(height: 12),
                      ],
                      // Branch Selector Top Bar
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(Icons.account_tree_rounded, color: AppTheme.primary),
                              ),
                              const SizedBox(width: 16),
                              const Text('Select Branch / Panchayat:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(width: 20),
                              Expanded(
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<PanchayatModel>(
                                    value: _selectedPanchayat,
                                    isExpanded: true,
                                    items: _panchayats.map((p) => DropdownMenuItem(
                                      value: p,
                                      child: Text(p.name),
                                    )).toList(),
                                    onChanged: (p) {
                                      if (p != null) {
                                        setState(() => _selectedPanchayat = p);
                                        _loadConfig(p.id);
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      const Text('Module Feature Matrix', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      const SizedBox(height: 4),
                      Text('Enable or disable municipal modules for the selected branch. Disabled modules will display a security lock to branch users.',
                          style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                      const SizedBox(height: 16),

                      // Grid of Toggles
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final crossCount = constraints.maxWidth > 1000 ? 3 : (constraints.maxWidth > 650 ? 2 : 1);
                            return GridView.builder(
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossCount,
                                mainAxisExtent: 90,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                              ),
                              itemCount: _modules.length,
                              itemBuilder: (context, index) {
                                final mod = _modules[index];
                                final key = mod['key'] as String;
                                final name = mod['name'] as String;
                                final icon = mod['icon'] as IconData;
                                final category = mod['category'] as String;
                                final isEnabled = _config[key] == true;

                                return Card(
                                  elevation: isEnabled ? 2 : 0,
                                  color: isEnabled ? AppTheme.bgCard : AppTheme.bgCard.withValues(alpha: 0.5),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(
                                      color: isEnabled ? AppTheme.primary.withValues(alpha: 0.4) : AppTheme.stroke,
                                      width: isEnabled ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          backgroundColor: isEnabled ? AppTheme.primary.withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.1),
                                          child: Icon(icon, color: isEnabled ? AppTheme.primary : Colors.grey),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(name, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: isEnabled ? AppTheme.textPrimary : AppTheme.textMuted), overflow: TextOverflow.ellipsis),
                                              const SizedBox(height: 2),
                                              Text(category, style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                                            ],
                                          ),
                                        ),
                                        Switch(
                                          value: isEnabled,
                                          activeTrackColor: AppTheme.primary,
                                          onChanged: (val) => _toggleFeature(key, val),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}
