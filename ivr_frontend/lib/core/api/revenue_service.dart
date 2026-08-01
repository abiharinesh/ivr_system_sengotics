import 'package:ivr_frontend/core/api/api_client.dart';

class RevenueService {
  final ApiClient _api = ApiClient.instance;

  // ─── Ad Campaigns ──────────────────────────────────────────────────────────

  Future<List<dynamic>> getCampaigns(int panchayatId) async {
    final response = await _api.get('/ad-campaigns', queryParams: {'panchayat_id': panchayatId}, forceRefresh: true);
    return response as List<dynamic>;
  }

  Future<dynamic> getCampaignAnalytics(int campaignId) async {
    return _api.get('/ad-campaigns/$campaignId/analytics', forceRefresh: true);
  }

  Future<dynamic> createCampaign(Map<String, dynamic> data) async {
    return _api.post('/ad-campaigns', data: data);
  }

  Future<dynamic> updateCampaign(int id, Map<String, dynamic> data) async {
    return _api.put('/ad-campaigns/$id', data: data);
  }

  Future<dynamic> deleteCampaign(int id) async {
    return _api.delete('/ad-campaigns/$id');
  }

  // ─── Penalties & SLA Rules ──────────────────────────────────────────────────

  Future<List<dynamic>> getRules(int panchayatId) async {
    final response = await _api.get('/penalties/rules', queryParams: {'panchayat_id': panchayatId}, forceRefresh: true);
    return response as List<dynamic>;
  }

  Future<dynamic> upsertRule(Map<String, dynamic> data) async {
    return _api.post('/penalties/rules', data: data);
  }

  Future<List<dynamic>> getPenalties(int panchayatId) async {
    final response = await _api.get('/penalties', queryParams: {'panchayat_id': panchayatId}, forceRefresh: true);
    return response as List<dynamic>;
  }

  Future<dynamic> getPenaltySummary(int panchayatId) async {
    return _api.get('/penalties/summary', queryParams: {'panchayat_id': panchayatId}, forceRefresh: true);
  }

  Future<dynamic> waivePenalty(int id, String reason) async {
    return _api.put('/penalties/$id/waive', data: {'reason': reason});
  }

  Future<dynamic> deductPenalty(int id) async {
    return _api.put('/penalties/$id/deduct');
  }

  // ─── Property Tax ──────────────────────────────────────────────────────────

  Future<List<dynamic>> getProperties(int panchayatId) async {
    final response = await _api.get('/property-tax/properties', queryParams: {'panchayat_id': panchayatId}, forceRefresh: true);
    return response as List<dynamic>;
  }

  Future<dynamic> createProperty(Map<String, dynamic> data) async {
    return _api.post('/property-tax/properties', data: data);
  }

  Future<dynamic> generateTaxDemands(Map<String, dynamic> data) async {
    return _api.post('/property-tax/generate-demands', data: data);
  }

  Future<dynamic> recordTaxPayment(int paymentId, Map<String, dynamic> data) async {
    return _api.post('/property-tax/payments/$paymentId/pay', data: data);
  }

  Future<List<dynamic>> getTaxDefaulters(int panchayatId, {String? financialYear}) async {
    final params = <String, dynamic>{'panchayat_id': panchayatId};
    if (financialYear != null) params['financial_year'] = financialYear;
    final response = await _api.get('/property-tax/defaulters', queryParams: params, forceRefresh: true);
    return response as List<dynamic>;
  }

  Future<dynamic> getTaxSummary(int panchayatId, {String? financialYear}) async {
    final params = <String, dynamic>{'panchayat_id': panchayatId};
    if (financialYear != null) params['financial_year'] = financialYear;
    return _api.get('/property-tax/revenue-summary', queryParams: params, forceRefresh: true);
  }

  // ─── Certificates ──────────────────────────────────────────────────────────

  Future<List<dynamic>> getCertificateRequests(int panchayatId, {String? type}) async {
    final params = <String, dynamic>{'panchayat_id': panchayatId};
    if (type != null) params['type'] = type;
    final response = await _api.get('/certificates', queryParams: params, forceRefresh: true);
    return response as List<dynamic>;
  }

  Future<dynamic> approveCertificate(int id, Map<String, dynamic> data) async {
    return _api.put('/certificates/$id/approve', data: data);
  }

  Future<dynamic> rejectCertificate(int id, String notes) async {
    return _api.put('/certificates/$id/reject', data: {'reviewer_notes': notes});
  }

  // ─── Asset Bookings ─────────────────────────────────────────────────────────

  Future<List<dynamic>> getAssets(int panchayatId) async {
    final response = await _api.get('/asset-bookings/assets', queryParams: {'panchayat_id': panchayatId}, forceRefresh: true);
    return response as List<dynamic>;
  }

  Future<dynamic> createAsset(Map<String, dynamic> data) async {
    return _api.post('/asset-bookings/assets', data: data);
  }

  Future<List<dynamic>> getBookings(int panchayatId) async {
    final response = await _api.get('/asset-bookings/list', queryParams: {'panchayat_id': panchayatId}, forceRefresh: true);
    return response as List<dynamic>;
  }

  Future<dynamic> createBooking(Map<String, dynamic> data) async {
    return _api.post('/asset-bookings/reserve', data: data);
  }

  Future<dynamic> confirmBooking(int bookingId, String paymentRef) async {
    return _api.post('/asset-bookings/$bookingId/confirm', data: {'payment_ref': paymentRef});
  }

  Future<dynamic> payBookingBalance(int bookingId) async {
    return _api.post('/asset-bookings/$bookingId/pay-balance');
  }

  Future<dynamic> cancelBooking(int bookingId, double fee) async {
    return _api.post('/asset-bookings/$bookingId/cancel', data: {'cancellation_fee': fee});
  }

  // ─── Markets & Stall Fees ──────────────────────────────────────────────────

  Future<List<dynamic>> getMarketDays(int panchayatId) async {
    final response = await _api.get('/markets/days', queryParams: {'panchayat_id': panchayatId}, forceRefresh: true);
    return response as List<dynamic>;
  }

  Future<dynamic> createMarketDay(Map<String, dynamic> data) async {
    return _api.post('/markets/days', data: data);
  }

  Future<List<dynamic>> getMarketVendors(int panchayatId) async {
    final response = await _api.get('/markets/vendors', queryParams: {'panchayat_id': panchayatId}, forceRefresh: true);
    return response as List<dynamic>;
  }

  Future<dynamic> createMarketVendor(Map<String, dynamic> data) async {
    return _api.post('/markets/vendors', data: data);
  }

  Future<dynamic> recordMarketFee(Map<String, dynamic> data) async {
    return _api.post('/markets/payments/pay', data: data);
  }

  Future<List<dynamic>> getMarketPayments(int panchayatId) async {
    final response = await _api.get('/markets/payments', queryParams: {'panchayat_id': panchayatId}, forceRefresh: true);
    return response as List<dynamic>;
  }
}
