import 'package:ivr_frontend/core/api/api_client.dart';
import 'models/zone_model.dart';

/// Repository for zone management API operations.
class ZoneRepository {
  final ApiClient _api;
  final bool isSuperAdmin;

  ZoneRepository({ApiClient? api, this.isSuperAdmin = false})
      : _api = api ?? ApiClient.instance;

  String get _basePath => isSuperAdmin ? '/api/superadmin/zones' : '/api/admin/zones';

  /// Synchronously retrieve cached zones if available
  List<ZoneModel>? getCachedZones({int? panchayatId}) {
    final path = isSuperAdmin && panchayatId != null
        ? '$_basePath/$panchayatId'
        : _basePath;
    final cached = _api.getCached(path);
    if (cached == null) return null;
    return (cached as List)
        .map((json) => ZoneModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// List all zones for the current user's scope.
  Future<List<ZoneModel>> listZones({int? panchayatId, bool forceRefresh = false}) async {
    final path = isSuperAdmin && panchayatId != null
        ? '$_basePath/$panchayatId'
        : _basePath;
    final resp = await _api.get(path, forceRefresh: forceRefresh);
    return (resp as List)
        .map((json) => ZoneModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Create a new zone.
  Future<ZoneModel> createZone({
    required String name,
    required Map<String, dynamic> boundaryGeojson,
    String? color,
    double? opacity,
    List<String>? places,
    int? panchayatId,
  }) async {
    final path = isSuperAdmin && panchayatId != null
        ? '$_basePath/$panchayatId'
        : _basePath;
    final resp = await _api.post(path, data: {
      'name': name,
      'boundary_geojson': boundaryGeojson,
      if (color != null) 'color': color,
      if (opacity != null) 'opacity': opacity,
      if (places != null) 'places': places,
    });
    return ZoneModel.fromJson(resp as Map<String, dynamic>);
  }

  /// Update an existing zone.
  Future<ZoneModel> updateZone({
    required int zoneId,
    String? name,
    Map<String, dynamic>? boundaryGeojson,
    String? color,
    double? opacity,
    List<String>? places,
    bool? isActive,
    int? panchayatId,
  }) async {
    final path = isSuperAdmin && panchayatId != null
        ? '$_basePath/$panchayatId/$zoneId'
        : '$_basePath/$zoneId';
    final resp = await _api.put(path, data: {
      if (name != null) 'name': name,
      if (boundaryGeojson != null) 'boundary_geojson': boundaryGeojson,
      if (color != null) 'color': color,
      if (opacity != null) 'opacity': opacity,
      if (places != null) 'places': places,
      if (isActive != null) 'is_active': isActive,
    });
    return ZoneModel.fromJson(resp as Map<String, dynamic>);
  }

  /// Delete a zone.
  Future<void> deleteZone(int zoneId, {int? panchayatId}) async {
    final path = isSuperAdmin && panchayatId != null
        ? '$_basePath/$panchayatId/$zoneId'
        : '$_basePath/$zoneId';
    await _api.delete(path);
  }

  /// Look up a place boundary from OSM Nominatim via backend proxy.
  Future<List<PlaceBoundaryResult>> lookupPlaceBoundary(
    String placeName, {
    String countryCode = 'in',
  }) async {
    final path = isSuperAdmin
        ? '/api/superadmin/zones/lookup-boundary'
        : '/api/admin/zones/lookup-boundary';
    final resp = await _api.post(path, data: {
      'place_name': placeName,
      'country_code': countryCode,
    });
    return (resp as List)
        .map((json) => PlaceBoundaryResult.fromJson(json as Map<String, dynamic>))
        .toList();
  }
}
