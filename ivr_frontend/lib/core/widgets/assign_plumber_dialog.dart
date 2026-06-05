import 'package:flutter/material.dart';

import '../../features/plumber/data/plumber_repository.dart';
import '../../features/super_admin/data/models/complaint_model.dart';

/// Returns selected plumber user id, or null if cancelled / error / empty list.
Future<int?> showAssignPlumberDialog({
  required BuildContext context,
  required ComplaintModel complaint,
}) async {
  final loadFuture = PlumberRepository().listPlumbers();

  if (!context.mounted) return null;
  return showDialog<int>(
    context: context,
    builder: (ctx) => _AssignPlumberDialog(future: loadFuture),
  );
}

class _AssignPlumberDialog extends StatefulWidget {
  const _AssignPlumberDialog({required this.future});

  final Future<List<dynamic>> future;

  @override
  State<_AssignPlumberDialog> createState() =>
      _AssignPlumberDialogState();
}

class _AssignPlumberDialogState extends State<_AssignPlumberDialog> {
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
      body = const Text('No plumbers found for this panchayat.');
    } else {
      body = DropdownButtonFormField<int>(
        initialValue: _selectedId,
        decoration: const InputDecoration(labelText: 'Plumber'),
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
      title: const Text('Assign Plumber'),
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
