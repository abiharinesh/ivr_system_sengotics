import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../config/app_theme.dart';
import '../../../../core/models/pole_model.dart';
import '../../../../core/widgets/map_overview.dart';
import '../../../auth/bloc/auth_bloc.dart';
import '../../../auth/bloc/auth_event.dart';
import '../../../super_admin/data/models/complaint_model.dart';
import '../../bloc/citizen_bloc.dart';

class CitizenDashboardScreen extends StatelessWidget {
  const CitizenDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => CitizenBloc()..add(LoadCitizenDashboard()),
      child: const _CitizenDashboardView(),
    );
  }
}

class _CitizenDashboardView extends StatefulWidget {
  const _CitizenDashboardView();

  @override
  State<_CitizenDashboardView> createState() => _CitizenDashboardViewState();
}

class _CitizenDashboardViewState extends State<_CitizenDashboardView> {
  PoleModel? _selectedPole;

  void _showPoleDetails(PoleModel pole) {
    setState(() {
      _selectedPole = pole;
    });

    final isWide = MediaQuery.of(context).size.width > 800;
    if (!isWide) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (modalContext) {
          return BlocProvider.value(
            value: context.read<CitizenBloc>(),
            child: _buildPoleBottomSheet(pole),
          );
        },
      ).then((_) {
        setState(() {
          _selectedPole = null;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 800;
    final currentUser = context.read<AuthBloc>().currentUser;

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: Column(
        children: [
          _buildNavBar(context, currentUser?.email ?? 'Citizen', currentUser?.panchayatName ?? 'Panchayat'),
          Expanded(
            child: BlocListener<CitizenBloc, CitizenState>(
              listener: (context, state) {
                if (state is CitizenComplaintSubmitSuccess) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.check_circle_outline, color: Colors.white),
                          const SizedBox(width: 10),
                          Expanded(child: Text(state.message)),
                        ],
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                  if (mounted && _selectedPole != null) {
                    Navigator.of(context).pop(); // Close bottom sheet if open
                  }
                  setState(() {
                    _selectedPole = null;
                  });
                } else if (state is CitizenError) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.white),
                          const SizedBox(width: 10),
                          Expanded(child: Text(state.message)),
                        ],
                      ),
                      backgroundColor: AppTheme.error,
                    ),
                  );
                }
              },
              child: BlocBuilder<CitizenBloc, CitizenState>(
                builder: (context, state) {
                  if (state is CitizenLoading && state is! CitizenComplaintSubmitting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  List<PoleModel> poles = [];
                  List<ComplaintModel> complaints = [];

                  if (state is CitizenDashboardLoaded) {
                    poles = state.poles;
                    complaints = state.complaints;
                  } else if (state is CitizenComplaintSubmitting || state is CitizenComplaintSubmitSuccess) {
                    // Retain data if loading/submitting in background
                    final bloc = context.read<CitizenBloc>();
                    if (bloc.state is CitizenDashboardLoaded) {
                      poles = (bloc.state as CitizenDashboardLoaded).poles;
                      complaints = (bloc.state as CitizenDashboardLoaded).complaints;
                    }
                  }

                  if (poles.isEmpty && complaints.isEmpty && state is CitizenLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  return RefreshIndicator(
                    onRefresh: () async {
                      context.read<CitizenBloc>().add(LoadCitizenDashboard());
                    },
                    child: isWide
                        ? _buildWideDashboard(poles, complaints)
                        : _buildMobileDashboard(poles, complaints),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavBar(BuildContext context, String email, String panchayat) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        border: Border(bottom: BorderSide(color: AppTheme.stroke)),
        boxShadow: AppTheme.softShadow,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.how_to_reg_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ooraatchi',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'Citizen Portal',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    email,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Panchayat: $panchayat',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              IconButton(
                icon: const Icon(Icons.logout_rounded),
                onPressed: () {
                  context.read<AuthBloc>().add(LogoutRequested());
                },
                tooltip: 'Logout',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWideDashboard(List<PoleModel> poles, List<ComplaintModel> complaints) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column: Interactive Map
        Expanded(
          flex: 3,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Panchayat Utility Map',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${poles.length} mapped poles found',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: MapOverview(
                    poles: poles,
                    height: double.infinity,
                    showCardDecoration: true,
                    onPoleTap: _showPoleDetails,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Right Column: Side details or complaint filing
        Expanded(
          flex: 2,
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.bgCard,
              border: Border(left: BorderSide(color: AppTheme.stroke)),
            ),
            child: _selectedPole != null
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: _buildPoleDetailPanel(_selectedPole!),
                  )
                : _buildComplaintsSideList(complaints),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileDashboard(List<PoleModel> poles, List<ComplaintModel> complaints) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Report Utility Issues',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Click on any pole marker to file a grievance directly.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 16),
          MapOverview(
            poles: poles,
            height: 380,
            showCardDecoration: true,
            onPoleTap: _showPoleDetails,
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Complaints',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                onPressed: () {
                  context.read<CitizenBloc>().add(LoadCitizenDashboard());
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildComplaintsListView(complaints),
        ],
      ),
    );
  }

  Widget _buildComplaintsSideList(List<ComplaintModel> complaints) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 24, left: 24, right: 24, bottom: 8),
          child: Text(
            'Panchayat Complaints',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'Review recent issues reported in your neighborhood.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(child: _buildComplaintsListView(complaints, padding: 24)),
      ],
    );
  }

  Widget _buildComplaintsListView(List<ComplaintModel> complaints, {double padding = 0}) {
    if (complaints.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: padding, vertical: 32),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.assignment_turned_in_outlined, size: 48, color: AppTheme.textMuted),
              const SizedBox(height: 12),
              Text(
                'No issues reported yet',
                style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: padding),
      itemCount: complaints.length,
      itemBuilder: (context, index) {
        final c = complaints[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.stroke),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Complaint #${c.id}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  _buildStatusBadge(c.statusLabel, c.status),
                ],
              ),
              const SizedBox(height: 8),
              if (c.pole != null)
                Row(
                  children: [
                    Icon(Icons.pin_drop_outlined, size: 14, color: AppTheme.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      'Pole Number: ${c.pole?.poleNumber ?? 'N/A'}',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              const SizedBox(height: 4),
              Text(
                c.description ?? 'No description provided.',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Text(
                'Reported: ${_formatDate(c.createdAt)}',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusBadge(String label, String status) {
    Color bg = Colors.grey.shade100;
    Color fg = Colors.grey.shade700;

    if (status == 'pending') {
      bg = AppTheme.error.withValues(alpha: 0.1);
      fg = AppTheme.error;
    } else if (status == 'assigned' || status == 'in_progress') {
      bg = Colors.amber.shade50;
      fg = Colors.amber.shade800;
    } else if (status == 'resolved') {
      bg = Colors.green.shade50;
      fg = Colors.green;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildPoleDetailPanel(PoleModel pole) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Pole Details',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () {
                setState(() {
                  _selectedPole = null;
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildPoleInfoCard(pole),
        const SizedBox(height: 24),
        const Text(
          'File a Grievance',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: SingleChildScrollView(
            child: _ComplaintForm(poleId: pole.id),
          ),
        ),
      ],
    );
  }

  Widget _buildPoleBottomSheet(PoleModel pole) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      padding: EdgeInsets.only(
        top: 24,
        left: 24,
        right: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Pole Information',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildPoleInfoCard(pole),
          const SizedBox(height: 20),
          const Text(
            'Raise a Complaint',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _ComplaintForm(poleId: pole.id),
        ],
      ),
    );
  }

  Widget _buildPoleInfoCard(PoleModel pole) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgDark.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bolt_rounded, color: AppTheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Pole Number: ${pole.poleNumber ?? 'N/A'}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Keypad ID: ${pole.keypadId ?? 'Not Assigned'}',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
          if (pole.landmarks.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Landmarks: ${pole.landmarks.join(', ')}',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

class _ComplaintForm extends StatefulWidget {
  final int poleId;
  const _ComplaintForm({required this.poleId});

  @override
  State<_ComplaintForm> createState() => _ComplaintFormState();
}

class _ComplaintFormState extends State<_ComplaintForm> {
  final _formKey = GlobalKey<FormState>();
  final _descController = TextEditingController();
  
  String _selectedType = 'Street Light Fault';
  String _selectedUrgency = 'medium';

  final List<String> _types = [
    'Street Light Fault',
    'Wire Hanging / Danger',
    'Water Pipeline Leak',
    'Open Junction Box',
    'Other Issue'
  ];

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            value: _selectedType,
            decoration: const InputDecoration(labelText: 'Grievance Type'),
            items: _types.map((t) {
              return DropdownMenuItem(value: t, child: Text(t));
            }).toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _selectedType = val;
                });
              }
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _selectedUrgency,
            decoration: const InputDecoration(labelText: 'Urgency Level'),
            items: const [
              DropdownMenuItem(value: 'low', child: Text('Low')),
              DropdownMenuItem(value: 'medium', child: Text('Medium')),
              DropdownMenuItem(value: 'high', child: Text('High')),
              DropdownMenuItem(value: 'critical', child: Text('Critical')),
            ],
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _selectedUrgency = val;
                });
              }
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _descController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Describe the issue...',
              alignLabelWithHint: true,
            ),
            validator: (v) => v == null || v.isEmpty ? 'Description is required' : null,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 45,
            child: ElevatedButton(
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  context.read<CitizenBloc>().add(
                    SubmitComplaint(
                      poleId: widget.poleId,
                      complaintType: _selectedType,
                      description: _descController.text.trim(),
                      urgencyLevel: _selectedUrgency,
                    ),
                  );
                }
              },
              child: const Text('Submit Grievance'),
            ),
          ),
        ],
      ),
    );
  }
}
