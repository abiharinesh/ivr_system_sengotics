import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../config/api_config.dart';
import '../../../core/api/api_client.dart';

/// Public-facing field-staff upload screen. No auth. Reads session metadata
/// and uploads a single image whose EXIF GPS the server matches against the
/// tender's pole subset.
class PublicFieldUploadScreen extends StatefulWidget {
  final String token;
  const PublicFieldUploadScreen({super.key, required this.token});

  @override
  State<PublicFieldUploadScreen> createState() => _PublicFieldUploadScreenState();
}

class _PublicFieldUploadScreenState extends State<PublicFieldUploadScreen> {
  final _picker = ImagePicker();
  Future<Map<String, dynamic>>? _sessionFuture;
  XFile? _picked;
  Uint8List? _previewBytes;
  String? _result;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _sessionFuture = _fetchSession();
  }

  Future<Map<String, dynamic>> _fetchSession() async {
    final res = await ApiClient.instance.get('/public/field-sessions/${widget.token}');
    return res as Map<String, dynamic>;
  }

  Future<void> _setPicked(XFile? f) async {
    if (f == null) return;
    final bytes = await f.readAsBytes();
    if (!mounted) return;
    setState(() {
      _picked = f;
      _previewBytes = bytes;
    });
  }

  Future<void> _pickFromCamera() async {
    final f = await _picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    await _setPicked(f);
  }

  Future<void> _pickFromGallery() async {
    final f = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    await _setPicked(f);
  }

  Future<void> _upload() async {
    final picked = _picked;
    if (picked == null) return;
    setState(() {
      _uploading = true;
      _result = null;
    });
    try {
      // Read bytes (avoids dart:io File.fromFile path; works on web + mobile).
      final bytes = _previewBytes ?? await picked.readAsBytes();
      final part = MultipartFile.fromBytes(bytes, filename: picked.name);
      final form = FormData.fromMap({'file': part});
      final res = await ApiClient.instance
          .postMultipart('/public/field-sessions/${widget.token}/uploads', form);
      if (!mounted) return;
      setState(() {
        _result = 'Upload received • match: ${res['match_confidence']} • '
            'pole: ${res['matched_pole_id'] ?? '—'} • distance: ${res['distance_meters']?.toStringAsFixed(1) ?? '—'} m';
        _picked = null;
        _previewBytes = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _result = 'Error: $e');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Field verification upload')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _sessionFuture,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
          final data = snap.data!;
          final session = (data['session'] ?? {}) as Map<String, dynamic>;
          final poles = ((data['poles'] ?? []) as List).cast<Map<String, dynamic>>();

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text('Tender #${session['tender_id']}',
                      style: Theme.of(context).textTheme.headlineSmall),
                  Text(((session['panchayat'] ?? {}) as Map)['name']?.toString() ?? '',
                      style: const TextStyle(color: Colors.black54)),
                  const SizedBox(height: 8),
                  if (session['expires_at'] != null)
                    Text('Expires: ${session['expires_at']}', style: const TextStyle(color: Colors.black54)),
                  const SizedBox(height: 16),
                  Text('${poles.length} pole(s) to inspect:',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  for (final p in poles)
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.location_on_outlined),
                      title: Text(p['pole_number']?.toString() ?? 'Pole #${p['id']}'),
                      subtitle: Text('Lat ${p['latitude']}, Lng ${p['longitude']}'),
                    ),
                  const Divider(height: 32),
                  if (_previewBytes != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        _previewBytes!,
                        height: 220,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _pickFromCamera,
                        icon: const Icon(Icons.camera_alt_outlined),
                        label: const Text('Take photo'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _pickFromGallery,
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('Pick from gallery'),
                      ),
                      FilledButton.icon(
                        onPressed: _picked == null || _uploading ? null : _upload,
                        icon: const Icon(Icons.cloud_upload_outlined),
                        label: Text(_uploading ? 'Uploading...' : 'Upload'),
                      ),
                    ],
                  ),
                  if (_result != null) ...[
                    const SizedBox(height: 16),
                    Card(color: Colors.green.shade50, child: Padding(padding: const EdgeInsets.all(12), child: Text(_result!))),
                  ],
                  const SizedBox(height: 24),
                  Text('Upload endpoint: ${ApiConfig.baseUrl}/public/field-sessions/${widget.token}/uploads',
                      style: const TextStyle(fontSize: 11, color: Colors.black45)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
