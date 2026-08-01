import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ivr_frontend/config/app_theme.dart';
import 'package:ivr_frontend/config/api_config.dart';
import 'package:ivr_frontend/core/api/api_client.dart';
import 'package:ivr_frontend/core/models/user_model.dart';
import 'package:ivr_frontend/features/auth/bloc/auth_bloc.dart';
import 'package:ivr_frontend/features/auth/bloc/auth_event.dart';
import 'package:ivr_frontend/features/roles/panchayat_admin/data/panchayat_admin_repository.dart';

class PanchayatAdminProfileScreen extends StatefulWidget {
  final String? adminId;
  const PanchayatAdminProfileScreen({super.key, this.adminId});

  @override
  State<PanchayatAdminProfileScreen> createState() => _PanchayatAdminProfileScreenState();
}

class _PanchayatAdminProfileScreenState extends State<PanchayatAdminProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  // Officer / User fields
  String _officerName = '';
  String _email = '';
  String _phone = '';
  String _role = '';
  String _empCode = '';
  String _cadre = '';
  String _designation = '';
  String _photoUrl = '';

  // Panchayat fields
  String _panchayatName = '';
  String _branchCode = '';
  String _district = '';
  String _taluk = '';
  String _address = '';
  String _ivrNumber = '';
  String _logoUrl = '';
  String _contactPhone = '';
  String _contactEmail = '';

  // Branding fields
  String _softwareNameTa = '';
  String _softwareNameEn = '';
  String _softwareTaglineTa = '';
  String _softwareTaglineEn = '';
  String _primaryColor = '';
  String _secondaryColor = '';

  // Stats
  int _wardsCount = 0;
  int _totalAssets = 0;
  int _resolvedGrievances = 0;
  int _activeStaff = 0;

  final PanchayatAdminRepository _repo = PanchayatAdminRepository();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final res = await ApiClient.instance.get(ApiConfig.paMe);
      final map = res is Map<String, dynamic> ? res : <String, dynamic>{};
      final panchayat = map['org_unit'] as Map<String, dynamic>?;
      final employee = map['employee'] as Map<String, dynamic>?;
      final stats = map['stats'] as Map<String, dynamic>?;

      final emailStr = (map['email'] ?? '').toString();
      final roleStr = (map['role'] ?? 'panchayat_admin').toString();
      final nameStr = employee?['officer_name']?.toString() ??
          (emailStr.contains('@') ? emailStr.split('@').first : '');

      setState(() {
        _email = emailStr;
        _role = roleStr;
        _phone = map['phone_e164']?.toString() ?? '';
        _officerName = nameStr.isNotEmpty ? nameStr.toUpperCase() : '';

        // Panchayat fields — direct from DB, no dummy fallbacks
        _panchayatName = panchayat?['name']?.toString() ?? '';
        _branchCode = panchayat?['branch_code']?.toString() ?? '';
        _district = panchayat?['district']?.toString() ?? '';
        _taluk = panchayat?['taluk']?.toString() ?? '';
        _address = panchayat?['address']?.toString() ?? '';
        _ivrNumber = panchayat?['ivr_number']?.toString() ?? '';
        _logoUrl = panchayat?['logo_url']?.toString() ?? '';
        _contactPhone = panchayat?['contact_phone']?.toString() ?? '';
        _contactEmail = panchayat?['contact_email']?.toString() ?? '';

        // Branding fields — direct from DB
        _softwareNameTa = panchayat?['software_name_ta']?.toString() ?? '';
        _softwareNameEn = panchayat?['software_name_en']?.toString() ?? '';
        _softwareTaglineTa = panchayat?['software_tagline_ta']?.toString() ?? '';
        _softwareTaglineEn = panchayat?['software_tagline_en']?.toString() ?? '';
        _primaryColor = panchayat?['primary_color']?.toString() ?? '';
        _secondaryColor = panchayat?['secondary_color']?.toString() ?? '';

        // Employee fields
        _photoUrl = employee?['photo_url']?.toString() ?? '';
        _empCode = employee?['employee_code']?.toString() ?? '';
        _cadre = employee?['cadre']?.toString() ?? '';
        _designation = employee?['designation']?.toString() ?? '';

        // Stats
        _wardsCount = stats?['wards'] as int? ?? 0;
        _totalAssets = stats?['total_assets'] as int? ?? 0;
        _resolvedGrievances = stats?['resolved_grievances'] as int? ?? 0;
        _activeStaff = stats?['active_field_staff'] as int? ?? 0;
      });

      if (mounted && map['email'] != null) {
        final updatedUser = UserModel.fromJson(map);
        context.read<AuthBloc>().add(UpdateAuthUser(updatedUser));
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Helper: returns "Not configured" styled widget when value is empty
  String _displayValue(String value, [String fallback = 'Not configured']) {
    return value.isNotEmpty ? value : fallback;
  }

  void _showEditProfileDialog() {
    // Officer fields
    final nameC = TextEditingController(text: _officerName);
    final emailC = TextEditingController(text: _email);
    final phoneC = TextEditingController(text: _phone);
    final photoUrlC = TextEditingController(text: _photoUrl);

    // Panchayat fields
    final panchayatC = TextEditingController(text: _panchayatName);
    final branchCodeC = TextEditingController(text: _branchCode);
    final districtC = TextEditingController(text: _district);
    final talukC = TextEditingController(text: _taluk);
    final addressC = TextEditingController(text: _address);
    final ivrNumberC = TextEditingController(text: _ivrNumber);
    final contactPhoneC = TextEditingController(text: _contactPhone);
    final contactEmailC = TextEditingController(text: _contactEmail);

    // Branding fields
    final logoUrlC = TextEditingController(text: _logoUrl);
    final softwareNameTaC = TextEditingController(text: _softwareNameTa);
    final softwareNameEnC = TextEditingController(text: _softwareNameEn);
    final taglineTaC = TextEditingController(text: _softwareTaglineTa);
    final taglineEnC = TextEditingController(text: _softwareTaglineEn);
    final primaryColorC = TextEditingController(text: _primaryColor);
    final secondaryColorC = TextEditingController(text: _secondaryColor);

    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.edit_note_rounded, color: AppTheme.primary),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Edit Profile & Branding',
                      style: TextStyle(fontSize: 18)),
                ),
              ],
            ),
            content: SizedBox(
              width: 700,
              height: 520,
              child: DefaultTabController(
                length: 3,
                child: Form(
                  key: formKey,
                  child: Column(
                    children: [
                      TabBar(
                        labelColor: AppTheme.primary,
                        unselectedLabelColor: AppTheme.textSecondary,
                        indicatorColor: AppTheme.primary,
                        tabs: const [
                          Tab(text: 'Officer Details'),
                          Tab(text: 'Panchayat & Branding'),
                          Tab(text: 'Contact & Location'),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: TabBarView(
                          children: [
                            // Tab 1: Officer Details
                            SingleChildScrollView(
                              child: Column(
                                children: [
                                  TextFormField(
                                    controller: nameC,
                                    decoration: const InputDecoration(
                                      labelText: 'Officer Full Name',
                                      prefixIcon: Icon(Icons.person_outline),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: emailC,
                                    decoration: const InputDecoration(
                                      labelText: 'Official Email *',
                                      prefixIcon: Icon(Icons.email_outlined),
                                    ),
                                    validator: (v) => v == null || !v.contains('@')
                                        ? 'Enter a valid email'
                                        : null,
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: phoneC,
                                    decoration: const InputDecoration(
                                      labelText: 'Contact Phone',
                                      prefixIcon: Icon(Icons.phone_outlined),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: photoUrlC,
                                    decoration: const InputDecoration(
                                      labelText: 'Profile Photo URL',
                                      prefixIcon: Icon(Icons.image_outlined),
                                      hintText: 'https://...',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Tab 2: Panchayat & Branding
                            SingleChildScrollView(
                              child: Column(
                                children: [
                                  TextFormField(
                                    controller: panchayatC,
                                    decoration: const InputDecoration(
                                      labelText: 'Panchayat Name *',
                                      prefixIcon:
                                          Icon(Icons.location_city_outlined),
                                    ),
                                    validator: (v) =>
                                        v == null || v.trim().isEmpty
                                            ? 'Required'
                                            : null,
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: softwareNameTaC,
                                    decoration: const InputDecoration(
                                      labelText: 'Software Name (Tamil)',
                                      prefixIcon: Icon(Icons.translate),
                                      hintText: 'e.g. கிராம ஊராட்சி குரல்',
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: softwareNameEnC,
                                    decoration: const InputDecoration(
                                      labelText: 'Software Name (English)',
                                      prefixIcon: Icon(Icons.abc),
                                      hintText: 'e.g. Grama Ooratchi Kural',
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: taglineTaC,
                                    decoration: const InputDecoration(
                                      labelText: 'Tagline (Tamil)',
                                      prefixIcon: Icon(Icons.short_text),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: taglineEnC,
                                    decoration: const InputDecoration(
                                      labelText: 'Tagline (English)',
                                      prefixIcon: Icon(Icons.short_text),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: logoUrlC,
                                    decoration: const InputDecoration(
                                      labelText: 'Logo URL',
                                      prefixIcon: Icon(Icons.image_outlined),
                                      hintText: 'https://...',
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextFormField(
                                          controller: primaryColorC,
                                          decoration: const InputDecoration(
                                            labelText: 'Primary Color',
                                            prefixIcon:
                                                Icon(Icons.color_lens_outlined),
                                            hintText: '#1E3A8A',
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: TextFormField(
                                          controller: secondaryColorC,
                                          decoration: const InputDecoration(
                                            labelText: 'Secondary Color',
                                            prefixIcon:
                                                Icon(Icons.color_lens_outlined),
                                            hintText: '#0EA5E9',
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            // Tab 3: Contact & Location
                            SingleChildScrollView(
                              child: Column(
                                children: [
                                  TextFormField(
                                    controller: branchCodeC,
                                    decoration: const InputDecoration(
                                      labelText: 'Branch Code',
                                      prefixIcon: Icon(Icons.qr_code_rounded),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: districtC,
                                    decoration: const InputDecoration(
                                      labelText: 'District',
                                      prefixIcon:
                                          Icon(Icons.location_on_outlined),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: talukC,
                                    decoration: const InputDecoration(
                                      labelText: 'Taluk',
                                      prefixIcon: Icon(Icons.map_outlined),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: addressC,
                                    decoration: const InputDecoration(
                                      labelText: 'Office Address',
                                      prefixIcon:
                                          Icon(Icons.business_outlined),
                                    ),
                                    maxLines: 2,
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: contactPhoneC,
                                    decoration: const InputDecoration(
                                      labelText: 'Office Contact Phone',
                                      prefixIcon: Icon(Icons.phone_outlined),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: contactEmailC,
                                    decoration: const InputDecoration(
                                      labelText: 'Office Contact Email',
                                      prefixIcon: Icon(Icons.email_outlined),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: ivrNumberC,
                                    decoration: const InputDecoration(
                                      labelText: 'IVR Helpline Number',
                                      prefixIcon:
                                          Icon(Icons.headset_mic_outlined),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: _isSaving ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                onPressed: _isSaving
                    ? null
                    : () async {
                        if (formKey.currentState!.validate()) {
                          setDialogState(() => _isSaving = true);
                          try {
                            final updatedUser = await _repo.updateProfile({
                              'officer_name': nameC.text.trim(),
                              'email': emailC.text.trim(),
                              'phone': phoneC.text.trim(),
                              'photo_url': photoUrlC.text.trim(),
                              'org_unit_name': panchayatC.text.trim(),
                              // Branding
                              'software_name_ta': softwareNameTaC.text.trim(),
                              'software_name_en': softwareNameEnC.text.trim(),
                              'software_tagline_ta': taglineTaC.text.trim(),
                              'software_tagline_en': taglineEnC.text.trim(),
                              'logo_url': logoUrlC.text.trim(),
                              'primary_color': primaryColorC.text.trim(),
                              'secondary_color': secondaryColorC.text.trim(),
                              // Contact & Location
                              'branch_code': branchCodeC.text.trim(),
                              'district': districtC.text.trim(),
                              'taluk': talukC.text.trim(),
                              'address': addressC.text.trim(),
                              'contact_phone': contactPhoneC.text.trim(),
                              'contact_email': contactEmailC.text.trim(),
                              'ivr_number': ivrNumberC.text.trim(),
                            });

                            if (mounted) {
                              context
                                  .read<AuthBloc>()
                                  .add(UpdateAuthUser(updatedUser));
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text(
                                      'Profile & branding updated and saved to database!'),
                                  backgroundColor: AppTheme.accent,
                                ),
                              );
                              _loadProfile();
                            }
                          } catch (err) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content:
                                      Text('Failed to update profile: $err'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          } finally {
                            setDialogState(() => _isSaving = false);
                          }
                        }
                      },
                icon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save_rounded, size: 18),
                label: Text(_isSaving ? 'Saving...' : 'Save All Changes'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(48.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    final roleTitle =
        _role == 'super_admin' ? 'Super Admin' : 'Active Panchayat Admin';
    final displayName = _officerName.isNotEmpty ? _officerName : (_email.isNotEmpty ? _email.split('@').first.toUpperCase() : 'Admin');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.amber),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Could not load profile from server: $_error',
                      style: TextStyle(
                          fontSize: 12, color: Colors.amber.shade900),
                    ),
                  ),
                  TextButton(
                    onPressed: _loadProfile,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ],
          // Top Header Banner Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.stroke),
              boxShadow: AppTheme.softShadow,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAvatarOrLogo(),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              displayName,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.shade100,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.check_circle,
                                    size: 14, color: Colors.green),
                                const SizedBox(width: 4),
                                Text(
                                  roleTitle,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        [
                          if (_panchayatName.isNotEmpty) _panchayatName,
                          if (_district.isNotEmpty) _district,
                        ].join(' • '),
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary),
                      ),
                      if (_branchCode.isNotEmpty || _empCode.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          [
                            if (_branchCode.isNotEmpty) 'Branch: $_branchCode',
                            if (_empCode.isNotEmpty) 'Employee: $_empCode',
                          ].join(' • '),
                          style: TextStyle(
                              fontSize: 13, color: AppTheme.textMuted),
                        ),
                      ],
                      if (_softwareNameTa.isNotEmpty || _softwareNameEn.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            [
                              if (_softwareNameTa.isNotEmpty) _softwareNameTa,
                              if (_softwareNameEn.isNotEmpty) _softwareNameEn,
                            ].join(' — '),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _showEditProfileDialog,
                      icon: const Icon(Icons.edit_rounded, size: 18),
                      label: const Text('Edit Profile'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text(
                                  'Downloading Official e-Service Credentials PDF...')),
                        );
                      },
                      icon: const Icon(Icons.badge_rounded, size: 18),
                      label: const Text('ID Credentials'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Quick Operational Statistics Banner
          Row(
            children: [
              _buildKpiCard('Assigned Wards', '$_wardsCount Wards',
                  Icons.map_rounded, Colors.blue),
              const SizedBox(width: 16),
              _buildKpiCard(
                  'Total Infrastructure Assets',
                  '$_totalAssets Assets',
                  Icons.lightbulb_rounded,
                  Colors.purple),
              const SizedBox(width: 16),
              _buildKpiCard(
                  'Grievances Resolved',
                  '$_resolvedGrievances Resolved',
                  Icons.task_alt_rounded,
                  Colors.green),
              const SizedBox(width: 16),
              _buildKpiCard('Active Field Staff', '$_activeStaff Staff',
                  Icons.engineering_rounded, Colors.orange),
            ],
          ),
          const SizedBox(height: 24),

          // Navigation Tab Bar
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.stroke),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: AppTheme.primary,
              unselectedLabelColor: AppTheme.textSecondary,
              indicatorColor: AppTheme.primary,
              tabs: const [
                Tab(text: 'Branch & Panchayat Details'),
                Tab(text: 'Branding & Software Config'),
                Tab(text: 'Officer Credentials & Contact'),
                Tab(text: 'RBAC Roles & Permissions'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Tab Contents View
          SizedBox(
            height: 520,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildBranchDetailsTab(),
                _buildBrandingTab(),
                _buildOfficerCredentialsTab(),
                _buildRbacPermissionsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarOrLogo() {
    if (_photoUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 40,
        backgroundImage: NetworkImage(ApiConfig.fileUrl(_photoUrl)),
        backgroundColor: AppTheme.primary.withValues(alpha: 0.12),
      );
    }
    if (_logoUrl.isNotEmpty) {
      return Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.stroke),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.network(
            ApiConfig.fileUrl(_logoUrl),
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => _defaultLetterAvatar(),
          ),
        ),
      );
    }
    return _defaultLetterAvatar();
  }

  Widget _defaultLetterAvatar() {
    final letter = _officerName.isNotEmpty
        ? _officerName[0].toUpperCase()
        : (_panchayatName.isNotEmpty ? _panchayatName[0].toUpperCase() : 'P');
    return CircleAvatar(
      radius: 40,
      backgroundColor: AppTheme.primary.withValues(alpha: 0.12),
      child: Text(
        letter,
        style: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: AppTheme.primary,
        ),
      ),
    );
  }

  Widget _buildKpiCard(String title, String val, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.stroke),
          boxShadow: AppTheme.softShadow,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 12, color: AppTheme.textSecondary)),
                  const SizedBox(height: 2),
                  Text(val,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBranchDetailsTab() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ListView(
          children: [
            _buildDetailTile(Icons.account_balance_rounded,
                'Panchayat Body Name', _displayValue(_panchayatName)),
            const Divider(),
            _buildDetailTile(Icons.qr_code_rounded,
                'Administrative Branch Code', _displayValue(_branchCode)),
            const Divider(),
            _buildDetailTile(
                Icons.location_on_rounded,
                'District & State',
                _district.isNotEmpty
                    ? '$_district, Tamil Nadu'
                    : 'Not configured'),
            const Divider(),
            _buildDetailTile(Icons.map_rounded, 'Taluk',
                _displayValue(_taluk)),
            const Divider(),
            _buildDetailTile(Icons.business_rounded,
                'Office Headquarters Address', _displayValue(_address)),
            const Divider(),
            _buildDetailTile(Icons.access_time_filled_rounded,
                'Official Business Hours', 'Monday to Saturday (09:30 AM – 05:45 PM)'),
            const Divider(),
            _buildDetailTile(Icons.headset_mic_rounded,
                'IVR Public Grievance Helpline', _displayValue(_ivrNumber)),
            const Divider(),
            _buildDetailTile(Icons.phone_rounded, 'Office Contact Phone',
                _displayValue(_contactPhone)),
            const Divider(),
            _buildDetailTile(Icons.email_rounded, 'Office Contact Email',
                _displayValue(_contactEmail)),
          ],
        ),
      ),
    );
  }

  Widget _buildBrandingTab() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ListView(
          children: [
            // Logo preview
            if (_logoUrl.isNotEmpty) ...[
              Center(
                child: Container(
                  width: 120,
                  height: 120,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.stroke),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      ApiConfig.fileUrl(_logoUrl),
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.broken_image,
                        size: 40,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ),
                ),
              ),
            ],
            _buildDetailTile(Icons.translate_rounded,
                'Software Name (Tamil)', _displayValue(_softwareNameTa)),
            const Divider(),
            _buildDetailTile(Icons.abc_rounded,
                'Software Name (English)', _displayValue(_softwareNameEn)),
            const Divider(),
            _buildDetailTile(Icons.short_text_rounded,
                'Tagline (Tamil)', _displayValue(_softwareTaglineTa)),
            const Divider(),
            _buildDetailTile(Icons.short_text_rounded,
                'Tagline (English)', _displayValue(_softwareTaglineEn)),
            const Divider(),
            // Color swatches
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.color_lens_rounded, color: AppTheme.primary, size: 24),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Brand Colors', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            if (_primaryColor.isNotEmpty) ...[
                              _buildColorChip('Primary', _primaryColor),
                              const SizedBox(width: 12),
                            ],
                            if (_secondaryColor.isNotEmpty)
                              _buildColorChip('Secondary', _secondaryColor),
                            if (_primaryColor.isEmpty && _secondaryColor.isEmpty)
                              Text('Not configured', style: TextStyle(
                                fontSize: 14, color: AppTheme.textMuted, fontStyle: FontStyle.italic)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            _buildDetailTile(Icons.image_rounded,
                'Logo URL', _displayValue(_logoUrl, 'No logo set')),
          ],
        ),
      ),
    );
  }

  Widget _buildColorChip(String label, String hexColor) {
    Color color;
    try {
      color = Color(int.parse(hexColor.replaceFirst('#', '0xFF')));
    } catch (_) {
      color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.black12),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$label: $hexColor',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfficerCredentialsTab() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ListView(
          children: [
            _buildDetailTile(Icons.person_rounded, 'Officer Full Name',
                _displayValue(_officerName, 'Not set')),
            const Divider(),
            _buildDetailTile(Icons.email_rounded,
                'Official Registered Email', _displayValue(_email)),
            const Divider(),
            _buildDetailTile(Icons.phone_rounded, 'Contact Phone Number',
                _displayValue(_phone, 'Not set')),
            const Divider(),
            _buildDetailTile(Icons.badge_rounded,
                'Employee Service Book Code', _displayValue(_empCode, 'Not assigned')),
            const Divider(),
            _buildDetailTile(
                Icons.work_history_rounded,
                'Service Cadre & Designation',
                [
                  if (_cadre.isNotEmpty) _cadre,
                  if (_designation.isNotEmpty) _designation,
                ].join(' — ').isNotEmpty
                    ? [
                        if (_cadre.isNotEmpty) _cadre,
                        if (_designation.isNotEmpty) _designation,
                      ].join(' — ')
                    : 'Not set'),
            const Divider(),
            _buildDetailTile(Icons.translate_rounded,
                'System Portal Preferences', 'Language: English & தமிழ் • Notifications: Active'),
          ],
        ),
      ),
    );
  }

  Widget _buildRbacPermissionsTab() {
    final permissions = [
      {
        'code': 'complaints.manage',
        'desc': 'Manage & Resolve Public Citizen Complaints',
        'status': 'Granted'
      },
      {
        'code': 'electricians.assign',
        'desc': 'Assign & Monitor Field Electrician Work Orders',
        'status': 'Granted'
      },
      {
        'code': 'assets.register',
        'desc': 'Register & Inspect Municipal Infrastructure Assets',
        'status': 'Granted'
      },
      {
        'code': 'mbook.approve',
        'desc': 'Verify Site Measurement Book (M-Book) Entries',
        'status': 'Granted'
      },
      {
        'code': 'reports.executive',
        'desc': 'Access Panchayat Analytics & SLA Compliance Reports',
        'status': 'Granted'
      },
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Granted Administrative Permissions (Role: $_role)',
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.separated(
                itemCount: permissions.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, index) {
                  final item = permissions[index];
                  return ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.green,
                      radius: 14,
                      child:
                          Icon(Icons.check, size: 16, color: Colors.white),
                    ),
                    title: Text(item['desc']!,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Text('Permission Code: ${item['code']}',
                        style: const TextStyle(
                            fontFamily: 'monospace', fontSize: 12)),
                    trailing: Chip(
                      label: Text(item['status']!),
                      backgroundColor: Colors.green.shade100,
                      labelStyle: TextStyle(
                          color: Colors.green.shade900,
                          fontWeight: FontWeight.bold,
                          fontSize: 11),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailTile(IconData icon, String title, String val) {
    final isNotConfigured = val == 'Not configured' || val == 'Not set' || val == 'Not assigned' || val == 'No logo set';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primary, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary)),
                const SizedBox(height: 2),
                Text(val,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isNotConfigured ? AppTheme.textMuted : AppTheme.textPrimary,
                        fontStyle: isNotConfigured ? FontStyle.italic : FontStyle.normal,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
