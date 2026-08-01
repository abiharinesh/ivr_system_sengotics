import 'package:equatable/equatable.dart';

/// Represents a zone/boundary area within a panchayat.
class ZoneModel extends Equatable {
  final int id;
  final int panchayatId;
  final String name;
  final Map<String, dynamic> boundaryGeojson;
  final String? color;
  final double opacity;
  final List<String> places;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  /// Only populated when fetched from the super admin endpoint.
  final String? panchayatName;

  const ZoneModel({
    required this.id,
    required this.panchayatId,
    required this.name,
    required this.boundaryGeojson,
    this.color,
    this.opacity = 0.3,
    this.places = const [],
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
    this.panchayatName,
  });

  factory ZoneModel.fromJson(Map<String, dynamic> json) {
    final panchayat = json['panchayat'] as Map<String, dynamic>?;
    return ZoneModel(
      id: json['id'] as int,
      panchayatId: json['panchayat_id'] as int,
      name: json['name'] as String,
      boundaryGeojson: json['boundary_geojson'] as Map<String, dynamic>? ?? {},
      color: json['color'] as String?,
      opacity: (json['opacity'] as num?)?.toDouble() ?? 0.3,
      places: (json['places'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
      panchayatName: panchayat?['name'] as String?,
    );
  }

  Map<String, dynamic> toCreateJson() => {
        'name': name,
        'boundary_geojson': boundaryGeojson,
        'color': color,
        'opacity': opacity,
        'places': places,
      };

  @override
  List<Object?> get props => [id, panchayatId, name, isActive];
}

/// A boundary search result from the OSM Nominatim API.
class PlaceBoundaryResult {
  final int placeId;
  final String displayName;
  final String type;
  final Map<String, dynamic>? geojson;
  final double lat;
  final double lng;

  const PlaceBoundaryResult({
    required this.placeId,
    required this.displayName,
    required this.type,
    this.geojson,
    required this.lat,
    required this.lng,
  });

  factory PlaceBoundaryResult.fromJson(Map<String, dynamic> json) {
    return PlaceBoundaryResult(
      placeId: json['place_id'] as int? ?? 0,
      displayName: json['display_name'] as String? ?? '',
      type: json['type'] as String? ?? '',
      geojson: json['geojson'] as Map<String, dynamic>?,
      lat: double.tryParse(json['lat']?.toString() ?? '') ?? 0,
      lng: double.tryParse(json['lon']?.toString() ?? '') ?? 0,
    );
  }

  bool get hasBoundary =>
      geojson != null &&
      (geojson!['type'] == 'Polygon' || geojson!['type'] == 'MultiPolygon');
}
