import 'package:flutter/material.dart';
import '../../super_admin/data/super_admin_repository.dart';
import '../data/tender_models.dart';
import '../../../core/widgets/app_loading_state.dart';
import '../data/tender_repository.dart';

class VendorDirectoryScreen extends StatefulWidget {
  final bool isSuperAdmin;
  const VendorDirectoryScreen({super.key, this.isSuperAdmin = false});

  @override
  State<VendorDirectoryScreen> createState() => _VendorDirectoryScreenState();
}

class _VendorDirectoryScreenState extends State<VendorDirectoryScreen> {
  late final TenderRepository _repo;
  int? _panchayatFilter;
  Future<List<Vendor>>? _future;

  @override
  void initState() {
    super.initState();
    _repo = TenderRepository(isSuperAdmin: widget.isSuperAdmin);
    _reload();
  }

  void _reload() {
    if (!mounted) return;
    setState(() {
      _future = _repo.listVendors(panchayatId: _panchayatFilter);
    });
  }

  Future<void> _addVendor() async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => _VendorDialog(isSuperAdmin: widget.isSuperAdmin),
    );
    if (result == null) return;
    try {
      final pidStr = result['panchayat_id'];
      final pid = pidStr != null && pidStr.isNotEmpty ? int.tryParse(pidStr) : null;
      await _repo.createVendor(
        name: result['name']!,
        phoneE164: result['phone']!,
        place: result['place'],
        notes: result['notes'],
        panchayatId: pid,
      );
      _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 480;
        final hPad = isNarrow ? 12.0 : 16.0;
        final title = Text(
          'Vendor directory',
          style: Theme.of(context).textTheme.headlineSmall,
        );
        final addButton = FilledButton.icon(
          onPressed: _addVendor,
          icon: const Icon(Icons.add),
          label: const Text('Add vendor'),
        );
        return Padding(
          padding: EdgeInsets.all(hPad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isNarrow)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    title,
                    const SizedBox(height: 8),
                    Align(alignment: Alignment.centerLeft, child: addButton),
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(child: title),
                    addButton,
                  ],
                ),
              const SizedBox(height: 12),
              if (widget.isSuperAdmin) ...[
                Row(
                  children: [
                    const Text('Filter by Panchayat: '),
                    const SizedBox(width: 8),
                    FutureBuilder<List<dynamic>>(
                      future: SuperAdminRepository().listPanchayats(),
                      builder: (context, snap) {
                        final list = snap.data ?? [];
                        return DropdownButton<int?>(
                          value: _panchayatFilter,
                          hint: const Text('All Panchayats'),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('All Panchayats')),
                            ...list.map((p) => DropdownMenuItem(
                              value: p.id as int,
                              child: Text(p.name as String),
                            )),
                          ],
                          onChanged: (v) {
                            setState(() => _panchayatFilter = v);
                            _reload();
                          },
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              Expanded(
                child: FutureBuilder<List<Vendor>>(
                  future: _future,
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const AppLoadingState(
                        message: 'Loading vendors...',
                        style: AppLoadingStyle.list,
                      );
                    }
                    if (snap.hasError) {
                      return Center(child: Text('Error: ${snap.error}'));
                    }
                    final vs = snap.data ?? [];
                    if (vs.isEmpty) {
                      return const Center(child: Text('No vendors yet.'));
                    }
                    return ListView.separated(
                      itemCount: vs.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final v = vs[i];
                        return ListTile(
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: isNarrow ? 8 : 16,
                          ),
                          leading: CircleAvatar(
                            child: Text(v.name.isNotEmpty ? v.name[0] : '?'),
                          ),
                          title: Row(
                            children: [
                              Text(v.name),
                              if (widget.isSuperAdmin && v.panchayatName != null) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.purple.shade50,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    v.panchayatName!,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.purple.shade700,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          subtitle: Text(
                            '${v.phoneE164}${v.place != null ? ' • ${v.place}' : ''}',
                          ),
                          trailing: Switch(
                            value: v.active,
                            onChanged: (active) async {
                              try {
                                await _repo.updateVendor(
                                  v.id,
                                  {'active': active},
                                );
                                _reload();
                              } catch (e) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error: $e')),
                                );
                              }
                            },
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _VendorDialog extends StatefulWidget {
  final bool isSuperAdmin;
  const _VendorDialog({required this.isSuperAdmin});

  @override
  State<_VendorDialog> createState() => _VendorDialogState();
}

class _VendorDialogState extends State<_VendorDialog> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _place = TextEditingController();
  final _notes = TextEditingController();
  int? _panchayatId;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context).size;
    final dialogWidth = media.width < 420 ? media.width - 48 : 360.0;
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: const Text('Add vendor'),
      content: SizedBox(
        width: dialogWidth,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.isSuperAdmin) ...[
                FutureBuilder<List<dynamic>>(
                  future: SuperAdminRepository().listPanchayats(),
                  builder: (context, snap) {
                    final list = snap.data ?? [];
                    return DropdownButtonFormField<int?>(
                      initialValue: _panchayatId,
                      hint: const Text('Select Panchayat'),
                      decoration: const InputDecoration(labelText: 'Panchayat'),
                      items: list.map((p) => DropdownMenuItem(
                        value: p.id as int,
                        child: Text(p.name as String),
                      )).toList(),
                      onChanged: (v) {
                        setState(() => _panchayatId = v);
                      },
                    );
                  },
                ),
                const SizedBox(height: 8),
              ],
              TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: _phone,
                decoration: const InputDecoration(
                  labelText: 'Phone (10 digits)',
                ),
                keyboardType: TextInputType.phone,
              ),
              TextField(
                controller: _place,
                decoration: const InputDecoration(
                  labelText: 'Place / Village',
                ),
              ),
              TextField(
                controller: _notes,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.of(context).pop({
            'name': _name.text.trim(),
            'phone': _phone.text.trim(),
            'place': _place.text.trim(),
            'notes': _notes.text.trim(),
            'panchayat_id': _panchayatId?.toString() ?? '',
          }),
          child: const Text('Add'),
        ),
      ],
    );
  }
}
