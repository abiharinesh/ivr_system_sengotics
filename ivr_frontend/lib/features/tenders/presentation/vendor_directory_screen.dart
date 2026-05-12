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
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Text('Vendor directory', style: Theme.of(context).textTheme.headlineSmall),
              const Spacer(),
              FilledButton.icon(
                onPressed: _addVendor,
                icon: const Icon(Icons.add),
                label: const Text('Add vendor'),
              ),
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
                if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
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
                      leading: CircleAvatar(child: Text(v.name.isNotEmpty ? v.name[0] : '?')),
                      title: Text(v.name),
                      subtitle: Text('${v.phoneE164}${v.place != null ? ' • ${v.place}' : ''}'),
                      trailing: Switch(
                        value: v.active,
                        onChanged: (active) async {
                          try {
                            await _repo.updateVendor(v.id, {'active': active});
                            _reload();
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context)
                                .showSnackBar(SnackBar(content: Text('Error: $e')));
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
    return AlertDialog(
      title: const Text('Add vendor'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'Name')),
            TextField(
              controller: _phone,
              decoration: const InputDecoration(labelText: 'Phone (10 digits)'),
              keyboardType: TextInputType.phone,
            ),
            TextField(controller: _place, decoration: const InputDecoration(labelText: 'Place / Village')),
            TextField(controller: _notes, decoration: const InputDecoration(labelText: 'Notes (optional)')),
          ],
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
