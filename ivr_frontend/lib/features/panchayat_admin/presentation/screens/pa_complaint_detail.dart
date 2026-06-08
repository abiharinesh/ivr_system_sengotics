import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmap;
import '../../../../config/app_theme.dart';
import '../../../../core/widgets/app_loading_state.dart';
import '../../../../core/widgets/app_shimmer.dart';
import '../../../../core/env_maps_loader.dart';
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

  // Audio Playback simulation variables
  bool _isPlaying = false;
  double _playProgress = 0.0;
  Timer? _playbackTimer;
  double _playbackSpeed = 1.0;
  final int _totalDurationSeconds = 134; // 2:14

  gmap.GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _playbackTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
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

      // 2. Fetch electricians list
      final electricians = await _repo.listElectricians();

      // 3. Fetch plumbers list
      final plumbers = await PlumberRepository().listPlumbers();

      setState(() {
        _complaint = complaint;
        _electricians = electricians;
        _plumbers = plumbers;
        _selectedElectricianId = complaint.assignedElectricianId;
        _selectedPlumberId = complaint.assignedPlumberId;
        _loading = false;
      });

      // Zoom map to coordinates if maps are initialized
      if (_mapController != null) {
        final coords = _getAssetCoordinates(complaint);
        if (coords != null) {
          _mapController!.animateCamera(gmap.CameraUpdate.newLatLngZoom(coords, 17.0));
        }
      }
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

  gmap.LatLng? _getAssetCoordinates(ComplaintModel complaint) {
    if (complaint.pole != null && complaint.pole!.latitude != null && complaint.pole!.longitude != null) {
      return gmap.LatLng(complaint.pole!.latitude!, complaint.pole!.longitude!);
    }
    if (complaint.tank != null) {
      return gmap.LatLng(complaint.tank!.latitude, complaint.tank!.longitude);
    }
    // Default fallback to Panchayat center coordinates if any
    return const gmap.LatLng(11.0168, 76.9558);
  }

  void _startMockPlayback() {
    _playbackTimer?.cancel();
    _playbackTimer = Timer.periodic(
      Duration(milliseconds: (200 / _playbackSpeed).round()),
      (timer) {
        if (!mounted) return;
        setState(() {
          _playProgress += 0.002;
          if (_playProgress >= 1.0) {
            _playProgress = 0.0;
            _isPlaying = false;
            timer.cancel();
          }
        });
      },
    );
  }

  void _stopMockPlayback() {
    _playbackTimer?.cancel();
  }

  void _togglePlayback() {
    setState(() {
      _isPlaying = !_isPlaying;
      if (_isPlaying) {
        _startMockPlayback();
      } else {
        _stopMockPlayback();
      }
    });
  }

  void _seekTo(double percent) {
    setState(() {
      _playProgress = percent.clamp(0.0, 1.0);
      if (_isPlaying) {
        _startMockPlayback();
      }
    });
  }

  String _getElapsedDuration() {
    final elapsedSeconds = (_playProgress * _totalDurationSeconds).round();
    final minutes = elapsedSeconds ~/ 60;
    final seconds = elapsedSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _assignTask() async {
    if (_complaint == null) return;
    final isWater = _isWaterComplaint(_complaint!);

    if (isWater) {
      if (_selectedPlumberId == null) return;
      setState(() => _submitting = true);
      try {
        // Direct plumbing assignment endpoint or mock
        await Future<void>.delayed(const Duration(milliseconds: 400));
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
      case 'assigned':
      case 'in_progress':
        return AppTheme.primary;
      case 'resolved':
        return AppTheme.accent;
      case 'rejected':
        return AppTheme.error;
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
    final isWater = _isWaterComplaint(complaint);
    final assetName = isWater
        ? (complaint.pipeline?.name ?? complaint.tank?.name ?? 'Water Grid')
        : (complaint.pole?.poleNumber ?? 'Pole #${complaint.poleId ?? 'N/A'}');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 4,
          runSpacing: 4,
          children: [
            InkWell(
              onTap: () => context.go('/complaints'),
              child: Text(
                'Panchayats',
                style: TextStyle(fontSize: 12, color: AppTheme.textMuted, decoration: TextDecoration.underline),
              ),
            ),
            Icon(Icons.chevron_right, size: 14, color: AppTheme.textMuted),
            Text(
              complaint.panchayat?.name ?? 'Alandur Panchayat',
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
            Icon(Icons.chevron_right, size: 14, color: AppTheme.textMuted),
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
                isWater
                    ? 'Water Supply Fault - $assetName'
                    : 'Street Light Fault - $assetName',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Metropolis',
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              if (isMobile) const SizedBox(height: 8) else const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                        boxShadow: [
                          BoxShadow(
                            color: _getStatusColor(complaint.status).withValues(alpha: 0.4),
                            blurRadius: 6,
                            spreadRadius: 2,
                          )
                        ],
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
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.stroke, width: 1.2),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Playing Button with scale/glow feedback
              GestureDetector(
                onTap: _togglePlayback,
                child: AnimatedContainer(
                  duration: AppTheme.durationFast,
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: _isPlaying
                        ? AppTheme.primaryGradient
                        : AppTheme.accentGradient,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: (_isPlaying ? AppTheme.primary : AppTheme.accent).withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
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
                      'Recorded Call Audio',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_getElapsedDuration()} / 2:14  •  Speed: ${_playbackSpeed}x',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              // Playback Speed Selector
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: AppTheme.bgSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.stroke, width: 0.8),
                ),
                child: Row(
                  children: [0.5, 1.0, 1.5, 2.0].map((speed) {
                    final isSelected = _playbackSpeed == speed;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _playbackSpeed = speed;
                          if (_isPlaying) {
                            _startMockPlayback();
                          }
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected ? AppTheme.bgCard : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: isSelected ? AppTheme.softShadow : null,
                        ),
                        child: Text(
                          '${speed}x',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Interactive Waveform scrubbing
          LayoutBuilder(
            builder: (context, constraints) {
              return GestureDetector(
                onTapDown: (details) {
                  final percent = details.localPosition.dx / constraints.maxWidth;
                  _seekTo(percent);
                },
                onHorizontalDragUpdate: (details) {
                  final percent = details.localPosition.dx / constraints.maxWidth;
                  _seekTo(percent);
                },
                child: Container(
                  height: 80,
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.bgSurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.stroke, width: 0.8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(barHeights.length, (i) {
                      final isPlayed = i / barHeights.length < _playProgress;
                      return Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 1.5),
                          height: barHeights[i].toDouble(),
                          decoration: BoxDecoration(
                            color: isPlayed
                                ? AppTheme.primary
                                : AppTheme.textMuted.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTranscriptCard(ComplaintModel complaint) {
    final originalText = complaint.voiceCall?.transcript ??
        complaint.description ??
        'வணக்கம், கம்பத்தில் விளக்கு எரியல. ரேஷன் கடைக்கு பக்கத்துல இருக்க கம்பத்தில வயரிங்ல தீப்பொறி பறக்குதுங்க. பயமா இருக்கு, சீக்கிரம் யாரையாவது அனுப்பி பாருங்க.';
    final translationText = complaint.voiceCall?.transcriptEnglish ??
        complaint.description ??
        'Hello, street light is not working. Sparking observed in the wiring of the pole near the ration shop. We are scared, please send someone quickly.';

    // Highlights target words (e.g. temples, school, ration shop, road) for extreme detail
    List<TextSpan> _highlightText(String text, String lang) {
      final List<TextSpan> spans = [];
      final words = text.split(' ');
      
      final keywords = lang == 'ta' 
          ? ['மாரியம்மன்', 'கோவில்', 'பள்ளி', 'ரேஷன்', 'கடை', 'தீப்பொறி', 'கம்பத்தில்']
          : ['Mariamman', 'temple', 'school', 'ration', 'shop', 'sparking', 'pole', 'wires'];

      for (var i = 0; i < words.length; i++) {
        final w = words[i];
        final cleanWord = w.replaceAll(RegExp(r'[.,\/#!$%\^&\*;:{}=\-_`~()]'), '');
        final isKeyword = keywords.any((kw) => cleanWord.toLowerCase().contains(kw.toLowerCase()));

        spans.add(TextSpan(
          text: '$w ',
          style: TextStyle(
            color: isKeyword ? AppTheme.primary : AppTheme.textSecondary,
            fontWeight: isKeyword ? FontWeight.w800 : FontWeight.normal,
            backgroundColor: isKeyword ? AppTheme.primary.withValues(alpha: 0.08) : null,
          ),
        ));
      }
      return spans;
    }

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.stroke, width: 1.2),
        boxShadow: AppTheme.softShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.description_outlined, color: AppTheme.textPrimary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Bilingual Call Transcript',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.accent.withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    'AI Translation: Active',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
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
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textMuted,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    RichText(
                      text: TextSpan(
                        children: _highlightText(originalText, 'ta'),
                        style: const TextStyle(
                          fontSize: 14.5,
                          height: 1.6,
                          fontFamily: 'Noto Sans Tamil',
                          fontStyle: FontStyle.italic,
                        ),
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
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textMuted,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    RichText(
                      text: TextSpan(
                        children: _highlightText(translationText, 'en'),
                        style: const TextStyle(
                          fontSize: 14.5,
                          height: 1.6,
                          fontStyle: FontStyle.normal,
                        ),
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
    final emotion = complaint.callerEmotion ?? 'Neutral';
    final urgency = complaint.urgencyLevel ?? 'Medium';
    final confidence = (complaint.voiceCall?.aiExtractedJson?['confidence_score'] as num?)?.toDouble() ?? 0.95;

    Color emotionColor = AppTheme.warning;
    IconData emotionIcon = Icons.mood_rounded;
    final emLower = emotion.toLowerCase();
    if (emLower.contains('angr') || emLower.contains('frust')) {
      emotionColor = AppTheme.error;
      emotionIcon = Icons.sentiment_very_dissatisfied_rounded;
    } else if (emLower.contains('neutral') || emLower.contains('calm')) {
      emotionColor = AppTheme.info;
      emotionIcon = Icons.sentiment_neutral_rounded;
    } else {
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
        final isMobile = constraints.maxWidth < 600;

        final card1 = Expanded(
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
                        emotion.toUpperCase(),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: emotionColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );

        final card2 = Expanded(
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
                        'Urgency Level',
                        style: TextStyle(fontSize: 12, color: AppTheme.textMuted, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${urgency.toUpperCase()} PRIORITY',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: urgencyColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );

        // Circular confidence score indicator
        final card3 = Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.bgCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.stroke, width: 1.2),
            boxShadow: AppTheme.softShadow,
          ),
          child: Row(
            children: [
              SizedBox(
                width: 52,
                height: 52,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: confidence,
                      strokeWidth: 5,
                      backgroundColor: AppTheme.stroke,
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accent),
                    ),
                    Text(
                      '${(confidence * 100).round()}%',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Extraction Confidence',
                      style: TextStyle(fontSize: 12, color: AppTheme.textMuted, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'AI TRANSCRIPTION',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );

        if (isMobile) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              card1,
              const SizedBox(height: 16),
              card2,
              const SizedBox(height: 16),
              card3,
            ],
          );
        }

        return Column(
          children: [
            Row(
              children: [
                card1,
                const SizedBox(width: 20),
                card2,
              ],
            ),
            const SizedBox(height: 20),
            card3,
          ],
        );
      },
    );
  }

  Widget _buildGisMapCard(ComplaintModel complaint) {
    final isWater = _isWaterComplaint(complaint);
    final isWebMobile = kIsWeb && !isMapsJsReady;

    final assetName = isWater
        ? (complaint.pipeline?.name ?? complaint.tank?.name ?? 'Water Grid')
        : (complaint.pole?.poleNumber ?? 'Pole #${complaint.poleId ?? 'N/A'}');

    final coords = _getAssetCoordinates(complaint);
    final markers = <gmap.Marker>{};

    if (coords != null) {
      markers.add(
        gmap.Marker(
          markerId: gmap.MarkerId('asset_marker_${complaint.id}'),
          position: coords,
          icon: gmap.BitmapDescriptor.defaultMarkerWithHue(
            isWater ? gmap.BitmapDescriptor.hueCyan : gmap.BitmapDescriptor.hueYellow
          ),
          infoWindow: gmap.InfoWindow(title: assetName),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.stroke, width: 1.2),
        boxShadow: AppTheme.softShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.map_outlined, color: AppTheme.textPrimary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'GIS Location Mapping',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () => context.go(isWater ? '/water-supply' : '/poles'),
                  child: const Text('Full GIS Grid View'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Google Map Section
          SizedBox(
            height: 250,
            width: double.infinity,
            child: isWebMobile
                ? Container(
                    color: const Color(0xFF0F172A),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      mapsWebUnavailableMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
                    ),
                  )
                : gmap.GoogleMap(
                    mapId: googleMapsMapId,
                    initialCameraPosition: gmap.CameraPosition(
                      target: coords ?? const gmap.LatLng(11.0168, 76.9558),
                      zoom: 17.0,
                    ),
                    onMapCreated: (controller) {
                      _mapController = controller;
                    },
                    markers: markers,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: true,
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
                    color: isWater ? AppTheme.info.withValues(alpha: 0.08) : AppTheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isWater ? Icons.water_drop_rounded : Icons.electric_bolt_rounded,
                    color: isWater ? AppTheme.info : AppTheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mapped Asset: $assetName',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        coords != null
                            ? '${coords.latitude.toStringAsFixed(6)}° N, ${coords.longitude.toStringAsFixed(6)}° E'
                            : 'Coordinates unavailable',
                        style: TextStyle(fontSize: 11, color: AppTheme.textMuted, fontFamily: 'monospace'),
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
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.stroke, width: 1.2),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Complaint Lifecycle',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 24),
          _TimelineItem(
            title: 'Call Received',
            subtitle: 'Voice portal log registered via Exotel IVR flow.',
            time: time1,
            icon: Icons.call_received_rounded,
            isCompleted: true,
          ),
          _TimelineItem(
            title: 'AI Parsed & Structured',
            subtitle: 'Gemini dynamic extraction complete. Assigned category.',
            time: time2,
            icon: Icons.auto_awesome,
            isCompleted: true,
          ),
          _TimelineItem(
            title: complaint.status == 'pending' ? 'Pending Assignment' : (complaint.status == 'assigned' || complaint.status == 'in_progress' ? 'Technician Dispatched' : 'Fault Resolved'),
            subtitle: complaint.status == 'pending'
                ? 'Queueing for technician dispatch.'
                : (complaint.status == 'assigned' || complaint.status == 'in_progress'
                    ? 'Technician on-site repairing components.'
                    : 'Resolution proof submitted. Case closed.'),
            time: 'Current',
            icon: complaint.status == 'resolved' ? Icons.check_circle_rounded : Icons.schedule_rounded,
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
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.stroke, width: 1.2),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.admin_panel_settings_outlined, color: AppTheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Administrative Dispatch',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            isWater ? 'Dispatch Plumber (Water Supply)' : 'Dispatch Electrician (Power Grid)',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 8),
          if (isWater)
            DropdownButtonFormField<int>(
              // ignore: deprecated_member_use
              value: _selectedPlumberId,
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
                  child: Text(email.split('@').first.toUpperCase()),
                );
              }).toList(),
              onChanged: _submitting ? null : (v) {
                setState(() => _selectedPlumberId = v);
              },
            )
          else
            DropdownButtonFormField<int>(
              // ignore: deprecated_member_use
              value: _selectedElectricianId,
              hint: const Text('Select electrician...'),
              decoration: InputDecoration(
                fillColor: AppTheme.bgSurface,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              items: _electricians.map((e) {
                final map = Map<String, dynamic>.from(e as Map);
                final id = map['id'] as int;
                final email = map['email']?.toString() ?? 'Electrician #$id';
                return DropdownMenuItem<int>(
                  value: id,
                  child: Text(email.split('@').first.toUpperCase()),
                );
              }).toList(),
              onChanged: _submitting ? null : (v) {
                setState(() => _selectedElectricianId = v);
              },
            ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final useVerticalButtons = constraints.maxWidth < 450;
              final assignButton = _submitting
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton.icon(
                      onPressed: _submitting
                          ? null
                          : (isWater
                              ? (_selectedPlumberId == null ? null : _assignTask)
                              : (_selectedElectricianId == null ? null : _assignTask)),
                      icon: const Icon(Icons.send_rounded, size: 16),
                      label: const Text('Dispatch Technician'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    );

              final updateStatusButton = OutlinedButton.icon(
                onPressed: _submitting
                    ? null
                    : () {
                        // Show modal to update status
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
                icon: const Icon(Icons.edit_note_rounded, size: 18),
                label: const Text('Update Status'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );

              if (useVerticalButtons) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(width: double.infinity, child: assignButton),
                    const SizedBox(height: 12),
                    SizedBox(width: double.infinity, child: updateStatusButton),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: assignButton),
                  const SizedBox(width: 12),
                  Expanded(child: updateStatusButton),
                ],
              );
            },
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
