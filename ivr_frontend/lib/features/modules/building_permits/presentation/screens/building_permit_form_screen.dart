import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'package:ivr_frontend/config/app_theme.dart';
import 'package:ivr_frontend/core/api/api_exceptions.dart';
import 'package:ivr_frontend/core/widgets/app_card.dart';
import 'package:ivr_frontend/core/widgets/app_error_state.dart';
import 'package:ivr_frontend/core/widgets/app_loading_state.dart';
import 'package:ivr_frontend/features/modules/building_permits/data/building_permit_repository.dart';
import 'package:ivr_frontend/features/modules/building_permits/data/models/building_permit_models.dart';

/// Intake and revision form for a building permit application.
///
/// Doubles as create and edit: pass a [permitId] to load an existing draft.
/// Only DRAFT and RETURNED permits are editable — the backend rejects the rest,
/// and this screen refuses to open them rather than letting a clerk type into a
/// form that cannot save.
class BuildingPermitFormScreen extends StatefulWidget {
  final int? permitId;

  const BuildingPermitFormScreen({super.key, this.permitId});

  @override
  State<BuildingPermitFormScreen> createState() =>
      _BuildingPermitFormScreenState();
}

class _BuildingPermitFormScreenState extends State<BuildingPermitFormScreen> {
  final _repo = BuildingPermitRepository();
  final _formKey = GlobalKey<FormState>();

  // Applicant
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _aadhaarCtrl = TextEditingController();
  final _poaCtrl = TextEditingController();
  bool _isOwner = true;

  // Site
  final _surveyCtrl = TextEditingController();
  final _subdivisionCtrl = TextEditingController();
  final _wardCtrl = TextEditingController();
  final _streetCtrl = TextEditingController();
  final _doorCtrl = TextEditingController();
  final _plotAreaCtrl = TextEditingController();

  // Proposal
  String _constructionType = 'residential';
  String _workNature = 'new';
  final _builtUpCtrl = TextEditingController();
  final _floorsCtrl = TextEditingController(text: '1');
  final _heightCtrl = TextEditingController();
  final _setbackFrontCtrl = TextEditingController();
  final _setbackRearCtrl = TextEditingController();
  final _setbackLeftCtrl = TextEditingController();
  final _setbackRightCtrl = TextEditingController();
  final _costCtrl = TextEditingController();

  // Professional
  final _architectCtrl = TextEditingController();
  final _licenceCtrl = TextEditingController();

  final Set<String> _selectedNocs = {};

  bool _saving = false;
  String? _saveError;
  Future<BuildingPermitDetail>? _loadFuture;

