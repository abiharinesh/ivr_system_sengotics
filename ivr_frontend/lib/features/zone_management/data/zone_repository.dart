import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../config/api_config.dart';
import '../../../models/zone_model.dart';

/// Repository for zone management API operations.
class ZoneRepository {
  final Dio _dio;
  final bool isSuperAdmin;
  static const _storage = FlutterSecureStorage();

  ZoneRepository({this.isSuperAdmin = false})
      : _dio = Dio(BaseOptions(baseUrl: ApiConfig.baseUrl)) {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: 'jwt_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
    ));
  }

  String get _basePath => isSuperAdmin ? '/api/superadmin/zones' : '/api/admin/zones';

  /// List all zones for the current user's scope.
  Future<List<ZoneModel>> listZones({int? panchayatId}) async {
    final path = isSuperAdmin && panchayatId != null
        ? '$_basePath/$panchayatId'
        : _basePath;
    final resp = await _dio.get(path);
    return (resp.data as List)
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
    final resp = await _dio.post(path, data: {
      'name': name,
      'boundary_geojson': boundaryGeojson,
      if (color != null) 'color': color,
      if (opacity != null) 'opacity': opacity,
      if (places != null) 'places': places,
    });
    return ZoneModel.fromJson(resp.data as Map<String, dynamic>);
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
    final resp = await _dio.put(path, data: {
      if (name != null) 'name': name,
      if (boundaryGeojson != null) 'boundary_geojson': boundaryGeojson,
      if (color != null) 'color': color,
      if (opacity != null) 'opacity': opacity,
      if (places != null) 'places': places,
      if (isActive != null) 'is_active': isActive,
    });
    return ZoneModel.fromJson(resp.data as Map<String, dynamic>);
  }

  /// Delete a zone.
  Future<void> deleteZone(int zoneId, {int? panchayatId}) async {
    final path = isSuperAdmin && panchayatId != null
        ? '$_basePath/$panchayatId/$zoneId'
        : '$_basePath/$zoneId';
    await _dio.delete(path);
  }

  /// Look up a place boundary from OSM Nominatim via backend proxy.
  Future<List<PlaceBoundaryResult>> lookupPlaceBoundary(
    String placeName, {
    String countryCode = 'in',
  }) async {
    final path = isSuperAdmin
        ? '/api/superadmin/zones/lookup-boundary'
        : '/api/admin/zones/lookup-boundary';
    final resp = await _dio.post(path, data: {
      'place_name': placeName,
      'country_code': countryCode,
    });
    return (resp.data as List)
        .map((json) => PlaceBoundaryResult.fromJson(json as Map<String, dynamic>))
        .toList();
  }
}
