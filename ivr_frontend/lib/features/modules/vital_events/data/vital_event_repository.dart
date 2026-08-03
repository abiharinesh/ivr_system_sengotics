import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:ivr_frontend/core/api/api_client.dart';
import 'models/vital_event_models.dart';

/// Thin wrapper over `/api/vital-events`, plus the unauthenticated
/// verification endpoint the printed QR code points at.
class VitalEventRepository {
  final ApiClient _api;

  VitalEventRepository({ApiClient? api}) : _api = api ?? ApiClient.instance;

  static const String _base = '/api/vital-events';

  /// Public verification lives outside the authenticated tree — a verifier
  /// scanning a certificate has no account here.
  static const String publicVerifyBase = '/public/vital-certificates';

  Map<String, dynamic> _listParams({
    VitalEventType? eventType,
    VitalStatus? status,
    String? query,
    DateTime? from,
    DateTime? to,
    bool? lateOnly,
    int? orgUnitId,
    int? take,
    int? skip,
  }) {
    String day(DateTime d) => d.toIso8601String().split('T').first;
    return <String, dynamic>{
      if (eventType != null) 'event_type': eventType.wire,
      if (status != null) 'status': status.wire,
      if (query != null && query.isNotEmpty) 'q': query,
      if (from != null) 'from': day(from),
      if (to != null) 'to': day(to),
      if (lateOnly == true) 'late_only': 'true',
      if (orgUnitId != null) 'org_unit_id': orgUnitId.toString(),
      if (take != null) 'take': take.toString(),
      if (skip != null) 'skip': skip.toString(),
    };
  }

  VitalEventPage? getCachedEvents({
    VitalEventType? eventType,
    VitalStatus? status,
    String? query,
    DateTime? from,
    DateTime? to,
    bool? lateOnly,
  }) {
    final params = _listParams(
      eventType: eventType,
      status: status,
      query: query,
      from: from,
      to: to,
      lateOnly: lateOnly,
    );
    final cached = _api.getCached(_base, queryParams: params.isEmpty ? null : params);
    if (cached == null) return null;
    return VitalEventPage.fromJson(cached as Map<String, dynamic>);
  }

  Future<VitalEventPage> listEvents({
    VitalEventType? eventType,
    VitalStatus? status,
    String? query,
    DateTime? from,
    DateTime? to,
    bool? lateOnly,
    int? orgUnitId,
    int? take,
    int? skip,
    bool forceRefresh = false,
  }) async {
    final params = _listParams(
      eventType: eventType,
      status: status,
      query: query,
      from: from,
      to: to,
      lateOnly: lateOnly,
      orgUnitId: orgUnitId,
      take: take,
      skip: skip,
    );
    final res = await _api.get(
      _base,
      queryParams: params.isEmpty ? null : params,
      forceRefresh: forceRefresh,
    );
    if (res == null) return VitalEventPage.empty;
    return VitalEventPage.fromJson(res as Map<String, dynamic>);
  }

  Future<VitalEventStats> fetchStats({
    int? orgUnitId,
    bool forceRefresh = false,
  }) async {
    final params = <String, dynamic>{
      if (orgUnitId != null) 'org_unit_id': orgUnitId.toString(),
    };
    final res = await _api.get(
      '$_base/summary',
      queryParams: params.isEmpty ? null : params,
      forceRefresh: forceRefresh,
    );
    if (res == null) return VitalEventStats.empty;
    return VitalEventStats.fromJson(res as Map<String, dynamic>);
  }

  Future<VitalEventDetail> getEvent(int id, {bool forceRefresh = false}) async {
    final res = await _api.get('$_base/$id', forceRefresh: forceRefresh);
    return VitalEventDetail.fromJson(res as Map<String, dynamic>);
  }

  // ── Intake ──────────────────────────────────────────────────────────────

  Future<VitalEventSummary> reportEvent(Map<String, dynamic> payload) async {
    final res = await _api.post(_base, data: payload);
    return VitalEventSummary.fromJson(res as Map<String, dynamic>);
  }

