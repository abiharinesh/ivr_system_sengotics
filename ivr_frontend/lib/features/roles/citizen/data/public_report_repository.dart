import 'package:ivr_frontend/core/api/api_client.dart';
import 'package:ivr_frontend/config/api_config.dart';

/// Repository for public (no-auth) endpoints: QR scan, guest complaints,
/// GPS lookup, IVR sync, and complaint tracking.
class PublicReportRepository {
  final ApiClient _api = ApiClient.instance;

  /// Fetch pole info by its public QR token.
  Future<Map<String, dynamic>> getPoleByToken(String token) async {
    final data = await _api.get(ApiConfig.publicPoleByToken(token));
    return Map<String, dynamic>.from(data as Map);
  }

  /// Submit a guest complaint for a pole (no login).
  Future<Map<String, dynamic>> submitGuestComplaint({
    required String token,
    required String complaintType,
    required String description,
    required String urgencyLevel,
    String? guestPhone,
  }) async {
    final data = await _api.post(
      ApiConfig.publicGuestComplaint(token),
      data: {
        'complaint_type': complaintType,
        'description': description,
        'urgency_level': urgencyLevel,
        if (guestPhone != null && guestPhone.isNotEmpty)
          'guest_phone': guestPhone,
      },
    );
    return Map<String, dynamic>.from(data as Map);
  }

  /// Track a complaint status by its guest tracking token.
  Future<Map<String, dynamic>> trackComplaint(String trackingToken) async {
    final data = await _api.get(ApiConfig.publicTrackComplaint(trackingToken));
    return Map<String, dynamic>.from(data as Map);
  }

  /// GPS panchayat auto-detection.
  Future<Map<String, dynamic>?> lookupPanchayatByCoords(
      double lat, double lng) async {
    try {
      final data = await _api.post(
        ApiConfig.publicPanchayatLookup,
        data: {'lat': lat, 'lng': lng},
      );
      if (data == null) return null;
      return Map<String, dynamic>.from(data as Map);
    } catch (_) {
      return null;
    }
  }

  /// Fetch IVR call history linked to citizen's phone (authenticated).
  Future<Map<String, dynamic>> getIvrHistory() async {
    final data = await _api.get(ApiConfig.publicIvrSync);
    return Map<String, dynamic>.from(data as Map);
  }
}
