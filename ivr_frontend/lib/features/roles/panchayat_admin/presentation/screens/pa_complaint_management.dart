import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:ivr_frontend/config/app_theme.dart';
import 'package:ivr_frontend/core/widgets/app_loading_state.dart';
import 'package:ivr_frontend/core/widgets/assign_electrician_dialog.dart';
import 'package:ivr_frontend/core/widgets/assign_plumber_dialog.dart';
import 'package:ivr_frontend/core/widgets/empty_state.dart';
import 'package:ivr_frontend/core/widgets/list_screen_shell.dart';
import 'package:ivr_frontend/core/widgets/pole_picker_dialog.dart';
import 'package:ivr_frontend/core/widgets/status_badge.dart';
import 'package:ivr_frontend/features/roles/super_admin/data/models/complaint_model.dart';
import 'package:ivr_frontend/features/roles/panchayat_admin/data/panchayat_admin_repository.dart';
import 'package:ivr_frontend/features/roles/panchayat_admin/bloc/pa_complaint_bloc.dart';
import 'pa_complaint_detail.dart';

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
  int? _selectedComplaintId;

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
          final isWide = constraints.maxWidth > 950;
          final hPad = constraints.maxWidth < 400 ? 12.0 : 24.0;

          if (isWide) {
            if (_selectedComplaintId == null && filtered.isNotEmpty) {
              _selectedComplaintId = filtered.first.id;
            } else if (_selectedComplaintId != null && !filtered.any((c) => c.id == _selectedComplaintId)) {
              _selectedComplaintId = filtered.isNotEmpty ? filtered.first.id : null;
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 380,
                  child: ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 8),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final c = filtered[index];
                      final isSelected = c.id == _selectedComplaintId;
                      return _PAComplaintCard(
                        complaint: c,
                        isSelected: isSelected,
                        onTap: () {
                          setState(() {
                            _selectedComplaintId = c.id;
                          });
                        },
                      );
                    },
                  ),
                ),
                VerticalDivider(width: 1, color: AppTheme.stroke, thickness: 1),
                Expanded(
                  child: _selectedComplaintId != null
                      ? PAComplaintDetailScreen(
                          key: ValueKey(_selectedComplaintId),
                          complaintId: _selectedComplaintId!,
                          embedMode: true,
                        )
                      : Center(
                          child: Text(
                            'Select a complaint to view details',
                            style: TextStyle(color: AppTheme.textMuted, fontSize: 16),
                          ),
                        ),
                ),
              ],
            );
          }

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

class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 10 + (_controller.value * 14),
              height: 10 + (_controller.value * 14),
              decoration: BoxDecoration(
                color: widget.color.withValues(alpha: 1.0 - _controller.value),
                shape: BoxShape.circle,
              ),
            ),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: widget.color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PAComplaintCard extends StatefulWidget {
  final ComplaintModel complaint;
  final bool isSelected;
  final VoidCallback? onTap;

  const _PAComplaintCard({
    required this.complaint,
    this.isSelected = false,
    this.onTap,
  });

  @override
  State<_PAComplaintCard> createState() => _PAComplaintCardState();
}

class _PAComplaintCardState extends State<_PAComplaintCard> {
  bool _isHovered = false;

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

  bool _isWaterComplaint(ComplaintModel c) {
    final type = (c.complaintType ?? '').toLowerCase();
    final desc = (c.description ?? '').toLowerCase();
    return type.contains('water') ||
        type.contains('leak') ||
        type.contains('plumb') ||
        type.contains('pipe') ||
        type.contains('valve') ||
        type.contains('tank') ||
        type.contains('borewell') ||
        type.contains('pump') ||
        desc.contains('water') ||
        desc.contains('leak') ||
        desc.contains('plumb') ||
        desc.contains('pipe');
  }

