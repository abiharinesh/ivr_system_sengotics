import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ivr_frontend/features/auth/bloc/auth_bloc.dart';
import 'package:ivr_frontend/features/auth/bloc/auth_state.dart';
import 'package:ivr_frontend/features/modules/reports/bloc/revenue_blocs.dart';
import 'package:ivr_frontend/features/roles/super_admin/data/super_admin_repository.dart';
import 'package:ivr_frontend/core/models/panchayat_model.dart';
import 'package:ivr_frontend/core/widgets/revenue_skeleton_loader.dart';

class CertificateReviewScreen extends StatefulWidget {
  const CertificateReviewScreen({super.key});

  @override
  State<CertificateReviewScreen> createState() => _CertificateReviewScreenState();
}

class _CertificateReviewScreenState extends State<CertificateReviewScreen> {
  late CertificateBloc _bloc;
  int? _panchayatId;
  String _selectedCategory = 'birth';
  bool _isSuperAdmin = false;
  List<PanchayatModel> _panchayats = [];

  @override
  void initState() {
    super.initState();
    _bloc = CertificateBloc();
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
            _bloc.add(LoadCertificates(_panchayatId!, type: _selectedCategory));
          }
        } catch (e) {
          if (mounted) {
            setState(() {
              _panchayatId = 1;
            });
            _bloc.add(LoadCertificates(_panchayatId!, type: _selectedCategory));
          }
        }
      } else {
        _panchayatId = authState.user.orgUnitId ?? 1;
        _bloc.add(LoadCertificates(_panchayatId!, type: _selectedCategory));
      }
    }
  }

  @override
  void dispose() {
    _bloc.close();
    super.dispose();
  }

  void _showApproveDialog(int id) {
    final notesController = TextEditingController();
    final docUrlController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Approve Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: notesController,
              decoration: const InputDecoration(labelText: 'Reviewer Notes'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: docUrlController,
              decoration: const InputDecoration(labelText: 'Document Storage URL'),
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
                _bloc.add(ApproveCertificateEvent(
                  orgUnitId: _panchayatId!,
                  id: id,
                  data: {
                    'reviewer_notes': notesController.text.trim(),
                    'certificate_url': docUrlController.text.trim(),
                  },
                ));
              }
              Navigator.pop(ctx);
            },
            child: const Text('Approve & Sign'),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(int id) {
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Request'),
        content: TextField(
          controller: notesController,
          decoration: const InputDecoration(
            labelText: 'Reason for Rejection',
            hintText: 'Enter missing details or notes',
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
                _bloc.add(RejectCertificateEvent(
                  orgUnitId: _panchayatId!,
                  id: id,
                  notes: notesController.text.trim(),
                ));
              }
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Reject Application'),
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
                    _bloc.add(LoadCertificates(_panchayatId!, type: _selectedCategory));
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
        title: const Text('Certificate Review Panel'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPanchayatSelector(),
          // Filter Row
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildCategoryFilter('birth', 'Birth Certificates'),
                  const SizedBox(width: 8),
                  _buildCategoryFilter('death', 'Death Certificates'),
                  const SizedBox(width: 8),
                  _buildCategoryFilter('trade_license', 'Trade Licenses'),
                  const SizedBox(width: 8),
                  _buildCategoryFilter('building_permit', 'Building Permits'),
                ],
              ),
            ),
          ),
          // Applications List
          Expanded(
            child: BlocBuilder<CertificateBloc, RevenueState>(
              bloc: _bloc,
              builder: (ctx, state) {
                if (state is RevenueLoading) {
                  return RevenueSkeletonLoader.list();
                }
                if (state is RevenueError) {
                  return Center(child: Text('Error: ${state.error}'));
                }
                if (state is CertificatesLoaded) {
                  final list = state.requests;
                  if (list.isEmpty) {
                    return const Center(child: Text('No applications pending in this category.'));
                  }
                  return ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      final item = list[index];
                      final status = item['review_status'] as String;
                      final isPending = status == 'pending';

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: ListTile(
                          title: Text('Applicant: ${item['applicant_name']}'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Type: ${item['certificate_type'].toString().replaceAll('_', ' ').toUpperCase()}'),
                              Text('Fee paid: ₹${item['fee_amount']} (${item['payment_status']})'),
                              if (item['reviewer_notes'] != null)
                                Text('Reviewer Notes: ${item['reviewer_notes']}', style: const TextStyle(fontStyle: FontStyle.italic)),
                            ],
                          ),
                          isThreeLine: true,
                          trailing: isPending
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.check_circle_outline, color: Colors.green),
                                      onPressed: () => _showApproveDialog(item['id']),
                                      tooltip: 'Approve & Issue',
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                                      onPressed: () => _showRejectDialog(item['id']),
                                      tooltip: 'Reject Application',
                                    ),
                                  ],
                                )
                              : Chip(
                                  label: Text(status.toUpperCase()),
                                  backgroundColor: status == 'approved' ? Colors.green.shade100 : Colors.red.shade100,
                                ),
                        ),
                      );
                    },
                  );
                }
                return const Center(child: Text('Initialize'));
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilter(String category, String label) {
    final isSelected = _selectedCategory == category;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) {
        if (val) {
          setState(() {
            _selectedCategory = category;
          });
          if (_panchayatId != null) {
            _bloc.add(LoadCertificates(_panchayatId!, type: _selectedCategory));
          }
        }
      },
    );
  }
}
