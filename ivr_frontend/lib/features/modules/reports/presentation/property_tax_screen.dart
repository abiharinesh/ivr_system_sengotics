import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ivr_frontend/features/auth/bloc/auth_bloc.dart';
import 'package:ivr_frontend/features/auth/bloc/auth_state.dart';
import 'package:ivr_frontend/features/modules/reports/bloc/revenue_blocs.dart';
import 'package:ivr_frontend/features/roles/super_admin/data/super_admin_repository.dart';
import 'package:ivr_frontend/core/models/panchayat_model.dart';
import 'package:ivr_frontend/core/widgets/revenue_skeleton_loader.dart';

class PropertyTaxScreen extends StatefulWidget {
  const PropertyTaxScreen({super.key});

  @override
  State<PropertyTaxScreen> createState() => _PropertyTaxScreenState();
}

class _PropertyTaxScreenState extends State<PropertyTaxScreen> with SingleTickerProviderStateMixin {
  late PropertyTaxBloc _bloc;
  late TabController _tabController;
  int? _panchayatId;
  String _selectedYear = '2025-26';
  bool _isSuperAdmin = false;
  List<PanchayatModel> _panchayats = [];

  @override
  void initState() {
    super.initState();
    _bloc = PropertyTaxBloc();
    _tabController = TabController(length: 3, vsync: this);
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
            _bloc.add(LoadPropertyTaxData(_panchayatId!, financialYear: _selectedYear));
          }
        } catch (e) {
          if (mounted) {
            setState(() {
              _panchayatId = 1;
            });
            _bloc.add(LoadPropertyTaxData(_panchayatId!, financialYear: _selectedYear));
          }
        }
      } else {
        _panchayatId = authState.user.panchayatId ?? 1;
        _bloc.add(LoadPropertyTaxData(_panchayatId!, financialYear: _selectedYear));
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _bloc.close();
    super.dispose();
  }

  void _showAddPropertyDialog() {
    final ownerController = TextEditingController();
    final phoneController = TextEditingController();
    final doorController = TextEditingController();
    final addressController = TextEditingController();
    final areaController = TextEditingController();
    final taxController = TextEditingController();
    String propertyType = 'residential';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Register Property'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ownerController,
                decoration: const InputDecoration(labelText: 'Owner Name'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: 'Owner Phone Number'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: doorController,
                decoration: const InputDecoration(labelText: 'Door Number'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: addressController,
                decoration: const InputDecoration(labelText: 'Address'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: 'residential',
                items: const [
                  DropdownMenuItem(value: 'residential', child: Text('Residential')),
                  DropdownMenuItem(value: 'commercial', child: Text('Commercial')),
                  DropdownMenuItem(value: 'vacant_land', child: Text('Vacant Land')),
                  DropdownMenuItem(value: 'industrial', child: Text('Industrial')),
                ],
                onChanged: (val) {
                  if (val != null) propertyType = val;
                },
                decoration: const InputDecoration(labelText: 'Property Type'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: areaController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Plot Area (Sq.Ft)'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: taxController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Annual Tax Surcharge (₹)'),
              ),
            ],
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
                _bloc.add(CreatePropertyEvent(_panchayatId!, {
                  'panchayat_id': _panchayatId!,
                  'owner_name': ownerController.text.trim(),
                  'owner_phone': phoneController.text.trim(),
                  'door_number': doorController.text.trim(),
                  'address': addressController.text.trim(),
                  'property_type': propertyType,
                  'area_sqft': double.tryParse(areaController.text) ?? 1000.0,
                  'annual_tax': double.tryParse(taxController.text) ?? 500.0,
                }));
              }
              Navigator.pop(ctx);
            },
            child: const Text('Register'),
          ),
        ],
      ),
    );
  }

  void _showGenerateDemandsDialog() {
    final yearController = TextEditingController(text: '2025-26');
    final dateController = TextEditingController(text: DateTime.now().add(const Duration(days: 30)).toIso8601String().split('T')[0]);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Generate Annual Tax Demands'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: yearController,
              decoration: const InputDecoration(labelText: 'Financial Year'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: dateController,
              decoration: const InputDecoration(labelText: 'Due Date (YYYY-MM-DD)'),
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
                _bloc.add(GenerateDemandsEvent(
                  panchayatId: _panchayatId!,
                  financialYear: yearController.text.trim(),
                  dueDate: dateController.text.trim(),
                ));
              }
              Navigator.pop(ctx);
            },
            child: const Text('Generate'),
          ),
        ],
      ),
    );
  }

  void _showRecordPaymentDialog(int paymentId) {
    final amountController = TextEditingController();
    final refController = TextEditingController();
    String method = 'upi';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Record Tax Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Paid Amount (₹)'),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: 'upi',
              items: const [
                DropdownMenuItem(value: 'upi', child: Text('UPI / Scan QR')),
                DropdownMenuItem(value: 'cash', child: Text('Cash')),
                DropdownMenuItem(value: 'card', child: Text('Credit/Debit Card')),
                DropdownMenuItem(value: 'bank_transfer', child: Text('Bank Transfer')),
              ],
              onChanged: (val) {
                if (val != null) method = val;
              },
              decoration: const InputDecoration(labelText: 'Payment Method'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: refController,
              decoration: const InputDecoration(labelText: 'Transaction Gateway Reference'),
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
                _bloc.add(RecordPaymentEvent(
                  panchayatId: _panchayatId!,
                  paymentId: paymentId,
                  data: {
                    'paid_amount': double.tryParse(amountController.text) ?? 0.0,
                    'payment_method': method,
                    'transaction_ref': refController.text.trim(),
                  },
                ));
              }
              Navigator.pop(ctx);
            },
            child: const Text('Submit Payment'),
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
                    _bloc.add(LoadPropertyTaxData(_panchayatId!, financialYear: _selectedYear));
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
        title: const Text('Property Tax Dashboard'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.home_work_outlined), text: 'Properties List'),
            Tab(icon: Icon(Icons.warning_amber), text: 'Defaulters'),
            Tab(icon: Icon(Icons.analytics_outlined), text: 'Revenue Summary'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bolt_outlined),
            tooltip: 'Generate Demands',
            onPressed: _showGenerateDemandsDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildPanchayatSelector(),
          Expanded(
            child: BlocBuilder<PropertyTaxBloc, RevenueState>(
              bloc: _bloc,
              builder: (context, state) {
                if (state is RevenueLoading) {
                  return Column(
                    children: [
                      RevenueSkeletonLoader.summaryCards(count: 3),
                      Expanded(child: RevenueSkeletonLoader.list()),
                    ],
                  );
                }
                if (state is RevenueError) {
                  return Center(child: Text('Error: ${state.error}'));
                }
                if (state is PropertyTaxLoaded) {
                  return TabBarView(
                    controller: _tabController,
                    children: [
                      _buildPropertiesTab(state.properties),
                      _buildDefaultersTab(state.defaulters),
                      _buildSummaryTab(state.summary),
                    ],
                  );
                }
                return const Center(child: Text('No property data loaded'));
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPropertiesTab(List<dynamic> list) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Registered Properties', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ElevatedButton.icon(
                onPressed: _showAddPropertyDialog,
                icon: const Icon(Icons.add),
                label: const Text('Register Home'),
              ),
            ],
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? const Center(child: Text('No properties registered.'))
              : ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (ctx, idx) {
                    final prop = list[idx];
                    final payments = prop['tax_payments'] as List<dynamic>? ?? [];
                    final hasUnpaid = payments.any((p) => p['status'] == 'unpaid' || p['status'] == 'overdue');
                    final unpaidId = hasUnpaid ? payments.firstWhere((p) => p['status'] == 'unpaid' || p['status'] == 'overdue')['id'] : null;

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Icon(prop['property_type'] == 'commercial' ? Icons.store : Icons.home),
                        ),
                        title: Text('${prop['owner_name']} (${prop['door_number'] ?? "N/A"})'),
                        subtitle: Text('Address: ${prop['address'] ?? "N/A"}\nAnnual tax: ₹${prop['annual_tax']}'),
                        isThreeLine: true,
                        trailing: hasUnpaid
                            ? ElevatedButton(
                                onPressed: () => _showRecordPaymentDialog(unpaidId),
                                child: const Text('Pay Dues'),
                              )
                            : const Text('No Dues', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildDefaultersTab(List<dynamic> list) {
    return Column(
      children: [
        Expanded(
          child: list.isEmpty
              ? const Center(child: Text('No pending tax defaulters!'))
              : ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (ctx, idx) {
                    final def = list[idx];
                    final prop = def['property'] ?? {};
                    return Card(
                      color: Colors.red.shade50,
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: ListTile(
                        leading: const Icon(Icons.warning, color: Colors.red),
                        title: Text('Owner: ${prop['owner_name']} • Door: ${prop['door_number']}'),
                        subtitle: Text('Dues: ₹${def['demand_amount']} • Penalty: ₹${def['penalty_amount']}\nStatus: ${def['status'].toString().toUpperCase()}'),
                        trailing: ElevatedButton(
                          onPressed: () => _showRecordPaymentDialog(def['id']),
                          child: const Text('Pay Now'),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSummaryTab(Map<String, dynamic> summary) {
    final breakdown = summary['status_breakdown'] as Map<String, dynamic>? ?? {};
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Financial Summary', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildSummaryCard('Total Tax Demand', '₹${summary['total_demand'] ?? "0.00"}', Colors.blue),
          const SizedBox(height: 8),
          _buildSummaryCard('Collected Amount', '₹${summary['total_collected'] ?? "0.00"}', Colors.green),
          const SizedBox(height: 8),
          _buildSummaryCard('Late Surcharge Penalties', '₹${summary['total_penalty'] ?? "0.00"}', Colors.orange),
          const SizedBox(height: 8),
          _buildSummaryCard('Total Outstanding Dues', '₹${summary['total_outstanding'] ?? "0.00"}', Colors.red),
          const SizedBox(height: 16),
          const Text('Demand Status Breakdown', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildBreakdownChip('Paid', '${breakdown['paid'] ?? 0}', Colors.green),
              _buildBreakdownChip('Unpaid', '${breakdown['unpaid'] ?? 0}', Colors.blue),
              _buildBreakdownChip('Overdue', '${breakdown['overdue'] ?? 0}', Colors.red),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String label, String value, Color color) {
    return Card(
      elevation: 2,
      child: ListTile(
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        trailing: Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
      ),
    );
  }

  Widget _buildBreakdownChip(String label, String count, Color color) {
    return Chip(
      avatar: CircleAvatar(backgroundColor: Colors.white, child: Text(count, style: TextStyle(color: color))),
      label: Text(label),
      backgroundColor: color.withValues(alpha: 0.15),
    );
  }
}
