import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../config/app_theme.dart';
import '../../../../core/widgets/app_loading_state.dart';
import '../../../../core/widgets/assign_electrician_dialog.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/list_screen_shell.dart';
import '../../../../core/widgets/pole_picker_dialog.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../super_admin/data/models/complaint_model.dart';
import '../../data/panchayat_admin_repository.dart';
import '../../bloc/pa_complaint_bloc.dart';

class PAComplaintManagement extends StatefulWidget {
  final String initialQuery;
  final bool openCreate;

  const PAComplaintManagement({
    super.key,
    this.initialQuery = '',
    this.openCreate = false,
  });

  @override
  State<PAComplaintManagement> createState() => _PAComplaintManagementState();
}

class _PAComplaintManagementState extends State<PAComplaintManagement> {
  String? _selectedStatus;
  String _query = '';
  bool _createPromptShown = false;

  final _statuses = [
    null,
    'pending',
    'reassign_required',
    'in_progress',
    'resolved',
    'manual_review',
    'rejected',
  ];
  final _statusLabels = [
    'All',
    'Pending',
    'Reassign',
    'In Progress',
    'Resolved',
    'Manual Review',
    'Rejected',
  ];

  @override
  void initState() {
    super.initState();
    _query = widget.initialQuery.trim().toLowerCase();
  }

  @override
  void didUpdateWidget(covariant PAComplaintManagement oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.initialQuery.trim().toLowerCase();
    if (next != oldWidget.initialQuery.trim().toLowerCase()) {
      setState(() => _query = next);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.openCreate && !_createPromptShown) {
      _createPromptShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('New Complaint'),
            content: const Text(
              'Manual complaint creation is not configured yet. '
              'Use IVR intake flow, or add backend support for manual creation.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      });
    }
  }

  List<ComplaintModel> _filterByQuery(List<ComplaintModel> source) {
    if (_query.isEmpty) return source;
    return source.where((c) {
      final chunks = <String>[
        c.id.toString(),
        c.status,
        c.description ?? '',
        c.complaintType ?? '',
        c.callerLanguage ?? '',
        c.callerEmotion ?? '',
        c.urgencyLevel ?? '',
        c.pole?.poleNumber ?? '',
      ];
      return chunks.any((x) => x.toLowerCase().contains(_query));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PAComplaintBloc, PAComplaintState>(
      listener: (context, state) {
        if (state is PAComplaintActionSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppTheme.accent,
            ),
          );
        }
        if (state is PAComplaintError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppTheme.error,
            ),
          );
        }
      },
      builder: (context, state) {
        final count = state is PAComplaintLoaded
            ? _filterByQuery(state.complaints).length
            : 0;
        return ListScreenShell(
          title: 'Complaints',
          subtitle: 'Manage panchayat complaints and assignments',
          countLabel: '$count complaint(s)',
          action: ElevatedButton.icon(
            onPressed:
                () => context.read<PAComplaintBloc>().add(
                  LoadPAComplaints(status: _selectedStatus),
                ),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Refresh'),
          ),
          filters: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(_statuses.length, (i) {
                final isSelected = _selectedStatus == _statuses[i];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(_statusLabels[i]),
                    selected: isSelected,
                    onSelected: (_) {
                      setState(() => _selectedStatus = _statuses[i]);
                      context.read<PAComplaintBloc>().add(
                        LoadPAComplaints(status: _selectedStatus),
                      );
                    },
                    selectedColor: AppTheme.primary.withValues(alpha: 0.12),
                    checkmarkColor: AppTheme.primary,
                  ),
                );
              }),
            ),
          ),
          child: _buildContent(context, state),
        );
      },
    );
  }

  Widget _buildContent(BuildContext context, PAComplaintState state) {
    if (state is PAComplaintLoading) {
      return const AppLoadingState(
        message: 'Loading complaints...',
        style: AppLoadingStyle.list,
      );
    }
    if (state is PAComplaintLoaded) {
      final filtered = _filterByQuery(state.complaints);
      if (filtered.isEmpty) {
        return const EmptyState(
          icon: Icons.check_circle_outline,
          title: 'No Complaints',
          subtitle: 'No complaints for the selected filter',
        );
      }
      return LayoutBuilder(
        builder: (context, constraints) {
          final hPad = constraints.maxWidth < 400 ? 12.0 : 24.0;
          return ListView.builder(
            padding: EdgeInsets.symmetric(horizontal: hPad),
            itemCount: filtered.length,
            itemBuilder: (context, index) => _PAComplaintCard(complaint: filtered[index]),
          );
        },
      );
    }
    return const SizedBox.shrink();
  }
}

