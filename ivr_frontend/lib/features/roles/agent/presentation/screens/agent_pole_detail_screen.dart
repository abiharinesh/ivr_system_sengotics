import 'package:flutter/material.dart';

import 'package:ivr_frontend/config/api_config.dart';
import 'package:ivr_frontend/config/app_theme.dart';
import 'package:ivr_frontend/core/widgets/app_shimmer.dart';
import 'package:ivr_frontend/core/api/api_exceptions.dart';
import 'package:ivr_frontend/core/offline/field_outbox.dart';
import 'package:ivr_frontend/core/offline/network_status.dart';
import 'package:ivr_frontend/core/utils/field_capture.dart';
import 'package:ivr_frontend/features/roles/agent/data/agent_repository.dart';

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
    final isLoading = _loading || _pole == null;
    final p = _pole ?? {};
    final imgUrl = isLoading ? '' : ApiConfig.fileUrl(p['image_url'] as String?);

    final titleWidget = isLoading
        ? const AppShimmer.rectangular(width: 120, height: 22)
        : Text(
            'Pole #${p['id']}',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
          );

    final subtitleWidget = isLoading
        ? const AppShimmer.rectangular(width: 180, height: 14)
        : Text(
            'No. ${p['pole_number'] ?? '—'} · Keypad ${p['keypad_id'] ?? '—'}',
            style: TextStyle(color: AppTheme.textMuted),
          );

    final geoWidget = isLoading
        ? const Padding(
            padding: EdgeInsets.only(top: 4),
            child: AppShimmer.rectangular(width: 220, height: 12),
          )
        : (p['image_latitude'] != null
            ? Text(
                'Last geo: ${p['image_latitude']}, ${p['image_longitude']}',
                style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
              )
            : const SizedBox.shrink());

    Widget buildImageArea() {
      if (isLoading) {
        return const AppShimmer.rectangular(width: double.infinity, height: 220);
      }
      if (imgUrl.isNotEmpty) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(imgUrl, height: 220, fit: BoxFit.cover),
        );
      }
      return Container(
        height: 160,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppTheme.bgSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.stroke),
        ),
        child: const Text('No reference photo yet'),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          titleWidget,
          const SizedBox(height: 8),
          subtitleWidget,
          const SizedBox(height: 4),
          geoWidget,
          const SizedBox(height: 20),
          buildImageArea(),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: Colors.red.shade800)),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: (isLoading || _uploading) ? null : _captureAndUpload,
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