import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:ivr_frontend/config/app_theme.dart';
import 'package:ivr_frontend/core/api/api_exceptions.dart';
import 'package:ivr_frontend/core/widgets/app_card.dart';
import 'package:ivr_frontend/core/widgets/app_error_state.dart';
import 'package:ivr_frontend/core/widgets/app_loading_state.dart';
import 'package:ivr_frontend/features/modules/trade_licences/data/models/trade_licence_models.dart';
import 'package:ivr_frontend/features/modules/trade_licences/data/trade_licence_repository.dart';

/// Intake and revision form for a trade licence.
///
/// Doubles as create and edit. Only DRAFT and SUBMITTED licences are editable
/// — the backend refuses the rest, and this screen refuses to open them rather
/// than letting a clerk type into a form that cannot save.
class TradeLicenceFormScreen extends StatefulWidget {
  final int? licenceId;

  const TradeLicenceFormScreen({super.key, this.licenceId});

  @override
  State<TradeLicenceFormScreen> createState() => _TradeLicenceFormScreenState();
}

class _TradeLicenceFormScreenState extends State<TradeLicenceFormScreen> {
  final _repo = TradeLicenceRepository();
  final _formKey = GlobalKey<FormState>();

  // Trade
  final _tradeNameCtrl = TextEditingController();
  String _category = 'eatery';
  final _subCategoryCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _hpCtrl = TextEditingController();
  final _workersCtrl = TextEditingController();
  final _hoursCtrl = TextEditingController();

  // Owner
  final _ownerNameCtrl = TextEditingController();
  String _ownershipType = 'PROPRIETOR';
  final _signatoryCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _aadhaarCtrl = TextEditingController();

  // Premises
  final _doorCtrl = TextEditingController();
  final _streetCtrl = TextEditingController();
  final _wardCtrl = TextEditingController();
  final _surveyCtrl = TextEditingController();
  final _areaCtrl = TextEditingController();
  bool _isRented = false;
  final _landlordCtrl = TextEditingController();
  final _rentRefCtrl = TextEditingController();

  // Statutory references
  final _fssaiCtrl = TextEditingController();
  DateTime? _fssaiExpiry;
  final _gstCtrl = TextEditingController();
  final _fireNocCtrl = TextEditingController();
  DateTime? _fireNocExpiry;
  final _pollutionCtrl = TextEditingController();
  DateTime? _pollutionExpiry;

  bool _saving = false;
  String? _saveError;
  Future<TradeLicenceDetail>? _loadFuture;

