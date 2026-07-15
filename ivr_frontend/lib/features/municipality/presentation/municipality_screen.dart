import 'package:flutter/material.dart';
import '../../../../config/app_theme.dart';
import '../../../../core/api/api_client.dart';

/// Phase 11: Municipality module transactions screen
class MunicipalityScreen extends StatefulWidget {
  const MunicipalityScreen({super.key});

  @override
  State<MunicipalityScreen> createState() => _MunicipalityScreenState();
}

class _MunicipalityScreenState extends State<MunicipalityScreen> {
  static const _modules = [
    _ModuleInfo(key: 'solid_waste_mgmt', label: 'Solid Waste', icon: Icons.delete_outline, color: Color(0xFF6B7280)),
    _ModuleInfo(key: 'drainage_mgmt', label: 'Drainage', icon: Icons.water_damage_outlined, color: Color(0xFF3B82F6)),
    _ModuleInfo(key: 'road_mgmt', label: 'Roads & Potholes', icon: Icons.add_road_outlined, color: Color(0xFFF59E0B)),
    _ModuleInfo(key: 'parks_mgmt', label: 'Parks', icon: Icons.park_outlined, color: Color(0xFF10B981)),
    _ModuleInfo(key: 'public_health', label: 'Public Health', icon: Icons.local_hospital_outlined, color: Color(0xFFEF4444)),
    _ModuleInfo(key: 'building_permit', label: 'Building Permit', icon: Icons.home_work_outlined, color: Color(0xFF8B5CF6)),
    _ModuleInfo(key: 'birth_death_reg', label: 'Birth & Death', icon: Icons.people_outlined, color: Color(0xFFEC4899)),
    _ModuleInfo(key: 'vehicle_fleet_mgmt', label: 'Vehicle Fleet', icon: Icons.local_shipping_outlined, color: Color(0xFF06B6D4)),
    _ModuleInfo(key: 'cemetery_mgmt', label: 'Cemetery', icon: Icons.landscape_outlined, color: Color(0xFF64748B)),
    _ModuleInfo(key: 'encroachment_mgmt', label: 'Encroachment', icon: Icons.do_not_disturb_on_outlined, color: Color(0xFFF97316)),
  ];

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final crossCount = w < 600 ? 2 : (w < 1024 ? 3 : 5);

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const Icon(Icons.account_balance_outlined, color: Colors.white, size: 36),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('Municipality Modules', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        SizedBox(height: 4),
                        Text('Feature-gated department functions', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text('Departments', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textMuted, letterSpacing: 1.0)),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossCount,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.95,
              ),
              itemCount: _modules.length,
              itemBuilder: (context, i) {
                final mod = _modules[i];
                return _ModuleCard(
                  module: mod,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MunicipalityTransactionsScreen(module: mod),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ModuleInfo {
  final String key;
  final String label;
  final IconData icon;
  final Color color;
  const _ModuleInfo({required this.key, required this.label, required this.icon, required this.color});
}

class _ModuleCard extends StatelessWidget {
  final _ModuleInfo module;
  final VoidCallback onTap;
  const _ModuleCard({required this.module, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppTheme.stroke),
          boxShadow: AppTheme.softShadow,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: module.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(module.icon, color: module.color, size: 28),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(module.label,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                  textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}

/// Transactions list for a specific municipality module
class MunicipalityTransactionsScreen extends StatefulWidget {
  final _ModuleInfo module;
  const MunicipalityTransactionsScreen({super.key, required this.module});

  @override
  State<MunicipalityTransactionsScreen> createState() => _MunicipalityTransactionsScreenState();
}

class _MunicipalityTransactionsScreenState extends State<MunicipalityTransactionsScreen> {
  List<dynamic> _records = [];
  bool _isLoading = true;
  String? _error;
  bool _isFeatureLocked = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _isLoading = true; _error = null; _isFeatureLocked = false; });
    try {
      final res = await ApiClient.instance.get('/api/municipality/${widget.module.key}/records');
      setState(() { _records = List<dynamic>.from(res['data'] ?? res ?? []); });
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('403') || msg.toLowerCase().contains('forbidden')) {
        setState(() { _isFeatureLocked = true; });
      } else {
        setState(() { _error = msg; });
      }
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        backgroundColor: AppTheme.bgCard,
        iconTheme: IconThemeData(color: AppTheme.textPrimary),
        title: Row(
          children: [
            Icon(widget.module.icon, color: widget.module.color, size: 20),
            const SizedBox(width: 8),
            Text(widget.module.label, style: TextStyle(color: AppTheme.textPrimary, fontSize: 16)),
          ],
        ),
      ),
      floatingActionButton: _isFeatureLocked ? null : FloatingActionButton.extended(
        onPressed: () => _showSubmitDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('New Record'),
        backgroundColor: widget.module.color,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _isFeatureLocked
              ? _buildLocked()
              : _error != null
                  ? Center(child: Text(_error!, style: TextStyle(color: Colors.red)))
                  : _records.isEmpty
                      ? _buildEmpty()
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _records.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (_, i) => _RecordTile(record: _records[i] as Map<String, dynamic>),
                          ),
                        ),
    );
  }

  Widget _buildLocked() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.lock_outline_rounded, size: 64, color: AppTheme.textMuted),
        const SizedBox(height: 16),
        Text('${widget.module.label} module is not enabled.', style: TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text('Contact your Super Admin to enable this feature for your branch.', style: TextStyle(color: AppTheme.textMuted, fontSize: 13), textAlign: TextAlign.center),
      ],
    ),
  );

  Widget _buildEmpty() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(widget.module.icon, size: 64, color: AppTheme.textMuted),
        const SizedBox(height: 16),
        Text('No records found for ${widget.module.label}.', style: TextStyle(color: AppTheme.textMuted, fontSize: 14)),
      ],
    ),
  );

  void _showSubmitDialog(BuildContext context) {
    final descCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: Row(children: [
          Icon(widget.module.icon, color: widget.module.color, size: 18),
          const SizedBox(width: 8),
          Text('New ${widget.module.label} Record', style: TextStyle(color: AppTheme.textPrimary, fontSize: 15)),
        ]),
        content: TextField(
          controller: descCtrl,
          maxLines: 3,
          style: TextStyle(color: AppTheme.textPrimary),
          decoration: InputDecoration(
            hintText: 'Description / details...',
            hintStyle: TextStyle(color: AppTheme.textMuted),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: widget.module.color),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ApiClient.instance.post('/api/municipality/${widget.module.key}/records', data: {
                  'description': descCtrl.text.trim(),
                  'submitted_at': DateTime.now().toIso8601String(),
                });
                _load();
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }
}

class _RecordTile extends StatelessWidget {
  final Map<String, dynamic> record;
  const _RecordTile({required this.record});

  @override
  Widget build(BuildContext context) {
    final status = record['status']?.toString() ?? 'submitted';
    final statusColors = {'submitted': AppTheme.primary, 'processing': Colors.orange, 'closed': Colors.green};
    final c = statusColors[status] ?? AppTheme.textMuted;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: AppTheme.stroke),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.bgSurface,
          child: Text('#${record['id']}', style: TextStyle(fontSize: 11, color: AppTheme.textMuted, fontWeight: FontWeight.bold)),
        ),
        title: Text(record['entity_type']?.toString().replaceAll('muni_', '').replaceAll('_', ' ').toUpperCase() ?? '—',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
        subtitle: Text(record['submitted_at']?.toString().substring(0, 10) ?? '—',
            style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: c.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
          child: Text(status.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: c)),
        ),
      ),
    );
  }
}
