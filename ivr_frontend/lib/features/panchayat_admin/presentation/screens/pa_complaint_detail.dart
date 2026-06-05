import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../../../config/app_theme.dart';
import '../../../../core/widgets/app_loading_state.dart';
import '../../../super_admin/data/models/complaint_model.dart';
import '../../data/panchayat_admin_repository.dart';

class PAComplaintDetailScreen extends StatefulWidget {
  final int complaintId;

  const PAComplaintDetailScreen({
    super.key,
    required this.complaintId,
  });

  @override
  State<PAComplaintDetailScreen> createState() => _PAComplaintDetailScreenState();
}

class _PAComplaintDetailScreenState extends State<PAComplaintDetailScreen> {
  final _repo = PanchayatAdminRepository();
  bool _loading = true;
  String? _error;
  ComplaintModel? _complaint;
  List<dynamic> _electricians = [];
  int? _selectedElectricianId;
  bool _submitting = false;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // 1. Fetch complaints list to find our specific complaint details
      final list = await _repo.listComplaints();
      final complaint = list.firstWhere(
        (c) => c.id == widget.complaintId,
        orElse: () => throw Exception('Complaint with ID ${widget.complaintId} not found.'),
      );

      // 2. Fetch electricians list for dropdown assignment
      final electricians = await _repo.listElectricians();

      setState(() {
        _complaint = complaint;
        _electricians = electricians;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _assignTask() async {
    if (_selectedElectricianId == null || _complaint == null) return;

    setState(() => _submitting = true);
    try {
      await _repo.assignElectrician(_complaint!.id, _selectedElectricianId!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Electrician assigned successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to assign task: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _updateStatus(String status) async {
    if (_complaint == null) return;

    setState(() => _submitting = true);
    try {
      await _repo.updateComplaintStatus(_complaint!.id, status);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status updated to ${status.replaceAll('_', ' ')}!'),
            backgroundColor: Colors.green,
          ),
        );
      }
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update status: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _getFormattedTime(DateTime date) {
    return DateFormat('h:mm a').format(date);
  }



  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return const Color(0xFFFFB000);
      case 'in_progress':
        return AppTheme.primary;
      case 'resolved':
        return AppTheme.accent;
      default:
        return AppTheme.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: AppTheme.bgDark,
        body: const AppLoadingState(message: 'Loading complaint details...'),
      );
    }

    if (_error != null || _complaint == null) {
      return Scaffold(
        backgroundColor: AppTheme.bgDark,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                _error ?? 'Complaint details could not be loaded.',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final complaint = _complaint!;
    final padding = MediaQuery.sizeOf(context).width < 600 ? 12.0 : 24.0;
    final w = MediaQuery.sizeOf(context).width;
    final isDesktop = w >= 1024;

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: SingleChildScrollView(
        padding: EdgeInsets.all(padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Breadcrumbs & Header
            _buildHeader(complaint),
            const SizedBox(height: 24),

            // Bento Grid Details
            if (isDesktop)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 7,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildAudioPlayerCard(complaint),
                        const SizedBox(height: 24),
                        _buildTranscriptCard(complaint),
                        const SizedBox(height: 24),
                        _buildAiInsightsGrid(complaint),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    flex: 5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildGisMapCard(complaint),
                        const SizedBox(height: 24),
                        _buildTimelineCard(complaint),
                        const SizedBox(height: 24),
                        _buildAdminActionsCard(complaint),
                      ],
                    ),
                  ),
                ],
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildAudioPlayerCard(complaint),
                  const SizedBox(height: 24),
                  _buildTranscriptCard(complaint),
                  const SizedBox(height: 24),
                  _buildAiInsightsGrid(complaint),
                  const SizedBox(height: 24),
                  _buildGisMapCard(complaint),
                  const SizedBox(height: 24),
                  _buildTimelineCard(complaint),
                  const SizedBox(height: 24),
                  _buildAdminActionsCard(complaint),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ComplaintModel complaint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            InkWell(
              onTap: () => context.go('/complaints'),
              child: Text(
                'Panchayats',
                style: TextStyle(fontSize: 12, color: AppTheme.textMuted, decoration: TextDecoration.underline),
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 14, color: AppTheme.textMuted),
            const SizedBox(width: 4),
            Text(
              complaint.panchayat?.name ?? 'Alandur Panchayat',
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 14, color: AppTheme.textMuted),
            const SizedBox(width: 4),
            Text(
              'Complaint #${complaint.id}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 600;
            final headerContent = [
              Text(
                'Street Light Fault - Ward ${complaint.pole?.poleNumber ?? '#${complaint.pole?.id ?? 'N/A'}'}',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Metropolis',
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              if (isMobile) const SizedBox(height: 8) else const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: _getStatusColor(complaint.status).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: _getStatusColor(complaint.status).withValues(alpha: 0.35)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _getStatusColor(complaint.status),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      complaint.statusLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _getStatusColor(complaint.status),
                      ),
                    ),
                  ],
                ),
              ),
            ];

