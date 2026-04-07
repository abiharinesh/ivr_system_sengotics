import 'package:flutter/material.dart';

import '../../../config/api_config.dart';
import '../../../config/app_theme.dart';
import '../../../core/api/api_exceptions.dart';
import '../../../core/offline/field_outbox.dart';
import '../../../core/offline/network_status.dart';
import '../../../core/utils/field_capture.dart';
import '../data/agent_repository.dart';

class AgentPoleDetailScreen extends StatefulWidget {
  const AgentPoleDetailScreen({super.key, required this.poleId});

  final int poleId;

  @override
  State<AgentPoleDetailScreen> createState() => _AgentPoleDetailScreenState();
}

class _AgentPoleDetailScreenState extends State<AgentPoleDetailScreen> {
  final _repo = AgentRepository();
  Map<String, dynamic>? _pole;
  bool _loading = true;
  bool _uploading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final p = await _repo.getPole(widget.poleId);
      setState(() {
        _pole = p;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _captureAndUpload() async {
    setState(() {
      _uploading = true;
      _error = null;
    });
    try {
      final shot = await FieldCapture.captureGeotaggedPhoto();
      if (shot == null) {
        setState(() => _uploading = false);
        return;
      }
      Future<void> queueOffline() async {
        await FieldOutbox.enqueuePoleImage(
          poleId: widget.poleId,
          imageBytes: shot.bytes,
          fileName: shot.filename,
          latitude: shot.position.latitude,
          longitude: shot.position.longitude,
          capturedAt: shot.capturedAt,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Offline: photo queued. It will upload when you are back online.'),
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
        await _repo.uploadPoleImage(
          poleId: widget.poleId,
          imageBytes: shot.bytes,
          fileName: shot.filename,
          latitude: shot.position.latitude,
          longitude: shot.position.longitude,
          capturedAt: shot.capturedAt,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pole image saved')),
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
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_pole == null) {
      return Center(child: Text(_error ?? 'Not found'));
    }
    final p = _pole!;
    final imgUrl = ApiConfig.fileUrl(p['image_url'] as String?);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Pole #${p['id']}',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            'No. ${p['pole_number'] ?? '—'} · Keypad ${p['keypad_id'] ?? '—'}',
            style: const TextStyle(color: AppTheme.textMuted),
          ),
          if (p['image_latitude'] != null)
            Text(
              'Last geo: ${p['image_latitude']}, ${p['image_longitude']}',
              style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
          const SizedBox(height: 20),
          if (imgUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(imgUrl, height: 220, fit: BoxFit.cover),
            )
          else
            Container(
              height: 160,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppTheme.bgSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.stroke),
              ),
              child: const Text('No reference photo yet'),
            ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: Colors.red.shade800)),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _uploading ? null : _captureAndUpload,
            icon: _uploading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.photo_camera),
            label: Text(_uploading ? 'Uploading…' : 'Capture & upload geotagged photo'),
          ),
        ],
      ),
    );
  }
}
