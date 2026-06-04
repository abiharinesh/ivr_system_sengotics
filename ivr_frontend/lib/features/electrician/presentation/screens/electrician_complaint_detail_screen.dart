import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../config/api_config.dart';
import '../../../../config/app_theme.dart';
import '../../../../core/widgets/app_loading_state.dart';
import '../../../../core/api/api_exceptions.dart';
import '../../../../core/offline/field_outbox.dart';
import '../../../../core/offline/network_status.dart';
import '../../../../core/utils/field_capture.dart';
import '../../data/electrician_repository.dart';

class ElectricianComplaintDetailScreen extends StatefulWidget {
  const ElectricianComplaintDetailScreen({super.key, required this.complaintId});

  final int complaintId;

  @override
  State<ElectricianComplaintDetailScreen> createState() => _ElectricianComplaintDetailScreenState();
}

class _ElectricianComplaintDetailScreenState extends State<ElectricianComplaintDetailScreen> {
  final _repo = ElectricianRepository();
  final _note = TextEditingController();
  Map<String, dynamic>? _c;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _repo.getComplaint(widget.complaintId);
      setState(() {
        _c = data;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _openMaps(double? lat, double? lng) async {
    if (lat == null || lng == null) return;
    final uri = Uri.parse('https://www.google.com/maps?q=$lat,$lng');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open maps')));
      }
    }
  }

  Future<void> _accept() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _repo.accept(widget.complaintId);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Marked in progress')));
      await _load();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _decline() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final t = TextEditingController();
        return AlertDialog(
          title: const Text('Cannot attend?'),
          content: TextField(
            controller: t,
            decoration: const InputDecoration(hintText: 'Reason (optional)'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, t.text), child: const Text('Submit')),
          ],
        );
      },
    );
    if (reason == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _repo.decline(widget.complaintId, reason: reason.isEmpty ? null : reason);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Returned to admin for reassignment')));
      }
      await _load();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resolve() async {
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
      final note = _note.text.trim().isEmpty ? null : _note.text.trim();
      Future<void> queueOffline() async {
        await FieldOutbox.enqueueResolve(
          complaintId: widget.complaintId,
          imageBytes: shot.bytes,
          fileName: shot.filename,
          latitude: shot.position.latitude,
          longitude: shot.position.longitude,
          capturedAt: shot.capturedAt,
          note: note,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Offline: proof queued. It will sync when you are back online.'),
            ),
          );
        }
        await _load();
      }

      if (!await deviceAppearsOnline()) {
        await queueOffline();
        return;
      }
      try {
        await _repo.submitResolution(
          complaintId: widget.complaintId,
          imageBytes: shot.bytes,
          fileName: shot.filename,
          latitude: shot.position.latitude,
          longitude: shot.position.longitude,
          capturedAt: shot.capturedAt,
          note: note,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Proof submitted — pending admin confirmation')),
          );
        }
        await _load();
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
  Widget build(BuildContext context) {
    if (_loading) {
      return const AppLoadingState(
        message: 'Loading details...',
        style: AppLoadingStyle.detail,
      );
    }
    if (_c == null) {
      return Center(child: Text(_error ?? 'Not found'));
    }
    final c = _c!;
    final st = c['status']?.toString() ?? '';
    final pole = c['pole'] as Map<String, dynamic>?;
    final lat = (pole?['latitude'] as num?)?.toDouble();
    final lng = (pole?['longitude'] as num?)?.toDouble();
    final poleImg = pole != null ? ApiConfig.fileUrl(pole['image_url'] as String?) : '';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Complaint #${c['id']}',
            style:       TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
          ),
          Text('Status: $st', style:       TextStyle(color: AppTheme.textMuted)),
          if (pole != null) ...[
            const SizedBox(height: 12),
            Text('Pole #${pole['id']} · ${pole['keypad_id'] ?? '—'}'),
            if (poleImg.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(poleImg, height: 180, fit: BoxFit.cover),
                ),
              ),
            if (lat != null && lng != null)
              TextButton.icon(
                onPressed: () => _openMaps(lat, lng),
                icon: const Icon(Icons.map),
                label: const Text('Get directions'),
              ),
          ],
          if ((c['description'] as String?)?.isNotEmpty ?? false)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(c['description'] as String),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(_error!, style: TextStyle(color: Colors.red.shade800)),
            ),
          const SizedBox(height: 12),
          if (st == 'assigned') ...[
            FilledButton.icon(
              onPressed: _busy ? null : _accept,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Accept & start'),
            ),
            OutlinedButton.icon(
              onPressed: _busy ? null : _decline,
              icon: const Icon(Icons.cancel_outlined),
              label: const Text('Cannot attend'),
            ),
          ],
          if (st == 'in_progress') ...[
            TextField(
              controller: _note,
              decoration: const InputDecoration(
                labelText: 'Work note (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _busy ? null : _resolve,
              icon: _busy
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.photo_camera),
              label: const Text('Submit geotagged proof photo'),
            ),
            OutlinedButton.icon(
              onPressed: _busy ? null : _decline,
              icon: const Icon(Icons.cancel_outlined),
              label: const Text('Release job'),
            ),
          ],
          if (st == 'resolved_pending_confirmation')
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Proof submitted. Waiting for admin to close the complaint.'),
              ),
            ),
        ],
      ),
    );
  }
}