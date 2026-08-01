import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ivr_frontend/config/app_theme.dart';
import 'package:ivr_frontend/core/models/tenant_model.dart';
import 'package:ivr_frontend/features/roles/super_admin/bloc/tenant_bloc.dart';

class TenantManagementScreen extends StatefulWidget {
  const TenantManagementScreen({super.key});

  @override
  State<TenantManagementScreen> createState() => _TenantManagementScreenState();
}

class _TenantManagementScreenState extends State<TenantManagementScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    return BlocListener<TenantBloc, TenantState>(
      listener: (context, state) {
        if (state is TenantActionSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message)),
          );
        } else if (state is TenantError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${state.message}'), backgroundColor: Colors.red),
          );
        }
      },
      child: BlocBuilder<TenantBloc, TenantState>(
        builder: (context, state) {
          final tenants = state is TenantLoaded
              ? state.tenants
              : (state is TenantActionSuccess || state is TenantError)
                  ? (context.read<TenantBloc>().state is TenantLoaded
                      ? (context.read<TenantBloc>().state as TenantLoaded).tenants
                      : const <TenantModel>[])
                  : const <TenantModel>[];
          final filtered = _search.isEmpty
              ? tenants
              : tenants
                  .where((t) =>
                      t.name.toLowerCase().contains(_search.toLowerCase()) ||
                      t.id.toLowerCase().contains(_search.toLowerCase()))
                  .toList();
          final isLoading = state is TenantLoading;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Multi-Tenant Administration',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Onboard and manage every client — one panel, many local bodies.',
                          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _showCreateTenantModal(context),
                      icon: const Icon(Icons.add_business_rounded),
                      label: const Text('Provision New Tenant'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    _buildKpiCard(
                      'Total Tenants',
                      '${tenants.length} ${tenants.length == 1 ? 'client' : 'clients'}',
                      Icons.domain_rounded,
                      Colors.blue,
                    ),
                    const SizedBox(width: 16),
                    _buildKpiCard(
                      'Active Tenants',
                      '${tenants.where((t) => t.isActive).length} active',
                      Icons.check_circle_rounded,
                      Colors.green,
                    ),
                    const SizedBox(width: 16),
                    _buildKpiCard(
                      'Total Branch Ceiling',
                      '${tenants.fold<int>(0, (sum, t) => sum + t.maxBranches)} branches',
                      Icons.account_tree_rounded,
                      Colors.purple,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        TextField(
                          onChanged: (v) => setState(() => _search = v),
                          decoration: InputDecoration(
                            hintText: 'Search tenants by name or ID...',
                            prefixIcon: const Icon(Icons.search),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (isLoading)
                          const Padding(
                            padding: EdgeInsets.all(32),
                            child: CircularProgressIndicator(),
                          )
                        else if (filtered.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(32),
                            child: Text(
                              'No tenants yet — provision your first client above.',
                              style: TextStyle(color: AppTheme.textSecondary),
                            ),
                          )
                        else
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              columns: const [
                                DataColumn(label: Text('Tenant ID')),
                                DataColumn(label: Text('Tenant Name')),
                                DataColumn(label: Text('Body Type')),
                                DataColumn(label: Text('Subscription Tier')),
                                DataColumn(label: Text('Max Branches')),
                                DataColumn(label: Text('Status')),
                                DataColumn(label: Text('Actions')),
                              ],
                              rows: filtered.map((t) {
                                return DataRow(
                                  cells: [
                                    DataCell(Text(t.id, style: const TextStyle(fontWeight: FontWeight.bold))),
                                    DataCell(Text(t.name)),
                                    DataCell(Text(t.branchTypeHint ?? '—')),
                                    DataCell(Chip(label: Text(t.subscription))),
                                    DataCell(Text('${t.maxBranches}')),
                                    DataCell(
                                      Chip(
                                        label: Text(t.isActive ? 'Active' : 'Inactive'),
                                        backgroundColor: t.isActive
                                            ? Colors.green.shade100
                                            : Colors.grey.shade200,
                                        labelStyle: TextStyle(
                                          color: t.isActive ? Colors.green.shade800 : Colors.grey.shade700,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      t.isActive
                                          ? IconButton(
                                              icon: const Icon(Icons.block_rounded, color: Colors.red),
                                              tooltip: 'Deactivate',
                                              onPressed: () => context
                                                  .read<TenantBloc>()
                                                  .add(DeactivateTenant(t.id)),
                                            )
                                          : const SizedBox.shrink(),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildKpiCard(String title, String val, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.stroke),
          boxShadow: AppTheme.softShadow,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                const SizedBox(height: 4),
                Text(val, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateTenantModal(BuildContext context) {
    final bloc = context.read<TenantBloc>();
    final slugCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final adminEmailCtrl = TextEditingController();
    String branchType = 'VILLAGE_PANCHAYAT';

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Provision New Tenant'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: slugCtrl,
                  decoration: const InputDecoration(labelText: 'Tenant slug (e.g. madurai-corp)'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Client display name'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: branchType,
                  decoration: const InputDecoration(labelText: 'Local body type'),
                  items: const [
                    DropdownMenuItem(value: 'VILLAGE_PANCHAYAT', child: Text('Village Panchayat')),
                    DropdownMenuItem(value: 'PANCHAYAT_UNION', child: Text('Panchayat Union')),
                    DropdownMenuItem(value: 'DISTRICT_PANCHAYAT', child: Text('District Panchayat')),
                    DropdownMenuItem(value: 'TOWN_PANCHAYAT', child: Text('Town Panchayat')),
                    DropdownMenuItem(value: 'MUNICIPALITY', child: Text('Municipality')),
                    DropdownMenuItem(value: 'MUNICIPAL_CORPORATION', child: Text('Municipal Corporation')),
                  ],
                  onChanged: (v) => setDialogState(() => branchType = v ?? branchType),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: adminEmailCtrl,
                  decoration: const InputDecoration(labelText: 'First admin email'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (slugCtrl.text.trim().isEmpty ||
                    nameCtrl.text.trim().isEmpty ||
                    adminEmailCtrl.text.trim().isEmpty) {
                  return;
                }
                bloc.add(ProvisionTenant({
                  'slug': slugCtrl.text.trim(),
                  'name': nameCtrl.text.trim(),
                  'branch_type': branchType,
                  'admin_email': adminEmailCtrl.text.trim(),
                }));
                Navigator.pop(dialogContext);
              },
              child: const Text('Create Tenant'),
            ),
          ],
        ),
      ),
    );
  }
}
