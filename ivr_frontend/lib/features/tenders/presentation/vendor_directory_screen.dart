import 'package:flutter/material.dart';
import '../data/tender_models.dart';
import '../data/tender_repository.dart';

class VendorDirectoryScreen extends StatefulWidget {
  const VendorDirectoryScreen({super.key});

  @override
  State<VendorDirectoryScreen> createState() => _VendorDirectoryScreenState();
}

class _VendorDirectoryScreenState extends State<VendorDirectoryScreen> {
  final _repo = TenderRepository();
  Future<List<Vendor>>? _future;

  @override
  void initState() {
    super.initState();
    _future = _repo.listVendors();
  }

  void _reload() {
    if (!mounted) return;
    setState(() {
      _future = _repo.listVendors();
    });
  }

  Future<void> _addVendor() async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => const _VendorDialog(),
    );
    if (result == null) return;
    try {
      await _repo.createVendor(
        name: result['name']!,
        phoneE164: result['phone']!,
        place: result['place'],
        notes: result['notes'],
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
              Expanded(
                child: FutureBuilder<List<Vendor>>(
                  future: _future,
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
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
                          title: Text(v.name),
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
  const _VendorDialog();
  @override
  State<_VendorDialog> createState() => _VendorDialogState();
}

class _VendorDialogState extends State<_VendorDialog> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _place = TextEditingController();
  final _notes = TextEditingController();

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
          }),
          child: const Text('Add'),
        ),
      ],
    );
  }
}