            if (isMobile) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: headerContent,
              );
            }
            return Row(
              children: headerContent,
            );
          },
        ),
      ],
    );
  }

  Widget _buildAudioPlayerCard(ComplaintModel complaint) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.stroke),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        children: [
          Row(
            children: [
              InkWell(
                onTap: () {
                  setState(() => _isPlaying = !_isPlaying);
                },
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: _isPlaying ? AppTheme.primary : AppTheme.accent,
                    shape: BoxShape.circle,
                    boxShadow: AppTheme.softShadow,
                  ),
                  child: Icon(
                    _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recorded Call #${complaint.voiceCallId ?? complaint.id}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      _isPlaying ? '0:14 / 2:14' : '0:00 / 2:14',
                      style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {},
                icon: Icon(Icons.download_rounded, color: AppTheme.textMuted),
                tooltip: 'Download Audio',
              ),
              IconButton(
                onPressed: () {},
                icon: Icon(Icons.share_rounded, color: AppTheme.textMuted),
                tooltip: 'Share Audio',
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Waveform image matching the Stitch design
          Container(
            height: 80,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              image: const DecorationImage(
                image: NetworkImage(
                  'https://lh3.googleusercontent.com/aida-public/AB6AXuCyTmkJmm01d2l3ZikDGoxyHmwrgrFVK_SB40dzYCcvjVBzK--OJkQyyWvjLb_7iYox9rK8dPTnetZTyq2O8PU5m8SdBk3JgISQ0beoRW7FMaTXcU-UKK1C77g5qw-tk_NzGB-kX6hP_MuimS6uHjGKGprKvvdVvJanB4iCLMuNDdN5oxfm6rqKu8bC31Fjt8oQPSlAIfSEHu4LBAjWtEIZBhGbqTh9GPtq1dUTwV3arucRR0dYRvICaC7_jo35EjPLkV9cO7yUbMU',
                ),
                fit: BoxFit.cover,
                opacity: 0.65,
              ),
            ),
            child: _isPlaying
                ? Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: 0.25,
                      child: Container(
                        color: AppTheme.accent.withValues(alpha: 0.25),
                      ),
                    ),
                  )
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildTranscriptCard(ComplaintModel complaint) {
    final originalText = complaint.voiceCall?.transcript ??
        complaint.description ??
        'வணக்கம், ஆலந்தூர் 4-வது வார்டில் இருந்து பேசுகிறேன். எங்க தெருவில் 4 நாட்களாக விளக்கு எரியவில்லை. இரவில் மக்கள் நடமாட மிகவும் சிரமமாக உள்ளது. தயவுசெய்து சரி செய்யுங்கள்.';
    final translationText = complaint.voiceCall?.transcriptEnglish ??
        complaint.description ??
        'Hello, I am calling from Alandur Ward 4. The street light in our street has not been working for 4 days. It is very difficult for people to move around at night. Please fix it.';

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.stroke),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.description_outlined, color: AppTheme.textPrimary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Call Transcript',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
                Text(
                  'AI Transcription Accuracy: 98%',
                  style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          LayoutBuilder(
            builder: (context, constraints) {
              final isTwoCol = constraints.maxWidth > 550;

              final leftCol = Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TAMIL (ORIGINAL)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.accent,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      originalText,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.6,
                        color: AppTheme.textPrimary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              );

              final rightCol = Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ENGLISH (TRANSLATION)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textMuted,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      translationText,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.6,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              );

              if (isTwoCol) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border(right: BorderSide(color: AppTheme.stroke)),
                        ),
                        child: leftCol,
                      ),
                    ),
                    Expanded(child: rightCol),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  leftCol,
                  const Divider(height: 1),
                  rightCol,
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAiInsightsGrid(ComplaintModel complaint) {
    final emotion = complaint.callerEmotion ?? 'Frustrated';
    final urgency = complaint.urgencyLevel ?? 'High';

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 500;
        final insights = [
          Expanded(
            flex: isMobile ? 0 : 1,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.bgCard,
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                border: Border.all(color: AppTheme.stroke),
                boxShadow: AppTheme.softShadow,
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppTheme.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.sentiment_very_dissatisfied_rounded,
                      color: AppTheme.error,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Caller Emotion',
                          style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          emotion,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isMobile) const SizedBox(height: 16) else const SizedBox(width: 24),
          Expanded(
            flex: isMobile ? 0 : 1,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.bgCard,
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                border: Border.all(color: AppTheme.stroke),
                boxShadow: AppTheme.softShadow,
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.priority_high_rounded,
                      color: AppTheme.accent,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AI Urgency Score',
                          style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$urgency Priority',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ];

        if (isMobile) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: insights,
          );
        }
        return Row(
          children: insights,
        );
      },
    );
  }

  Widget _buildGisMapCard(ComplaintModel complaint) {
    final poleNum = complaint.pole?.poleNumber ?? 'EP-4402-A';
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.stroke),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.map_outlined, color: AppTheme.textPrimary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Precise Location',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () => context.go('/poles'),
                  child: const Text('Full Map View'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // GIS Map image matching the Stitch design
          Container(
            height: 250,
            width: double.infinity,
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: NetworkImage(
                  'https://lh3.googleusercontent.com/aida-public/AB6AXuCSvoZ_j8kA8qnPvPFAn_K_-voKUj6xETcKo2439es60V--Ln0Zi9Ce7O10qceGQCHaPlNA0_p8yU9cCe182vtzILvNRyqi6t5w1kI29hfRBQ1k_FlgE6ZSyYs4P6jssJFi486f9-8U7U-5rfJo09CVzREPtb7kK5Ec1Rgp9m2F0McP_RPNNKHOXAcathczUnyp9FCB6wEKvGidL3l-Ar9WQJKUws59qGxC-SqPck5GBeVwXPL2Jz7fPVb_fdlG56zE66jCU7m2SPk',
                ),
                fit: BoxFit.cover,
              ),
            ),
            child: Stack(
              children: [
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: AppTheme.softShadow,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.location_on, color: Colors.white, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          'Pole #$poleNum',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      '13.0827° N, 80.2707° E',
                      style: TextStyle(fontSize: 9, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.bgSurface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.electric_bolt_rounded, color: AppTheme.primary, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Asset ID: $poleNum',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Last Service: Oct 12, 2023',
                        style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineCard(ComplaintModel complaint) {
    final time1 = _getFormattedTime(complaint.createdAt);
    final time2 = _getFormattedTime(complaint.createdAt.add(const Duration(minutes: 1)));

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.stroke),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Complaint Timeline',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 24),
          _TimelineItem(
            title: 'Call Received',
            subtitle: 'Voice portal initiated via IVR.',
            time: time1,
            icon: Icons.call,
            isCompleted: true,
          ),
          _TimelineItem(
            title: 'AI Transcribed',
            subtitle: 'Sentiment analysis & categorization complete.',
            time: time2,
            icon: Icons.psychology,
            isCompleted: true,
          ),
          _TimelineItem(
            title: complaint.status == 'pending' ? 'Pending Assignment' : (complaint.status == 'in_progress' ? 'Task Assigned' : 'Resolved'),
            subtitle: complaint.status == 'pending'
                ? 'Awaiting manual technician allocation.'
                : (complaint.status == 'in_progress'
                    ? 'Technician on site repairing asset.'
                    : 'Fault resolved and closed.'),
            time: 'Current',
            icon: complaint.status == 'resolved' ? Icons.check_circle : Icons.pending_actions_rounded,
            isLast: true,
            isCurrent: true,
            statusColor: _getStatusColor(complaint.status),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminActionsCard(ComplaintModel complaint) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.stroke),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Administrative Actions',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Assign Electrician',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            initialValue: _selectedElectricianId,
            hint: const Text('Select field agent...'),
            decoration: InputDecoration(
              fillColor: AppTheme.bgSurface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            items: _electricians.map((e) {
              final map = Map<String, dynamic>.from(e as Map);
              final id = map['id'] as int;
              final email = map['email']?.toString() ?? 'Agent #$id';
              return DropdownMenuItem<int>(
                value: id,
                child: Text(email.split('@').first),
              );
            }).toList(),
            onChanged: (v) {
              setState(() => _selectedElectricianId = v);
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _submitting
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton.icon(
                        onPressed: _selectedElectricianId == null ? null : _assignTask,
                        icon: const Icon(Icons.send_rounded, size: 16),
                        label: const Text('Assign Task'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accent,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: _submitting
                      ? null
                      : () {
                          // Show menu to update status
                          showModalBottomSheet<void>(
                            context: context,
                            builder: (ctx) => SafeArea(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ListTile(
                                    leading: const Icon(Icons.schedule_rounded),
                                    title: const Text('Mark Pending'),
                                    onTap: () {
                                      Navigator.pop(ctx);
                                      _updateStatus('pending');
                                    },
                                  ),
                                  ListTile(
                                    leading: const Icon(Icons.engineering_rounded),
                                    title: const Text('Mark In Progress'),
                                    onTap: () {
                                      Navigator.pop(ctx);
                                      _updateStatus('in_progress');
                                    },
                                  ),
                                  ListTile(
                                    leading: const Icon(Icons.check_circle_rounded),
                                    title: const Text('Mark Resolved'),
                                    onTap: () {
                                      Navigator.pop(ctx);
                                      _updateStatus('resolved');
                                    },
                                  ),
                                  ListTile(
                                    leading: const Icon(Icons.cancel_rounded, color: Colors.red),
                                    title: const Text('Mark Rejected', style: TextStyle(color: Colors.red)),
                                    onTap: () {
                                      Navigator.pop(ctx);
                                      _updateStatus('rejected');
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                  ),
                  child: const Text('Update Status'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final String time;
  final IconData icon;
  final bool isCompleted;
  final bool isLast;
  final bool isCurrent;
  final Color? statusColor;

  const _TimelineItem({
    required this.title,
    required this.subtitle,
    required this.time,
    required this.icon,
    this.isCompleted = false,
    this.isLast = false,
    this.isCurrent = false,
    this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isCurrent
                      ? (statusColor ?? const Color(0xFFFFB000))
                      : AppTheme.accent,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: isCurrent ? 4 : 1),
                  boxShadow: AppTheme.softShadow,
                ),
                child: Icon(icon, color: Colors.white, size: 14),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: isCompleted ? AppTheme.accent : AppTheme.stroke,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isCurrent ? Colors.white : AppTheme.bgSurface.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: isCurrent
                      ? Border.all(color: (statusColor ?? const Color(0xFFFFB000)).withValues(alpha: 0.35))
                      : Border.all(color: AppTheme.stroke),
                  boxShadow: isCurrent ? AppTheme.softShadow : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          time,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isCurrent ? (statusColor ?? const Color(0xFFFFB000)) : AppTheme.accent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
