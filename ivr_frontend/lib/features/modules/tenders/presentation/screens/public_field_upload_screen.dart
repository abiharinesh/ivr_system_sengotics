import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:ivr_frontend/core/api/api_exceptions.dart';
import 'package:ivr_frontend/core/api/api_client.dart';
import 'package:ivr_frontend/core/widgets/app_card.dart';
import 'package:ivr_frontend/core/widgets/app_error_state.dart';
import 'package:ivr_frontend/core/widgets/app_loading_state.dart';

/// Public field-staff upload (Flutter web link). Upload a GPS Map Camera geotag JPG;
/// server reads EXIF + overlay OCR and matches poles in the officer's section batch.
class PublicFieldUploadScreen extends StatefulWidget {
  final String token;
  const PublicFieldUploadScreen({super.key, required this.token});

  @override
  State<PublicFieldUploadScreen> createState() =>
      _PublicFieldUploadScreenState();
}

class _PublicFieldUploadScreenState extends State<PublicFieldUploadScreen> {
  final _picker = ImagePicker();
  final _notesCtrl = TextEditingController();
  Future<Map<String, dynamic>>? _sessionFuture;
  XFile? _picked;
  Uint8List? _previewBytes;
  String? _result;
  bool _resultIsError = false;
  bool _uploading = false;
  int? _manualPoleId;

  @override
  void initState() {
    super.initState();
    _sessionFuture = _fetchSession();
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _fetchSession() async {
    final res = await ApiClient.instance.get(
      '/public/field-sessions/${widget.token}',
    );
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
    // Do not recompress — preserves EXIF GPS and overlay text for server OCR.
    final f = await _picker.pickImage(source: ImageSource.camera);
    await _setPicked(f);
  }

  Future<void> _pickFromGallery() async {
    final f = await _picker.pickImage(source: ImageSource.gallery);
    await _setPicked(f);
  }

  Future<void> _upload() async {
    final picked = _picked;
    if (picked == null) return;
    setState(() {
      _uploading = true;
      _result = null;
      _resultIsError = false;
    });
    try {
      final bytes = _previewBytes ?? await picked.readAsBytes();
      final part = MultipartFile.fromBytes(bytes, filename: picked.name);
      final form = FormData.fromMap({
        'file': part,
        if (_notesCtrl.text.trim().isNotEmpty) 'notes': _notesCtrl.text.trim(),
        if (_manualPoleId != null) 'manual_pole_id': _manualPoleId,
      });
      final res = await ApiClient.instance.postMultipart(
        '/public/field-sessions/${widget.token}/uploads',
        form,
      );
      if (!mounted) return;
      final message =
          res['message']?.toString() ??
          'Image uploaded. Match: ${res['match_confidence'] ?? '—'}';
      setState(() {
        _result = message;
        _resultIsError = false;
        _picked = null;
        _previewBytes = null;
        _notesCtrl.clear();
      });
      _sessionFuture = _fetchSession();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _result = userFacingMessage(e);
        _resultIsError = true;
      });
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  String _workLabel(Map<String, dynamic> wi) {
    final ta = wi['description_ta']?.toString();
    final en = wi['description_en']?.toString();
    if (en != null && en.isNotEmpty) return en;
    if (ta != null && ta.isNotEmpty) return ta;
    return 'Work item #${wi['line_item_id'] ?? wi['pole_id']}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Field verification upload')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _sessionFuture,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const AppLoadingState(
              message: 'Loading field session...',
              style: AppLoadingStyle.detail,
            );
          }
          if (snap.hasError) {
            return AppErrorState(
              message: userFacingMessage(snap.error!),
              onRetry: () {
                setState(() => _sessionFuture = _fetchSession());
              },
            );
          }
          final data = snap.data!;
          final session = (data['session'] ?? {}) as Map<String, dynamic>;
          final poles =
              ((data['poles'] ?? []) as List).cast<Map<String, dynamic>>();
          final workItems =
              ((data['work_items'] ?? []) as List).cast<Map<String, dynamic>>();
          final sectionLabel = session['label']?.toString();

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    sectionLabel?.isNotEmpty == true
                        ? sectionLabel!
                        : 'Field verification',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  Text(
                    '${((session['panchayat'] ?? {}) as Map)['name']?.toString() ?? ''} • Tender #${session['tender_id']}',
                    style: const TextStyle(color: Colors.black54),
                  ),
                  if (session['expires_at'] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Link expires: ${session['expires_at']}',
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Instructions',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Use the GPS Map Camera app (or similar) so the photo includes '
                          'Lat/Long at the bottom. Then upload the JPG here.',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Work in this section (${workItems.length})',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (workItems.isEmpty)
                    const ListTile(
                      dense: true,
                      title: Text('No work items listed for this section.'),
                    ),
                  for (final wi in workItems)
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.build_outlined),
                      title: Text(_workLabel(wi)),
                      subtitle: Text(
                        wi['pole_id'] != null
                            ? 'Pole #${wi['pole_id']}'
                            : 'No pole linked',
                      ),
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
                  const SizedBox(height: 12),
                  TextField(
                    controller: _notesCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Notes (optional)',
                      hintText: 'e.g. LED replaced',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  if (poles.isNotEmpty)
                    DropdownButtonFormField<int>(
                      initialValue: _manualPoleId,
                      decoration: const InputDecoration(
                        labelText: 'Manual pole (if GPS not read)',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<int>(
                          value: null,
                          child: Text('Auto-match from photo'),
                        ),
                        for (final p in poles)
                          DropdownMenuItem<int>(
                            value: p['id'] as int,
                            child: Text(
                              p['pole_number']?.toString() ??
                                  'Pole #${p['id']}',
                            ),
                          ),
                      ],
                      onChanged: (v) => setState(() => _manualPoleId = v),
                    ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _uploading ? null : _pickFromCamera,
                        icon: const Icon(Icons.camera_alt_outlined),
                        label: const Text('Take photo'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _uploading ? null : _pickFromGallery,
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('Pick geotag JPG'),
                      ),
                      FilledButton.icon(
                        onPressed:
                            _picked == null || _uploading ? null : _upload,
                        icon:
                            _uploading
                                ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                                : const Icon(Icons.cloud_upload_outlined),
                        label: Text(_uploading ? 'Uploading…' : 'Upload'),
                      ),
                    ],
                  ),
                  if (_result != null) ...[
                    const SizedBox(height: 16),
                    AppCard(
                      color:
                          _resultIsError
                              ? Colors.red.shade50
                              : Colors.green.shade50,
                      child: Text(_result!),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
