import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:ivr_frontend/config/app_theme.dart';
import 'package:ivr_frontend/core/api/api_client.dart';
import 'package:ivr_frontend/core/api/api_exceptions.dart';
import 'package:ivr_frontend/core/widgets/api_file_image.dart';
import 'package:ivr_frontend/core/widgets/app_card.dart';
import 'package:ivr_frontend/core/widgets/pdf_preview_surface.dart';
import 'package:ivr_frontend/features/modules/building_permits/data/models/building_permit_models.dart';

/// Blueprints, NOC letters and site photos held against the permit.
///
/// Files live in the shared DMS (`entity_type = building_permit`), so they
/// inherit its versioning, tagging and soft delete rather than sitting in a
/// module-specific table.
class PermitDocumentsCard extends StatelessWidget {
  final List<PermitDocument> documents;
  final bool uploading;
  final VoidCallback onUpload;

  const PermitDocumentsCard({
    super.key,
    required this.documents,
    required this.onUpload,
    this.uploading = false,
  });

  @override
  Widget build(BuildContext context) {
    final df = DateFormat.yMMMd();

    return AppCard(
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.folder_open_rounded, color: AppTheme.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Plans & documents',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: uploading ? null : onUpload,
                icon: uploading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.upload_file_rounded, size: 18),
                label: Text(uploading ? 'Uploading...' : 'Upload'),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceSm),
          if (documents.isEmpty)
            Text(
              'No plans uploaded yet. Attach the site plan, floor plans and any '
              'clearance letters received from departments.',
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
            )
          else
            ...documents.map(
              (doc) => ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: Icon(
                  doc.isPdf
                      ? Icons.picture_as_pdf_rounded
                      : Icons.image_outlined,
                  color: doc.isPdf ? AppTheme.error : AppTheme.info,
                ),
                title: Text(
                  doc.title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  'v${doc.version}'
                  '${doc.createdAt != null ? ' · ${df.format(doc.createdAt!)}' : ''}'
                  ' · ${doc.fileName}',
                  style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                ),
                trailing: Icon(
                  Icons.open_in_full_rounded,
                  size: 18,
                  color: AppTheme.textMuted,
                ),
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (_) => PermitDocumentViewer(document: doc),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Full-bleed viewer — renders PDFs inline on web via the shared
/// [PdfPreviewSurface], and images through [ApiFileImage] so the request
/// carries the auth header instead of tripping CORS on a bare `Image.network`.
class PermitDocumentViewer extends StatelessWidget {
  final PermitDocument document;

  const PermitDocumentViewer({super.key, required this.document});

  @override
  Widget build(BuildContext context) {
    final url = document.fileUrl;

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: SizedBox(
        width: 900,
        height: 680,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      document.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: url == null || url.isEmpty
                  ? Center(
                      child: Text(
                        'This document has no stored file.',
                        style: TextStyle(color: AppTheme.textMuted),
                      ),
                    )
                  : document.isPdf
                      ? _PdfBody(url: url)
                      : InteractiveViewer(
                          maxScale: 5,
                          child: ApiFileImage(path: url, fit: BoxFit.contain),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PdfBody extends StatefulWidget {
  final String url;

  const _PdfBody({required this.url});

  @override
  State<_PdfBody> createState() => _PdfBodyState();
}

class _PdfBodyState extends State<_PdfBody> {
  late final Future<Uint8List> _future;

  @override
  void initState() {
    super.initState();
    _future = ApiClient.instance.getBytes(widget.url);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError || !snap.hasData) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                snap.hasError
                    ? userFacingMessage(snap.error!)
                    : 'Could not load this plan.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ),
          );
        }
        return PdfPreviewSurface(bytes: snap.data!);
      },
    );
  }
}
