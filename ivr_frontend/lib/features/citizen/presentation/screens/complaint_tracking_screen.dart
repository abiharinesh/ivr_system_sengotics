import 'package:flutter/material.dart';
import '../../../../config/app_theme.dart';
import '../../../../core/api/api_exceptions.dart';
import '../../data/public_report_repository.dart';

/// Public complaint tracking page. No auth required.
/// Opened via: `/public/track/:token`
class ComplaintTrackingScreen extends StatefulWidget {
  final String trackingToken;
  const ComplaintTrackingScreen({super.key, required this.trackingToken});

  @override
  State<ComplaintTrackingScreen> createState() => _ComplaintTrackingScreenState();
}

class _ComplaintTrackingScreenState extends State<ComplaintTrackingScreen>
    with SingleTickerProviderStateMixin {
  final _repo = PublicReportRepository();
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  bool _isTamil = false;
  Map<String, dynamic>? _complaint;
  bool _isLoading = true;
  String? _error;

  String _t(String en, String ta) => _isTamil ? ta : en;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await _repo.trackComplaint(widget.trackingToken);
      if (mounted) {
        setState(() {
          _complaint = data;
          _isLoading = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load complaint status.';
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: FadeTransition(
            opacity: _fadeAnim,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 520),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppTheme.stroke),
                boxShadow: AppTheme.softShadow,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHeader(),
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _error != null
                            ? _buildError()
                            : _buildTrackingInfo(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: const BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _t('Ooraatchi', 'ஊராட்சி'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _t('Complaint Tracker', 'புகார் கண்காணிப்பு'),
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _langButton('EN', !_isTamil),
                _langButton('தமிழ்', _isTamil),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _langButton(String label, bool isActive) {
    return GestureDetector(
      onTap: () => setState(() => _isTamil = label == 'தமிழ்'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? AppTheme.primary : Colors.white70,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Column(
      children: [
        Icon(Icons.search_off_rounded, size: 56, color: AppTheme.textMuted),
        const SizedBox(height: 16),
        Text(
          _t('Tracking link not found', 'கண்காணிப்பு இணைப்பு கிடைக்கவில்லை'),
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          _error!,
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildTrackingInfo() {
    final c = _complaint!;
    final status = c['status'] as String? ?? 'pending';
    final poleNumber = c['pole']?['pole_number'] as String? ?? 'N/A';
    final landmarks = (c['pole']?['landmarks'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    final panchayatName = c['panchayat']?['name'] as String? ?? 'Unknown';
    final createdAt = DateTime.tryParse(c['created_at'] ?? '');
    final resolvedAt = DateTime.tryParse(c['resolved_at'] ?? '');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status Badge
        Center(child: _buildStatusVisual(status)),
        const SizedBox(height: 24),

        // Complaint Details
        _infoRow(Icons.numbers_rounded, _t('Complaint ID', 'புகார் எண்'), '#${c['id']}'),
        const SizedBox(height: 12),
        _infoRow(Icons.bolt_rounded, _t('Pole', 'கம்பம்'), poleNumber),
        const SizedBox(height: 12),
        _infoRow(Icons.location_city_rounded, _t('Panchayat', 'ஊராட்சி'), panchayatName),
        if (landmarks.isNotEmpty) ...[
          const SizedBox(height: 12),
          _infoRow(Icons.place_outlined, _t('Landmarks', 'அடையாள இடம்'), landmarks.join(', ')),
        ],
        const SizedBox(height: 12),
        _infoRow(Icons.category_outlined, _t('Type', 'வகை'), c['complaint_type'] ?? '-'),
        if (c['urgency_level'] != null) ...[
          const SizedBox(height: 12),
          _infoRow(Icons.priority_high_rounded, _t('Urgency', 'அவசரம்'), c['urgency_level']),
        ],
        if (c['description'] != null) ...[
          const SizedBox(height: 12),
          _infoRow(Icons.description_outlined, _t('Description', 'விவரம்'), c['description']),
        ],
        if (createdAt != null) ...[
          const SizedBox(height: 12),
          _infoRow(Icons.access_time_rounded, _t('Reported', 'புகார் நாள்'), _formatDate(createdAt)),
        ],
        if (resolvedAt != null) ...[
          const SizedBox(height: 12),
          _infoRow(Icons.check_circle_outlined, _t('Resolved', 'தீர்ந்தது'), _formatDate(resolvedAt)),
        ],

        const SizedBox(height: 24),

        // Progress Timeline
        _buildTimeline(status, c['assigned_at'] != null, resolvedAt != null),
      ],
    );
  }

  Widget _buildStatusVisual(String status) {
    Color color;
    IconData icon;
    String label;

    switch (status) {
      case 'resolved':
        color = Colors.green;
        icon = Icons.check_circle_rounded;
        label = _t('Resolved', 'தீர்ந்தது');
        break;
      case 'assigned':
      case 'in_progress':
        color = Colors.amber.shade700;
        icon = Icons.engineering_rounded;
        label = _t('In Progress', 'செயல்பாட்டில்');
        break;
      case 'rejected':
        color = Colors.red;
        icon = Icons.cancel_rounded;
        label = _t('Rejected', 'நிராகரிக்கப்பட்டது');
        break;
      default:
        color = AppTheme.primary;
        icon = Icons.hourglass_top_rounded;
        label = _t('Pending Review', 'பரிசீலனையில்');
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppTheme.textMuted),
        const SizedBox(width: 10),
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeline(String status, bool isAssigned, bool isResolved) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _t('Progress', 'நிலை'),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 12),
        _timelineStep(
          _t('Complaint Received', 'புகார் பெறப்பட்டது'),
          true,
          isLast: false,
        ),
        _timelineStep(
          _t('Under Review', 'ஆய்வில் உள்ளது'),
          status != 'pending',
          isLast: false,
        ),
        _timelineStep(
          _t('Assigned to Field Staff', 'நிபுணருக்கு ஒதுக்கப்பட்டது'),
          isAssigned,
          isLast: false,
        ),
        _timelineStep(
          _t('Resolved', 'தீர்ந்தது'),
          isResolved,
          isLast: true,
        ),
      ],
    );
  }

  Widget _timelineStep(String label, bool isCompleted, {required bool isLast}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCompleted ? Colors.green : Colors.grey.shade300,
                border: Border.all(
                  color: isCompleted ? Colors.green.shade700 : Colors.grey.shade400,
                  width: 2,
                ),
              ),
              child: isCompleted
                  ? const Icon(Icons.check, size: 12, color: Colors.white)
                  : null,
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 28,
                color: isCompleted ? Colors.green.shade300 : Colors.grey.shade300,
              ),
          ],
        ),
        const SizedBox(width: 12),
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isCompleted ? FontWeight.w600 : FontWeight.normal,
              color: isCompleted ? AppTheme.textPrimary : AppTheme.textMuted,
            ),
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
