import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../config/app_theme.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../../auth/bloc/auth_bloc.dart';
import '../../../auth/bloc/auth_event.dart';
import '../../data/citizen_repository.dart';
import '../../data/public_report_repository.dart';

class CitizenRegisterScreen extends StatefulWidget {
  const CitizenRegisterScreen({super.key});

  @override
  State<CitizenRegisterScreen> createState() => _CitizenRegisterScreenState();
}

class _CitizenRegisterScreenState extends State<CitizenRegisterScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  
  final CitizenRepository _citizenRepository = CitizenRepository();
  final PublicReportRepository _publicRepo = PublicReportRepository();
  
  List<Map<String, dynamic>> _panchayats = [];
  int? _selectedPanchayatId;
  bool _isLoadingPanchayats = true;
  bool _isSubmitting = false;
  bool _obscurePassword = true;
  bool _isDetectingGps = false;
  String? _gpsDetectedName;

  // Tamil / English toggle
  bool _isTamil = false;
  String _t(String en, String ta) => _isTamil ? ta : en;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
    _animController.forward();
    _loadPanchayats();
  }

  Future<void> _loadPanchayats() async {
    try {
      final list = await _citizenRepository.listPanchayats();
      setState(() {
        _panchayats = list;
        if (list.isNotEmpty) {
          _selectedPanchayatId = list.first['id'] as int;
        }
        _isLoadingPanchayats = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load Panchayats: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
        setState(() {
          _isLoadingPanchayats = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate() || _selectedPanchayatId == null) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final response = await _citizenRepository.registerCitizen(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        panchayatId: _selectedPanchayatId!,
        phone: _phoneController.text.trim(),
      );

      // Save credentials in storage
      await SecureStorageService.saveToken(response.accessToken);
      await SecureStorageService.saveUserInfo(
        role: response.user.role,
        email: response.user.email,
        userId: response.user.id,
        panchayatId: response.user.panchayatId,
      );

      if (!mounted) return;

      // Update AuthBloc so router reacts
      context.read<AuthBloc>().add(AuthCheckRequested());
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Registration successful! Welcome to the Ooraatchi Citizen Portal.'),
          backgroundColor: Colors.green,
        ),
      );

      context.go('/citizen');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Registration failed: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 800;

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 980),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppTheme.stroke),
                  color: Colors.white,
                  boxShadow: AppTheme.softShadow,
                ),
                child: isWide ? _buildWideLayout() : _buildMobileLayout(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWideLayout() {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(36),
            decoration: const BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                bottomLeft: Radius.circular(24),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Ooraatchi',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Citizen Services Portal',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Access public utility mapping, track status updates, and report pole or pipeline issues directly in your local body.',
                  style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
                ),
                const SizedBox(height: 36),
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset(
                    'assets/redesign/illustrations/hero_banner.jpg',
                    height: 220,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 220,
                      color: Colors.white12,
                      child: const Icon(
                        Icons.map_outlined,
                        color: Colors.white30,
                        size: 64,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: _buildForm(),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: _buildForm(),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Column(
              children: [
                // Language Toggle
                Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: AppTheme.bgDark,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _langButton('English', !_isTamil),
                      _langButton('தமிழ்', _isTamil),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.how_to_reg_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  _t('Create Citizen Account', 'குடிமக்கள் கணக்கை உருவாக்கு'),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _t('Access public map services instantly', 'பொது வரைபட சேவைகளை உடனடியாக அணுகவும்'),
                  style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Email
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: _t('Email Address', 'மின்னஞ்சல் முகவரி'),
              prefixIcon: Icon(Icons.email_outlined, color: AppTheme.textMuted),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return _t('Email is required', 'மின்னஞ்சல் தேவை');
              if (!v.contains('@')) return _t('Enter a valid email', 'சரியான மின்னஞ்சலை உள்ளிடவும்');
              return null;
            },
          ),
          const SizedBox(height: 16),
          
          // Password
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: _t('Password', 'கடவுச்சொல்'),
              prefixIcon: Icon(Icons.lock_outline, color: AppTheme.textMuted),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: AppTheme.textMuted,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return _t('Password is required', 'கடவுச்சொல் தேவை');
              if (v.length < 6) return _t('Password must be at least 6 characters', 'கடவுச்சொல் 6 எழுத்துக்களாவது இருக்க வேண்டும்');
              return null;
            },
          ),
          const SizedBox(height: 16),
          
          // Phone (Optional)
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: _t('Phone Number (Optional)', 'தொலைபேசி எண் (விருப்பத்திற்கு)'),
              prefixIcon: Icon(Icons.phone_outlined, color: AppTheme.textMuted),
              helperText: _t('E.164 format, e.g. +919876543210', 'E.164 வடிவம், எ.கா. +919876543210'),
            ),
          ),
          const SizedBox(height: 16),

          // Panchayat Dropdown
          _isLoadingPanchayats
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(8.0),
                    child: CircularProgressIndicator(),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<int>(
                      initialValue: _selectedPanchayatId,
                      decoration: InputDecoration(
                        labelText: _t('Select Panchayat', 'ஊராட்சியை தேர்ந்தெடுக்கவும்'),
                        prefixIcon: Icon(Icons.location_city_outlined, color: AppTheme.textMuted),
                      ),
                      items: _panchayats.map((p) {
                        return DropdownMenuItem<int>(
                          value: p['id'] as int,
                          child: Text(p['name'] as String),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedPanchayatId = val;
                          _gpsDetectedName = null;
                        });
                      },
                      validator: (v) => v == null ? _t('Please select your Panchayat', 'உங்கள் ஊராட்சியை தேர்ந்தெடுக்கவும்') : null,
                    ),
                    const SizedBox(height: 10),
                    // GPS Auto-Detect Button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isDetectingGps ? null : _detectPanchayatByGps,
                        icon: _isDetectingGps
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.my_location_rounded, size: 18),
                        label: Text(
                          _isDetectingGps
                              ? _t('Detecting...', 'கண்டறிகிறது...')
                              : _t('Auto-detect my Panchayat (GPS)', 'என் ஊராட்சியை GPS மூலம் கண்டறிக'),
                          style: const TextStyle(fontSize: 13),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    if (_gpsDetectedName != null) ...[  
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.check_circle, size: 16, color: Colors.green.shade600),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _t('GPS detected: $_gpsDetectedName', 'GPS கண்டறிந்தது: $_gpsDetectedName'),
                              style: TextStyle(color: Colors.green.shade700, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
          
          const SizedBox(height: 28),
          
          // Submit Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _handleRegister,
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
                      _t('Sign Up as Citizen', 'குடிமகனாக பதிவு செய்'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Redirect to Login
          Center(
            child: TextButton(
              onPressed: () => context.go('/login'),
              child: Text(
                _t('Already have an account? Sign In', 'ஏற்கனவே கணக்கு உள்ளதா? உள்நுழையுங்கள்'),
                style: TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : AppTheme.textSecondary,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Future<void> _detectPanchayatByGps() async {
    setState(() => _isDetectingGps = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(_t('Location permission denied', 'இருப்பிட அனுமதி மறுக்கப்பட்டது')),
                backgroundColor: AppTheme.error,
              ),
            );
          }
          setState(() => _isDetectingGps = false);
          return;
        }
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      final result = await _publicRepo.lookupPanchayatByCoords(
        position.latitude,
        position.longitude,
      );

      if (result != null && mounted) {
        final detectedId = result['id'] as int?;
        final detectedName = result['name'] as String?;
        if (detectedId != null) {
          // Try to match with the panchayat list
          final match = _panchayats.any((p) => p['id'] == detectedId);
          setState(() {
            if (match) {
              _selectedPanchayatId = detectedId;
              _gpsDetectedName = detectedName;
            } else {
              _gpsDetectedName = null;
            }
          });
          if (!match && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(_t(
                  'Detected panchayat "$detectedName" is not in the available list.',
                  'கண்டறியப்பட்ட ஊராட்சி "$detectedName" பட்டியலில் இல்லை.',
                )),
              ),
            );
          }
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_t(
              'Could not detect panchayat from your location.',
              'உங்கள் இருப்பிடத்திலிருந்து ஊராட்சியை கண்டறிய முடியவில்லை.',
            )),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_t('GPS detection failed: $e', 'GPS கண்டறிதல் தோல்வி: $e')),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isDetectingGps = false);
    }
  }
}
