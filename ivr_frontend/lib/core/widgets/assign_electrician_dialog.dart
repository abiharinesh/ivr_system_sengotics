import 'package:flutter/material.dart';

import '../../features/panchayat_admin/data/panchayat_admin_repository.dart';
import '../../features/super_admin/data/super_admin_repository.dart';
import '../../features/super_admin/data/models/complaint_model.dart';

/// Returns selected electrician user id, or null if cancelled / error / empty list.
Future<int?> showAssignElectricianDialog({
  required BuildContext context,
  required ComplaintModel complaint,
  required bool isSuperAdmin,
}) async {
  late Future<List<dynamic>> loadFuture;
  if (isSuperAdmin) {
    final pid = complaint.panchayatId;
    if (pid == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'This complaint has no panchayat; cannot list electricians.',
            ),
          ),
        );
      }
      return null;
    }
    loadFuture = SuperAdminRepository().listElectricians(panchayatId: pid);
  } else {
    loadFuture = PanchayatAdminRepository().listElectricians();
  }

  if (!context.mounted) return null;
  return showDialog<int>(
    context: context,
    builder: (ctx) => _AssignElectricianDialog(future: loadFuture),
  );
}

class _AssignElectricianDialog extends StatefulWidget {
  const _AssignElectricianDialog({required this.future});

  final Future<List<dynamic>> future;

  @override
  State<_AssignElectricianDialog> createState() =>
      _AssignElectricianDialogState();
}

class _AssignElectricianDialogState extends State<_AssignElectricianDialog> {
  List<dynamic>? _rows;
  Object? _error;
  int? _selectedId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await widget.future;
      if (!mounted) return;
      setState(() {
        _rows = rows;
        if (rows.isNotEmpty) {
          _selectedId =
              Map<String, dynamic>.from(rows.first as Map)['id'] as int;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_error != null) {
      body = Text(_error.toString());
    } else if (_rows == null) {
      body = const SizedBox(
        height: 120,
        width: 300,
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (_rows!.isEmpty) {
      body = const Text('No electricians found for this panchayat.');
    } else {
      body = DropdownButtonFormField<int>(
        initialValue: _selectedId,
        decoration: const InputDecoration(labelText: 'Electrician'),
        items:
            _rows!.map((e) {
              final m = Map<String, dynamic>.from(e as Map);
              final uid = m['id'] as int;
              final email = m['email']?.toString() ?? '$uid';
              return DropdownMenuItem(value: uid, child: Text(email));
            }).toList(),
        onChanged: (v) => setState(() => _selectedId = v),
      );
    }

    final canAssign =
        _rows != null &&
        _rows!.isNotEmpty &&
        _selectedId != null &&
        _error == null;

    return AlertDialog(
      title: const Text('Assign electrician'),
      content: SizedBox(width: 320, child: body),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed:
              canAssign ? () => Navigator.pop(context, _selectedId) : null,
          child: const Text('Assign'),
        ),
      ],
    );
  }
}
