import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../config/app_theme.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/list_screen_shell.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../models/complaint_model.dart';
import '../bloc/pa_complaint_bloc.dart';

class PAComplaintManagement extends StatefulWidget {
  const PAComplaintManagement({super.key});

  @override
  State<PAComplaintManagement> createState() => _PAComplaintManagementState();
}

class _PAComplaintManagementState extends State<PAComplaintManagement> {
  String? _selectedStatus;

  final _statuses = [
    null,
    'pending',
    'in_progress',
    'resolved',
    'manual_review',
    'rejected',
  ];
  final _statusLabels = [
    'All',
    'Pending',
    'In Progress',
    'Resolved',
    'Manual Review',
    'Rejected',
  ];

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
        final count = state is PAComplaintLoaded ? state.complaints.length : 0;
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
      return const Center(child: CircularProgressIndicator());
    }
    if (state is PAComplaintLoaded) {
      if (state.complaints.isEmpty) {
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
            itemCount: state.complaints.length,
            itemBuilder:
                (context, index) =>
                    _PAComplaintCard(complaint: state.complaints[index]),
          );
        },
      );
    }
    return const SizedBox.shrink();
  }
}

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
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryLight,
                  ),
                ),
                const SizedBox(width: 12),
                StatusBadge(status: complaint.status),
                const Spacer(),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: AppTheme.textMuted),
                  onSelected: (action) {
                    if (action == 'resolve') {
                      _showResolveDialog(context);
                    } else {
                      context.read<PAComplaintBloc>().add(
                        UpdatePAComplaintStatus(complaint.id, action),
                      );
                    }
                  },
                  itemBuilder:
                      (_) => [
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

  void _showResolveDialog(BuildContext context) {
    final poleIdC = TextEditingController();
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Resolve Complaint'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Assign this complaint to an electric pole:',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: poleIdC,
                  decoration: const InputDecoration(labelText: 'Pole ID'),
                  keyboardType: TextInputType.number,
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
                  final poleId = int.tryParse(poleIdC.text);
                  if (poleId != null) {
                    context.read<PAComplaintBloc>().add(
                      ResolvePAComplaint(complaint.id, poleId),
                    );
                    Navigator.pop(ctx);
                  }
                },
                child: const Text('Resolve'),
              ),
            ],
          ),
    );
  }
}
