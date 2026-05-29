import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/nav_guard.dart';
import '../../super_admin/data/super_admin_repository.dart';
import '../data/tender_models.dart';
import '../data/tender_repository.dart';

class TenderCreateScreen extends StatefulWidget {
  final bool isSuperAdmin;
  const TenderCreateScreen({super.key, this.isSuperAdmin = false});

  @override
  State<TenderCreateScreen> createState() => _TenderCreateScreenState();
}

class _TenderCreateScreenState extends State<TenderCreateScreen>
    with NavGuardMixin {
  late final TenderRepository _repo;
  final _formKey = GlobalKey<FormState>();
  final _titleEn = TextEditingController();
  final _titleTa = TextEditingController();
  final _narrativeEn = TextEditingController();
  String _accessMode = 'invited_only';
  bool _autoResolve = false;
  bool _officerSelfInspection = false;
  DateTime? _anchorDate;
  int? _selectedPanchayatId;

  bool _saving = false;
  bool _justSaved = false;
  List<Vendor> _vendors = [];
  final Set<int> _selectedVendorIds = {};
  final List<_LineItemDraft> _lineItems = [_LineItemDraft()];

  @override
  bool get hasUnsavedChanges {
    if (_justSaved) return false;
    if (_titleEn.text.trim().isNotEmpty) return true;
    if (_titleTa.text.trim().isNotEmpty) return true;
    if (_narrativeEn.text.trim().isNotEmpty) return true;
    if (_anchorDate != null) return true;
    if (_selectedVendorIds.isNotEmpty) return true;
    if (_lineItems.any((e) => e.hasContent)) return true;
    return false;
  }

  @override
  void initState() {
    super.initState();
    _repo = TenderRepository(isSuperAdmin: widget.isSuperAdmin);
    if (!widget.isSuperAdmin) {
      _loadVendors();
    }
  }

  Future<void> _loadVendors() async {
    try {
      final vs = await _repo.listVendors(active: true);
      if (!mounted) return;
      setState(() => _vendors = vs);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load vendors: $e')),
      );
    }
  }

  Future<void> _loadVendorsForPanchayat(int panchayatId) async {
    try {
      final vs = await _repo.listVendors(active: true, panchayatId: panchayatId);
      if (!mounted) return;
      setState(() {
        _vendors = vs;
        _selectedVendorIds.clear();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load vendors: $e')),
      );
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final id = await _repo.createTender({
        'title_en': _titleEn.text.trim(),
        'title_ta': _titleTa.text.trim(),
        'narrative_en': _narrativeEn.text.trim(),
        'quotation_access_mode': _accessMode,
        'auto_resolve_linked_complaints': _autoResolve,
        'officer_self_inspection': _officerSelfInspection,
        if (_anchorDate != null) 'anchor_date': _anchorDate!.toUtc().toIso8601String(),
        'invited_vendor_ids': _selectedVendorIds.toList(),
        'line_items': _lineItems.where((e) => e.hasContent).map((e) => e.toJson()).toList(),
        if (widget.isSuperAdmin && _selectedPanchayatId != null) 'panchayat_id': _selectedPanchayatId,
      });
      if (!mounted) return;
      _justSaved = true;
      context.go(widget.isSuperAdmin ? '/superadmin/tenders/$id' : '/tenders/$id');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 560;
        final hPad = constraints.maxWidth < 480 ? 12.0 : 16.0;
        final accessField = DropdownButtonFormField<String>(
          initialValue: _accessMode,
          decoration: const InputDecoration(
            labelText: 'Access mode',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(value: 'invited_only', child: Text('Invited only')),
            DropdownMenuItem(
              value: 'open_with_phone',
              child: Text('Open with phone'),
            ),
          ],
          onChanged: (v) => setState(() => _accessMode = v!),
        );
        final dateField = InkWell(
          onTap: () async {
            final d = await showDatePicker(
              context: context,
              initialDate: _anchorDate ?? DateTime.now(),
              firstDate: DateTime(2024),
              lastDate: DateTime(2030),
            );
            if (d != null) setState(() => _anchorDate = d);
          },
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Anchor date',
              border: OutlineInputBorder(),
            ),
            child: Text(
              _anchorDate?.toIso8601String().substring(0, 10) ?? 'Select date',
            ),
          ),
        );
        return Padding(
          padding: EdgeInsets.all(hPad),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                Text(
                  'New tender',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                if (widget.isSuperAdmin) ...[
                  FutureBuilder<List<dynamic>>(
                    future: SuperAdminRepository().listPanchayats(),
                    builder: (context, snap) {
                      final list = snap.data ?? [];
                      return DropdownButtonFormField<int?>(
                        value: _selectedPanchayatId,
                        hint: const Text('Select Panchayat'),
                        decoration: const InputDecoration(
                          labelText: 'Panchayat',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => v == null ? 'Panchayat is required' : null,
                        items: list.map((p) => DropdownMenuItem(
                          value: p.id as int,
                          child: Text(p.name as String),
                        )).toList(),
                        onChanged: (v) {
                          setState(() {
                            _selectedPanchayatId = v;
                          });
                          if (v != null) {
                            _loadVendorsForPanchayat(v);
                          }
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                ],
                TextFormField(
                  controller: _titleEn,
                  decoration: const InputDecoration(
                    labelText: 'Title (English)',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _titleTa,
                  decoration: const InputDecoration(
                    labelText: 'Title (Tamil)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _narrativeEn,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Work narrative',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                if (isNarrow) ...[
                  accessField,
                  const SizedBox(height: 12),
                  dateField,
                ] else
                  Row(
                    children: [
                      Expanded(child: accessField),
                      const SizedBox(width: 12),
                      Expanded(child: dateField),
                    ],
                  ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  dense: true,
                  title: const Text('Auto-resolve linked complaints on field-verification confirm'),
                  value: _autoResolve,
                  onChanged: (v) => setState(() => _autoResolve = v ?? false),
                ),
                CheckboxListTile(
                  dense: true,
                  title: const Text('Allow officer self-inspection (no field photo required)'),
                  value: _officerSelfInspection,
                  onChanged: (v) => setState(() => _officerSelfInspection = v ?? false),
                ),
                const Divider(height: 32),
                Text('Invited vendors', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                if (widget.isSuperAdmin && _selectedPanchayatId == null)
                  const Text('Select a Panchayat to load vendors.')
                else if (_vendors.isEmpty)
                  const Text('No vendors yet. Add some via Vendor directory.')
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: _vendors
                        .map((v) => FilterChip(
                              selected: _selectedVendorIds.contains(v.id),
                              label: Text('${v.name} (${v.phoneE164})'),
                              onSelected: (sel) => setState(() {
                                sel ? _selectedVendorIds.add(v.id) : _selectedVendorIds.remove(v.id);
                              }),
                            ))
                        .toList(),
                  ),
                const Divider(height: 32),
                Row(
                  children: [
                    Text('Line items', style: Theme.of(context).textTheme.titleMedium),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => setState(() => _lineItems.add(_LineItemDraft())),
                      icon: const Icon(Icons.add),
                      label: const Text('Add line item'),
                    ),
                  ],
                ),
                ..._lineItems.asMap().entries.map((e) => _LineItemEditor(
                      index: e.key,
                      draft: e.value,
                      onRemove: _lineItems.length > 1
                          ? () => setState(() => _lineItems.removeAt(e.key))
                          : null,
                    )),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Create tender'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LineItemDraft {
  final descTa = TextEditingController();
  final descEn = TextEditingController();
  final qty = TextEditingController();
  final unit = TextEditingController();
  final poleId = TextEditingController();
  final complaintId = TextEditingController();

  bool get hasContent =>
      descTa.text.isNotEmpty ||
      descEn.text.isNotEmpty ||
      qty.text.isNotEmpty ||
      unit.text.isNotEmpty;

  Map<String, dynamic> toJson() => {
        if (descTa.text.isNotEmpty) 'description_ta': descTa.text,
        if (descEn.text.isNotEmpty) 'description_en': descEn.text,
        if (qty.text.isNotEmpty) 'quantity': qty.text,
        if (unit.text.isNotEmpty) 'unit': unit.text,
        if (poleId.text.isNotEmpty) 'pole_ref': poleId.text.trim(),
        if (complaintId.text.isNotEmpty)
          if (int.tryParse(complaintId.text) != null)
            'complaint_id': int.parse(complaintId.text),
      };
}

class _LineItemEditor extends StatelessWidget {
  final int index;
  final _LineItemDraft draft;
  final VoidCallback? onRemove;
  const _LineItemEditor({required this.index, required this.draft, this.onRemove});

  @override
  Widget build(BuildContext context) {
    final qty = TextField(
      controller: draft.qty,
      decoration: const InputDecoration(labelText: 'Quantity'),
      keyboardType: TextInputType.number,
    );
    final unit = TextField(
      controller: draft.unit,
      decoration: const InputDecoration(labelText: 'Unit'),
    );
    final pole = TextField(
      controller: draft.poleId,
      decoration: const InputDecoration(
        labelText: 'Pole number or ID (optional)',
        helperText: 'Matches pole number (e.g. 007) or database ID',
      ),
      keyboardType: TextInputType.number,
    );
    final complaint = TextField(
      controller: draft.complaintId,
      decoration: const InputDecoration(labelText: 'Complaint ID (optional)'),
      keyboardType: TextInputType.number,
    );
    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 400;
            Widget pair(Widget a, Widget b) => isNarrow
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      a,
                      const SizedBox(height: 8),
                      b,
                    ],
                  )
                : Row(
                    children: [
                      Expanded(child: a),
                      const SizedBox(width: 8),
                      Expanded(child: b),
                    ],
                  );
            return Column(
              children: [
                Row(
                  children: [
                    Text(
                      'Item ${index + 1}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    if (onRemove != null)
                      IconButton(
                        onPressed: onRemove,
                        icon: const Icon(Icons.delete_outline),
                      ),
                  ],
                ),
                TextField(
                  controller: draft.descEn,
                  decoration: const InputDecoration(
                    labelText: 'Description (English)',
                  ),
                ),
                TextField(
                  controller: draft.descTa,
                  decoration: const InputDecoration(
                    labelText: 'விவரம் (Tamil)',
                  ),
                ),
                const SizedBox(height: 8),
                pair(qty, unit),
                const SizedBox(height: 8),
                pair(pole, complaint),
              ],
            );
          },
        ),
      ),
    );
  }
}
