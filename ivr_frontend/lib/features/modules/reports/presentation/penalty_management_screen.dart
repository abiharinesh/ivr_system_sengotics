import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ivr_frontend/features/auth/bloc/auth_bloc.dart';
import 'package:ivr_frontend/features/auth/bloc/auth_state.dart';
import 'package:ivr_frontend/features/modules/reports/bloc/revenue_blocs.dart';
import 'package:ivr_frontend/features/roles/super_admin/data/super_admin_repository.dart';
import 'package:ivr_frontend/core/models/panchayat_model.dart';
import 'package:ivr_frontend/core/widgets/revenue_skeleton_loader.dart';

class PenaltyManagementScreen extends StatefulWidget {
  const PenaltyManagementScreen({super.key});

  @override
  State<PenaltyManagementScreen> createState() => _PenaltyManagementScreenState();
}

class _PenaltyManagementScreenState extends State<PenaltyManagementScreen> with SingleTickerProviderStateMixin {
  late PenaltyBloc _bloc;
  late TabController _tabController;
  int? _panchayatId;
  bool _isSuperAdmin = false;
  List<PanchayatModel> _panchayats = [];

  @override
  void initState() {
    super.initState();
    _bloc = PenaltyBloc();
    _tabController = TabController(length: 2, vsync: this);
    _initPanchayat();
  }

