import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:ivr_frontend/config/app_theme.dart';
import 'package:ivr_frontend/core/api/api_exceptions.dart';
import 'package:ivr_frontend/core/widgets/app_card.dart';
import 'package:ivr_frontend/features/modules/vital_events/data/models/vital_event_models.dart';
import 'package:ivr_frontend/features/modules/vital_events/data/vital_event_repository.dart';
import 'package:ivr_frontend/features/modules/vital_events/presentation/widgets/vital_status_badge.dart';

/// Intake form for a birth (Form 1) or death (Form 2) report.
///
/// The delay banner updates as soon as an event date is picked, because a
/// clerk needs to know *before* filling three screens of particulars that this
/// one is going to need a magistrate's order.
class VitalEventFormScreen extends StatefulWidget {
  final VitalEventType eventType;

  const VitalEventFormScreen({super.key, required this.eventType});

  @override
  State<VitalEventFormScreen> createState() => _VitalEventFormScreenState();
}

class _VitalEventFormScreenState extends State<VitalEventFormScreen> {
  final _repo = VitalEventRepository();
  final _formKey = GlobalKey<FormState>();

  // Event
  DateTime? _eventDate;
  final _eventTimeCtrl = TextEditingController();
  String _placeType = 'hospital';
  final _placeNameCtrl = TextEditingController();
  final _placeAddressCtrl = TextEditingController();
  String _reportingSource = 'SELF_REPORTED';
  final _hospitalNameCtrl = TextEditingController();
  final _hospitalRegCtrl = TextEditingController();

  // Informant
  final _informantNameCtrl = TextEditingController();
  String _informantRelation = 'father';
  final _informantPhoneCtrl = TextEditingController();
  final _informantAddressCtrl = TextEditingController();
  final _informantAadhaarCtrl = TextEditingController();

  // Birth particulars
  final _childNameCtrl = TextEditingController();
  String _birthSex = 'male';
  final _weightCtrl = TextEditingController();
  String? _deliveryType;
  final _fatherNameCtrl = TextEditingController();
  final _fatherAadhaarCtrl = TextEditingController();
  final _fatherOccupationCtrl = TextEditingController();
  final _motherNameCtrl = TextEditingController();
  final _motherAadhaarCtrl = TextEditingController();
  final _motherOccupationCtrl = TextEditingController();
  final _motherAgeCtrl = TextEditingController();
  final _birthOrderCtrl = TextEditingController();
  final _permanentAddressCtrl = TextEditingController();

  // Death particulars
  final _deceasedNameCtrl = TextEditingController();
  String _deathSex = 'male';
  final _ageYearsCtrl = TextEditingController();
  final _ageMonthsCtrl = TextEditingController();
  final _ageDaysCtrl = TextEditingController();
  final _spouseNameCtrl = TextEditingController();
  final _deathFatherNameCtrl = TextEditingController();
  final _deathAddressCtrl = TextEditingController();
  final _causeCtrl = TextEditingController();
  String? _causeCategory;
  bool _medicallyCertified = false;
  final _doctorCtrl = TextEditingController();
  final _doctorRegCtrl = TextEditingController();
  String? _disposalMethod;
  final _disposalPlaceCtrl = TextEditingController();

  bool _saving = false;
  String? _saveError;

  bool get _isBirth => widget.eventType == VitalEventType.birth;

  @override
  void initState() {
    super.initState();
    if (!_isBirth) _informantRelation = 'son';
  }

