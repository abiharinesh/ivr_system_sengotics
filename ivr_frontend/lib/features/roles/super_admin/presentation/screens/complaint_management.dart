import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:ivr_frontend/config/app_theme.dart';
import 'package:ivr_frontend/core/widgets/app_loading_state.dart';
import 'package:ivr_frontend/core/widgets/assign_electrician_dialog.dart';
import 'package:ivr_frontend/core/widgets/empty_state.dart';
import 'package:ivr_frontend/core/widgets/status_badge.dart';
import 'package:ivr_frontend/core/widgets/list_screen_shell.dart';
import 'package:ivr_frontend/core/widgets/pole_picker_dialog.dart';
import 'package:ivr_frontend/features/roles/super_admin/data/models/complaint_model.dart';
import 'package:ivr_frontend/core/models/pole_model.dart';
import 'package:ivr_frontend/features/roles/super_admin/data/super_admin_repository.dart';
import 'package:ivr_frontend/features/roles/super_admin/bloc/complaint_bloc.dart';

class ComplaintManagement extends StatefulWidget {
  final String initialQuery;
  final bool openCreate;

  const ComplaintManagement({
    super.key,
    this.initialQuery = '',
    this.openCreate = false,
  });

  @override
  State<ComplaintManagement> createState() => _ComplaintManagementState();
}