  void _initPanchayat() async {
    final authState = context.read<AuthBloc>().state;
    if (authState is Authenticated) {
      if (authState.user.isSuperAdmin) {
        _isSuperAdmin = true;
        try {
          final list = await SuperAdminRepository().listPanchayats();
          if (list.isNotEmpty && mounted) {
            setState(() {
              _panchayats = list;
              _panchayatId = list[0].id;
            });
            _bloc.add(LoadPenaltyData(_panchayatId!));
          }
        } catch (e) {
          if (mounted) {
            setState(() {
              _panchayatId = 1;
            });
            _bloc.add(LoadPenaltyData(_panchayatId!));
          }
        }
      } else {
        _panchayatId = authState.user.panchayatId ?? 1;
        _bloc.add(LoadPenaltyData(_panchayatId!));
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _bloc.close();
    super.dispose();
  }

  void _showWaiveDialog(int penaltyId) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Waive Penalty'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
            labelText: 'Reason for Waiver',
            hintText: 'e.g., Weather delay, supply delay',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (_panchayatId != null) {
                _bloc.add(WaivePenaltyEvent(
                  panchayatId: _panchayatId!,
                  penaltyId: penaltyId,
                  reason: reasonController.text.trim(),
                ));
              }
              Navigator.pop(ctx);
            },
            child: const Text('Waive'),
          ),
        ],
      ),
    );
  }

  void _showUpsertRuleDialog() {
    final roleController = TextEditingController(text: 'electrician');
    final urgencyController = TextEditingController(text: 'medium');
    final hoursController = TextEditingController(text: '24');
    final feeController = TextEditingController(text: '100');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Configure SLA Rule'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: 'electrician',
              items: const [
                DropdownMenuItem(value: 'electrician', child: Text('Electrician')),
                DropdownMenuItem(value: 'plumber', child: Text('Plumber')),
              ],
              onChanged: (val) {
                if (val != null) roleController.text = val;
              },
              decoration: const InputDecoration(labelText: 'Role'),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: 'medium',
              items: const [
                DropdownMenuItem(value: 'low', child: Text('Low Urgency')),
                DropdownMenuItem(value: 'medium', child: Text('Medium Urgency')),
                DropdownMenuItem(value: 'high', child: Text('High Urgency')),
                DropdownMenuItem(value: 'critical', child: Text('Critical Urgency')),
              ],
              onChanged: (val) {
                if (val != null) urgencyController.text = val;
              },
              decoration: const InputDecoration(labelText: 'Urgency Level'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: hoursController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Deadline Limit (Hours)'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: feeController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Penalty Fee (₹)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (_panchayatId != null) {
                _bloc.add(UpsertRuleEvent(_panchayatId!, {
                  'panchayat_id': _panchayatId!,
                  'role': roleController.text,
                  'urgency_level': urgencyController.text,
                  'deadline_hours': int.tryParse(hoursController.text) ?? 24,
                  'penalty_amount': double.tryParse(feeController.text) ?? 100.0,
                }));
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save Rule'),
          ),
        ],
      ),
    );
  }

  Widget _buildPanchayatSelector() {
    if (!_isSuperAdmin || _panchayats.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              const Icon(Icons.location_city, color: Colors.blueAccent),
              const SizedBox(width: 8),
              const Text('Active Panchayat: ', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              DropdownButton<int>(
                value: _panchayatId,
                items: _panchayats.map((p) => DropdownMenuItem<int>(
                  value: p.id,
                  child: Text(p.name),
                )).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _panchayatId = val;
                    });
                    _bloc.add(LoadPenaltyData(_panchayatId!));
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Technician Penalties & SLAs'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.warning_amber_rounded), text: 'Penalties Log'),
            Tab(icon: Icon(Icons.settings_outlined), text: 'SLA Configuration'),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildPanchayatSelector(),
          Expanded(
            child: BlocBuilder<PenaltyBloc, RevenueState>(
              bloc: _bloc,
              builder: (context, state) {
                if (state is RevenueLoading) {
                  return Column(
                    children: [
                      RevenueSkeletonLoader.summaryCards(count: 2),
                      Expanded(child: RevenueSkeletonLoader.list()),
                    ],
                  );
                }
                if (state is RevenueError) {
                  return Center(child: Text('Error: ${state.error}'));
                }
                if (state is PenaltyDataLoaded) {
                  return TabBarView(
                    controller: _tabController,
                    children: [
                      _buildPenaltiesTab(state.penalties, state.summary),
                      _buildRulesTab(state.rules),
                    ],
                  );
                }
                return const Center(child: Text('Initial State'));
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPenaltiesTab(List<dynamic> list, Map<String, dynamic> summary) {
    return Column(
      children: [
        // Summary stats cards
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: Card(
                  color: Colors.blue.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Total Penalties', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text('${summary['total_penalties'] ?? 0}', style: const TextStyle(fontSize: 20, color: Colors.blue)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Card(
                  color: Colors.orange.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Pending Collection', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text('₹${summary['pending_amount'] ?? "0.00"}', style: const TextStyle(fontSize: 20, color: Colors.orange)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Penalties Table
        Expanded(
          child: list.isEmpty
              ? const Center(child: Text('No penalties logged.'))
              : ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (ctx, idx) {
                    final item = list[idx];
                    final status = item['status'] as String;
                    final isPending = status == 'pending';
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: ListTile(
                        title: Text('User ID: ${item['user_id']} • Fine: ₹${item['amount']}'),
                        subtitle: Text(
                          'Reason: ${item['reason']}\nDelayed: ${item['hours_delayed'].toStringAsFixed(1)} hours past SLA',
                          style: const TextStyle(fontSize: 12),
                        ),
                        isThreeLine: true,
                        trailing: isPending
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  TextButton(
                                    onPressed: () => _showWaiveDialog(item['id']),
                                    child: const Text('Waive', style: TextStyle(color: Colors.orange)),
                                  ),
                                  ElevatedButton(
                                    onPressed: () {
                                      if (_panchayatId != null) {
                                        _bloc.add(DeductPenaltyEvent(
                                          panchayatId: _panchayatId!,
                                          penaltyId: item['id'],
                                        ));
                                      }
                                    },
                                    child: const Text('Deduct'),
                                  ),
                                ],
                              )
                            : Chip(
                                label: Text(
                                  status.toUpperCase(),
                                  style: TextStyle(
                                    color: status == 'waived' ? Colors.amber.shade900 : Colors.green.shade900,
                                  ),
                                ),
                                backgroundColor: status == 'waived' ? Colors.amber.shade100 : Colors.green.shade100,
                              ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildRulesTab(List<dynamic> list) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'SLA SLA Rules',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              ElevatedButton.icon(
                onPressed: _showUpsertRuleDialog,
                icon: const Icon(Icons.add_to_photos_rounded),
                label: const Text('Configure Rule'),
              ),
            ],
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? const Center(child: Text('No SLA rules configured.'))
              : ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (ctx, idx) {
                    final rule = list[idx];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Icon(rule['role'] == 'plumber' ? Icons.plumbing : Icons.electric_bolt),
                        ),
                        title: Text('${rule['role'].toString().toUpperCase()} — ${rule['urgency_level'].toString().toUpperCase()}'),
                        subtitle: Text('Attending limit: ${rule['deadline_hours']} hours'),
                        trailing: Text(
                          '₹${rule['penalty_amount']}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.redAccent),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