  Future<HospitalFeedResult> hospitalFeed({
    required String hospitalName,
    String? hospitalRegNo,
    required List<Map<String, dynamic>> events,
  }) async {
    final res = await _api.post('$_base/hospital-feed', data: {
      'hospital_name': hospitalName,
      if (hospitalRegNo != null && hospitalRegNo.isNotEmpty)
        'hospital_reg_no': hospitalRegNo,
      'events': events,
    });
    return HospitalFeedResult.fromJson(res as Map<String, dynamic>);
  }

  Future<VitalEventSummary> updateParticulars(
    int id,
    Map<String, dynamic> patch,
  ) async {
    final res = await _api.put('$_base/$id', data: patch);
    return VitalEventSummary.fromJson(res as Map<String, dynamic>);
  }

  // ── Registrar's acts ────────────────────────────────────────────────────

  Future<VitalEventSummary> verifyEntry(int id) async {
    final res = await _api.post('$_base/$id/verify');
    return VitalEventSummary.fromJson(res as Map<String, dynamic>);
  }

  Future<VitalEventSummary> registerEntry(
    int id, {
    String? delayApprovalRef,
  }) async {
    final res = await _api.post('$_base/$id/register', data: {
      if (delayApprovalRef != null && delayApprovalRef.isNotEmpty)
        'delay_approval_ref': delayApprovalRef,
    });
    return VitalEventSummary.fromJson(res as Map<String, dynamic>);
  }

  Future<VitalEventSummary> rejectEntry(int id, String reason) async {
    final res = await _api.post('$_base/$id/reject', data: {'reason': reason});
    return VitalEventSummary.fromJson(res as Map<String, dynamic>);
  }

  /// Correction under s.15. Any certificate issued against the superseded
  /// particulars is cancelled server-side.
  Future<VitalEventDetail> correctEntry(
    int id, {
    required String correctionNote,
    Map<String, dynamic>? birth,
    Map<String, dynamic>? death,
  }) async {
    final res = await _api.post('$_base/$id/correct', data: {
      'correction_note': correctionNote,
      if (birth != null) 'birth': birth,
      if (death != null) 'death': death,
    });
    return VitalEventDetail.fromJson(res as Map<String, dynamic>);
  }

  // ── Certificates ────────────────────────────────────────────────────────

  Future<VitalCertificate> issueCertificate(
    int id, {
    required String issuedTo,
    String? issuedToRelation,
    String? purpose,
    double? feeAmount,
    String? paymentRef,
  }) async {
    final res = await _api.post('$_base/$id/certificates', data: {
      'issued_to': issuedTo,
      if (issuedToRelation != null && issuedToRelation.isNotEmpty)
        'issued_to_relation': issuedToRelation,
      if (purpose != null && purpose.isNotEmpty) 'purpose': purpose,
      if (feeAmount != null) 'fee_amount': feeAmount,
      if (paymentRef != null && paymentRef.isNotEmpty) 'payment_ref': paymentRef,
    });
    return VitalCertificate.fromJson(res as Map<String, dynamic>);
  }

  Future<VitalCertificate> cancelCertificate(
    int id,
    int certificateId,
    String reason,
  ) async {
    final res = await _api.put(
      '$_base/$id/certificates/$certificateId/cancel',
      data: {'reason': reason},
    );
    return VitalCertificate.fromJson(res as Map<String, dynamic>);
  }

  /// Look up a certificate by the token embedded in its QR code. Works
  /// without a session — the endpoint is public by design.
  Future<CertificateVerification> verifyByToken(String token) async {
    final res = await _api.get('$publicVerifyBase/$token', forceRefresh: true);
    return CertificateVerification.fromJson(res as Map<String, dynamic>);
  }

  // ── Supporting documents ────────────────────────────────────────────────

  Future<VitalDocument> uploadDocument(
    int id, {
    required Uint8List bytes,
    required String fileName,
    String? title,
  }) async {
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: fileName),
      if (title != null && title.isNotEmpty) 'title': title,
    });
    final res = await _api.postMultipart('$_base/$id/documents', form);
    return VitalDocument.fromJson(res as Map<String, dynamic>);
  }
}
