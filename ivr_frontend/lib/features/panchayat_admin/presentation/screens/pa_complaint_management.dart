import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../config/app_theme.dart';
import '../../../../core/widgets/app_loading_state.dart';
import '../../../../core/widgets/assign_electrician_dialog.dart';
import '../../../../core/widgets/assign_plumber_dialog.dart';
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

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return AppTheme.warning;
      case 'assigned':
      case 'in_progress':
        return AppTheme.info;
      case 'resolved_pending_confirmation':
        return AppTheme.primaryLight;
      case 'reassign_required':
        return AppTheme.warning;
      case 'resolved':
        return AppTheme.accent;
      case 'manual_review':
        return AppTheme.primaryLight;
      case 'rejected':
        return AppTheme.error;
      default:
        return AppTheme.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('MMM d, yyyy – h:mm a').format(complaint.createdAt);
    final sColor = _statusColor(complaint.status);

    // Get color for urgency
    Color? urgencyColor;
    if (complaint.urgencyLevel != null) {
      final ul = complaint.urgencyLevel!.toLowerCase();
      if (ul.contains('high') || ul.contains('crit')) {
        urgencyColor = AppTheme.error;
      } else if (ul.contains('med')) {
        urgencyColor = AppTheme.warning;
      } else {
        urgencyColor = AppTheme.accent;
      }
    }

    // Get color for emotion
    Color? emotionColor;
    if (complaint.callerEmotion != null) {
      final em = complaint.callerEmotion!.toLowerCase();
      if (em.contains('angr') || em.contains('frust')) {
        emotionColor = AppTheme.error;
      } else if (em.contains('neutral') || em.contains('calm')) {
        emotionColor = AppTheme.info;
      } else if (em.contains('happ') || em.contains('thank')) {
        emotionColor = AppTheme.accent;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.stroke, width: 1.2),
        boxShadow: AppTheme.softShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go('/complaints/${complaint.id}'),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: sColor, width: 6),
            ),
          ),
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '#${complaint.id}',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(width: 12),
                  StatusBadge(status: complaint.status),
                  const Spacer(),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, color: AppTheme.textMuted, size: 20),
                    tooltip: 'Complaint actions',
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
                      } else if (action == 'assign_plumber') {
                        final id = await showAssignPlumberDialog(
                          context: context,
                          complaint: complaint,
                        );
                        if (id != null && context.mounted) {
                          context.read<PAComplaintBloc>().add(
                            AssignPAComplaintPlumber(complaint.id, id),
                          );
                        }
                      } else {
                        context.read<PAComplaintBloc>().add(
                          UpdatePAComplaintStatus(complaint.id, action),
                        );
                      }
                    },
                    itemBuilder: (_) => [
                      if (_canAssignElectrician(complaint.status))
                        const PopupMenuItem(
                          value: 'assign_electrician',
                          child: Row(
                            children: [
                              Icon(Icons.engineering_rounded, size: 16),
                              SizedBox(width: 8),
                              Text('Assign electrician'),
                            ],
                          ),
                        ),
                      if (_canAssignElectrician(complaint.status))
                        const PopupMenuItem(
                          value: 'assign_plumber',
                          child: Row(
                            children: [
                              Icon(Icons.plumbing_rounded, size: 16),
                              SizedBox(width: 8),
                              Text('Assign plumber'),
                            ],
                          ),
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
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (complaint.pole != null)
                    _infoItem(
                      Icons.electrical_services_rounded,
                      'Pole ${complaint.pole!.poleNumber ?? '#${complaint.pole!.id}'}',
                    ),
                  if (complaint.complaintType != null)
                    _infoItem(
                      Icons.category_rounded,
                      complaint.complaintType!,
                      bgColor: AppTheme.primary.withValues(alpha: 0.08),
                      textColor: AppTheme.primary,
                    ),
                  if (complaint.callerLanguage != null)
                    _infoItem(Icons.translate_rounded, complaint.callerLanguage!),
                  if (complaint.callerEmotion != null)
                    _infoItem(
                      Icons.mood_rounded,
                      complaint.callerEmotion!,
                      bgColor: emotionColor?.withValues(alpha: 0.08),
                      textColor: emotionColor,
                    ),
                  if (complaint.urgencyLevel != null)
                    _infoItem(
                      Icons.priority_high_rounded,
                      'Urgency: ${complaint.urgencyLevel!}',
                      bgColor: urgencyColor?.withValues(alpha: 0.08),
                      textColor: urgencyColor,
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
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.stroke, width: 0.8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.record_voice_over_rounded, size: 12, color: AppTheme.textMuted),
                          const SizedBox(width: 6),
                          Text(
                            'AI ENGLISH TRANSCRIPT SUMMARY',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textMuted,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        complaint.voiceCall!.transcriptEnglish!,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoItem(IconData icon, String text, {Color? bgColor, Color? textColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor ?? AppTheme.bgSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: textColor?.withValues(alpha: 0.2) ?? AppTheme.stroke,
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: textColor ?? AppTheme.textMuted),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: textColor ?? AppTheme.textSecondary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
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