bool _canAssignElectrician(String status) =>
    status == 'pending' || status == 'reassign_required';

class _PAComplaintCard extends StatelessWidget {
  final ComplaintModel complaint;

  const _PAComplaintCard({required this.complaint});

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat(
      'MMM d, yyyy – h:mm a',
    ).format(complaint.createdAt);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '#${complaint.id}',
                  style:       TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryLight,
                  ),
                ),
                const SizedBox(width: 12),
                StatusBadge(status: complaint.status),
                const Spacer(),
                PopupMenuButton<String>(
                  icon:       Icon(Icons.more_vert, color: AppTheme.textMuted),
                  onSelected: (action) async {
                    if (action == 'resolve') {
                      _showResolveDialog(context);
                    } else if (action == 'assign_electrician') {
                      final id = await showAssignElectricianDialog(
                        context: context,
                        complaint: complaint,
                        isSuperAdmin: false,
                      );
                      if (id != null && context.mounted) {
                        context.read<PAComplaintBloc>().add(
                          AssignPAComplaintElectrician(complaint.id, id),
                        );
                      }
                    } else {
                      context.read<PAComplaintBloc>().add(
                        UpdatePAComplaintStatus(complaint.id, action),
                      );
                    }
                  },
                  itemBuilder:
                      (_) => [
                        if (_canAssignElectrician(complaint.status))
                          const PopupMenuItem(
                            value: 'assign_electrician',
                            child: Text('Assign electrician'),
                          ),
                        const PopupMenuItem(
                          value: 'pending',
                          child: Text('Mark Pending'),
                        ),
                        const PopupMenuItem(
                          value: 'in_progress',
                          child: Text('Mark In Progress'),
                        ),
                        const PopupMenuItem(
                          value: 'resolved',
                          child: Text('Mark Resolved'),
                        ),
                        const PopupMenuItem(
                          value: 'rejected',
                          child: Text('Mark Rejected'),
                        ),
                        if (complaint.status == 'manual_review')
                          const PopupMenuItem(
                            value: 'resolve',
                            child: Text('Assign Pole & Resolve'),
                          ),
                      ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (complaint.description != null)
              Text(
                complaint.description!,
                style:       TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                if (complaint.pole != null)
                  _infoItem(
                    Icons.electrical_services_rounded,
                    'Pole ${complaint.pole!.poleNumber ?? '#${complaint.pole!.id}'}',
                  ),
                if (complaint.complaintType != null)
                  _infoItem(Icons.category_rounded, complaint.complaintType!),
                if (complaint.callerLanguage != null)
                  _infoItem(Icons.translate_rounded, complaint.callerLanguage!),
                if (complaint.callerEmotion != null)
                  _infoItem(Icons.mood_rounded, complaint.callerEmotion!),
                if (complaint.urgencyLevel != null)
                  _infoItem(
                    Icons.priority_high_rounded,
                    'Urgency: ${complaint.urgencyLevel!}',
                  ),
                _infoItem(Icons.access_time_rounded, dateStr),
              ],
            ),
            if (complaint.voiceCall?.transcriptEnglish != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.bgSurface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                          Text(
                      'Transcript',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textMuted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      complaint.voiceCall!.transcriptEnglish!,
                      style:       TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppTheme.textMuted),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            style:       TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  void _showResolveDialog(BuildContext context) {
    _showResolveWithMap(context);
  }

  Future<void> _showResolveWithMap(BuildContext context) async {
    try {
      final poles = await PanchayatAdminRepository().listPoles();
      if (!context.mounted) return;
      final selected = await showPolePickerDialog(
        context: context,
        poles: poles,
        title: 'Map complaint to pole',
        confirmLabel: 'Assign Pole & Resolve',
      );
      if (!context.mounted || selected == null) return;
      context.read<PAComplaintBloc>().add(
        ResolvePAComplaint(complaint.id, selected.id),
      );
    } catch (err) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load poles: $err')),
      );
    }
  }
}