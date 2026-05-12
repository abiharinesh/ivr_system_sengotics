import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/api/api_client.dart';
import '../../../core/download/browser_download.dart';
import 'tender_models.dart';

class TenderRepository {
  final ApiClient _api;
  TenderRepository({ApiClient? api}) : _api = api ?? ApiClient.instance;

  // ── Vendors ─────────────────────────────────────────────────────────
  Future<List<Vendor>> listVendors({bool? active}) async {
    final res = await _api.get('/api/admin/vendors',
        queryParams: active == null ? null : {'active': active.toString()});
    return ((res ?? []) as List)
        .map((e) => Vendor.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Vendor> createVendor({
    required String name,
    required String phoneE164,
    String? place,
    String? notes,
  }) async {
    final res = await _api.post('/api/admin/vendors', data: {
      'name': name,
      'phone_e164': phoneE164,
      if (place != null) 'place': place,
      if (notes != null) 'notes': notes,
    });
    return Vendor.fromJson(res as Map<String, dynamic>);
  }

  Future<Vendor> updateVendor(int id, Map<String, dynamic> patch) async {
    final res = await _api.patch('/api/admin/vendors/$id', data: patch);
    return Vendor.fromJson(res as Map<String, dynamic>);
  }

  Future<void> deactivateVendor(int id) async {
    await _api.delete('/api/admin/vendors/$id');
  }

  // ── Tenders ─────────────────────────────────────────────────────────
  Future<List<TenderSummary>> listTenders({String? status}) async {
    final res = await _api.get('/api/admin/tenders',
        queryParams: status == null ? null : {'status': status});
    return ((res ?? []) as List)
        .map((e) => TenderSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<TenderDetail> getTender(int id) async {
    final res = await _api.get('/api/admin/tenders/$id');
    return TenderDetail.fromJson(res as Map<String, dynamic>);
  }

  Future<int> createTender(Map<String, dynamic> body) async {
    final res = await _api.post('/api/admin/tenders', data: body);
    return (res as Map<String, dynamic>)['id'] as int;
  }

  Future<void> patchTender(int id, Map<String, dynamic> patch) async {
    await _api.patch('/api/admin/tenders/$id', data: patch);
  }

  /// Switch public quotation link between invited-only and open-with-phone.
  /// Allowed for any tender status except `closed`.
  Future<void> setQuotationAccessMode(int tenderId, String mode) async {
    await _api.patch(
      '/api/admin/tenders/$tenderId/quotation-access-mode',
      data: {'quotation_access_mode': mode},
    );
  }

  Future<void> publish(int id) => _api.post('/api/admin/tenders/$id/publish');
  Future<void> closeQuotations(int id) => _api.post('/api/admin/tenders/$id/close-quotations');
  Future<void> award(int id, int quotationId) =>
      _api.post('/api/admin/tenders/$id/award', data: {'quotation_id': quotationId});
  Future<void> recordWorkCompletion(int id, {DateTime? at, String? notes}) =>
      _api.post('/api/admin/tenders/$id/work-completion', data: {
        if (at != null) 'work_completed_at': at.toIso8601String(),
        if (notes != null) 'inspection_notes': notes,
      });
  Future<void> recordPayment(int id, Map<String, dynamic> paymentMeta, {bool close = false}) =>
      _api.post('/api/admin/tenders/$id/payment',
          data: {'payment_meta': paymentMeta, 'close': close});

  Future<void> addOfficerQuotation(int tenderId, Map<String, dynamic> body) =>
      _api.post('/api/admin/tenders/$tenderId/quotations', data: body);
  Future<void> setInvites(int tenderId, List<int> vendorIds) =>
      _api.post('/api/admin/tenders/$tenderId/invites', data: {'vendor_ids': vendorIds});
  Future<void> addLineItem(int tenderId, Map<String, dynamic> body) =>
      _api.post('/api/admin/tenders/$tenderId/line-items', data: body);
  Future<void> updateLineItem(int tenderId, int itemId, Map<String, dynamic> body) =>
      _api.patch('/api/admin/tenders/$tenderId/line-items/$itemId', data: body);
  Future<void> deleteLineItem(int tenderId, int itemId) =>
      _api.delete('/api/admin/tenders/$tenderId/line-items/$itemId');

  // ── Documents ───────────────────────────────────────────────────────
  Future<List<TenderDocumentSummary>> listDocuments(int tenderId) async {
    final res = await _api.get('/api/admin/tenders/$tenderId/documents');
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
      '/api/admin/tenders/$tenderId/documents/$templateId/generate',
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
      '/api/admin/tenders/$tenderId/documents/$docId/download',
    );
    await saveBytes(
      bytes: file.bytes,
      filename: file.filename ?? fallbackName ?? 'tender-$tenderId-doc-$docId.pdf',
      contentType: file.contentType ?? 'application/pdf',
    );
  }

  /// Download the latest-of-each-template zip bundle for a tender.
  Future<void> downloadDocumentsZip(int tenderId) async {
    final file = await _api.getDownload(
      '/api/admin/tenders/$tenderId/documents.zip',
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
      '/api/admin/tenders/$tenderId/documents/$docId/share-link',
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
      '/api/admin/tenders/$tenderId/documents.zip/share-link',
      data: {'ttl_minutes': ttlMinutes},
    );
    final json = res as Map<String, dynamic>;
    return (
      url: json['url'] as String,
      expiresAt: DateTime.parse(json['expires_at'] as String),
    );
  }

  // ── Field verification ─────────────────────────────────────────────
  Future<FieldVerificationSession> createSession(int tenderId,
      {List<int>? poleSubsetIds, int? expiresInDays}) async {
    final res = await _api.post('/api/admin/tenders/$tenderId/verification-sessions', data: {
      if (poleSubsetIds != null) 'pole_subset_ids': poleSubsetIds,
      if (expiresInDays != null) 'expires_in_days': expiresInDays,
    });
    return FieldVerificationSession.fromJson(res as Map<String, dynamic>);
  }

  Future<List<ChecklistItem>> getChecklist(int tenderId) async {
    final res = await _api.get('/api/admin/tenders/$tenderId/checklist');
    return ((res ?? []) as List)
        .map((e) => ChecklistItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ChecklistItem> patchChecklistItem(
    int tenderId,
    int itemId, {
    bool? isDone,
    int? verifiedUploadId,
    String? notes,
  }) async {
    final res = await _api.patch(
      '/api/admin/tenders/$tenderId/checklist/$itemId',
      data: {
        if (isDone != null) 'is_done': isDone,
        if (verifiedUploadId != null) 'verified_upload_id': verifiedUploadId,
        if (notes != null) 'notes': notes,
      },
    );
    return ChecklistItem.fromJson(res as Map<String, dynamic>);
  }

  Future<void> confirmVerification(int tenderId) =>
      _api.post('/api/admin/tenders/$tenderId/confirm-verification');

  // ── Public flows (no auth, used by web build) ───────────────────────
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
}
