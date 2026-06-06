import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../../../config/app_theme.dart';
import '../../../../core/widgets/app_loading_state.dart';
import '../../../../core/widgets/app_shimmer.dart';
import '../../../super_admin/data/models/complaint_model.dart';
import '../../data/panchayat_admin_repository.dart';
import '../../../plumber/data/plumber_repository.dart';


class PAComplaintDetailScreen extends StatefulWidget {
  final int complaintId;
  final bool embedMode;

  const PAComplaintDetailScreen({
    super.key,
    required this.complaintId,
    this.embedMode = false,
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
  List<dynamic> _plumbers = [];
  int? _selectedPlumberId;
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

      // 3. Fetch plumbers list
      final plumbers = await PlumberRepository().listPlumbers();

      setState(() {
        _complaint = complaint;
        _electricians = electricians;
        _plumbers = plumbers;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
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

  Future<void> _assignTask() async {
    if (_complaint == null) return;
    final isWater = _isWaterComplaint(_complaint!);

    if (isWater) {
      if (_selectedPlumberId == null) return;
      setState(() => _submitting = true);
      try {
        // Mock plumber assignment response
        await Future<void>.delayed(const Duration(milliseconds: 300));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Plumber assigned successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
        await _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to assign plumber: $e'),
              backgroundColor: AppTheme.error,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _submitting = false);
      }
    } else {
      if (_selectedElectricianId == null) return;
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

  Widget _buildLoadingDashboard(BuildContext context) {
    final padding = widget.embedMode ? 16.0 : (MediaQuery.sizeOf(context).width < 600 ? 12.0 : 24.0);
    final w = MediaQuery.sizeOf(context).width;
    final isDesktop = w >= (widget.embedMode ? 850 : 1024);

    final loadingHeader = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Panchayats', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 14, color: AppTheme.textMuted),
            const SizedBox(width: 4),
            const AppShimmer.rectangular(width: 100, height: 12),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const AppShimmer.rectangular(width: 300, height: 26),
            const Spacer(),
            AppShimmer.rounded(width: 120, height: 32),
          ],
        )
      ],
    );

    final leftColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 180,
          decoration: BoxDecoration(
            color: AppTheme.bgCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.stroke, width: 1.2),
          ),
          child: const AppLoadingState(message: 'Loading call audio...', style: AppLoadingStyle.detail),
        ),
        const SizedBox(height: 24),
        Container(
          height: 200,
          decoration: BoxDecoration(
            color: AppTheme.bgCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.stroke, width: 1.2),
          ),
          child: const AppLoadingState(message: 'Loading transcript...', style: AppLoadingStyle.detail),
        ),
        const SizedBox(height: 24),
        Container(
          height: 150,
          decoration: BoxDecoration(
            color: AppTheme.bgCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.stroke, width: 1.2),
          ),
          child: const AppLoadingState(message: 'Loading AI insights...', style: AppLoadingStyle.detail),
        ),
      ],
    );

    final rightColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 250,
          decoration: BoxDecoration(
            color: AppTheme.bgCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.stroke, width: 1.2),
          ),
          child: const AppLoadingState(message: 'Loading GIS location...', style: AppLoadingStyle.detail),
        ),
        const SizedBox(height: 24),
        Container(
          height: 200,
          decoration: BoxDecoration(
            color: AppTheme.bgCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.stroke, width: 1.2),
          ),
          child: const AppLoadingState(message: 'Loading timeline history...', style: AppLoadingStyle.detail),
        ),
        const SizedBox(height: 24),
        Container(
          height: 180,
          decoration: BoxDecoration(
            color: AppTheme.bgCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.stroke, width: 1.2),
          ),
          child: const AppLoadingState(message: 'Loading actions...', style: AppLoadingStyle.detail),
        ),
      ],
    );

    final Widget bodyContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!widget.embedMode) ...[
          loadingHeader,
          const SizedBox(height: 24),
        ],
        if (isDesktop)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 7, child: leftColumn),
              const SizedBox(width: 24),
              Expanded(flex: 5, child: rightColumn),
            ],
          )
        else
          Column(
            children: [leftColumn, const SizedBox(height: 24), rightColumn],
          ),
      ],
    );

    if (widget.embedMode) {
      return SingleChildScrollView(
        padding: EdgeInsets.all(padding),
        child: bodyContent,
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: SingleChildScrollView(
        padding: EdgeInsets.all(padding),
        child: bodyContent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return widget.embedMode
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_error!, style: TextStyle(color: AppTheme.textSecondary)),
              ),
            )
          : Scaffold(
              backgroundColor: AppTheme.bgDark,
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(
                      _error!,
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

    if (_loading || _complaint == null) {
      return _buildLoadingDashboard(context);
    }

    final complaint = _complaint!;
    final padding = widget.embedMode ? 16.0 : (MediaQuery.sizeOf(context).width < 600 ? 12.0 : 24.0);
    final w = MediaQuery.sizeOf(context).width;
    final isDesktop = w >= (widget.embedMode ? 850 : 1024);

    final Widget contentBody = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!widget.embedMode) ...[
          _buildHeader(complaint),
          const SizedBox(height: 24),
        ],
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
    );

    if (widget.embedMode) {
      return SingleChildScrollView(
        padding: EdgeInsets.all(padding),
        child: contentBody,
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: SingleChildScrollView(
        padding: EdgeInsets.all(padding),
        child: contentBody,
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
    final barHeights = [
      20, 25, 45, 30, 15, 35, 60, 40, 25, 30, 55, 65, 40, 20, 35, 50, 45, 15, 25, 30,
      40, 60, 70, 50, 30, 20, 35, 45, 30, 15, 25, 40, 55, 60, 45, 25, 30, 35, 20, 15,
      25, 40, 50, 35, 20, 30, 45, 55, 40, 25, 15, 30, 35, 20
    ];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.stroke, width: 1.2),
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
                borderRadius: BorderRadius.circular(30),
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: _isPlaying
                        ? AppTheme.primaryGradient
                        : AppTheme.accentGradient,
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
                      'Recorded Call Summary #${complaint.voiceCallId ?? complaint.id}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isPlaying ? '0:47 / 2:14' : '0:00 / 2:14',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textMuted,
                      ),
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
          Container(
            height: 80,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.bgSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.stroke, width: 0.8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(barHeights.length, (i) {
                final isPlayed = _isPlaying && (i / barHeights.length < 0.35);
                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                    height: barHeights[i].toDouble(),
                    decoration: BoxDecoration(
                      color: isPlayed ? AppTheme.primary : AppTheme.textMuted.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }),
            ),
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.stroke, width: 1.2),
        boxShadow: AppTheme.softShadow,
      ),
      clipBehavior: Clip.antiAlias,
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
                      'Interactive Call Transcript',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.accent.withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    'AI Transcription: 98% Accuracy',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.accent,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          LayoutBuilder(
            builder: (context, constraints) {
              final isTwoCol = constraints.maxWidth > 600;

              final leftCol = Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'TA',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primary),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'TAMIL (ORIGINAL)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textMuted,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
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
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.accent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'EN',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.accent),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'ENGLISH (TRANSLATION)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textMuted,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
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
                          border: Border(right: BorderSide(color: AppTheme.stroke, width: 1)),
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

    Color emotionColor = AppTheme.warning;
    IconData emotionIcon = Icons.mood_rounded;
    final emLower = emotion.toLowerCase();
    if (emLower.contains('angr') || emLower.contains('frust')) {
      emotionColor = AppTheme.error;
      emotionIcon = Icons.sentiment_very_dissatisfied_rounded;
    } else if (emLower.contains('neutral') || emLower.contains('calm')) {
      emotionColor = AppTheme.info;
      emotionIcon = Icons.sentiment_neutral_rounded;
    } else if (emLower.contains('happ') || emLower.contains('thank')) {
      emotionColor = AppTheme.accent;
      emotionIcon = Icons.sentiment_satisfied_alt_rounded;
    }

    Color urgencyColor = AppTheme.info;
    final urgLower = urgency.toLowerCase();
    if (urgLower.contains('high') || urgLower.contains('crit')) {
      urgencyColor = AppTheme.error;
    } else if (urgLower.contains('med')) {
      urgencyColor = AppTheme.warning;
    } else {
      urgencyColor = AppTheme.accent;
    }

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
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.stroke, width: 1.2),
                boxShadow: AppTheme.softShadow,
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: emotionColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: emotionColor.withValues(alpha: 0.15), width: 1),
                    ),
                    child: Icon(
                      emotionIcon,
                      color: emotionColor,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Caller Emotion',
                          style: TextStyle(fontSize: 12, color: AppTheme.textMuted, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          emotion,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: emotionColor,
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
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.stroke, width: 1.2),
                boxShadow: AppTheme.softShadow,
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: urgencyColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: urgencyColor.withValues(alpha: 0.15), width: 1),
                    ),
                    child: Icon(
                      Icons.priority_high_rounded,
                      color: urgencyColor,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AI Urgency Priority',
                          style: TextStyle(fontSize: 12, color: AppTheme.textMuted, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$urgency Priority',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: urgencyColor,
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
    final isWater = _isWaterComplaint(complaint);
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
            isWater ? 'Assign Plumber' : 'Assign Electrician',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 8),
          if (isWater)
            DropdownButtonFormField<int>(
              initialValue: _selectedPlumberId,
              hint: const Text('Select plumber...'),
              decoration: InputDecoration(
                fillColor: AppTheme.bgSurface,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              items: _plumbers.map((e) {
                final map = Map<String, dynamic>.from(e as Map);
                final id = map['id'] as int;
                final email = map['email']?.toString() ?? 'Plumber #$id';
                return DropdownMenuItem<int>(
                  value: id,
                  child: Text(email.split('@').first),
                );
              }).toList(),
              onChanged: (v) {
                setState(() => _selectedPlumberId = v);
              },
            )
          else
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
                        onPressed: isWater
                            ? (_selectedPlumberId == null ? null : _assignTask)
                            : (_selectedElectricianId == null ? null : _assignTask),
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
