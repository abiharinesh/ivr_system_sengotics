import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../config/app_theme.dart';
import '../../../../core/models/panchayat_model.dart';
import '../../bloc/panchayat_bloc.dart';
import '../../data/super_admin_repository.dart';

/// Super Admin screen for configuring dynamic software names and branding
/// per local body branch (e.g. நகராட்சி குரல், கிராம ஊராட்சி குரல்).
class BranchBrandingConfigScreen extends StatefulWidget {
  const BranchBrandingConfigScreen({super.key});

  @override
  State<BranchBrandingConfigScreen> createState() =>
      _BranchBrandingConfigScreenState();
}

class _BranchBrandingConfigScreenState
    extends State<BranchBrandingConfigScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repo = SuperAdminRepository();

  // Controllers
  final _softwareNameTaCtrl = TextEditingController();
  final _softwareNameEnCtrl = TextEditingController();
  final _taglineTaCtrl = TextEditingController();
  final _taglineEnCtrl = TextEditingController();
  final _logoUrlCtrl = TextEditingController();
  final _primaryColorCtrl = TextEditingController();
  final _secondaryColorCtrl = TextEditingController();
  final _welcomeAudioUrlCtrl = TextEditingController();

  // State
  PanchayatModel? _selectedBranch;
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;

  static const Map<String, Map<String, String>> _presets = {
    'VILLAGE_PANCHAYAT': {
      'ta': 'கிராம ஊராட்சி குரல்',
      'en': 'Grama Ooratchi Kural',
    },
    'PANCHAYAT_UNION': {
      'ta': 'ஊராட்சி ஒன்றிய குரல்',
      'en': 'Ooratchi Union Kural',
    },
    'DISTRICT_PANCHAYAT': {
      'ta': 'மாவட்ட ஊராட்சி குரல்',
      'en': 'District Ooratchi Kural',
    },
    'TOWN_PANCHAYAT': {
      'ta': 'பேரூராட்சி குரல்',
      'en': 'Peeraatchi Kural',
    },
    'MUNICIPALITY': {
      'ta': 'நகராட்சி குரல்',
      'en': 'Nagaraatchi Kural',
    },
    'MUNICIPAL_CORPORATION': {
      'ta': 'மாநகராட்சி குரல்',
      'en': 'Maanagaraatchi Kural',
    },
  };

  @override
  void dispose() {
    _softwareNameTaCtrl.dispose();
    _softwareNameEnCtrl.dispose();
    _taglineTaCtrl.dispose();
    _taglineEnCtrl.dispose();
    _logoUrlCtrl.dispose();
    _primaryColorCtrl.dispose();
    _secondaryColorCtrl.dispose();
    _welcomeAudioUrlCtrl.dispose();
    super.dispose();
  }

  /// Load branding data for selected branch from API
  Future<void> _loadBranding(int branchId) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final data = await _repo.getBranchBranding(branchId);
      if (!mounted) return;
      _softwareNameTaCtrl.text = data['software_name_ta'] as String? ?? '';
      _softwareNameEnCtrl.text = data['software_name_en'] as String? ?? '';
      _taglineTaCtrl.text = data['software_tagline_ta'] as String? ?? '';
      _taglineEnCtrl.text = data['software_tagline_en'] as String? ?? '';
      _logoUrlCtrl.text = data['logo_url'] as String? ?? '';
      _primaryColorCtrl.text = data['primary_color'] as String? ?? '#1E3A8A';
      _secondaryColorCtrl.text =
          data['secondary_color'] as String? ?? '#0EA5E9';
      _welcomeAudioUrlCtrl.text = data['welcome_audio_url'] as String? ?? '';
      setState(() => _isLoading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load branding: $e';
      });
    }
  }

  /// Apply a preset based on branch type
  void _applyPreset(String branchType) {
    final preset = _presets[branchType];
    if (preset == null) return;
    setState(() {
      _softwareNameTaCtrl.text = preset['ta']!;
      _softwareNameEnCtrl.text = preset['en']!;
    });
  }

  /// Save branding to API
  Future<void> _saveBranding() async {
    if (!_formKey.currentState!.validate() || _selectedBranch == null) return;
    setState(() => _isSaving = true);

    try {
      await _repo.updateBranchBranding(_selectedBranch!.id, {
        'software_name_ta': _softwareNameTaCtrl.text.trim(),
        'software_name_en': _softwareNameEnCtrl.text.trim(),
        'software_tagline_ta': _taglineTaCtrl.text.trim(),
        'software_tagline_en': _taglineEnCtrl.text.trim(),
        'logo_url': _logoUrlCtrl.text.trim().isEmpty
            ? null
            : _logoUrlCtrl.text.trim(),
        'primary_color': _primaryColorCtrl.text.trim(),
        'secondary_color': _secondaryColorCtrl.text.trim(),
        'welcome_audio_url': _welcomeAudioUrlCtrl.text.trim().isEmpty
            ? null
            : _welcomeAudioUrlCtrl.text.trim(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✅ Branding saved for ${_selectedBranch!.name} — "${_softwareNameTaCtrl.text}"',
          ),
          backgroundColor: AppTheme.accent,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save: $e'),
          backgroundColor: AppTheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PanchayatBloc, PanchayatState>(
      builder: (context, state) {
        final panchayats =
            state is PanchayatLoaded ? state.panchayats : <PanchayatModel>[];

        return LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 900;
            final hPad = constraints.maxWidth < 500 ? 12.0 : 24.0;

            return SingleChildScrollView(
              padding: EdgeInsets.all(hPad),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 20),
                  _buildBranchSelector(panchayats),
                  const SizedBox(height: 20),
                  if (_selectedBranch != null) ...[
                    _buildPresetRibbon(),
                    const SizedBox(height: 20),
                    if (_isLoading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(48),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (_errorMessage != null)
                      _buildErrorState()
                    else if (isWide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 3, child: _buildFormCard()),
                          const SizedBox(width: 20),
                          Expanded(flex: 2, child: _buildPreviewCard()),
                        ],
                      )
                    else ...[
                      _buildFormCard(),
                      const SizedBox(height: 20),
                      _buildPreviewCard(),
                    ],
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Branch Software Identity & Branding',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Configure dynamic software names, logos, theme colors, and IVR voice greetings per local body',
          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
        ),
      ],
    );
  }

  // ── Branch Selector ────────────────────────────────────────────────────

  Widget _buildBranchSelector(List<PanchayatModel> panchayats) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.account_tree_rounded,
                    color: AppTheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Select Branch / Local Body',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (panchayats.isEmpty)
              Text(
                'No branches available. Create a panchayat first.',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
              )
            else
              DropdownButtonFormField<int>(
                initialValue: _selectedBranch?.id,
                decoration: const InputDecoration(
                  labelText: 'Branch',
                  prefixIcon: Icon(Icons.location_city_rounded),
                ),
                items: panchayats.map((p) {
                  final typeLabel =
                      (p.branchType ?? 'VILLAGE_PANCHAYAT').replaceAll('_', ' ');
                  return DropdownMenuItem(
                    value: p.id,
                    child: Text(
                      '${p.name}  ·  $typeLabel',
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (id) {
                  if (id == null) return;
                  final branch = panchayats.firstWhere((p) => p.id == id);
                  setState(() => _selectedBranch = branch);
                  _loadBranding(id);
                },
              ),
          ],
        ),
      ),
    );
  }

  // ── Preset Ribbon ──────────────────────────────────────────────────────

  Widget _buildPresetRibbon() {
    final currentType = _selectedBranch?.branchType ?? 'VILLAGE_PANCHAYAT';
    return Card(
      elevation: 0,
      color: AppTheme.primary.withValues(alpha: 0.04),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.12)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome, color: AppTheme.primary, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Quick Preset — Auto-fill software name by local body type',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primary,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _presets.keys.map((type) {
                final isActive = type == currentType;
                return ChoiceChip(
                  label: Text(
                    type.replaceAll('_', ' '),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: isActive ? Colors.white : AppTheme.textSecondary,
                    ),
                  ),
                  selected: isActive,
                  selectedColor: AppTheme.primary,
                  onSelected: (_) => _applyPreset(type),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // ── Error State ────────────────────────────────────────────────────────

  Widget _buildErrorState() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            children: [
              const Icon(Icons.error_outline, size: 40, color: AppTheme.error),
              const SizedBox(height: 12),
              Text(
                _errorMessage ?? 'Unknown error',
                style: TextStyle(color: AppTheme.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => _loadBranding(_selectedBranch!.id),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Form Card ──────────────────────────────────────────────────────────

  Widget _buildFormCard() {
    return Form(
      key: _formKey,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle(Icons.translate, 'Software Name'),
              const SizedBox(height: 14),
              TextFormField(
                controller: _softwareNameTaCtrl,
                decoration: const InputDecoration(
                  labelText: 'Software Name (Tamil / தமிழ்)',
                  hintText: 'எ.கா. நகராட்சி குரல்',
                  prefixIcon: Icon(Icons.translate),
                ),
                onChanged: (_) => setState(() {}),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _softwareNameEnCtrl,
                decoration: const InputDecoration(
                  labelText: 'Software Name (English)',
                  hintText: 'e.g. Nagaraatchi Kural',
                  prefixIcon: Icon(Icons.font_download),
                ),
                onChanged: (_) => setState(() {}),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 20),
              _sectionTitle(Icons.short_text, 'Taglines'),
              const SizedBox(height: 14),
              TextFormField(
                controller: _taglineTaCtrl,
                decoration: const InputDecoration(
                  labelText: 'Tagline (Tamil)',
                  hintText: 'குடிமக்கள் சேவை மையம்',
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _taglineEnCtrl,
                decoration: const InputDecoration(
                  labelText: 'Tagline (English)',
                  hintText: 'Citizen Service Portal',
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 20),
              _sectionTitle(Icons.palette, 'Brand Assets & Colors'),
              const SizedBox(height: 14),
              TextFormField(
                controller: _logoUrlCtrl,
                decoration: const InputDecoration(
                  labelText: 'Logo URL',
                  hintText: 'https://...',
                  prefixIcon: Icon(Icons.image_outlined),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _primaryColorCtrl,
                      decoration: InputDecoration(
                        labelText: 'Primary Color',
                        hintText: '#1E3A8A',
                        prefixIcon: Icon(Icons.color_lens,
                            color: _tryParseColor(_primaryColorCtrl.text)),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _secondaryColorCtrl,
                      decoration: InputDecoration(
                        labelText: 'Secondary Color',
                        hintText: '#0EA5E9',
                        prefixIcon: Icon(Icons.color_lens_outlined,
                            color: _tryParseColor(_secondaryColorCtrl.text)),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _sectionTitle(Icons.record_voice_over, 'IVR Voice Greeting'),
              const SizedBox(height: 14),
              TextFormField(
                controller: _welcomeAudioUrlCtrl,
                decoration: const InputDecoration(
                  labelText: 'Custom Welcome Audio URL (Optional)',
                  hintText: 'https://storage.com/welcome.mp3',
                  prefixIcon: Icon(Icons.audio_file_outlined),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveBranding,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_rounded),
                  label: Text(_isSaving ? 'Saving...' : 'Save Branding'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Preview Card ───────────────────────────────────────────────────────

  Widget _buildPreviewCard() {
    final nameTa = _softwareNameTaCtrl.text.isNotEmpty
        ? _softwareNameTaCtrl.text
        : 'நகராட்சி குரல்';
    final nameEn = _softwareNameEnCtrl.text.isNotEmpty
        ? _softwareNameEnCtrl.text
        : 'Nagaraatchi Kural';
    final taglineTa = _taglineTaCtrl.text.isNotEmpty
        ? _taglineTaCtrl.text
        : 'குடிமக்கள் சேவை மையம்';
    final branchLabel =
        (_selectedBranch?.branchType ?? 'MUNICIPALITY').replaceAll('_', ' ');
    final previewColor =
        _tryParseColor(_primaryColorCtrl.text) ?? AppTheme.primary;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.preview_rounded,
                    color: AppTheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Live Preview',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Mock AppBar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: previewColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  // Logo placeholder
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: _logoUrlCtrl.text.trim().isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              _logoUrlCtrl.text.trim(),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.location_city,
                                color: Colors.white70,
                                size: 20,
                              ),
                            ),
                          )
                        : const Icon(Icons.location_city,
                            color: Colors.white70, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nameTa,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          nameEn,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      branchLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Tagline preview
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: previewColor.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: previewColor.withValues(alpha: 0.15)),
              ),
              child: Text(
                taglineTa,
                style: TextStyle(
                  fontSize: 12,
                  color: previewColor,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),

            // IVR Script preview
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: Colors.amber.withValues(alpha: 0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.record_voice_over,
                          color: Colors.amber.shade700, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'IVR Greeting Script',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: Colors.amber.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '🗣️ "வணக்கம்! $nameTa சேவைக்கு வரவேற்கிறோம்..."',
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '🗣️ "Welcome to $nameEn service..."',
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.5,
                      fontStyle: FontStyle.italic,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────

  Widget _sectionTitle(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.primary),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }

  Color? _tryParseColor(String hex) {
    if (hex.isEmpty) return null;
    final clean = hex.replaceAll('#', '').trim();
    if (clean.length != 6) return null;
    final value = int.tryParse(clean, radix: 16);
    if (value == null) return null;
    return Color(0xFF000000 | value);
  }
}
