import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/tender_models.dart';
import '../data/tender_repository.dart';

class TenderCreateScreen extends StatefulWidget {
  const TenderCreateScreen({super.key});

  @override
  State<TenderCreateScreen> createState() => _TenderCreateScreenState();
}

class _TenderCreateScreenState extends State<TenderCreateScreen> {
  final _repo = TenderRepository();
  final _formKey = GlobalKey<FormState>();
  final _titleEn = TextEditingController();
  final _titleTa = TextEditingController();
  final _narrativeEn = TextEditingController();
  String _accessMode = 'invited_only';
  bool _autoResolve = false;
  bool _officerSelfInspection = false;
  DateTime? _anchorDate;

  bool _saving = false;
  List<Vendor> _vendors = [];
  final Set<int> _selectedVendorIds = {};
  final List<_LineItemDraft> _lineItems = [_LineItemDraft()];

  @override
  void initState() {
    super.initState();
    _loadVendors();
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
        if (_anchorDate != null) 'anchor_date': _anchorDate!.toIso8601String(),
        'invited_vendor_ids': _selectedVendorIds.toList(),
        'line_items': _lineItems.where((e) => e.hasContent).map((e) => e.toJson()).toList(),
      });
      if (!mounted) return;
      context.go('/tenders/$id');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: ListView(
          children: [
            Text('New tender', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            TextFormField(
              controller: _titleEn,
              decoration: const InputDecoration(labelText: 'Title (English)', border: OutlineInputBorder()),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _titleTa,
              decoration: const InputDecoration(labelText: 'Title (Tamil)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _narrativeEn,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Work narrative', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _accessMode,
                    decoration: const InputDecoration(labelText: 'Access mode', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'invited_only', child: Text('Invited only')),
                      DropdownMenuItem(value: 'open_with_phone', child: Text('Open with phone')),
                    ],
                    onChanged: (v) => setState(() => _accessMode = v!),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
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
                      decoration: const InputDecoration(labelText: 'Anchor date', border: OutlineInputBorder()),
                      child: Text(_anchorDate?.toIso8601String().substring(0, 10) ?? 'Select date'),
                    ),
                  ),
                ),
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
            if (_vendors.isEmpty)
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
        if (poleId.text.isNotEmpty) 'pole_id': int.tryParse(poleId.text),
        if (complaintId.text.isNotEmpty) 'complaint_id': int.tryParse(complaintId.text),
      };
}

class _LineItemEditor extends StatelessWidget {
  final int index;
  final _LineItemDraft draft;
  final VoidCallback? onRemove;
  const _LineItemEditor({required this.index, required this.draft, this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Text('Item ${index + 1}', style: const TextStyle(fontWeight: FontWeight.w600)),
                const Spacer(),
                if (onRemove != null)
                  IconButton(onPressed: onRemove, icon: const Icon(Icons.delete_outline)),
              ],
            ),
            TextField(
              controller: draft.descEn,
              decoration: const InputDecoration(labelText: 'Description (English)'),
            ),
            TextField(
              controller: draft.descTa,
              decoration: const InputDecoration(labelText: 'விவரம் (Tamil)'),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: draft.qty,
                    decoration: const InputDecoration(labelText: 'Quantity'),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: draft.unit,
                    decoration: const InputDecoration(labelText: 'Unit'),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: draft.poleId,
                    decoration: const InputDecoration(labelText: 'Pole ID (optional)'),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: draft.complaintId,
                    decoration: const InputDecoration(labelText: 'Complaint ID (optional)'),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
