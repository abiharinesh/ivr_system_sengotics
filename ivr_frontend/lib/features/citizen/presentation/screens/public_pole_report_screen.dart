import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../config/app_theme.dart';
import '../../../../core/api/api_exceptions.dart';
import '../../data/public_report_repository.dart';

/// Public-facing pole report page. No authentication required.
/// Opened via QR scan: `/public/report/:token`
class PublicPoleReportScreen extends StatefulWidget {
  final String token;
  const PublicPoleReportScreen({super.key, required this.token});

  @override
  State<PublicPoleReportScreen> createState() => _PublicPoleReportScreenState();
}

class _PublicPoleReportScreenState extends State<PublicPoleReportScreen>
    with SingleTickerProviderStateMixin {
  final _repo = PublicReportRepository();
  final _formKey = GlobalKey<FormState>();
  final _descController = TextEditingController();
  final _phoneController = TextEditingController();

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  // Tamil / English toggle
  bool _isTamil = false;

  Map<String, dynamic>? _poleInfo;
  bool _isLoadingPole = true;
  String? _poleError;

  String _selectedType = 'Street Light Fault';
  String _selectedUrgency = 'medium';
  bool _isSubmitting = false;

  // Success state
  String? _trackingUrl;

  final List<String> _typesEn = [
    'Street Light Fault',
    'Wire Hanging / Danger',
    'Water Pipeline Leak',
    'Open Junction Box',
    'Other Issue',
  ];

  final List<String> _typesTa = [
    'தெரு விளக்கு பழுது',
    'கம்பி தொங்குகிறது / ஆபத்து',
    'குழாய் கசிவு',
    'ஜங்ஷன் பாக்ஸ் திறந்துள்ளது',
    'பிற பிரச்சினை',
  ];

  List<String> get _types => _isTamil ? _typesTa : _typesEn;

  // Localization map
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
    _loadPoleInfo();
  }

  Future<void> _loadPoleInfo() async {
    try {
      final info = await _repo.getPoleByToken(widget.token);
      if (mounted) {
        setState(() {
          _poleInfo = info;
          _isLoadingPole = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _poleError = e.message;
          _isLoadingPole = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _poleError = 'Failed to load pole information.';
          _isLoadingPole = false;
        });
      }
    }
  }

  Future<void> _submitComplaint() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      final result = await _repo.submitGuestComplaint(
        token: widget.token,
        complaintType: _selectedType,
        description: _descController.text.trim(),
        urgencyLevel: _selectedUrgency,
        guestPhone: _phoneController.text.trim(),
      );
      if (mounted) {
        setState(() {
          _trackingUrl = result['tracking_url'] as String?;
          _isSubmitting = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: AppTheme.error),
        );
        setState(() => _isSubmitting = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_t('Failed to submit complaint', 'புகார் சமர்ப்பிக்க முடியவில்லை')),
            backgroundColor: AppTheme.error,
          ),
        );
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  void dispose() {
    _descController.dispose();
    _phoneController.dispose();
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
                    child: _trackingUrl != null
                        ? _buildSuccessView()
                        : _isLoadingPole
                            ? const Center(child: CircularProgressIndicator())
                            : _poleError != null
                                ? _buildErrorView()
                                : _buildFormView(),
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
          Expanded(
            child: Column(
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
                  _t('Quick Grievance Report', 'விரைவு புகார் அறிக்கை'),
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          // Tamil / English Toggle
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
      onTap: () {
        setState(() {
          _isTamil = label == 'தமிழ்';
          // Reset complaint type to first in the new language list
          _selectedType = _types.first;
        });
      },
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

  Widget _buildErrorView() {
    return Column(
      children: [
        const Icon(Icons.error_outline_rounded, size: 56, color: AppTheme.error),
        const SizedBox(height: 16),
        Text(
          _poleError!,
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 15,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          _t(
            'The QR code may be invalid or the pole has been removed.',
            'QR குறியீடு தவறாக இருக்கலாம் அல்லது கம்பம் அகற்றப்பட்டிருக்கிறது.',
          ),
          style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildFormView() {
    final panchayatName =
        _poleInfo?['panchayat']?['name'] as String? ?? 'Unknown';
    final poleNumber = _poleInfo?['pole_number'] as String? ?? 'N/A';
    final landmarks = (_poleInfo?['landmarks'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Pole Identification Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.bolt_rounded, color: AppTheme.primary, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      '${_t('Pole', 'கம்பம்')}: $poleNumber',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${_t('Panchayat', 'ஊராட்சி')}: $panchayatName',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                  ),
                ),
                if (landmarks.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${_t('Near', 'அருகில்')}: ${landmarks.join(', ')}',
                    style: TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Issue Type
          Text(
            _t('Issue Type', 'பிரச்சினை வகை'),
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _selectedType,
            decoration: InputDecoration(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            items: _types.map((t) {
              return DropdownMenuItem(value: t, child: Text(t));
            }).toList(),
            onChanged: (val) {
              if (val != null) setState(() => _selectedType = val);
            },
          ),

          const SizedBox(height: 16),

          // Urgency
          Text(
            _t('Urgency Level', 'அவசர நிலை'),
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _selectedUrgency,
            decoration: InputDecoration(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            items: [
              DropdownMenuItem(value: 'low', child: Text(_t('Low', 'குறைவு'))),
              DropdownMenuItem(
                  value: 'medium', child: Text(_t('Medium', 'நடுத்தரம்'))),
              DropdownMenuItem(
                  value: 'high', child: Text(_t('High', 'உயர்வு'))),
              DropdownMenuItem(
                  value: 'critical',
                  child: Text(_t('Critical', 'மிக அவசரம்'))),
            ],
            onChanged: (val) {
              if (val != null) setState(() => _selectedUrgency = val);
            },
          ),

          const SizedBox(height: 16),

          // Description
          Text(
            _t('Describe the Issue', 'பிரச்சினையை விவரிக்கவும்'),
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _descController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: _t(
                'e.g. The street light is not working since 3 days...',
                'எ.கா. தெரு விளக்கு 3 நாட்களாக வேலை செய்யவில்லை...',
              ),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            validator: (v) => v == null || v.trim().isEmpty
                ? _t('Description is required', 'விவரம் தேவை')
                : null,
          ),

          const SizedBox(height: 16),

          // Phone (Optional)
          Text(
            _t('Phone Number (Optional)', 'தொலைபேசி எண் (விருப்பத்திற்கு)'),
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            _t(
              'Provide your number to receive status updates via SMS.',
              'SMS மூலம் நிலை புதுப்பிப்புகளை பெற உங்கள் எண்ணை கொடுக்கவும்.',
            ),
            style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              hintText: '+919876543210',
              prefixIcon:
                  Icon(Icons.phone_outlined, color: AppTheme.textMuted),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),

          const SizedBox(height: 24),

          // Submit
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submitComplaint,
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      _t('Submit Grievance', 'புகார் சமர்ப்பிக்கவும்'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessView() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.check_circle_rounded,
            size: 56,
            color: Colors.green.shade600,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          _t('Complaint Submitted!', 'புகார் சமர்ப்பிக்கப்பட்டது!'),
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          _t(
            'Your grievance has been registered successfully. You can track its progress using the link below.',
            'உங்கள் புகார் வெற்றிகரமாக பதிவு செய்யப்பட்டது. கீழே உள்ள இணைப்பைப் பயன்படுத்தி அதன் நிலையை கண்காணிக்கலாம்.',
          ),
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        if (_trackingUrl != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.bgDark,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.stroke),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _trackingUrl!,
                    style: TextStyle(
                      color: AppTheme.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 20),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _trackingUrl!));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(_t(
                          'Tracking link copied!',
                          'கண்காணிப்பு இணைப்பு நகலெடுக்கப்பட்டது!',
                        )),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                  tooltip: _t('Copy link', 'இணைப்பை நகலெடு'),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        Text(
          _t(
            'Save this link to check your complaint status anytime.',
            'உங்கள் புகார் நிலையை எப்போது வேண்டுமானாலும் சரிபார்க்க இந்த இணைப்பை சேமிக்கவும்.',
          ),
          style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