  @override
  void dispose() {
    for (final c in [
      _eventTimeCtrl,
      _placeNameCtrl,
      _placeAddressCtrl,
      _hospitalNameCtrl,
      _hospitalRegCtrl,
      _informantNameCtrl,
      _informantPhoneCtrl,
      _informantAddressCtrl,
      _informantAadhaarCtrl,
      _childNameCtrl,
      _weightCtrl,
      _fatherNameCtrl,
      _fatherAadhaarCtrl,
      _fatherOccupationCtrl,
      _motherNameCtrl,
      _motherAadhaarCtrl,
      _motherOccupationCtrl,
      _motherAgeCtrl,
      _birthOrderCtrl,
      _permanentAddressCtrl,
      _deceasedNameCtrl,
      _ageYearsCtrl,
      _ageMonthsCtrl,
      _ageDaysCtrl,
      _spouseNameCtrl,
      _deathFatherNameCtrl,
      _deathAddressCtrl,
      _causeCtrl,
      _doctorCtrl,
      _doctorRegCtrl,
      _disposalPlaceCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Mirrors `assessDelay` on the backend so the clerk sees the consequence
  /// immediately. The server recomputes it — this is guidance, not authority.
  ({DelayBand band, int days}) get _delay {
    if (_eventDate == null) return (band: DelayBand.ordinary, days: 0);
    final days = DateTime.now().difference(_eventDate!).inDays;
    if (days <= 21) return (band: DelayBand.ordinary, days: days);
    if (days <= 30) return (band: DelayBand.lateFee, days: days);
    if (days <= 365) return (band: DelayBand.authorityPermission, days: days);
    return (band: DelayBand.magistrateOrder, days: days);
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_eventDate == null) {
      setState(() => _saveError = 'Pick the date of the event');
      return;
    }

    setState(() {
      _saving = true;
      _saveError = null;
    });

    String? t(TextEditingController c) =>
        c.text.trim().isEmpty ? null : c.text.trim();
    int? i(TextEditingController c) => int.tryParse(c.text.trim());

    final payload = <String, dynamic>{
      'event_type': widget.eventType.wire,
      'event_date': _eventDate!.toIso8601String(),
      if (t(_eventTimeCtrl) != null) 'event_time': t(_eventTimeCtrl),
      'place_type': _placeType,
      if (t(_placeNameCtrl) != null) 'place_name': t(_placeNameCtrl),
      if (t(_placeAddressCtrl) != null) 'place_address': t(_placeAddressCtrl),
      'reporting_source': _reportingSource,
      if (t(_hospitalNameCtrl) != null) 'hospital_name': t(_hospitalNameCtrl),
      if (t(_hospitalRegCtrl) != null) 'hospital_reg_no': t(_hospitalRegCtrl),
      'informant_name': _informantNameCtrl.text.trim(),
      'informant_relation': _informantRelation,
      if (t(_informantPhoneCtrl) != null)
        'informant_phone': t(_informantPhoneCtrl),
      if (t(_informantAddressCtrl) != null)
        'informant_address': t(_informantAddressCtrl),
      if (t(_informantAadhaarCtrl) != null)
        'informant_aadhaar': t(_informantAadhaarCtrl),
      if (_isBirth)
        'birth': {
          if (t(_childNameCtrl) != null) 'child_name': t(_childNameCtrl),
          'sex': _birthSex,
          if (double.tryParse(_weightCtrl.text.trim()) != null)
            'weight_kg': double.parse(_weightCtrl.text.trim()),
          if (_deliveryType != null) 'delivery_type': _deliveryType,
          if (t(_fatherNameCtrl) != null) 'father_name': t(_fatherNameCtrl),
          if (t(_fatherAadhaarCtrl) != null)
            'father_aadhaar': t(_fatherAadhaarCtrl),
          if (t(_fatherOccupationCtrl) != null)
            'father_occupation': t(_fatherOccupationCtrl),
          'mother_name': _motherNameCtrl.text.trim(),
          if (t(_motherAadhaarCtrl) != null)
            'mother_aadhaar': t(_motherAadhaarCtrl),
          if (t(_motherOccupationCtrl) != null)
            'mother_occupation': t(_motherOccupationCtrl),
          if (i(_motherAgeCtrl) != null) 'mother_age_at_birth': i(_motherAgeCtrl),
          if (i(_birthOrderCtrl) != null) 'birth_order': i(_birthOrderCtrl),
          if (t(_permanentAddressCtrl) != null)
            'permanent_address': t(_permanentAddressCtrl),
        }
      else
        'death': {
          'deceased_name': _deceasedNameCtrl.text.trim(),
          'sex': _deathSex,
          if (i(_ageYearsCtrl) != null) 'age_years': i(_ageYearsCtrl),
          if (i(_ageMonthsCtrl) != null) 'age_months': i(_ageMonthsCtrl),
          if (i(_ageDaysCtrl) != null) 'age_days': i(_ageDaysCtrl),
          if (t(_spouseNameCtrl) != null) 'spouse_name': t(_spouseNameCtrl),
          if (t(_deathFatherNameCtrl) != null)
            'father_name': t(_deathFatherNameCtrl),
          if (t(_deathAddressCtrl) != null) 'address': t(_deathAddressCtrl),
          if (t(_causeCtrl) != null) 'cause_of_death': t(_causeCtrl),
          if (_causeCategory != null) 'cause_category': _causeCategory,
          'medically_certified': _medicallyCertified,
          if (t(_doctorCtrl) != null) 'certifying_doctor': t(_doctorCtrl),
          if (t(_doctorRegCtrl) != null) 'doctor_reg_no': t(_doctorRegCtrl),
          if (_disposalMethod != null) 'disposal_method': _disposalMethod,
          if (t(_disposalPlaceCtrl) != null)
            'disposal_place': t(_disposalPlaceCtrl),
        },
    };

    try {
      final saved = await _repo.reportEvent(payload);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${widget.eventType.label} reported — awaiting the registrar',
          ),
        ),
      );
      context.go('/municipality/vital-events/${saved.id}');
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
    final delay = _delay;

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(AppTheme.spaceLg),
        children: [
          if (_eventDate != null && delay.band != DelayBand.ordinary)
            Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.spaceMd),
              child: _delayBanner(delay.band, delay.days),
            ),
          _Section(
            title: _isBirth ? 'The birth' : 'The death',
            icon: _isBirth
                ? Icons.child_care_rounded
                : Icons.local_florist_rounded,
            children: [
              _row([
                _datePicker(),
                _field(
                  controller: _eventTimeCtrl,
                  label: 'Time (HH:MM)',
                  hint: '14:35',
                  validator: (v) {
                    final raw = (v ?? '').trim();
                    if (raw.isEmpty) return null;
                    return RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(raw)
                        ? null
                        : 'Use 24-hour HH:MM';
                  },
                ),
              ]),
              _row([
                _dropdown(
                  label: 'Place of event *',
                  value: _placeType,
                  options: kPlaceTypes,
                  onChanged: (v) => setState(() => _placeType = v!),
                ),
                _dropdown(
                  label: 'Reported by *',
                  value: _reportingSource,
                  options: const [
                    'SELF_REPORTED',
                    'HOSPITAL',
                    'INSTITUTION',
                    'DOMICILIARY',
                  ],
                  labelFor: (v) => ReportingSource.parse(v).label,
                  onChanged: (v) => setState(() => _reportingSource = v!),
                ),
              ]),
              _field(controller: _placeNameCtrl, label: 'Name of place'),
              const SizedBox(height: AppTheme.spaceSm),
              _field(
                controller: _placeAddressCtrl,
                label: 'Address of place',
                maxLines: 2,
              ),
              if (_reportingSource == 'HOSPITAL' || _placeType == 'hospital') ...[
                const SizedBox(height: AppTheme.spaceSm),
                _row([
                  _field(controller: _hospitalNameCtrl, label: 'Hospital name'),
                  _field(
                    controller: _hospitalRegCtrl,
                    label: 'Hospital registration no.',
                  ),
                ]),
              ],
            ],
          ),
          if (_isBirth) _birthSection() else _deathSection(),
          _Section(
            title: 'Informant',
            icon: Icons.record_voice_over_outlined,
            subtitle:
                'The person legally bound to report the event under s.8/s.9.',
            children: [
              _row([
                _field(
                  controller: _informantNameCtrl,
                  label: 'Informant name *',
                  validator: (v) => (v == null || v.trim().length < 2)
                      ? 'Record who reported the event'
                      : null,
                ),
                _dropdown(
                  label: 'Relationship *',
                  value: _informantRelation,
                  options: kInformantRelations,
                  onChanged: (v) => setState(() => _informantRelation = v!),
                ),
              ]),
              _row([
                _field(
                  controller: _informantPhoneCtrl,
                  label: 'Mobile number',
                  keyboardType: TextInputType.phone,
                  validator: _optionalPhone,
                ),
                _field(
                  controller: _informantAadhaarCtrl,
                  label: 'Aadhaar (12 digits)',
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(12),
                  ],
                  helper: 'Only the last 4 digits are stored',
                  validator: _optionalAadhaar,
                ),
              ]),
              _field(
                controller: _informantAddressCtrl,
                label: 'Informant address',
                maxLines: 2,
              ),
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
                label: Text('Report ${widget.eventType.label.toLowerCase()}'),
              ),
              const SizedBox(width: 12),
              TextButton(
                onPressed: _saving
                    ? null
                    : () => context.go('/municipality/vital-events'),
                child: const Text('Cancel'),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceXl),
        ],
      ),
    );
  }

  Widget _birthSection() => _Section(
        title: 'Child & parents (Form 1)',
        icon: Icons.family_restroom_rounded,
        children: [
          _row([
            _field(
              controller: _childNameCtrl,
              label: 'Name of child',
              helper: 'May be left blank and supplied within a year',
            ),
            _dropdown(
              label: 'Sex *',
              value: _birthSex,
              options: kSexes,
              onChanged: (v) => setState(() => _birthSex = v!),
            ),
          ]),
          _row([
            _field(
              controller: _weightCtrl,
              label: 'Weight at birth (kg)',
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            _optionalDropdown(
              label: 'Type of delivery',
              value: _deliveryType,
              options: kDeliveryTypes,
              onChanged: (v) => setState(() => _deliveryType = v),
            ),
            _field(
              controller: _birthOrderCtrl,
              label: 'Birth order',
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
          ]),
          _row([
            _field(
              controller: _motherNameCtrl,
              label: 'Mother\'s name *',
              validator: (v) => (v == null || v.trim().length < 2)
                  ? 'Mother\'s name is required on Form 1'
                  : null,
            ),
            _field(
              controller: _motherAadhaarCtrl,
              label: 'Mother\'s Aadhaar',
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(12),
              ],
              validator: _optionalAadhaar,
            ),
          ]),
          _row([
            _field(controller: _motherOccupationCtrl, label: 'Mother\'s occupation'),
            _field(
              controller: _motherAgeCtrl,
              label: 'Mother\'s age at birth',
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
          ]),
          _row([
            _field(controller: _fatherNameCtrl, label: 'Father\'s name'),
            _field(
              controller: _fatherAadhaarCtrl,
              label: 'Father\'s Aadhaar',
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(12),
              ],
              validator: _optionalAadhaar,
            ),
          ]),
          _row([
            _field(controller: _fatherOccupationCtrl, label: 'Father\'s occupation'),
          ]),
          _field(
            controller: _permanentAddressCtrl,
            label: 'Permanent address of parents',
            maxLines: 2,
          ),
        ],
      );

  Widget _deathSection() => _Section(
        title: 'Deceased (Form 2)',
        icon: Icons.person_outline_rounded,
        children: [
          _row([
            _field(
              controller: _deceasedNameCtrl,
              label: 'Name of deceased *',
              validator: (v) => (v == null || v.trim().length < 2)
                  ? 'Name of the deceased is required'
                  : null,
            ),
            _dropdown(
              label: 'Sex *',
              value: _deathSex,
              options: kSexes,
              onChanged: (v) => setState(() => _deathSex = v!),
            ),
          ]),
          Text(
            'Record the age in whichever unit is meaningful — an infant death is '
            'counted in days, not a rounded-down zero years.',
            style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
          ),
          const SizedBox(height: AppTheme.spaceXs),
          _row([
            _field(
              controller: _ageYearsCtrl,
              label: 'Age — years',
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            _field(
              controller: _ageMonthsCtrl,
              label: 'Age — months',
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            _field(
              controller: _ageDaysCtrl,
              label: 'Age — days',
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
          ]),
          _row([
            _field(controller: _deathFatherNameCtrl, label: 'Father\'s name'),
            _field(controller: _spouseNameCtrl, label: 'Spouse\'s name'),
          ]),
          _field(
            controller: _deathAddressCtrl,
            label: 'Usual residence',
            maxLines: 2,
          ),
          const SizedBox(height: AppTheme.spaceSm),
          _row([
            _field(controller: _causeCtrl, label: 'Cause of death'),
            _optionalDropdown(
              label: 'Category',
              value: _causeCategory,
              options: kCauseCategories,
              onChanged: (v) => setState(() => _causeCategory = v),
            ),
          ]),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _medicallyCertified,
            onChanged: (v) => setState(() => _medicallyCertified = v),
            title: const Text('Medically certified cause of death'),
            subtitle: Text(
              'Attach the MCCD to this entry after saving',
              style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
            ),
          ),
          if (_medicallyCertified)
            _row([
              _field(controller: _doctorCtrl, label: 'Certifying doctor'),
              _field(controller: _doctorRegCtrl, label: 'Medical council reg. no.'),
            ]),
          const SizedBox(height: AppTheme.spaceSm),
          _row([
            _optionalDropdown(
              label: 'Disposal method',
              value: _disposalMethod,
              options: kDisposalMethods,
              onChanged: (v) => setState(() => _disposalMethod = v),
            ),
            _field(controller: _disposalPlaceCtrl, label: 'Place of disposal'),
          ]),
        ],
      );

  Widget _delayBanner(DelayBand band, int days) {
    final color = DelayBandChip.colorFor(band);
    final String message;
    switch (band) {
      case DelayBand.lateFee:
        message =
            'This event is $days days old. It can still be registered, but the prescribed late fee is payable.';
      case DelayBand.authorityPermission:
        message =
            'This event is $days days old. Registration needs the written permission of the prescribed authority and an affidavit — record the reference before the registrar can complete the entry.';
      case DelayBand.magistrateOrder:
        message =
            'This event is over a year old ($days days). Registration needs an order of a magistrate of the first class.';
      case DelayBand.ordinary:
        message = '';
    }

    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.schedule_rounded, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  band.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Field builders ───────────────────────────────────────────────────────

  String? _optionalPhone(String? v) {
    final raw = (v ?? '').trim();
    if (raw.isEmpty) return null;
    return RegExp(r'^(\+91)?[6-9]\d{9}$').hasMatch(raw)
        ? null
        : 'Enter a valid 10-digit mobile number';
  }

  String? _optionalAadhaar(String? v) {
    final raw = (v ?? '').trim();
    if (raw.isEmpty) return null;
    return raw.length == 12 ? null : 'Aadhaar must be 12 digits';
  }

  Widget _datePicker() {
    final df = DateFormat.yMMMd();
    return InputDecorator(
      decoration: InputDecoration(
        labelText: _isBirth ? 'Date of birth *' : 'Date of death *',
        isDense: true,
        errorText: _saveError != null && _eventDate == null ? 'Required' : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _eventDate == null ? 'Not set' : df.format(_eventDate!),
              style: TextStyle(
                fontSize: 14,
                color: _eventDate == null
                    ? AppTheme.textMuted
                    : AppTheme.textPrimary,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _eventDate ?? DateTime.now(),
                firstDate: DateTime(1900),
                lastDate: DateTime.now(),
              );
              if (picked != null) setState(() => _eventDate = picked);
            },
            child: const Text('Pick'),
          ),
        ],
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    String? hint,
    String? helper,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      maxLines: maxLines,
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
    String Function(String)? labelFor,
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
          .map(
            (o) => DropdownMenuItem(
              value: o,
              child: Text(labelFor?.call(o) ?? titleCase(o)),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _optionalDropdown({
    required String label,
    required String? value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String?>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
      ),
      items: [
        const DropdownMenuItem<String?>(value: null, child: Text('Not recorded')),
        ...options.map(
          (o) => DropdownMenuItem<String?>(value: o, child: Text(titleCase(o))),
        ),
      ],
      onChanged: onChanged,
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
