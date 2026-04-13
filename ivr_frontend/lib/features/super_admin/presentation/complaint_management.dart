import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../config/app_theme.dart';
import '../../../core/widgets/assign_electrician_dialog.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/widgets/list_screen_shell.dart';
import '../../../core/widgets/pole_picker_dialog.dart';
import '../../../models/complaint_model.dart';
import '../../../models/pole_model.dart';
import '../data/super_admin_repository.dart';
import '../bloc/complaint_bloc.dart';

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
      return const Center(child: CircularProgressIndicator());
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
            itemBuilder: (context, index) => _ComplaintCard(complaint: filtered[index]),
          );
        },
      );
    }
    return const SizedBox.shrink();
  }
}

bool _canAssignElectricianSA(String status) =>
    status == 'pending' || status == 'reassign_required';

class _ComplaintCard extends StatelessWidget {
  final ComplaintModel complaint;

  const _ComplaintCard({required this.complaint});

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat(
      'MMM d, yyyy – h:mm a',
    ).format(complaint.createdAt);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '#${complaint.id}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryLight,
                  ),
                ),
                const SizedBox(width: 12),
                StatusBadge(status: complaint.status),
                const Spacer(),
                _buildStatusMenu(context),
              ],
            ),
            const SizedBox(height: 12),
            if (complaint.description != null)
              Text(
                complaint.description!,
                style: const TextStyle(
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
                if (complaint.panchayat != null)
                  _infoItem(
                    Icons.location_city_rounded,
                    complaint.panchayat!.name,
                  ),
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
            if (complaint.voiceCall != null) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              if (complaint.voiceCall!.transcriptEnglish != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.bgSurface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
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
                        style: const TextStyle(
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
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusMenu(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: AppTheme.textMuted),
      onSelected: (action) async {
        if (action == 'resolve') {
          _showResolveDialog(context);
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

  void _showResolveDialog(BuildContext context) {
    _showResolveWithMap(context);
  }

  Future<void> _showResolveWithMap(BuildContext context) async {
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