class _ComplaintManagementState extends State<ComplaintManagement> {
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
  void didUpdateWidget(covariant ComplaintManagement oldWidget) {
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
              'Use IVR intake flow, or create via backend API milestone.',
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
        c.panchayat?.name ?? '',
        c.pole?.poleNumber ?? '',
      ];
      return chunks.any((x) => x.toLowerCase().contains(_query));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SAComplaintBloc, SAComplaintState>(
      listener: (context, state) {
        if (state is SAComplaintActionSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppTheme.accent,
            ),
          );
        }
        if (state is SAComplaintError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppTheme.error,
            ),
          );
        }
      },
      builder: (context, state) {
        final count = state is SAComplaintLoaded
            ? _filterByQuery(state.complaints).length
            : 0;
        return ListScreenShell(
          title: 'Complaint Management',
          subtitle: 'Track and resolve incoming voice complaints',
          countLabel: '$count complaint(s)',
          action: ElevatedButton.icon(
            onPressed:
                () => context.read<SAComplaintBloc>().add(
                  LoadSAComplaints(status: _selectedStatus),
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
                      context.read<SAComplaintBloc>().add(
                        LoadSAComplaints(status: _selectedStatus),
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

  Widget _buildContent(BuildContext context, SAComplaintState state) {
    if (state is SAComplaintLoading) {
      return const AppLoadingState(
        message: 'Loading complaints...',
        style: AppLoadingStyle.list,
      );
    }
    if (state is SAComplaintLoaded) {
      final filtered = _filterByQuery(state.complaints);
      if (filtered.isEmpty) {
        return const EmptyState(
          icon: Icons.check_circle_outline,
          title: 'No Complaints',
          subtitle: 'No complaints found for the selected filter',
        );
      }
      return LayoutBuilder(
        builder: (context, constraints) {
          final hPad = constraints.maxWidth < 400 ? 12.0 : 24.0;
          return ListView.builder(
            padding: EdgeInsets.symmetric(horizontal: hPad),
            itemCount: filtered.length,
            itemBuilder: (context, index) => _ModernComplaintCard(complaint: filtered[index]),
          );
        },
      );
    }
    return const SizedBox.shrink();
  }
}

bool _canAssignElectricianSA(String status) =>
    status == 'pending' || status == 'reassign_required';

// ══════════════════════════════════════════════════════════════════════════════
// MODERN COMPLAINT CARD — Redesigned to match PA style
// ══════════════════════════════════════════════════════════════════════════════

class _ModernComplaintCard extends StatefulWidget {
  final ComplaintModel complaint;
  const _ModernComplaintCard({required this.complaint});

  @override
  State<_ModernComplaintCard> createState() => _ModernComplaintCardState();
}

class _ModernComplaintCardState extends State<_ModernComplaintCard> {
  bool _assigning = false;

  String _getTimeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} mins ago';
    if (diff.inHours < 24) return '${diff.inHours} hours ago';
    return DateFormat('MMM d, h:mm a').format(date);
  }

  Color _statusDotColor(String status) {
    switch (status) {
      case 'resolved':
        return AppTheme.accent;
      case 'in_progress':
        return AppTheme.info;
      case 'pending':
      case 'reassign_required':
        return AppTheme.warning;
      case 'manual_review':
        return AppTheme.error;
      case 'rejected':
        return AppTheme.error;
      default:
        return AppTheme.textMuted;
    }
  }

  IconData _complaintIcon(String? type) {
    if (type == null) return Icons.mic;
    final lower = type.toLowerCase();
    if (lower.contains('water') || lower.contains('pipe') || lower.contains('நீர்')) return Icons.water_drop_rounded;
    if (lower.contains('electric') || lower.contains('light') || lower.contains('மின்')) return Icons.electrical_services_rounded;
    if (lower.contains('road') || lower.contains('சாலை')) return Icons.add_road_rounded;
    return Icons.mic;
  }

  @override
  Widget build(BuildContext context) {
    final complaint = widget.complaint;
    final timeStr = _getTimeAgo(complaint.createdAt);
    final statusColor = _statusDotColor(complaint.status);
    final iconData = _complaintIcon(complaint.complaintType);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        onTap: () {
          // Could navigate to detail page
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Icon + Title + Status + Actions
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(iconData, color: statusColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${complaint.complaintType ?? 'Voice Complaint'} #${complaint.id}',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            StatusBadge(status: complaint.status),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$timeStr • Pole ${complaint.pole?.poleNumber ?? '#${complaint.pole?.id ?? 'N/A'}'}',
                          style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                  _buildActionButtons(context, complaint),
                ],
              ),

              // Panchayat Tag
              if (complaint.panchayat != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.location_city_rounded, size: 12, color: AppTheme.primary),
                      const SizedBox(width: 4),
                      Text(
                        complaint.panchayat!.name,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Metadata chips
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  if (complaint.callerLanguage != null)
                    _MetadataChip(
                      icon: Icons.translate_rounded,
                      label: complaint.callerLanguage!,
                    ),
                  if (complaint.callerEmotion != null)
                    _MetadataChip(
                      icon: Icons.mood_rounded,
                      label: complaint.callerEmotion!,
                    ),
                  if (complaint.urgencyLevel != null)
                    _MetadataChip(
                      icon: Icons.priority_high_rounded,
                      label: 'Urgency: ${complaint.urgencyLevel!}',
                      color: complaint.urgencyLevel == 'high' ? AppTheme.error : null,
                    ),
                  if (complaint.assignedElectrician != null)
                    _MetadataChip(
                      icon: Icons.engineering_rounded,
                      label: complaint.assignedElectrician!.email.split('@').first,
                      color: AppTheme.accent,
                    ),
                ],
              ),

              // Transcript section
              if (complaint.voiceCall != null) ...[
                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isTwoCol = constraints.maxWidth > 500;
                    final originalText = complaint.voiceCall?.transcript ??
                        complaint.description ??
                        'Voice complaint received via IVR.';
                    final translationText = complaint.voiceCall?.transcriptEnglish ??
                        complaint.description ??
                        'Voice complaint received via IVR.';

                    final leftWidget = Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.bgSurface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.stroke),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.translate, size: 12, color: AppTheme.textMuted),
                              const SizedBox(width: 4),
                              Text(
                                'ORIGINAL TRANSCRIPT',
                                style: TextStyle(fontSize: 9, color: AppTheme.textMuted, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            originalText,
                            style: TextStyle(
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                              color: AppTheme.textSecondary,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    );

                    final rightWidget = Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.25)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.check_circle_outline, size: 12, color: AppTheme.accent),
                              const SizedBox(width: 4),
                              Text(
                                'AI ENGLISH TRANSLATION',
                                style: TextStyle(fontSize: 9, color: AppTheme.accent, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            translationText,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.accent,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    );

                    if (isTwoCol) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: leftWidget),
                          const SizedBox(width: 12),
                          Expanded(child: rightWidget),
                        ],
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        leftWidget,
                        const SizedBox(height: 8),
                        rightWidget,
                      ],
                    );
                  },
                ),
              ] else if (complaint.description != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.bgSurface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'DESCRIPTION',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textMuted,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        complaint.description!,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
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

  Widget _buildActionButtons(BuildContext context, ComplaintModel complaint) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_canAssignElectricianSA(complaint.status)) ...[
          if (_assigning)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            ElevatedButton(
              onPressed: () => _handleAssign(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                minimumSize: Size.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Assign',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          const SizedBox(width: 4),
        ],
        _buildStatusMenu(context, complaint),
      ],
    );
  }

  Widget _buildStatusMenu(BuildContext context, ComplaintModel complaint) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, color: AppTheme.textMuted, size: 20),
      tooltip: 'Actions',
      onSelected: (action) async {
        if (action == 'resolve') {
          _showResolveWithMap(context, complaint);
        } else if (action == 'assign_electrician') {
          final id = await showAssignElectricianDialog(
            context: context,
            complaint: complaint,
            isSuperAdmin: true,
          );
          if (id != null && context.mounted) {
            context.read<SAComplaintBloc>().add(
              AssignSAComplaintElectrician(complaint.id, id),
            );
          }
        } else {
          context.read<SAComplaintBloc>().add(
            UpdateSAComplaintStatus(complaint.id, action),
          );
        }
      },
      itemBuilder:
          (_) => [
            if (_canAssignElectricianSA(complaint.status))
              const PopupMenuItem(
                value: 'assign_electrician',
                child: Text('Assign electrician'),
              ),
            const PopupMenuItem(value: 'pending', child: Text('Mark Pending')),
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
    );
  }

  Future<void> _handleAssign(BuildContext context) async {
    final complaint = widget.complaint;
    setState(() => _assigning = true);

    try {
      final id = await showAssignElectricianDialog(
        context: context,
        complaint: complaint,
        isSuperAdmin: true,
      );

      if (id != null && context.mounted) {
        context.read<SAComplaintBloc>().add(
          AssignSAComplaintElectrician(complaint.id, id),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _assigning = false);
    }
  }

  Future<void> _showResolveWithMap(BuildContext context, ComplaintModel complaint) async {
    try {
      final raw = await SuperAdminRepository().listPoles();
      if (!context.mounted) return;
      final poles =
          raw
              .whereType<Map>()
              .map((j) => PoleModel.fromJson(Map<String, dynamic>.from(j)))
              .toList();
      final selected = await showPolePickerDialog(
        context: context,
        poles: poles,
        title: 'Map complaint to pole',
        confirmLabel: 'Assign Pole & Resolve',
      );
      if (!context.mounted || selected == null) return;
      context.read<SAComplaintBloc>().add(
        ResolveSAComplaint(complaint.id, selected.id),
      );
    } catch (err) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load poles: $err')),
      );
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// METADATA CHIP — Small informational chip
// ══════════════════════════════════════════════════════════════════════════════

class _MetadataChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _MetadataChip({
    required this.icon,
    required this.label,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: c),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: c,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}