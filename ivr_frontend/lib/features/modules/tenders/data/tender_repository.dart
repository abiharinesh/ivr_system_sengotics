import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ivr_frontend/core/api/api_client.dart';
import 'package:ivr_frontend/core/api/api_exceptions.dart';
import 'package:ivr_frontend/core/download/browser_download.dart';
import 'models/tender_models.dart';

class TenderRepository {
  final ApiClient _api;
  final bool isSuperAdmin;
  TenderRepository({ApiClient? api, this.isSuperAdmin = false}) : _api = api ?? ApiClient.instance;

  String get _base => isSuperAdmin ? '/api/superadmin' : '/api/admin';

  // ── Vendors ─────────────────────────────────────────────────────────
  List<Vendor>? getCachedVendors({bool? active, int? orgUnitId}) {
    final params = <String, dynamic>{
      if (active != null) 'active': active.toString(),
      if (orgUnitId != null) 'org_unit_id': orgUnitId.toString(),
    };
    final cached = _api.getCached('$_base/vendors',
        queryParams: params.isEmpty ? null : params);
    if (cached == null) return null;
    return ((cached) as List)
        .map((e) => Vendor.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<Vendor>> listVendors({bool? active, int? orgUnitId, bool forceRefresh = false}) async {
    final params = <String, dynamic>{
      if (active != null) 'active': active.toString(),
      if (orgUnitId != null) 'org_unit_id': orgUnitId.toString(),
    };
    final res = await _api.get('$_base/vendors',
        queryParams: params.isEmpty ? null : params, forceRefresh: forceRefresh);
    return ((res ?? []) as List)
        .map((e) => Vendor.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Vendor> createVendor({
    required String name,
    required String phoneE164,
    String? place,
    String? notes,
    int? orgUnitId,
  }) async {
    final res = await _api.post('$_base/vendors', data: {
      'name': name,
      'phone_e164': phoneE164,
      if (place != null) 'place': place,
      if (notes != null) 'notes': notes,
      if (orgUnitId != null) 'org_unit_id': orgUnitId,
    });
    return Vendor.fromJson(res as Map<String, dynamic>);
  }

  Future<Vendor> updateVendor(int id, Map<String, dynamic> patch) async {
    final res = await _api.patch('$_base/vendors/$id', data: patch);
    return Vendor.fromJson(res as Map<String, dynamic>);
  }

  Future<void> deactivateVendor(int id) async {
    await _api.delete('$_base/vendors/$id');
  }

  // ── Tenders ─────────────────────────────────────────────────────────
  List<TenderSummary>? getCachedTenders({String? status, int? orgUnitId}) {
    final params = <String, dynamic>{
      if (status != null) 'status': status,
      if (orgUnitId != null) 'org_unit_id': orgUnitId.toString(),
    };
    final cached = _api.getCached('$_base/tenders',
        queryParams: params.isEmpty ? null : params);
    if (cached == null) return null;
    return ((cached) as List)
        .map((e) => TenderSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<TenderSummary>> listTenders({String? status, int? orgUnitId, bool forceRefresh = false}) async {
    final params = <String, dynamic>{
      if (status != null) 'status': status,
      if (orgUnitId != null) 'org_unit_id': orgUnitId.toString(),
    };
    final res = await _api.get('$_base/tenders',
        queryParams: params.isEmpty ? null : params, forceRefresh: forceRefresh);
    return ((res ?? []) as List)
        .map((e) => TenderSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<TenderDetail> getTender(int id) async {
    final res = await _api.get('$_base/tenders/$id');
    return TenderDetail.fromJson(res as Map<String, dynamic>);
  }

  Future<int> createTender(Map<String, dynamic> body) async {
    final res = await _api.post('$_base/tenders', data: body);
    return (res as Map<String, dynamic>)['id'] as int;
  }

  Future<void> patchTender(int id, Map<String, dynamic> patch) async {
    await _api.patch('$_base/tenders/$id', data: patch);
  }

  /// Switch public quotation link between invited-only and open-with-phone.
  /// Allowed for any tender status except `closed`.
  Future<void> setQuotationAccessMode(int tenderId, String mode) async {
    await _api.patch(
      '$_base/tenders/$tenderId/quotation-access-mode',
      data: {'quotation_access_mode': mode},
    );
  }

  Future<void> publish(int id) => _api.post('$_base/tenders/$id/publish');
  Future<void> closeQuotations(int id) => _api.post('$_base/tenders/$id/close-quotations');
  Future<void> award(int id, int quotationId) =>
      _api.post('$_base/tenders/$id/award', data: {'quotation_id': quotationId});
  Future<void> recordWorkCompletion(int id, {DateTime? at, String? notes}) =>
      _api.post('$_base/tenders/$id/work-completion', data: {
        if (at != null) 'work_completed_at': at.toIso8601String(),
        if (notes != null) 'inspection_notes': notes,
      });
  Future<void> recordPayment(int id, Map<String, dynamic> paymentMeta, {bool close = false}) =>
      _api.post('$_base/tenders/$id/payment',
          data: {'payment_meta': paymentMeta, 'close': close});

  Future<void> addOfficerQuotation(int tenderId, Map<String, dynamic> body) =>
      _api.post('$_base/tenders/$tenderId/quotations', data: body);
  Future<void> setInvites(int tenderId, List<int> vendorIds) =>
      _api.post('$_base/tenders/$tenderId/invites', data: {'vendor_ids': vendorIds});
  Future<void> addLineItem(int tenderId, Map<String, dynamic> body) =>
      _api.post('$_base/tenders/$tenderId/line-items', data: body);
  Future<void> updateLineItem(int tenderId, int itemId, Map<String, dynamic> body) =>
      _api.patch('$_base/tenders/$tenderId/line-items/$itemId', data: body);
  Future<void> deleteLineItem(int tenderId, int itemId) =>
      _api.delete('$_base/tenders/$tenderId/line-items/$itemId');

  // ── Documents ───────────────────────────────────────────────────────
  Future<List<TenderDocumentSummary>> listDocuments(int tenderId) async {
    final res = await _api.get('$_base/tenders/$tenderId/documents');
    return ((res ?? []) as List)
        .map((e) => TenderDocumentSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<TenderDocumentSummary> generateDocument(
    int tenderId,
    String templateId, {
    int? vendorId,
    Map<String, dynamic>? fieldOverrides,
  }) async {
    final res = await _api.post(
      '$_base/tenders/$tenderId/documents/$templateId/generate',
      data: {
        if (vendorId != null) 'vendor_id': vendorId,
        if (fieldOverrides != null) 'field_overrides': fieldOverrides,
      },
    );
    return TenderDocumentSummary.fromJson(res as Map<String, dynamic>);
  }

  /// Download a single ready document via the authenticated endpoint and hand
  /// it to the platform save sheet (web blob / mobile share).
  Future<void> downloadDocument(
    int tenderId,
    int docId, {
    String? fallbackName,
  }) async {
    final file = await _api.getDownload(
      '$_base/tenders/$tenderId/documents/$docId/download',
    );
    await saveBytes(
      bytes: file.bytes,
      filename: file.filename ?? fallbackName ?? 'tender-$tenderId-doc-$docId.pdf',
      contentType: file.contentType ?? 'application/pdf',
    );
  }

  /// Fetch a ready document for in-app preview (no save prompt).
  /// Returns both bytes and the content type so the UI can switch between
  /// PDF and HTML preview surfaces.
  Future<PreviewResult> previewDocument(int tenderId, int docId) async {
    final file = await _api.getDownload(
      '$_base/tenders/$tenderId/documents/$docId/preview',
    );
    return PreviewResult(
      bytes: file.bytes,
      contentType: file.contentType ?? 'application/pdf',
    );
  }

  Future<CanvasState> getCanvasState(int tenderId, int docId) async {
    final res = await _api.get('$_base/tenders/$tenderId/documents/$docId/canvas');
    final json = res as Map<String, dynamic>;
    final layers = (json['layers'] as List?) ?? const [];
    final parsedLayers = layers
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    return CanvasState(
      canEdit: (json['can_edit'] ?? true) == true,
      lockedReason: json['locked_reason']?.toString(),
      layers: parsedLayers,
    );
  }

  Future<void> saveCanvasLayers(
    int tenderId,
    int docId,
    List<Map<String, dynamic>> layers,
  ) async {
    await _api.post(
      '$_base/tenders/$tenderId/documents/$docId/canvas',
      data: {'layers': layers},
    );
  }

  Future<void> mergeCanvasLayers(
    int tenderId,
    int docId,
    List<Map<String, dynamic>> layers,
  ) async {
    await _api.post(
      '$_base/tenders/$tenderId/documents/$docId/canvas/merge',
      data: {'layers': layers},
    );
  }

  /// Download the latest-of-each-template zip bundle for a tender.
  Future<void> downloadDocumentsZip(int tenderId) async {
    final file = await _api.getDownload(
      '$_base/tenders/$tenderId/documents.zip',
    );
    await saveBytes(
      bytes: file.bytes,
      filename: file.filename ?? 'tender-$tenderId-bundle.zip',
      contentType: file.contentType ?? 'application/zip',
    );
  }

  /// Mint a short-lived signed URL for a single ready document. Officer-only.
  Future<({String url, DateTime expiresAt})> mintDocShareLink(
    int tenderId,
    int docId, {
    int ttlMinutes = 15,
  }) async {
    final res = await _api.post(
      '$_base/tenders/$tenderId/documents/$docId/share-link',
      data: {'ttl_minutes': ttlMinutes},
    );
    final json = res as Map<String, dynamic>;
    return (
      url: json['url'] as String,
      expiresAt: DateTime.parse(json['expires_at'] as String),
    );
  }

  /// Mint a short-lived signed URL for the zip bundle. Officer-only.
  Future<({String url, DateTime expiresAt})> mintZipShareLink(
    int tenderId, {
    int ttlMinutes = 15,
  }) async {
    final res = await _api.post(
      '$_base/tenders/$tenderId/documents.zip/share-link',
      data: {'ttl_minutes': ttlMinutes},
    );
    final json = res as Map<String, dynamic>;
    return (
      url: json['url'] as String,
      expiresAt: DateTime.parse(json['expires_at'] as String),
    );
  }

  // ── Field verification ─────────────────────────────────────────────
  Future<FieldVerificationSession> createSession(
    int tenderId, {
    String? label,
    List<int>? poleSubsetIds,
    int? expiresInDays,
  }) async {
    final res = await _api.post('$_base/tenders/$tenderId/verification-sessions', data: {
      if (label != null && label.trim().isNotEmpty) 'label': label.trim(),
      if (poleSubsetIds != null) 'pole_subset_ids': poleSubsetIds,
      if (expiresInDays != null) 'expires_in_days': expiresInDays,
    });
    return FieldVerificationSession.fromJson(res as Map<String, dynamic>);
  }

  Future<List<ChecklistItem>> getChecklist(int tenderId) async {
    final res = await _api.get('$_base/tenders/$tenderId/checklist');
    return ((res ?? []) as List)
        .map((e) => ChecklistItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ChecklistItem> patchChecklistItem(
    int tenderId,
    int itemId, {
    bool? isDone,
    int? verifiedUploadId,
    bool clearVerifiedUpload = false,
    String? notes,
  }) async {
    final data = <String, dynamic>{
      if (isDone != null) 'is_done': isDone,
      if (notes != null) 'notes': notes,
    };
    if (clearVerifiedUpload) {
      data['verified_upload_id'] = null;
    } else if (verifiedUploadId != null) {
      data['verified_upload_id'] = verifiedUploadId;
    }
    final res = await _api.patch(
      '$_base/tenders/$tenderId/checklist/$itemId',
      data: data,
    );
    return ChecklistItem.fromJson(res as Map<String, dynamic>);
  }

  Future<ChecklistItem> assignUpload(
    int tenderId,
    int uploadId,
    int poleId, {
    bool approve = false,
  }) async {
    final res = await _api.post(
      '$_base/tenders/$tenderId/verification-uploads/$uploadId/assign',
      data: {'pole_id': poleId, if (approve) 'approve': true},
    );
    return ChecklistItem.fromJson(res as Map<String, dynamic>);
  }

  Future<void> confirmVerification(int tenderId) =>
      _api.post('$_base/tenders/$tenderId/confirm-verification');

  // ── Public flows (no auth, used by web build) ───────────────────────

  /// True when the API host has not been deployed with the new public routes yet.
  bool _isMissingPublicRoute(NotFoundException e) {
    final msg = e.message.toLowerCase();
    return msg.contains('cannot get') || msg.contains('cannot post');
  }

  Future<Map<String, dynamic>> readPublicOpenTender(String token) async {
    try {
      final res = await _api.get('/public/open/$token');
      return res as Map<String, dynamic>;
    } on NotFoundException catch (e) {
      if (!_isMissingPublicRoute(e)) rethrow;
      // Older API builds only expose /public/tenders/:token.
      final res = await _api.get('/public/tenders/$token');
      return res as Map<String, dynamic>;
    }
  }

  Future<Map<String, dynamic>> submitPublicOpenQuotation(
    String token, {
    required String name,
    required String phone,
    required String amount,
    String? remarks,
    XFile? attachment,
  }) async {
    MultipartFile? attachmentPart;
    if (attachment != null) {
      final bytes = await attachment.readAsBytes();
      attachmentPart = MultipartFile.fromBytes(bytes, filename: attachment.name);
    }
    final form = FormData.fromMap({
      'name': name,
      'phone': phone,
      'amount': amount,
      if (remarks != null) 'remarks': remarks,
      if (attachmentPart != null) 'attachment': attachmentPart,
    });
    try {
      final res = await _api.postMultipart('/public/open/$token/quotations', form);
      return res as Map<String, dynamic>;
    } on NotFoundException catch (e) {
      if (!_isMissingPublicRoute(e)) rethrow;
      final res = await _api.postMultipart('/public/tenders/$token/quotations', form);
      return res as Map<String, dynamic>;
    }
  }

  Future<Map<String, dynamic>> readInviteTender(String inviteToken) async {
    try {
      final res = await _api.get('/public/invite/$inviteToken');
      return res as Map<String, dynamic>;
    } on NotFoundException catch (e) {
      if (!_isMissingPublicRoute(e)) rethrow;
      throw ApiException(
        'This API host does not support invite links yet. '
        'Deploy the latest backend (with /public/invite routes) and try again.',
        statusCode: 404,
      );
    }
  }

  Future<Map<String, dynamic>> submitInviteQuotation(
    String inviteToken, {
    required String name,
    required String amount,
    String? phone,
    String? remarks,
    XFile? attachment,
  }) async {
    MultipartFile? attachmentPart;
    if (attachment != null) {
      final bytes = await attachment.readAsBytes();
      attachmentPart = MultipartFile.fromBytes(bytes, filename: attachment.name);
    }
    final form = FormData.fromMap({
      'name': name,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
      'amount': amount,
      if (remarks != null) 'remarks': remarks,
      if (attachmentPart != null) 'attachment': attachmentPart,
    });
    try {
      final res = await _api.postMultipart(
        '/public/invite/$inviteToken/quotation',
        form,
      );
      return res as Map<String, dynamic>;
    } on NotFoundException catch (e) {
      if (!_isMissingPublicRoute(e)) rethrow;
      throw ApiException(
        'This API host does not support invite links yet. '
        'Deploy the latest backend and retry.',
        statusCode: 404,
      );
    }
  }

  Future<Map<String, dynamic>> readPublicTender(String token) async {
    final res = await _api.get('/public/tenders/$token');
    return res as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> submitPublicQuotation(
    String token, {
    required String name,
    required String phone,
    required String amount,
    String? remarks,
    XFile? attachment,
  }) async {
    MultipartFile? attachmentPart;
    if (attachment != null) {
      // Use bytes path so the same code works on web (no dart:io) and mobile.
      final bytes = await attachment.readAsBytes();
      attachmentPart = MultipartFile.fromBytes(bytes, filename: attachment.name);
    }
    final form = FormData.fromMap({
      'name': name,
      'phone': phone,
      'amount': amount,
      if (remarks != null) 'remarks': remarks,
      if (attachmentPart != null) 'attachment': attachmentPart,
    });
    final res = await _api.postMultipart('/public/tenders/$token/quotations', form);
    return res as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> readFieldSession(String token) async {
    final res = await _api.get('/public/field-sessions/$token');
    return res as Map<String, dynamic>;
  }

  // ── Document editing & format download ──────────────────────────────

  /// Fetch the HTML source of a document for inline editing.
  Future<String> getDocumentHtmlContent(int tenderId, int docId) async {
    final res = await _api.get(
      '$_base/tenders/$tenderId/documents/$docId/html-content',
    );
    return (res as Map<String, dynamic>)['html'] as String;
  }

  /// Save edited HTML content back to the server.
  Future<void> saveDocumentContent(
    int tenderId,
    int docId,
    String html,
  ) async {
    await _api.post(
      '$_base/tenders/$tenderId/documents/$docId/content',
      data: {'html': html},
    );
  }

  /// Download a document in a specific format (pdf, html, docx).
  Future<void> downloadDocumentInFormat(
    int tenderId,
    int docId, {
    required String format,
    String? fallbackName,
  }) async {
    final file = await _api.getDownload(
      '$_base/tenders/$tenderId/documents/$docId/download?format=$format',
    );
    final ext = format == 'docx' ? 'doc' : format;
    await saveBytes(
      bytes: file.bytes,
      filename:
          file.filename ?? fallbackName ?? 'tender-$tenderId-doc-$docId.$ext',
      contentType: file.contentType ?? 'application/octet-stream',
    );
  }
}

class CanvasState {
  final bool canEdit;
  final String? lockedReason;
  final List<Map<String, dynamic>> layers;
  const CanvasState({
    required this.canEdit,
    this.lockedReason,
    required this.layers,
  });
}

/// Result of a document preview fetch, carrying both bytes and content type
/// so the UI can choose between PDF and HTML rendering.
class PreviewResult {
  final Uint8List bytes;
  final String contentType;
  const PreviewResult({required this.bytes, required this.contentType});

  bool get isHtml => contentType.toLowerCase().contains('text/html');
}