  bool get _isEdit => widget.licenceId != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _loadFuture = _repo.getLicence(widget.licenceId!).then((d) {
        _populate(d);
        return d;
      });
    }
  }

  @override
  void dispose() {
    for (final c in [
      _tradeNameCtrl,
      _subCategoryCtrl,
      _descriptionCtrl,
      _hpCtrl,
      _workersCtrl,
      _hoursCtrl,
      _ownerNameCtrl,
      _signatoryCtrl,
      _phoneCtrl,
      _emailCtrl,
      _addressCtrl,
      _aadhaarCtrl,
      _doorCtrl,
      _streetCtrl,
      _wardCtrl,
      _surveyCtrl,
      _areaCtrl,
      _landlordCtrl,
      _rentRefCtrl,
      _fssaiCtrl,
      _gstCtrl,
      _fireNocCtrl,
      _pollutionCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _populate(TradeLicenceDetail d) {
    final s = d.summary;
    _tradeNameCtrl.text = s.tradeName;
    _category = s.tradeCategory.isEmpty ? 'eatery' : s.tradeCategory;
    _subCategoryCtrl.text = s.tradeSubCategory ?? '';
    _descriptionCtrl.text = d.description ?? '';
    _hpCtrl.text = s.motivePowerHp?.toString() ?? '';
    _workersCtrl.text = d.workerCount?.toString() ?? '';
    _hoursCtrl.text = d.operatingHours ?? '';

    _ownerNameCtrl.text = s.ownerName;
    _ownershipType = d.ownershipType ?? 'PROPRIETOR';
    _signatoryCtrl.text = d.signatoryName ?? '';
    _phoneCtrl.text = s.ownerPhone ?? '';
    _emailCtrl.text = d.ownerEmail ?? '';
    _addressCtrl.text = d.ownerAddress ?? '';

    _doorCtrl.text = s.doorNumber ?? '';
    _streetCtrl.text = s.streetName ?? '';
    _wardCtrl.text = s.wardNumber ?? '';
    _surveyCtrl.text = d.surveyNumber ?? '';
    _areaCtrl.text = s.areaSqft.toStringAsFixed(0);
    _isRented = d.isRented;
    _landlordCtrl.text = d.landlordName ?? '';

    _fssaiCtrl.text = d.fssaiNumber ?? '';
    _fssaiExpiry = d.fssaiExpiry;
    _gstCtrl.text = d.gstNumber ?? '';
    _fireNocCtrl.text = d.fireNocRef ?? '';
    _fireNocExpiry = d.fireNocExpiry;
    _pollutionCtrl.text = d.pollutionConsentRef ?? '';
    _pollutionExpiry = d.pollutionConsentExpiry;
  }

  String? _t(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _saving = true;
      _saveError = null;
    });

    final payload = <String, dynamic>{
      'trade_name': _tradeNameCtrl.text.trim(),
      if (_t(_descriptionCtrl) != null) 'description': _t(_descriptionCtrl),
      if (double.tryParse(_hpCtrl.text.trim()) != null)
        'motive_power_hp': double.parse(_hpCtrl.text.trim()),
      if (int.tryParse(_workersCtrl.text.trim()) != null)
        'worker_count': int.parse(_workersCtrl.text.trim()),
      'owner_name': _ownerNameCtrl.text.trim(),
      if (_t(_phoneCtrl) != null) 'owner_phone': _t(_phoneCtrl),
      if (_t(_emailCtrl) != null) 'owner_email': _t(_emailCtrl),
      if (_t(_addressCtrl) != null) 'owner_address': _t(_addressCtrl),
      'area_sqft': double.tryParse(_areaCtrl.text.trim()) ?? 0,
      if (_t(_fssaiCtrl) != null) 'fssai_number': _t(_fssaiCtrl),
      if (_fssaiExpiry != null) 'fssai_expiry': _fssaiExpiry!.toIso8601String(),
      if (_t(_fireNocCtrl) != null) 'fire_noc_ref': _t(_fireNocCtrl),
      if (_fireNocExpiry != null)
        'fire_noc_expiry': _fireNocExpiry!.toIso8601String(),
    };

    if (!_isEdit) {
      payload.addAll({
        'trade_category': _category,
        if (_t(_subCategoryCtrl) != null)
          'trade_sub_category': _t(_subCategoryCtrl),
        if (_t(_hoursCtrl) != null) 'operating_hours': _t(_hoursCtrl),
        'ownership_type': _ownershipType,
        if (_ownershipType != 'PROPRIETOR' && _t(_signatoryCtrl) != null)
          'signatory_name': _t(_signatoryCtrl),
        if (_t(_aadhaarCtrl) != null) 'owner_aadhaar': _t(_aadhaarCtrl),
        if (_t(_doorCtrl) != null) 'door_number': _t(_doorCtrl),
        if (_t(_streetCtrl) != null) 'street_name': _t(_streetCtrl),
        if (_t(_wardCtrl) != null) 'ward_number': _t(_wardCtrl),
        if (_t(_surveyCtrl) != null) 'survey_number': _t(_surveyCtrl),
        'is_rented': _isRented,
        if (_isRented && _t(_landlordCtrl) != null)
          'landlord_name': _t(_landlordCtrl),
        if (_isRented && _t(_rentRefCtrl) != null)
          'rent_agreement_ref': _t(_rentRefCtrl),
        if (_t(_gstCtrl) != null) 'gst_number': _t(_gstCtrl),
        if (_t(_pollutionCtrl) != null)
          'pollution_consent_ref': _t(_pollutionCtrl),
        if (_pollutionExpiry != null)
          'pollution_consent_expiry': _pollutionExpiry!.toIso8601String(),
      });
    }

    try {
      final saved = _isEdit
          ? await _repo.updateLicence(widget.licenceId!, payload)
          : await _repo.createLicence(payload);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEdit
                ? 'Application updated'
                : 'Application ${saved.licenceNumber} created as a draft',
          ),
        ),
      );
      context.go('/municipality/trade-licences/${saved.id}');
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
    if (!_isEdit) return _buildForm();

    return FutureBuilder<TradeLicenceDetail>(
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
                'This licence is ${snap.data!.status.label} and can no longer be edited.',
            onRetry: () =>
                context.go('/municipality/trade-licences/${widget.licenceId}'),
          );
        }
        return _buildForm();
      },
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(AppTheme.spaceLg),
        children: [
          _Section(
            title: 'The trade',
            icon: Icons.storefront_outlined,
            children: [
              _row([
                _field(
                  controller: _tradeNameCtrl,
                  label: 'Trade name *',
                  validator: (v) => (v == null || v.trim().length < 2)
                      ? 'Enter the name the trade operates under'
                      : null,
                ),
                _dropdown(
                  label: 'Category *',
                  value: _category,
                  options: kTradeCategories,
                  enabled: !_isEdit,
                  helper: _isEdit
                      ? 'A different trade is a different licence'
                      : null,
                  onChanged: (v) => setState(() => _category = v!),
                ),
              ]),
              _row([
                _field(controller: _subCategoryCtrl, label: 'Sub-category', enabled: !_isEdit),
                _field(
                  controller: _hpCtrl,
                  label: 'Motive power (HP)',
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  helper: 'Affects the fee band',
                ),
                _field(
                  controller: _workersCtrl,
                  label: 'Workers',
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ]),
              _field(
                controller: _descriptionCtrl,
                label: 'Description of the trade',
                maxLines: 2,
              ),
              if (!_isEdit) ...[
                const SizedBox(height: AppTheme.spaceSm),
                _field(
                  controller: _hoursCtrl,
                  label: 'Operating hours',
                  hint: '06:00-22:00',
                  validator: (v) {
                    final raw = (v ?? '').trim();
                    if (raw.isEmpty) return null;
                    return RegExp(
                      r'^([01]\d|2[0-3]):[0-5]\d-([01]\d|2[0-3]):[0-5]\d$',
                    ).hasMatch(raw)
                        ? null
                        : 'Use HH:MM-HH:MM';
                  },
                ),
              ],
            ],
          ),
          _Section(
            title: 'Owner',
            icon: Icons.person_outline_rounded,
            children: [
              _row([
                _field(
                  controller: _ownerNameCtrl,
                  label: 'Owner / firm name *',
                  validator: (v) => (v == null || v.trim().length < 3)
                      ? 'Enter the owner or firm name'
                      : null,
                ),
                if (!_isEdit)
                  _dropdown(
                    label: 'Legal form *',
                    value: _ownershipType,
                    options: kOwnershipTypes,
                    onChanged: (v) => setState(() => _ownershipType = v!),
                  ),
              ]),
              if (!_isEdit && _ownershipType != 'PROPRIETOR')
                _field(
                  controller: _signatoryCtrl,
                  label: 'Authorised signatory',
                  helper: 'Who signs on behalf of the firm',
                ),
              const SizedBox(height: AppTheme.spaceSm),
              _row([
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
                _field(
                  controller: _emailCtrl,
                  label: 'Email',
                  keyboardType: TextInputType.emailAddress,
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
                    helper: 'Only the last 4 digits are stored',
                    validator: (v) {
                      final raw = (v ?? '').trim();
                      if (raw.isEmpty) return null;
                      return raw.length == 12 ? null : 'Aadhaar must be 12 digits';
                    },
                  ),
              ]),
              _field(
                controller: _addressCtrl,
                label: 'Correspondence address',
                maxLines: 2,
              ),
            ],
          ),
          _Section(
            title: 'Premises',
            icon: Icons.place_outlined,
            children: [
              _row([
                _field(controller: _doorCtrl, label: 'Door number', enabled: !_isEdit),
                _field(controller: _streetCtrl, label: 'Street', enabled: !_isEdit),
                _field(controller: _wardCtrl, label: 'Ward', enabled: !_isEdit),
              ]),
              _row([
                _field(
                  controller: _surveyCtrl,
                  label: 'Survey number',
                  enabled: !_isEdit,
                ),
                _field(
                  controller: _areaCtrl,
                  label: 'Floor area (sqft) *',
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  helper: 'Drives the area component of the fee',
                  validator: (v) {
                    final n = double.tryParse((v ?? '').trim());
                    if (n == null || n <= 0) {
                      return 'Enter an area greater than zero';
                    }
                    return null;
                  },
                ),
              ]),
              if (!_isEdit) ...[
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _isRented,
                  onChanged: (v) => setState(() => _isRented = v),
                  title: const Text('Premises are rented'),
                ),
                if (_isRented)
                  _row([
                    _field(controller: _landlordCtrl, label: 'Landlord name'),
                    _field(
                      controller: _rentRefCtrl,
                      label: 'Rent agreement reference',
                    ),
                  ]),
              ],
            ],
          ),
          _Section(
            title: 'Statutory references',
            icon: Icons.verified_outlined,
            subtitle:
                'Licences the trade holds from other authorities. These are '
                'recorded here, not issued — a licence resting on a lapsed NOC '
                'is flagged on the detail screen.',
            children: [
              _row([
                _field(
                  controller: _fssaiCtrl,
                  label: 'FSSAI number',
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(14),
                  ],
                  validator: (v) {
                    final raw = (v ?? '').trim();
                    if (raw.isEmpty) return null;
                    return raw.length == 14 ? null : 'FSSAI number is 14 digits';
                  },
                ),
                _datePicker(
                  label: 'FSSAI expiry',
                  value: _fssaiExpiry,
                  onPicked: (d) => setState(() => _fssaiExpiry = d),
                ),
              ]),
              _row([
                _field(
                  controller: _fireNocCtrl,
                  label: 'Fire NOC reference',
                ),
                _datePicker(
                  label: 'Fire NOC expiry',
                  value: _fireNocExpiry,
                  onPicked: (d) => setState(() => _fireNocExpiry = d),
                ),
              ]),
              if (!_isEdit)
                _row([
                  _field(controller: _gstCtrl, label: 'GSTIN'),
                  _field(
                    controller: _pollutionCtrl,
                    label: 'Pollution board consent',
                  ),
                  _datePicker(
                    label: 'Consent expiry',
                    value: _pollutionExpiry,
                    onPicked: (d) => setState(() => _pollutionExpiry = d),
                  ),
                ]),
            ],
          ),
          if (_saveError != null) ...[
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
                      style: const TextStyle(fontSize: 12, color: AppTheme.error),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spaceMd),
          ],
          Text(
            'The fee is calculated on save from the council\'s approved rate '
            'schedule, and pro-rated by the quarters remaining in the licence '
            'year (1 April – 31 March).',
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
                              ? '/municipality/trade-licences/${widget.licenceId}'
                              : '/municipality/trade-licences',
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

  // ── Field builders ───────────────────────────────────────────────────────

  Widget _field({
    required TextEditingController controller,
    required String label,
    String? hint,
    String? helper,
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
        hintText: hint,
        helperText: helper,
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
    bool enabled = true,
    String? helper,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        helperText: helper,
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
      ),
      items: options
          .map((o) => DropdownMenuItem(value: o, child: Text(titleCase(o))))
          .toList(),
      onChanged: enabled ? onChanged : null,
    );
  }

  Widget _datePicker({
    required String label,
    required DateTime? value,
    required ValueChanged<DateTime> onPicked,
  }) {
    final df = DateFormat.yMMMd();
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              value == null ? 'Not set' : df.format(value),
              style: TextStyle(
                fontSize: 14,
                color: value == null ? AppTheme.textMuted : AppTheme.textPrimary,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: value ?? DateTime.now(),
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (picked != null) onPicked(picked);
            },
            child: const Text('Pick'),
          ),
        ],
      ),
    );
  }

  Widget _row(List<Widget> children) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 720 || children.length == 1) {
          return Column(
            children: [
              for (final child in children) ...[
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
              for (var i = 0; i < children.length; i++) ...[
                Expanded(child: children[i]),
                if (i != children.length - 1)
                  const SizedBox(width: AppTheme.spaceSm),
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