  @override
  Widget build(BuildContext context) {
    final complaint = widget.complaint;
    final isSelected = widget.isSelected;
    final dateStr = DateFormat('MMM d – h:mm a').format(complaint.createdAt);
    final sColor = _statusColor(complaint.status);
    final isWater = _isWaterComplaint(complaint);

    // Get color for urgency
    Color? urgencyColor;
    bool showPulse = false;
    if (complaint.urgencyLevel != null) {
      final ul = complaint.urgencyLevel!.toLowerCase();
      if (ul.contains('high') || ul.contains('crit')) {
        urgencyColor = AppTheme.error;
        showPulse = true;
      } else if (ul.contains('med')) {
        urgencyColor = AppTheme.warning;
      } else {
        urgencyColor = AppTheme.accent;
      }
    }

    if (complaint.status == 'pending') {
      showPulse = true;
    }

    // Get color for emotion
    Color? emotionColor;
    IconData emotionIcon = Icons.mood_rounded;
    if (complaint.callerEmotion != null) {
      final em = complaint.callerEmotion!.toLowerCase();
      if (em.contains('angr') || em.contains('frust')) {
        emotionColor = AppTheme.error;
        emotionIcon = Icons.sentiment_very_dissatisfied_rounded;
      } else if (em.contains('neutral') || em.contains('calm')) {
        emotionColor = AppTheme.info;
        emotionIcon = Icons.sentiment_neutral_rounded;
      } else {
        emotionColor = AppTheme.accent;
        emotionIcon = Icons.sentiment_satisfied_alt_rounded;
      }
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: AppTheme.durationFast,
        margin: const EdgeInsets.only(bottom: 16),
        transform: Matrix4.translationValues(0, _isHovered ? -4 : 0, 0),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppTheme.primary
                : (_isHovered ? AppTheme.strokeStrong : AppTheme.stroke),
            width: isSelected ? 2.2 : 1.2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.18),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  )
                ]
              : (_isHovered
                  ? [
                      BoxShadow(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      )
                    ]
                  : AppTheme.softShadow),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap ?? () => context.go('/complaints/${complaint.id}'),
          borderRadius: BorderRadius.circular(20),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left dynamic gradient border strip
                Container(
                  width: 8,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [sColor, sColor.withValues(alpha: 0.4)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top ID & Badges row
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.bgSurface,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppTheme.stroke, width: 0.8),
                              ),
                              child: Text(
                                '#${complaint.id}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontFamily: 'monospace',
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (showPulse)
                              _PulsingDot(color: urgencyColor ?? AppTheme.warning),
                            const SizedBox(width: 6),
                            StatusBadge(status: complaint.status),
                            const Spacer(),
                            PopupMenuButton<String>(
                              icon: Icon(Icons.more_vert_rounded, color: AppTheme.textMuted, size: 20),
                              tooltip: 'Quick actions',
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
                        // Description
                        if (complaint.description != null)
                          Text(
                            complaint.description!,
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 14,
                              height: 1.45,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        const SizedBox(height: 14),
                        // Category & asset type badge
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isWater
                                    ? AppTheme.info.withValues(alpha: 0.08)
                                    : const Color(0xFF8B5CF6).withValues(alpha: 0.08),
                                border: Border.all(
                                  color: isWater
                                      ? AppTheme.info.withValues(alpha: 0.25)
                                      : const Color(0xFF8B5CF6).withValues(alpha: 0.25),
                                  width: 0.8,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isWater ? Icons.opacity_rounded : Icons.flash_on_rounded,
                                    size: 11,
                                    color: isWater ? AppTheme.info : const Color(0xFF8B5CF6),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    isWater ? 'WATER SUPPLY' : 'ELECTRICITY',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: isWater ? AppTheme.info : const Color(0xFF8B5CF6),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
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
                            if (complaint.callerEmotion != null)
                              _infoItem(
                                emotionIcon,
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
                        // Speech Bubble summary preview
                        if (complaint.voiceCall?.transcriptEnglish != null) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.bgSurface.withValues(alpha: 0.6),
                              borderRadius: const BorderRadius.only(
                                topRight: Radius.circular(16),
                                bottomRight: Radius.circular(16),
                                bottomLeft: Radius.circular(16),
                              ),
                              border: Border.all(color: AppTheme.stroke, width: 0.8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.auto_awesome, size: 12, color: AppTheme.primaryLight),
                                    const SizedBox(width: 6),
                                    Text(
                                      'AI SUMMARY',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        color: AppTheme.primaryLight,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  complaint.voiceCall!.transcriptEnglish!,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: AppTheme.textSecondary,
                                    height: 1.4,
                                    fontStyle: FontStyle.italic,
                                  ),
                                  maxLines: 2,
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
              ],
            ),
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
          color: textColor?.withValues(alpha: 0.15) ?? AppTheme.stroke,
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: textColor ?? AppTheme.textMuted),
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
        ResolvePAComplaint(widget.complaint.id, selected.id),
      );
    } catch (err) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load poles: $err')),
      );
    }
  }
}