import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/api/api_exceptions.dart';
import '../../../../core/offline/field_outbox.dart';
import '../../../../core/offline/network_status.dart';
import '../../../../core/utils/field_capture.dart';
import '../../data/agent_repository.dart';

class AgentAddPoleScreen extends StatefulWidget {
  const AgentAddPoleScreen({super.key});

  @override
  State<AgentAddPoleScreen> createState() => _AgentAddPoleScreenState();
}

class _AgentAddPoleScreenState extends State<AgentAddPoleScreen> {
  final _repo = AgentRepository();
  final _poleNumber = TextEditingController();
  final _keypad = TextEditingController();
  bool _busy = false;
  String? _error;

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final shot = await FieldCapture.captureGeotaggedPhoto();
      if (shot == null) {
        setState(() => _busy = false);
        return;
      }
      Future<void> queueOffline() async {
        await FieldOutbox.enqueuePoleCreate(
          imageBytes: shot.bytes,
          fileName: shot.filename,
          latitude: shot.position.latitude,
          longitude: shot.position.longitude,
          capturedAt: shot.capturedAt,
          poleNumber: _poleNumber.text.trim().isEmpty ? null : _poleNumber.text.trim(),
          keypadId: _keypad.text.trim().isEmpty ? null : _keypad.text.trim(),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Offline: new pole queued. It will sync when you are back online.'),
            ),
          );
          context.go('/agent/poles');
        }
      }

      if (!await deviceAppearsOnline()) {
        await queueOffline();
        return;
      }
      try {
        final created = await _repo.createPoleWithImage(
          imageBytes: shot.bytes,
          fileName: shot.filename,
          latitude: shot.position.latitude,
          longitude: shot.position.longitude,
          capturedAt: shot.capturedAt,
          poleNumber: _poleNumber.text.trim().isEmpty ? null : _poleNumber.text.trim(),
          keypadId: _keypad.text.trim().isEmpty ? null : _keypad.text.trim(),
        );
        final id = created['id'] as int;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Pole #$id created')));
          context.go('/agent/poles/$id');
        }
      } on ApiException catch (e) {
        if (e.statusCode == 0) {
          await queueOffline();
          return;
        }
        setState(() => _error = e.message);
      }
    } on StateError catch (e) {
      setState(() => _error = e.message);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _poleNumber.dispose();
    _keypad.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'New pole requires a live geotagged photo (camera + GPS).',
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _poleNumber,
            decoration: const InputDecoration(
              labelText: 'Pole number (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _keypad,
            decoration: const InputDecoration(
              labelText: 'Keypad ID (recommended)',
              border: OutlineInputBorder(),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: Colors.red.shade800)),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _busy ? null : _submit,
            icon: _busy
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.add_a_photo),
            label: const Text('Create pole with camera capture'),
          ),
        ],
      ),
    );
  }
}
