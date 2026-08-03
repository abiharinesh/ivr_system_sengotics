import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:ivr_frontend/core/api/api_client.dart';
import 'models/trade_licence_models.dart';

/// Thin wrapper over `/api/trade-licences`, plus the unauthenticated
/// verification endpoint behind the QR printed on the displayed licence.
class TradeLicenceRepository {
  final ApiClient _api;

  TradeLicenceRepository({ApiClient? api}) : _api = api ?? ApiClient.instance;

  static const String _base = '/api/trade-licences';
  static const String publicVerifyBase = '/public/trade-licences';

  Map<String, dynamic> _listParams({
    LicenceStatus? status,
    String? category,
    String? ward,
    String? query,
    int? expiringWithinDays,
    bool? overdueOnly,
    int? take,
    int? skip,
  }) {
    return <String, dynamic>{
      if (status != null) 'status': status.wire,
      if (category != null) 'trade_category': category,
      if (ward != null && ward.isNotEmpty) 'ward_number': ward,
      if (query != null && query.isNotEmpty) 'q': query,
      if (expiringWithinDays != null)
        'expiring_within_days': expiringWithinDays.toString(),
      if (overdueOnly == true) 'overdue_only': 'true',
      if (take != null) 'take': take.toString(),
      if (skip != null) 'skip': skip.toString(),
    };
  }

  TradeLicencePage? getCachedLicences({
    LicenceStatus? status,
    String? category,
    String? query,
    int? expiringWithinDays,
    bool? overdueOnly,
  }) {
    final params = _listParams(
      status: status,
      category: category,
      query: query,
      expiringWithinDays: expiringWithinDays,
      overdueOnly: overdueOnly,
    );
    final cached =
        _api.getCached(_base, queryParams: params.isEmpty ? null : params);
    if (cached == null) return null;
    return TradeLicencePage.fromJson(cached as Map<String, dynamic>);
  }

  Future<TradeLicencePage> listLicences({
    LicenceStatus? status,
    String? category,
    String? ward,
    String? query,
    int? expiringWithinDays,
    bool? overdueOnly,
    int? take,
    int? skip,
    bool forceRefresh = false,
  }) async {
    final params = _listParams(
      status: status,
      category: category,
      ward: ward,
      query: query,
      expiringWithinDays: expiringWithinDays,
      overdueOnly: overdueOnly,
      take: take,
      skip: skip,
    );
    final res = await _api.get(
      _base,
      queryParams: params.isEmpty ? null : params,
      forceRefresh: forceRefresh,
    );
    if (res == null) return TradeLicencePage.empty;
    return TradeLicencePage.fromJson(res as Map<String, dynamic>);
  }

  Future<TradeLicenceStats> fetchStats({bool forceRefresh = false}) async {
    final res = await _api.get('$_base/summary', forceRefresh: forceRefresh);
    if (res == null) return TradeLicenceStats.empty;
    return TradeLicenceStats.fromJson(res as Map<String, dynamic>);
  }

  Future<TradeLicenceDetail> getLicence(
    int id, {
    bool forceRefresh = false,
  }) async {
    final res = await _api.get('$_base/$id', forceRefresh: forceRefresh);
    return TradeLicenceDetail.fromJson(res as Map<String, dynamic>);
  }

  // ── Application ─────────────────────────────────────────────────────────

  Future<TradeLicenceSummary> createLicence(Map<String, dynamic> payload) async {
    final res = await _api.post(_base, data: payload);
    return TradeLicenceSummary.fromJson(res as Map<String, dynamic>);
  }

  Future<TradeLicenceSummary> updateLicence(
    int id,
    Map<String, dynamic> patch,
  ) async {
    final res = await _api.put('$_base/$id', data: patch);
    return TradeLicenceSummary.fromJson(res as Map<String, dynamic>);
  }

  Future<TradeLicenceSummary> submit(int id) async {
    final res = await _api.post('$_base/$id/submit');
    return TradeLicenceSummary.fromJson(res as Map<String, dynamic>);
  }

  // ── Inspections ─────────────────────────────────────────────────────────

  Future<LicenceInspection> scheduleInspection(
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
    return LicenceInspection.fromJson(res as Map<String, dynamic>);
  }

  Future<LicenceInspection> recordInspection(
    int id,
    int inspectionId, {
    required bool isCompliant,
    String? findings,
    List<String>? violations,
  }) async {
    final res = await _api.put('$_base/$id/inspections/$inspectionId', data: {
      'is_compliant': isCompliant,
      if (findings != null && findings.isNotEmpty) 'findings': findings,
      if (violations != null && violations.isNotEmpty) 'violations': violations,
    });
    return LicenceInspection.fromJson(res as Map<String, dynamic>);
  }

  // ── Fees ────────────────────────────────────────────────────────────────

  Future<TradeLicenceSummary> recordPayment(
    int id, {
    required double amount,
    String? paymentRef,
  }) async {
    final res = await _api.post('$_base/$id/payments', data: {
      'amount': amount,
      if (paymentRef != null && paymentRef.isNotEmpty) 'payment_ref': paymentRef,
    });
    return TradeLicenceSummary.fromJson(res as Map<String, dynamic>);
  }

  // ── Decisions ───────────────────────────────────────────────────────────

  Future<TradeLicenceSummary> approve(int id, {String? remarks}) async {
    final res = await _api.post('$_base/$id/approve', data: {
      if (remarks != null && remarks.isNotEmpty) 'remarks': remarks,
    });
    return TradeLicenceSummary.fromJson(res as Map<String, dynamic>);
  }

  Future<TradeLicenceSummary> reject(int id, String reason) async {
    final res = await _api.post('$_base/$id/reject', data: {'reason': reason});
    return TradeLicenceSummary.fromJson(res as Map<String, dynamic>);
  }

  /// Roll into the next licence year. The year, dates and penalty are all
  /// derived server-side from the current validity.
  Future<TradeLicenceDetail> renew(int id, {String? remarks}) async {
    final res = await _api.post('$_base/$id/renew', data: {
      if (remarks != null && remarks.isNotEmpty) 'remarks': remarks,
    });
    return TradeLicenceDetail.fromJson(res as Map<String, dynamic>);
  }

  Future<TradeLicenceSummary> suspend(int id, String reason) async {
    final res = await _api.post('$_base/$id/suspend', data: {'reason': reason});
    return TradeLicenceSummary.fromJson(res as Map<String, dynamic>);
  }

  Future<TradeLicenceSummary> restore(int id) async {
    final res = await _api.post('$_base/$id/restore');
    return TradeLicenceSummary.fromJson(res as Map<String, dynamic>);
  }

  Future<TradeLicenceSummary> cancel(int id, String reason) async {
    final res = await _api.post('$_base/$id/cancel', data: {'reason': reason});
    return TradeLicenceSummary.fromJson(res as Map<String, dynamic>);
  }

  // ── Certificates ────────────────────────────────────────────────────────

  Future<LicenceCertificate> issueCertificate(int id) async {
    final res = await _api.post('$_base/$id/certificates', data: {});
    return LicenceCertificate.fromJson(res as Map<String, dynamic>);
  }

  Future<LicenceVerification> verifyByToken(String token) async {
    final res = await _api.get('$publicVerifyBase/$token', forceRefresh: true);
    return LicenceVerification.fromJson(res as Map<String, dynamic>);
  }

  // ── Documents ───────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> uploadDocument(
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
    return Map<String, dynamic>.from(res as Map);
  }
}
