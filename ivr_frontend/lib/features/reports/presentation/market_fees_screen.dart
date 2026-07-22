import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../features/auth/bloc/auth_bloc.dart';
import '../../../features/auth/bloc/auth_state.dart';
import '../bloc/revenue_blocs.dart';
import '../../super_admin/data/super_admin_repository.dart';
import '../../../core/models/panchayat_model.dart';
import '../../../core/widgets/revenue_skeleton_loader.dart';

class MarketFeesScreen extends StatefulWidget {
  const MarketFeesScreen({super.key});

  @override
  State<MarketFeesScreen> createState() => _MarketFeesScreenState();
}

class _MarketFeesScreenState extends State<MarketFeesScreen> with SingleTickerProviderStateMixin {
  late MarketBloc _bloc;
  late TabController _tabController;
  int? _panchayatId;
  bool _isSuperAdmin = false;
  List<PanchayatModel> _panchayats = [];

  @override
  void initState() {
    super.initState();
    _bloc = MarketBloc();
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
            _bloc.add(LoadMarketData(_panchayatId!));
          }
        } catch (e) {
          if (mounted) {
            setState(() {
              _panchayatId = 1;
            });
            _bloc.add(LoadMarketData(_panchayatId!));
          }
        }
      } else {
        _panchayatId = authState.user.panchayatId ?? 1;
        _bloc.add(LoadMarketData(_panchayatId!));
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _bloc.close();
    super.dispose();
  }

  void _showAddMarketDayDialog() {
    final nameController = TextEditingController();
    final locationController = TextEditingController();
    final dayController = TextEditingController(text: '0'); // Sunday
    final feeController = TextEditingController(text: '50');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Configure Weekly Market Day'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Market Name (e.g. Sunday Shandy)'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: locationController,
              decoration: const InputDecoration(labelText: 'Location / Venue'),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              initialValue: 0,
              items: const [
                DropdownMenuItem(value: 0, child: Text('Sunday')),
                DropdownMenuItem(value: 1, child: Text('Monday')),
                DropdownMenuItem(value: 2, child: Text('Tuesday')),
                DropdownMenuItem(value: 3, child: Text('Wednesday')),
                DropdownMenuItem(value: 4, child: Text('Thursday')),
                DropdownMenuItem(value: 5, child: Text('Friday')),
                DropdownMenuItem(value: 6, child: Text('Saturday')),
              ],
              onChanged: (val) {
                if (val != null) dayController.text = val.toString();
              },
              decoration: const InputDecoration(labelText: 'Market Day of Week'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: feeController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Standard Stall Fee (₹)'),
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
                _bloc.add(CreateMarketDayEvent(_panchayatId!, {
                  'panchayat_id': _panchayatId!,
                  'name': nameController.text.trim(),
                  'location': locationController.text.trim(),
                  'day_of_week': int.tryParse(dayController.text) ?? 0,
                  'daily_fee': double.tryParse(feeController.text) ?? 50.0,
                }));
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showAddVendorDialog() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final typeController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Register Market Vendor'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Vendor / Merchant Name'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(labelText: 'Mobile Phone'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: typeController,
              decoration: const InputDecoration(labelText: 'Business Type (e.g. Vegetables)'),
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
                _bloc.add(CreateVendorEvent(_panchayatId!, {
                  'panchayat_id': _panchayatId!,
                  'vendor_name': nameController.text.trim(),
                  'vendor_phone': phoneController.text.trim(),
                  'business_type': typeController.text.trim(),
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

  void _showVendorCard(Map<String, dynamic> vendor) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${vendor['vendor_name']}\'s Digital Stall Card'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Scan this QR code during daily market checks to record stall fees.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.white,
              child: QrImageView(
                data: vendor['vendor_token'] ?? 'N/A',
                version: QrVersions.auto,
                size: 200.0,
              ),
            ),
            const SizedBox(height: 16),
            Text('Mobile: ${vendor['vendor_phone']}', style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showRecordPaymentDialog(List<dynamic> marketDays, List<dynamic> vendors) {
    if (vendors.isEmpty || marketDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please register market days and vendors first.')),
      );
      return;
    }

    int selectedVendorId = vendors[0]['id'];
    int selectedMarketDayId = marketDays[0]['id'];
    final amountController = TextEditingController(text: marketDays[0]['daily_fee'].toString());
    final collectorController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Record Daily Stall Fee'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                initialValue: selectedVendorId,
                items: vendors.map((v) => DropdownMenuItem<int>(
                  value: v['id'] as int,
                  child: Text(v['vendor_name'] as String),
                )).toList(),
                onChanged: (val) {
                  if (val != null) selectedVendorId = val;
                },
                decoration: const InputDecoration(labelText: 'Vendor'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                initialValue: selectedMarketDayId,
                items: marketDays.map((md) => DropdownMenuItem<int>(
                  value: md['id'] as int,
                  child: Text(md['name'] as String),
                )).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setDialogState(() {
                      selectedMarketDayId = val;
                      final selectedMD = marketDays.firstWhere((element) => element['id'] == val);
                      amountController.text = selectedMD['daily_fee'].toString();
                    });
                  }
                },
                decoration: const InputDecoration(labelText: 'Market Shandy'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Daily Fee Amount (₹)'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: collectorController,
                decoration: const InputDecoration(labelText: 'Revenue Collector Name'),
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
                  _bloc.add(RecordMarketFeeEvent(_panchayatId!, {
                    'vendor_id': selectedVendorId,
                    'market_day_id': selectedMarketDayId,
                    'amount_paid': double.tryParse(amountController.text) ?? 50.0,
                    'payment_method': 'cash',
                    'collected_by': collectorController.text.trim(),
                  }));
                }
                Navigator.pop(ctx);
              },
              child: const Text('Collect Fee'),
            ),
          ],
        ),
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
                    _bloc.add(LoadMarketData(_panchayatId!));
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
        title: const Text('Shandy Market Stall Fees'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.store_mall_directory_rounded), text: 'Stall Merchants'),
            Tab(icon: Icon(Icons.calendar_month_rounded), text: 'Market Days'),
            Tab(icon: Icon(Icons.receipt_long_rounded), text: 'Collection History'),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildPanchayatSelector(),
          Expanded(
            child: BlocBuilder<MarketBloc, RevenueState>(
              bloc: _bloc,
              builder: (context, state) {
                if (state is RevenueLoading) {
                  return RevenueSkeletonLoader.list();
                }
                if (state is RevenueError) {
                  return Center(child: Text('Error: ${state.error}'));
                }
                if (state is MarketDataLoaded) {
                  return Scaffold(
                    floatingActionButton: _tabController.index == 2
                        ? null
                        : FloatingActionButton.extended(
                            onPressed: () => _showRecordPaymentDialog(state.marketDays, state.vendors),
                            icon: const Icon(Icons.currency_rupee),
                            label: const Text('Record Fee'),
                          ),
                    body: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildVendorsTab(state.vendors),
                        _buildMarketDaysTab(state.marketDays),
                        _buildPaymentsTab(state.payments),
                      ],
                    ),
                  );
                }
                return const Center(child: Text('No market data loaded'));
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVendorsTab(List<dynamic> list) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Registered Merchants', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ElevatedButton.icon(
                onPressed: _showAddVendorDialog,
                icon: const Icon(Icons.add),
                label: const Text('Register Merchant'),
              ),
            ],
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? const Center(child: Text('No vendors registered.'))
              : ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (ctx, idx) {
                    final vendor = list[idx];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Icon(vendor['is_active'] ? Icons.check_circle : Icons.error),
                        ),
                        title: Text(vendor['vendor_name']),
                        subtitle: Text('Mobile: ${vendor['vendor_phone']} • ${vendor['business_type'] ?? "General"}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.qr_code, color: Colors.blueAccent),
                          onPressed: () => _showVendorCard(vendor),
                          tooltip: 'Stall ID QR Card',
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildMarketDaysTab(List<dynamic> list) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Weekly Market Schedule', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ElevatedButton.icon(
                onPressed: _showAddMarketDayDialog,
                icon: const Icon(Icons.add),
                label: const Text('Add Market Day'),
              ),
            ],
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? const Center(child: Text('No market days configured.'))
              : ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (ctx, idx) {
                    final day = list[idx];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.store)),
                        title: Text(day['name']),
                        subtitle: Text('Location: ${day['location'] ?? "N/A"}'),
                        trailing: Text(
                          '₹${day['daily_fee']}/stall',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildPaymentsTab(List<dynamic> list) {
    return list.isEmpty
        ? const Center(child: Text('No collections recorded.'))
        : ListView.builder(
            itemCount: list.length,
            itemBuilder: (ctx, idx) {
              final pay = list[idx];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: ListTile(
                  title: Text('Merchant: ${pay['vendor']['vendor_name']}'),
                  subtitle: Text('Shandy: ${pay['market_day']['name']} • Collected by: ${pay['collected_by'] ?? "Inspector"}'),
                  trailing: Text(
                    '₹${pay['amount_paid']}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green),
                  ),
                ),
              );
            },
          );
  }
}