  bool get _isEdit => widget.permitId != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _loadFuture = _repo.getPermit(widget.permitId!).then((detail) {
        _populate(detail);
        return detail;
      });
    }
  }

  @override
  void dispose() {
    for (final c in [
      _nameCtrl,
      _phoneCtrl,
      _emailCtrl,
      _addressCtrl,
      _aadhaarCtrl,
      _poaCtrl,
      _surveyCtrl,
      _subdivisionCtrl,
      _wardCtrl,
      _streetCtrl,
      _doorCtrl,
      _plotAreaCtrl,
      _builtUpCtrl,
      _floorsCtrl,
      _heightCtrl,
      _setbackFrontCtrl,
      _setbackRearCtrl,
      _setbackLeftCtrl,
      _setbackRightCtrl,
      _costCtrl,
      _architectCtrl,
      _licenceCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _populate(BuildingPermitDetail d) {
    final s = d.summary;
    _nameCtrl.text = s.applicantName;
    _phoneCtrl.text = s.applicantPhone ?? '';
    _emailCtrl.text = d.applicantEmail ?? '';
    _addressCtrl.text = d.applicantAddress ?? '';
    _poaCtrl.text = d.powerOfAttorney ?? '';
    _isOwner = d.isOwner;

    _surveyCtrl.text = s.surveyNumber;
    _subdivisionCtrl.text = d.subdivisionNo ?? '';
    _wardCtrl.text = d.wardNumber ?? '';
    _streetCtrl.text = s.streetName ?? '';
    _doorCtrl.text = s.doorNumber ?? '';
    _plotAreaCtrl.text = _fmt(s.plotAreaSqm);

    _constructionType = s.constructionType.isEmpty ? 'residential' : s.constructionType;
    _workNature = s.workNature.isEmpty ? 'new' : s.workNature;
    _builtUpCtrl.text = _fmt(s.builtUpAreaSqm);
    _floorsCtrl.text = '${s.floorsProposed}';
    _heightCtrl.text = d.heightM == null ? '' : _fmt(d.heightM!);
    _setbackFrontCtrl.text = d.setbackFrontM == null ? '' : _fmt(d.setbackFrontM!);
    _setbackRearCtrl.text = d.setbackRearM == null ? '' : _fmt(d.setbackRearM!);
    _setbackLeftCtrl.text = d.setbackLeftM == null ? '' : _fmt(d.setbackLeftM!);
    _setbackRightCtrl.text = d.setbackRightM == null ? '' : _fmt(d.setbackRightM!);
    _costCtrl.text = d.estimatedCost == null ? '' : _fmt(d.estimatedCost!);

    _architectCtrl.text = d.architectName ?? '';
    _licenceCtrl.text = d.architectLicence ?? '';
  }

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  double? _parse(TextEditingController c) {
    final raw = c.text.trim();
    if (raw.isEmpty) return null;
    return double.tryParse(raw);
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _saving = true;
      _saveError = null;
    });

    final payload = <String, dynamic>{
      'applicant_name': _nameCtrl.text.trim(),
      if (_phoneCtrl.text.trim().isNotEmpty) 'applicant_phone': _phoneCtrl.text.trim(),
      if (_emailCtrl.text.trim().isNotEmpty) 'applicant_email': _emailCtrl.text.trim(),
      if (_addressCtrl.text.trim().isNotEmpty)
        'applicant_address': _addressCtrl.text.trim(),
      if (_wardCtrl.text.trim().isNotEmpty) 'ward_number': _wardCtrl.text.trim(),
      if (_streetCtrl.text.trim().isNotEmpty) 'street_name': _streetCtrl.text.trim(),
      if (_doorCtrl.text.trim().isNotEmpty) 'door_number': _doorCtrl.text.trim(),
      'plot_area_sqm': _parse(_plotAreaCtrl),
      'construction_type': _constructionType,
      'work_nature': _workNature,
      'built_up_area_sqm': _parse(_builtUpCtrl),
      'floors_proposed': int.tryParse(_floorsCtrl.text.trim()) ?? 1,
      if (_parse(_heightCtrl) != null) 'height_m': _parse(_heightCtrl),
      if (_parse(_setbackFrontCtrl) != null)
        'setback_front_m': _parse(_setbackFrontCtrl),
      if (_parse(_setbackRearCtrl) != null) 'setback_rear_m': _parse(_setbackRearCtrl),
      if (_parse(_setbackLeftCtrl) != null) 'setback_left_m': _parse(_setbackLeftCtrl),
      if (_parse(_setbackRightCtrl) != null)
        'setback_right_m': _parse(_setbackRightCtrl),
      if (_parse(_costCtrl) != null) 'estimated_cost': _parse(_costCtrl),
      if (_architectCtrl.text.trim().isNotEmpty)
        'architect_name': _architectCtrl.text.trim(),
      if (_licenceCtrl.text.trim().isNotEmpty)
        'architect_licence': _licenceCtrl.text.trim(),
    };

    if (!_isEdit) {
      payload['survey_number'] = _surveyCtrl.text.trim();
      payload['is_owner'] = _isOwner;
      if (_subdivisionCtrl.text.trim().isNotEmpty) {
        payload['subdivision_no'] = _subdivisionCtrl.text.trim();
      }
      if (!_isOwner && _poaCtrl.text.trim().isNotEmpty) {
        payload['power_of_attorney'] = _poaCtrl.text.trim();
      }
      if (_aadhaarCtrl.text.trim().isNotEmpty) {
        payload['applicant_aadhaar'] = _aadhaarCtrl.text.trim();
      }
      if (_selectedNocs.isNotEmpty) {
        payload['noc_departments'] = _selectedNocs.toList();
      }
    }

    try {
      final saved = _isEdit
          ? await _repo.updatePermit(widget.permitId!, payload)
          : await _repo.createPermit(payload);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEdit
                ? 'Application updated'
                : 'Application ${saved.permitNumber} created as a draft',
          ),
        ),
      );
      context.go('/municipality/building-permits/${saved.id}');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveError = userFacingMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isEdit) return _buildForm(context);

    return FutureBuilder<BuildingPermitDetail>(
      future: _loadFuture,
      builder: (context, snap) {
        if (snap.hasError) {
          return AppErrorState(message: userFacingMessage(snap.error!));
        }
        if (!snap.hasData) {
          return const AppLoadingState(
            message: 'Loading application...',
            style: AppLoadingStyle.detail,
          );
        }
        if (!snap.data!.status.isEditable) {
          return AppErrorState(
            message:
                'This application is in ${snap.data!.status.label} and can no longer be edited. '
                'Return it to the applicant first.',
            onRetry: () =>
                context.go('/municipality/building-permits/${widget.permitId}'),
          );
        }
        return _buildForm(context);
      },
    );
  }

  Widget _buildForm(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(AppTheme.spaceLg),
        children: [
          _Section(
            title: 'Applicant',
            icon: Icons.person_outline_rounded,
            children: [
              _row([
                _field(
                  controller: _nameCtrl,
                  label: 'Applicant name *',
                  validator: (v) => (v == null || v.trim().length < 3)
                      ? 'Enter the applicant\'s full name'
                      : null,
                ),
                _field(
                  controller: _phoneCtrl,
                  label: 'Mobile number',
                  keyboardType: TextInputType.phone,
                  validator: (v) {
                    final raw = (v ?? '').trim();
                    if (raw.isEmpty) return null;
                    return RegExp(r'^(\+91)?[6-9]\d{9}$').hasMatch(raw)
                        ? null
                        : 'Enter a valid 10-digit mobile number';
                  },
                ),
              ]),
              _row([
                _field(
                  controller: _emailCtrl,
                  label: 'Email',
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    final raw = (v ?? '').trim();
                    if (raw.isEmpty) return null;
                    return raw.contains('@') ? null : 'Enter a valid email';
                  },
                ),
                if (!_isEdit)
                  _field(
                    controller: _aadhaarCtrl,
                    label: 'Aadhaar (12 digits)',
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(12),
                    ],
                    helperText: 'Only the last 4 digits are stored',
                    validator: (v) {
                      final raw = (v ?? '').trim();
                      if (raw.isEmpty) return null;
                      return raw.length == 12 ? null : 'Aadhaar must be 12 digits';
                    },
                  )
                else
                  const SizedBox.shrink(),
              ]),
              _field(
                controller: _addressCtrl,
                label: 'Correspondence address',
                maxLines: 2,
              ),
              if (!_isEdit) ...[
                const SizedBox(height: AppTheme.spaceSm),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _isOwner,
                  onChanged: (v) => setState(() => _isOwner = v),
                  title: const Text('Applicant is the site owner'),
                  subtitle: const Text(
                    'Turn off if applying through a power of attorney holder',
                  ),
                ),
                if (!_isOwner)
                  _field(
                    controller: _poaCtrl,
                    label: 'Power of attorney holder',
                  ),
              ],
            ],
          ),
          _Section(
            title: 'Site',
            icon: Icons.place_outlined,
            children: [
              _row([
                _field(
                  controller: _surveyCtrl,
                  label: 'Survey number *',
                  enabled: !_isEdit,
                  helperText: _isEdit
                      ? 'A permit cannot be moved to a different plot'
                      : null,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Survey number is required'
                      : null,
                ),
                _field(
                  controller: _subdivisionCtrl,
                  label: 'Subdivision',
                  enabled: !_isEdit,
                ),
              ]),
              _row([
                _field(controller: _doorCtrl, label: 'Door number'),
                _field(controller: _streetCtrl, label: 'Street'),
                _field(controller: _wardCtrl, label: 'Ward'),
              ]),
              _field(
                controller: _plotAreaCtrl,
                label: 'Plot area (sqm) *',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: _positiveNumber,
              ),
            ],
          ),
          _Section(
            title: 'Proposal',
            icon: Icons.architecture_rounded,
            children: [
              _row([
                _dropdown(
                  label: 'Construction type *',
                  value: _constructionType,
                  options: kConstructionTypes,
                  onChanged: (v) => setState(() => _constructionType = v!),
                ),
                _dropdown(
                  label: 'Nature of work *',
                  value: _workNature,
                  options: kWorkNatures,
                  onChanged: (v) => setState(() => _workNature = v!),
                ),
              ]),
              _row([
                _field(
                  controller: _builtUpCtrl,
                  label: 'Built-up area (sqm) *',
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: _positiveNumber,
                ),
                _field(
                  controller: _floorsCtrl,
                  label: 'Floors proposed *',
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  helperText: 'Above 3 attracts a high-rise surcharge',
                  validator: (v) {
                    final n = int.tryParse((v ?? '').trim());
                    if (n == null || n < 1) return 'At least one floor';
                    return null;
                  },
                ),
                _field(
                  controller: _heightCtrl,
                  label: 'Height (m)',
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
              ]),
              _row([
                _field(
                  controller: _setbackFrontCtrl,
                  label: 'Setback front (m)',
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
                _field(
                  controller: _setbackRearCtrl,
                  label: 'Setback rear (m)',
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
                _field(
                  controller: _setbackLeftCtrl,
                  label: 'Setback left (m)',
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
                _field(
                  controller: _setbackRightCtrl,
                  label: 'Setback right (m)',
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
              ]),
              _field(
                controller: _costCtrl,
                label: 'Estimated cost of construction (₹)',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ],
          ),
          _Section(
            title: 'Licensed surveyor / architect',
            icon: Icons.badge_outlined,
            children: [
              _row([
                _field(controller: _architectCtrl, label: 'Name'),
                _field(controller: _licenceCtrl, label: 'Licence number'),
              ]),
            ],
          ),
          if (!_isEdit)
            _Section(
              title: 'Department clearances',
              icon: Icons.fact_check_outlined,
              subtitle:
                  'Leave empty to use the standard checklist for this construction type. '
                  'Departments can be added or removed later.',
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: kNocDepartments.map((dept) {
                    final selected = _selectedNocs.contains(dept);
                    return FilterChip(
                      label: Text(titleCase(dept)),
                      selected: selected,
                      onSelected: (on) => setState(() {
                        if (on) {
                          _selectedNocs.add(dept);
                        } else {
                          _selectedNocs.remove(dept);
                        }
                      }),
                    );
                  }).toList(),
                ),
              ],
            ),
          if (_saveError != null) ...[
            const SizedBox(height: AppTheme.spaceMd),
            Container(
              padding: const EdgeInsets.all(AppTheme.spaceSm),
              decoration: BoxDecoration(
                color: AppTheme.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, size: 18, color: AppTheme.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _saveError!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppTheme.spaceMd),
          Text(
            'Scrutiny, permit and development fees are calculated on save from the '
            'council\'s approved rate schedule.',
            style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
          ),
          const SizedBox(height: AppTheme.spaceMd),
          Row(
            children: [
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_rounded),
                label: Text(_isEdit ? 'Save changes' : 'Create draft'),
              ),
              const SizedBox(width: 12),
              TextButton(
                onPressed: _saving
                    ? null
                    : () => context.go(
                          _isEdit
                              ? '/municipality/building-permits/${widget.permitId}'
                              : '/municipality/building-permits',
                        ),
                child: const Text('Cancel'),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceXl),
        ],
      ),
    );
  }

  String? _positiveNumber(String? v) {
    final n = double.tryParse((v ?? '').trim());
    if (n == null || n <= 0) return 'Enter a number greater than zero';
    return null;
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    String? helperText,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    int maxLines = 1,
    bool enabled = true,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      maxLines: maxLines,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label,
        helperText: helperText,
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
      ),
    );
  }

  Widget _dropdown({
    required String label,
    required String value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
      ),
      items: options
          .map((o) => DropdownMenuItem(value: o, child: Text(titleCase(o))))
          .toList(),
      onChanged: onChanged,
    );
  }

  /// Lay fields out side by side on wide screens, stacked on narrow ones.
  Widget _row(List<Widget> children) {
    final visible = children.where((c) => c is! SizedBox).toList();
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 720 || visible.length == 1) {
          return Column(
            children: [
              for (final child in visible) ...[
                child,
                const SizedBox(height: AppTheme.spaceSm),
              ],
            ],
          );
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: AppTheme.spaceSm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < visible.length; i++) ...[
                Expanded(child: visible[i]),
                if (i != visible.length - 1) const SizedBox(width: AppTheme.spaceSm),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final String? subtitle;
  final List<Widget> children;

  const _Section({
    required this.title,
    required this.icon,
    required this.children,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: AppTheme.spaceMd),
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
          ],
          const SizedBox(height: AppTheme.spaceMd),
          ...children,
        ],
      ),
    );
  }
}
