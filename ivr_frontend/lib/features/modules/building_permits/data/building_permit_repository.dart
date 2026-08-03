import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:ivr_frontend/core/api/api_client.dart';
import 'models/building_permit_models.dart';

/// Thin wrapper over `/api/building-permits`.
///
/// Every method returns a typed model rather than a raw map, so a shape change
/// on the backend surfaces here as one compile error instead of a scattering of
/// null-checks in widgets.
class BuildingPermitRepository {
  final ApiClient _api;

  BuildingPermitRepository({ApiClient? api}) : _api = api ?? ApiClient.instance;

  static const String _base = '/api/building-permits';

  Map<String, dynamic> _listParams({
    String? status,
    String? constructionType,
    String? query,
    int? orgUnitId,
    int? take,
    int? skip,
  }) {
    return <String, dynamic>{
      if (status != null) 'status': status,
      if (constructionType != null) 'construction_type': constructionType,
      if (query != null && query.isNotEmpty) 'q': query,
      if (orgUnitId != null) 'org_unit_id': orgUnitId.toString(),
      if (take != null) 'take': take.toString(),
      if (skip != null) 'skip': skip.toString(),
    };
  }

  /// Cached page, for painting the list before the network settles.
  BuildingPermitPage? getCachedPermits({
    String? status,
    String? constructionType,
    String? query,
    int? orgUnitId,
  }) {
    final params = _listParams(
      status: status,
      constructionType: constructionType,
      query: query,
      orgUnitId: orgUnitId,
    );
    final cached = _api.getCached(_base, queryParams: params.isEmpty ? null : params);
    if (cached == null) return null;
    return BuildingPermitPage.fromJson(cached as Map<String, dynamic>);
  }

  Future<BuildingPermitPage> listPermits({
    String? status,
    String? constructionType,
    String? query,
    int? orgUnitId,
    int? take,
    int? skip,
    bool forceRefresh = false,
  }) async {
    final params = _listParams(
      status: status,
      constructionType: constructionType,
      query: query,
      orgUnitId: orgUnitId,
      take: take,
      skip: skip,
    );
    final res = await _api.get(
      _base,
      queryParams: params.isEmpty ? null : params,
      forceRefresh: forceRefresh,
    );
    if (res == null) return BuildingPermitPage.empty;
    return BuildingPermitPage.fromJson(res as Map<String, dynamic>);
  }

  Future<BuildingPermitStats> fetchStats({
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
    if (res == null) return BuildingPermitStats.empty;
    return BuildingPermitStats.fromJson(res as Map<String, dynamic>);
  }

  Future<BuildingPermitDetail> getPermit(int id, {bool forceRefresh = false}) async {
    final res = await _api.get('$_base/$id', forceRefresh: forceRefresh);
    return BuildingPermitDetail.fromJson(res as Map<String, dynamic>);
  }

  // ── Application lifecycle ───────────────────────────────────────────────

  Future<BuildingPermitSummary> createPermit(Map<String, dynamic> payload) async {
    final res = await _api.post(_base, data: payload);
    return BuildingPermitSummary.fromJson(res as Map<String, dynamic>);
  }

  Future<BuildingPermitSummary> updatePermit(
    int id,
    Map<String, dynamic> patch,
  ) async {
    final res = await _api.put('$_base/$id', data: patch);
    return BuildingPermitSummary.fromJson(res as Map<String, dynamic>);
  }

  Future<BuildingPermitSummary> submitPermit(int id) async {
    final res = await _api.post('$_base/$id/submit');
    return BuildingPermitSummary.fromJson(res as Map<String, dynamic>);
  }

  Future<BuildingPermitSummary> changeStatus(int id, PermitStatus target) async {
    final res = await _api.post('$_base/$id/status', data: {'status': target.wire});
    return BuildingPermitSummary.fromJson(res as Map<String, dynamic>);
  }

  Future<BuildingPermitSummary> approvePermit(
    int id, {
    int? validityMonths,
    String? remarks,
  }) async {
    final res = await _api.post('$_base/$id/approve', data: {
      if (validityMonths != null) 'validity_months': validityMonths,
      if (remarks != null && remarks.isNotEmpty) 'remarks': remarks,
    });
    return BuildingPermitSummary.fromJson(res as Map<String, dynamic>);
  }

  Future<BuildingPermitSummary> rejectPermit(int id, String reason) async {
    final res = await _api.post('$_base/$id/reject', data: {'reason': reason});
    return BuildingPermitSummary.fromJson(res as Map<String, dynamic>);
  }

  // ── NOC clearances ──────────────────────────────────────────────────────

  Future<void> addNoc(int id, String department, {bool isMandatory = true}) async {
    await _api.post('$_base/$id/nocs', data: {
      'department': department,
      'is_mandatory': isMandatory,
    });
  }

  /// Returns the refreshed permit — the backend may have auto-advanced the
  /// status when this was the last mandatory clearance.
  Future<BuildingPermitDetail> updateNoc(
    int id,
    int nocId, {
    required NocState status,
    String? referenceNo,
    String? remarks,
  }) async {
    final res = await _api.put('$_base/$id/nocs/$nocId', data: {
      'status': status.wire,
      if (referenceNo != null && referenceNo.isNotEmpty) 'reference_no': referenceNo,
      if (remarks != null && remarks.isNotEmpty) 'remarks': remarks,
    });
    return BuildingPermitDetail.fromJson(res as Map<String, dynamic>);
  }

  // ── Site inspections ────────────────────────────────────────────────────

  Future<PermitInspection> scheduleInspection(
    int id, {
    required String inspectionType,
    required DateTime scheduledFor,
    int? inspectorUserId,
  }) async {
    final res = await _api.post('$_base/$id/inspections', data: {
      'inspection_type': inspectionType,
      'scheduled_for': scheduledFor.toIso8601String(),
      if (inspectorUserId != null) 'inspector_user_id': inspectorUserId,
    });
    return PermitInspection.fromJson(res as Map<String, dynamic>);
  }

  Future<PermitInspection> recordInspection(
    int id,
    int inspectionId, {
    required bool isCompliant,
    String? findings,
    double? lat,
    double? lng,
    double? accuracyM,
  }) async {
    final res = await _api.put('$_base/$id/inspections/$inspectionId', data: {
      'is_compliant': isCompliant,
      if (findings != null && findings.isNotEmpty) 'findings': findings,
      if (lat != null) 'location_lat': lat,
      if (lng != null) 'location_lng': lng,
      if (accuracyM != null) 'gps_accuracy_m': accuracyM,
    });
    return PermitInspection.fromJson(res as Map<String, dynamic>);
  }

  // ── Fees ────────────────────────────────────────────────────────────────

  Future<BuildingPermitSummary> recordPayment(
    int id, {
    required double amount,
    String? paymentRef,
  }) async {
    final res = await _api.post('$_base/$id/payments', data: {
      'amount': amount,
      if (paymentRef != null && paymentRef.isNotEmpty) 'payment_ref': paymentRef,
    });
    return BuildingPermitSummary.fromJson(res as Map<String, dynamic>);
  }

  // ── Documents ───────────────────────────────────────────────────────────

  /// Upload a blueprint, NOC letter or site photo against the permit.
  Future<PermitDocument> uploadDocument(
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
    return PermitDocument.fromJson(res as Map<String, dynamic>);
  }
}
