import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../features/auth/bloc/auth_bloc.dart';
import '../../../features/auth/bloc/auth_state.dart';
import '../bloc/revenue_blocs.dart';
import '../../../core/api/revenue_service.dart';
import '../../super_admin/data/super_admin_repository.dart';
import '../../../core/models/panchayat_model.dart';
import '../../../core/widgets/revenue_skeleton_loader.dart';

class AdCampaignScreen extends StatefulWidget {
  const AdCampaignScreen({super.key});

  @override
  State<AdCampaignScreen> createState() => _AdCampaignScreenState();
}

class _AdCampaignScreenState extends State<AdCampaignScreen> {
  final RevenueService _service = RevenueService();
  late AdCampaignBloc _bloc;
  int? _panchayatId;
  bool _isSuperAdmin = false;
  List<PanchayatModel> _panchayats = [];

  @override
  void initState() {
    super.initState();
    _bloc = AdCampaignBloc();
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
            _bloc.add(LoadAdCampaigns(_panchayatId!));
          }
        } catch (e) {
          // Fallback if list fails
          if (mounted) {
            setState(() {
              _panchayatId = 1;
            });
            _bloc.add(LoadAdCampaigns(_panchayatId!));
          }
        }
      } else {
        _panchayatId = authState.user.panchayatId ?? 1;
        _bloc.add(LoadAdCampaigns(_panchayatId!));
      }
    }
  }

  @override
  void dispose() {
    _bloc.close();
    super.dispose();
  }

  void _showCreateCampaignDialog() {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    final imgController = TextEditingController();
    final linkController = TextEditingController();
    final advertiserController = TextEditingController();
    final amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create Ad Campaign'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: advertiserController,
                decoration: const InputDecoration(labelText: 'Advertiser Name'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Ad Title'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descController,
                decoration: const InputDecoration(labelText: 'Description / Slogan'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: imgController,
                decoration: const InputDecoration(labelText: 'Image URL'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: linkController,
                decoration: const InputDecoration(labelText: 'CTA Redirect Link'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Amount Paid (₹)'),
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
                _bloc.add(CreateCampaignEvent(_panchayatId!, {
                  'panchayat_id': _panchayatId!,
                  'advertiser_name': advertiserController.text.trim(),
                  'title': titleController.text.trim(),
                  'description': descController.text.trim(),
                  'image_url': imgController.text.trim(),
                  'link_url': linkController.text.trim(),
                  'amount_paid': double.tryParse(amountController.text) ?? 1000.0,
                  'starts_at': DateTime.now().toIso8601String(),
                  'ends_at': DateTime.now().add(const Duration(days: 7)).toIso8601String(),
                }));
              }
              Navigator.pop(ctx);
            },
            child: const Text('Publish'),
          ),
        ],
      ),
    );
  }

  void _showAnalyticsModal(int campaignId) async {
    showDialog(
      context: context,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final stats = await _service.getCampaignAnalytics(campaignId);
      if (mounted) Navigator.pop(context); // Dismiss loading spinner

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('Analytics: ${stats['title']}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatRow('Total Impressions:', '${stats['total_impressions']}'),
                const SizedBox(height: 8),
                _buildStatRow('Total Clicks:', '${stats['total_clicks']}'),
                const SizedBox(height: 8),
                _buildStatRow('Click-Through Rate (CTR):', '${stats['click_through_rate']}'),
                const SizedBox(height: 8),
                _buildStatRow('Total Paid:', '₹${stats['amount_paid']}'),
                const SizedBox(height: 8),
                _buildStatRow('Cost Per Impression:', '₹${stats['cost_per_impression']}'),
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
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load analytics: $e')),
        );
      }
    }
  }

  Widget _buildStatRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(value, style: const TextStyle(color: Colors.blueAccent)),
      ],
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
                    _bloc.add(LoadAdCampaigns(_panchayatId!));
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
      body: BlocBuilder<AdCampaignBloc, RevenueState>(
        bloc: _bloc,
        builder: (context, state) {
          if (state is RevenueLoading) {
            return Column(
              children: [
                _buildPanchayatSelector(),
                Expanded(child: RevenueSkeletonLoader.list()),
              ],
            );
          }
          if (state is RevenueError) {
            return Center(child: Text('Error: ${state.error}'));
          }
          if (state is AdCampaignsLoaded) {
            final list = state.campaigns;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPanchayatSelector(),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'QR Ad Campaigns',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      ElevatedButton.icon(
                        onPressed: _showCreateCampaignDialog,
                        icon: const Icon(Icons.add),
                        label: const Text('Create Campaign'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: list.isEmpty
                      ? const Center(child: Text('No active ad campaigns.'))
                      : ListView.builder(
                          itemCount: list.length,
                          itemBuilder: (ctx, idx) {
                            final campaign = list[idx];
                            final isActive = campaign['is_active'] as bool;
                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              elevation: 2,
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: isActive ? Colors.green.shade100 : Colors.grey.shade200,
                                  child: Icon(
                                    isActive ? Icons.campaign : Icons.disabled_by_default,
                                    color: isActive ? Colors.green : Colors.grey,
                                  ),
                                ),
                                title: Text(campaign['title'] ?? 'Ad Title'),
                                subtitle: Text('Advertiser: ${campaign['advertiser_name']} • Cost: ₹${campaign['amount_paid']}'),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.bar_chart, color: Colors.blueAccent),
                                      onPressed: () => _showAnalyticsModal(campaign['id']),
                                      tooltip: 'Analytics',
                                    ),
                                    Switch(
                                      value: isActive,
                                      onChanged: (val) {
                                        if (_panchayatId != null) {
                                          _bloc.add(UpdateCampaignEvent(_panchayatId!, campaign['id'], {
                                            'is_active': val,
                                          }));
                                        }
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.redAccent),
                                      onPressed: () {
                                        if (_panchayatId != null) {
                                          _bloc.add(DeleteCampaignEvent(_panchayatId!, campaign['id']));
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          }
          return const Center(child: Text('Initial state'));
        },
      ),
    );
  }
}
