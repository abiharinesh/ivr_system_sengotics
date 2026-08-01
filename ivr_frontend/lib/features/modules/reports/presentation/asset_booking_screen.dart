import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ivr_frontend/features/auth/bloc/auth_bloc.dart';
import 'package:ivr_frontend/features/auth/bloc/auth_state.dart';
import 'package:ivr_frontend/features/modules/reports/bloc/revenue_blocs.dart';
import 'package:ivr_frontend/features/roles/super_admin/data/super_admin_repository.dart';
import 'package:ivr_frontend/core/models/panchayat_model.dart';
import 'package:ivr_frontend/core/widgets/revenue_skeleton_loader.dart';

class AssetBookingScreen extends StatefulWidget {
  const AssetBookingScreen({super.key});

  @override
  State<AssetBookingScreen> createState() => _AssetBookingScreenState();
}

class _AssetBookingScreenState extends State<AssetBookingScreen> with SingleTickerProviderStateMixin {
  late AssetBookingBloc _bloc;
  late TabController _tabController;
  int? _panchayatId;
  bool _isSuperAdmin = false;
  List<PanchayatModel> _panchayats = [];

  @override
  void initState() {
    super.initState();
    _bloc = AssetBookingBloc();
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
            _bloc.add(LoadAssetBookings(_panchayatId!));
          }
        } catch (e) {
          if (mounted) {
            setState(() {
              _panchayatId = 1;
            });
            _bloc.add(LoadAssetBookings(_panchayatId!));
          }
        }
      } else {
        _panchayatId = authState.user.orgUnitId ?? 1;
        _bloc.add(LoadAssetBookings(_panchayatId!));
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _bloc.close();
    super.dispose();
  }

  void _showAddAssetDialog() {
    final nameController = TextEditingController();
    final typeController = TextEditingController(text: 'hall');
    final descController = TextEditingController();
    final dailyRateController = TextEditingController();
    final depositController = TextEditingController();
    final capController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Rentable Asset'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Asset Name (e.g., Main Hall)'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: 'hall',
                items: const [
                  DropdownMenuItem(value: 'hall', child: Text('Community Hall')),
                  DropdownMenuItem(value: 'ground', child: Text('Open Ground / Maidan')),
                  DropdownMenuItem(value: 'equipment', child: Text('Equipment (PA/Chairs)')),
                  DropdownMenuItem(value: 'vehicle', child: Text('Vehicle / Tractor')),
                ],
                onChanged: (val) {
                  if (val != null) typeController.text = val;
                },
                decoration: const InputDecoration(labelText: 'Asset Type'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descController,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: dailyRateController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Daily Rate (₹)'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: depositController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Security Deposit (₹)'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: capController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Max Capacity (Optional)'),
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
                _bloc.add(CreateAssetEvent(_panchayatId!, {
                  'org_unit_id': _panchayatId!,
                  'name': nameController.text.trim(),
                  'facility_type': typeController.text,
                  'description': descController.text.trim(),
                  'daily_rate': double.tryParse(dailyRateController.text) ?? 1000.0,
                  'deposit_amount': double.tryParse(depositController.text) ?? 500.0,
                  'max_capacity': int.tryParse(capController.text),
                }));
              }
              Navigator.pop(ctx);
            },
            child: const Text('Add Asset'),
          ),
        ],
      ),
    );
  }

  void _showBookAssetDialog(int assetId, double dailyRate, double deposit) {
    final clientNameController = TextEditingController();
    final clientPhoneController = TextEditingController();
    final eventController = TextEditingController();
    final startController = TextEditingController(text: DateTime.now().toIso8601String().split('T')[0]);
    final endController = TextEditingController(text: DateTime.now().add(const Duration(days: 1)).toIso8601String().split('T')[0]);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reserve Asset'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: clientNameController,
                decoration: const InputDecoration(labelText: 'Customer Name'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: clientPhoneController,
                decoration: const InputDecoration(labelText: 'Customer Phone'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: eventController,
                decoration: const InputDecoration(labelText: 'Event Details'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: startController,
                decoration: const InputDecoration(labelText: 'Start Date (YYYY-MM-DD)'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: endController,
                decoration: const InputDecoration(labelText: 'End Date (YYYY-MM-DD)'),
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
                _bloc.add(CreateBookingEvent(_panchayatId!, {
                  'facility_id': assetId,
                  'booked_by_name': clientNameController.text.trim(),
                  'booked_by_phone': clientPhoneController.text.trim(),
                  'event_type': eventController.text.trim(),
                  'start_date': startController.text.trim(),
                  'end_date': endController.text.trim(),
                  'deposit_paid': deposit,
                }));
              }
              Navigator.pop(ctx);
            },
            child: const Text('Reserve'),
          ),
        ],
      ),
    );
  }

  void _showConfirmPaymentDialog(int bookingId) {
    final refController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Deposit Payment'),
        content: TextField(
          controller: refController,
          decoration: const InputDecoration(labelText: 'Payment Gateway Ref / Receipt ID'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (_panchayatId != null) {
                _bloc.add(ConfirmBookingEvent(
                  orgUnitId: _panchayatId!,
                  bookingId: bookingId,
                  paymentRef: refController.text.trim(),
                ));
              }
              Navigator.pop(ctx);
            },
            child: const Text('Confirm'),
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
                    _bloc.add(LoadAssetBookings(_panchayatId!));
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
        title: const Text('Community Asset Booking'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.apartment_rounded), text: 'Assets Catalog'),
            Tab(icon: Icon(Icons.event_note_rounded), text: 'Bookings History'),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildPanchayatSelector(),
          Expanded(
            child: BlocBuilder<AssetBookingBloc, RevenueState>(
              bloc: _bloc,
              builder: (context, state) {
                if (state is RevenueLoading) {
                  return RevenueSkeletonLoader.list();
                }
                if (state is RevenueError) {
                  return Center(child: Text('Error: ${state.error}'));
                }
                if (state is AssetBookingsLoaded) {
                  return TabBarView(
                    controller: _tabController,
                    children: [
                      _buildAssetsTab(state.assets),
                      _buildBookingsTab(state.bookings),
                    ],
                  );
                }
                return const Center(child: Text('No asset data loaded'));
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssetsTab(List<dynamic> list) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Rentable Assets', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ElevatedButton.icon(
                onPressed: _showAddAssetDialog,
                icon: const Icon(Icons.add_home_rounded),
                label: const Text('Add Asset'),
              ),
            ],
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? const Center(child: Text('No rentable assets registered.'))
              : ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (ctx, idx) {
                    final asset = list[idx];
                    final isAvailable = asset['is_available'] as bool;
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Icon(asset['facility_type'] == 'hall' ? Icons.meeting_room : Icons.electric_car),
                        ),
                        title: Text(asset['name']),
                        subtitle: Text('Rate: ₹${asset['daily_rate']}/day • Deposit: ₹${asset['deposit_amount']}'),
                        trailing: isAvailable
                            ? ElevatedButton(
                                onPressed: () => _showBookAssetDialog(
                                  asset['id'],
                                  (asset['daily_rate'] as num).toDouble(),
                                  (asset['deposit_amount'] as num).toDouble(),
                                ),
                                child: const Text('Book'),
                              )
                            : const Chip(label: Text('Unavailable')),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildBookingsTab(List<dynamic> list) {
    return list.isEmpty
        ? const Center(child: Text('No reservation history.'))
        : ListView.builder(
            itemCount: list.length,
            itemBuilder: (ctx, idx) {
              final booking = list[idx];
              final status = booking['booking_status'] as String;
              final isPending = status == 'pending';
              final isConfirmed = status == 'confirmed';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text('Customer: ${booking['booked_by_name']} (${booking['booked_by_phone']})'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Asset: ${booking['asset']['name']}'),
                      Text('Dates: ${booking['start_date'].toString().split('T')[0]} to ${booking['end_date'].toString().split('T')[0]}'),
                      Text('Total: ₹${booking['total_amount']} • Deposit: ₹${booking['deposit_paid']} • Balance: ₹${booking['balance_amount']}'),
                    ],
                  ),
                  isThreeLine: true,
                  trailing: isPending
                      ? ElevatedButton(
                          onPressed: () => _showConfirmPaymentDialog(booking['id']),
                          child: const Text('Confirm Dep.'),
                        )
                      : isConfirmed
                          ? ElevatedButton(
                              onPressed: () {
                                if (_panchayatId != null) {
                                  _bloc.add(PayBalanceEvent(_panchayatId!, booking['id']));
                                }
                              },
                              child: const Text('Pay Balance'),
                            )
                          : Chip(
                              label: Text(status.toUpperCase()),
                              backgroundColor: status == 'completed' ? Colors.green.shade100 : Colors.red.shade100,
                            ),
                ),
              );
            },
          );
  }
}
