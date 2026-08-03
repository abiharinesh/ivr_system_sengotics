import 'package:ivr_frontend/core/api/api_client.dart';
import 'models/solid_waste_models.dart';

/// Thin wrapper over `/api/solid-waste`.
class SolidWasteRepository {
  final ApiClient _api;

  SolidWasteRepository({ApiClient? api}) : _api = api ?? ApiClient.instance;

  static const String _base = '/api/solid-waste';

  String _day(DateTime d) => d.toIso8601String().split('T').first;

  // ── Dashboard ───────────────────────────────────────────────────────────

  Future<SolidWasteSummary> fetchSummary({bool forceRefresh = false}) async {
    final res = await _api.get('$_base/summary', forceRefresh: forceRefresh);
    if (res == null) return SolidWasteSummary.empty;
    return SolidWasteSummary.fromJson(res as Map<String, dynamic>);
  }

  // ── Bins ────────────────────────────────────────────────────────────────

  Map<String, dynamic> _binParams({
    BinFillLevel? fillLevel,
    BinStatus? status,
    int? zoneId,
    String? wardNumber,
    bool? needsClearance,
    String? query,
  }) {
    return <String, dynamic>{
      if (fillLevel != null) 'fill_level': fillLevel.wire,
      if (status != null) 'status': status.wire,
      if (zoneId != null) 'zone_id': zoneId.toString(),
      if (wardNumber != null && wardNumber.isNotEmpty) 'ward_number': wardNumber,
      if (needsClearance == true) 'needs_clearance': 'true',
      if (query != null && query.isNotEmpty) 'q': query,
    };
  }

  BinPage? getCachedBins({
    BinFillLevel? fillLevel,
    BinStatus? status,
    bool? needsClearance,
    String? query,
  }) {
    final params = _binParams(
      fillLevel: fillLevel,
      status: status,
      needsClearance: needsClearance,
      query: query,
    );
    final cached =
        _api.getCached('$_base/bins', queryParams: params.isEmpty ? null : params);
    if (cached == null) return null;
    return BinPage.fromJson(cached as Map<String, dynamic>);
  }

  Future<BinPage> listBins({
    BinFillLevel? fillLevel,
    BinStatus? status,
    int? zoneId,
    String? wardNumber,
    bool? needsClearance,
    String? query,
    bool forceRefresh = false,
  }) async {
    final params = _binParams(
      fillLevel: fillLevel,
      status: status,
      zoneId: zoneId,
      wardNumber: wardNumber,
      needsClearance: needsClearance,
      query: query,
    );
    final res = await _api.get(
      '$_base/bins',
      queryParams: params.isEmpty ? null : params,
      forceRefresh: forceRefresh,
    );
    if (res == null) return BinPage.empty;
    return BinPage.fromJson(res as Map<String, dynamic>);
  }

  Future<WasteBinDetail> getBin(int id, {bool forceRefresh = false}) async {
    final res = await _api.get('$_base/bins/$id', forceRefresh: forceRefresh);
    return WasteBinDetail.fromJson(res as Map<String, dynamic>);
  }

  Future<WasteBin> createBin({
    required String binType,
    required int capacityLitres,
    required double latitude,
    required double longitude,
    int? zoneId,
    String? wardNumber,
    String? landmark,
  }) async {
    final res = await _api.post('$_base/bins', data: {
      'bin_type': binType,
      'capacity_litres': capacityLitres,
      'latitude': latitude,
      'longitude': longitude,
      if (zoneId != null) 'zone_id': zoneId,
      if (wardNumber != null && wardNumber.isNotEmpty) 'ward_number': wardNumber,
      if (landmark != null && landmark.isNotEmpty) 'landmark': landmark,
    });
    return WasteBin.fromJson(res as Map<String, dynamic>);
  }

  Future<WasteBin> updateBin(int id, Map<String, dynamic> patch) async {
    final res = await _api.put('$_base/bins/$id', data: patch);
    return WasteBin.fromJson(res as Map<String, dynamic>);
  }

  /// Record a fill-level observation. The band is derived server-side from the
  /// percentage, so this deliberately does not send one.
  Future<BinReading> recordReading(
    int binId, {
    required int fillPct,
    bool emptied = false,
    String? remarks,
    double? latitude,
    double? longitude,
  }) async {
    final res = await _api.post('$_base/bins/$binId/readings', data: {
      'fill_pct': fillPct,
      'emptied': emptied,
      if (remarks != null && remarks.isNotEmpty) 'remarks': remarks,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
    });
    return BinReading.fromJson(res as Map<String, dynamic>);
  }

  // ── Routes ──────────────────────────────────────────────────────────────

  Future<List<CollectionRoute>> listRoutes({bool forceRefresh = false}) async {
    final res = await _api.get('$_base/routes', forceRefresh: forceRefresh);
    return ((res ?? []) as List)
        .map((e) => CollectionRoute.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, dynamic>> getRoute(int id, {bool forceRefresh = false}) async {
    final res = await _api.get('$_base/routes/$id', forceRefresh: forceRefresh);
    return Map<String, dynamic>.from(res as Map);
  }

  Future<CollectionRoute> createRoute({
    required String name,
    int? zoneId,
    String? wardNumber,
    List<int>? serviceDays,
    String? shift,
    int? householdCount,
    double? distanceKm,
    List<Map<String, dynamic>>? stops,
  }) async {
    final res = await _api.post('$_base/routes', data: {
      'name': name,
      if (zoneId != null) 'zone_id': zoneId,
      if (wardNumber != null && wardNumber.isNotEmpty) 'ward_number': wardNumber,
      if (serviceDays != null) 'service_days': serviceDays,
      if (shift != null) 'shift': shift,
      if (householdCount != null) 'household_count': householdCount,
      if (distanceKm != null) 'distance_km': distanceKm,
      if (stops != null) 'stops': stops,
    });
    return CollectionRoute.fromJson(res as Map<String, dynamic>);
  }

  Future<CollectionRoute> updateRoute(int id, Map<String, dynamic> patch) async {
    final res = await _api.put('$_base/routes/$id', data: patch);
    return CollectionRoute.fromJson(res as Map<String, dynamic>);
  }

  // ── Trips ───────────────────────────────────────────────────────────────

  Future<TripPage> listTrips({
    int? routeId,
    TripStatus? status,
    DateTime? from,
    DateTime? to,
    bool forceRefresh = false,
  }) async {
    final params = <String, dynamic>{
      if (routeId != null) 'route_id': routeId.toString(),
      if (status != null) 'status': status.wire,
      if (from != null) 'from': _day(from),
      if (to != null) 'to': _day(to),
    };
    final res = await _api.get(
      '$_base/trips',
      queryParams: params.isEmpty ? null : params,
      forceRefresh: forceRefresh,
    );
    if (res == null) return TripPage.empty;
    return TripPage.fromJson(res as Map<String, dynamic>);
  }

  Future<CollectionTripDetail> getTrip(int id, {bool forceRefresh = false}) async {
    final res = await _api.get('$_base/trips/$id', forceRefresh: forceRefresh);
    return CollectionTripDetail.fromJson(res as Map<String, dynamic>);
  }

  Future<CollectionTrip> startTrip({
    required int routeId,
    DateTime? tripDate,
    String? shift,
    String? vehicleNumber,
    int? crewSize,
    int? odometerStartKm,
  }) async {
    final res = await _api.post('$_base/trips', data: {
      'route_id': routeId,
      if (tripDate != null) 'trip_date': _day(tripDate),
      if (shift != null) 'shift': shift,
      if (vehicleNumber != null && vehicleNumber.isNotEmpty)
        'vehicle_number': vehicleNumber,
      if (crewSize != null) 'crew_size': crewSize,
      if (odometerStartKm != null) 'odometer_start_km': odometerStartKm,
    });
    return CollectionTrip.fromJson(res as Map<String, dynamic>);
  }

  Future<CollectionTrip> completeStop(
    int tripId,
    int stopId, {
    bool skipped = false,
    String? skipReason,
    double? latitude,
    double? longitude,
    int? binFillPct,
  }) async {
    final res = await _api.put('$_base/trips/$tripId/stops/$stopId', data: {
      'skipped': skipped,
      if (skipReason != null && skipReason.isNotEmpty) 'skip_reason': skipReason,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (binFillPct != null) 'bin_fill_pct': binFillPct,
    });
    return CollectionTrip.fromJson(res as Map<String, dynamic>);
  }

  Future<CollectionTrip> closeTrip(
    int tripId, {
    double? wasteCollectedKg,
    double? segregatedWetKg,
    double? segregatedDryKg,
    int? odometerEndKm,
    String? remarks,
  }) async {
    final res = await _api.post('$_base/trips/$tripId/close', data: {
      if (wasteCollectedKg != null) 'waste_collected_kg': wasteCollectedKg,
      if (segregatedWetKg != null) 'segregated_wet_kg': segregatedWetKg,
      if (segregatedDryKg != null) 'segregated_dry_kg': segregatedDryKg,
      if (odometerEndKm != null) 'odometer_end_km': odometerEndKm,
      if (remarks != null && remarks.isNotEmpty) 'remarks': remarks,
    });
    return CollectionTrip.fromJson(res as Map<String, dynamic>);
  }

  Future<CollectionTrip> abandonTrip(int tripId, String reason) async {
    final res =
        await _api.post('$_base/trips/$tripId/abandon', data: {'reason': reason});
    return CollectionTrip.fromJson(res as Map<String, dynamic>);
  }

  // ── Attendance ──────────────────────────────────────────────────────────

  Future<AttendanceSheet> listAttendance({
    DateTime? date,
    String? shift,
    int? routeId,
    bool forceRefresh = false,
  }) async {
    final params = <String, dynamic>{
      if (date != null) 'date': _day(date),
      if (shift != null) 'shift': shift,
      if (routeId != null) 'route_id': routeId.toString(),
    };
    final res = await _api.get(
      '$_base/attendance',
      queryParams: params.isEmpty ? null : params,
      forceRefresh: forceRefresh,
    );
    if (res == null) return AttendanceSheet.empty;
    return AttendanceSheet.fromJson(res as Map<String, dynamic>);
  }

  Future<AttendanceRecord> markAttendance({
    required String workerName,
    required AttendanceStatus status,
    String? workerPhone,
    bool isContract = false,
    DateTime? date,
    String? shift,
    int? routeId,
    String? remarks,
  }) async {
    final res = await _api.post('$_base/attendance', data: {
      'worker_name': workerName,
      'status': status.wire,
      if (workerPhone != null && workerPhone.isNotEmpty)
        'worker_phone': workerPhone,
      'is_contract': isContract,
      if (date != null) 'attendance_date': _day(date),
      if (shift != null) 'shift': shift,
      if (routeId != null) 'route_id': routeId,
      if (remarks != null && remarks.isNotEmpty) 'remarks': remarks,
    });
    return AttendanceRecord.fromJson(res as Map<String, dynamic>);
  }

  Future<AttendanceRecord> checkOut(int id) async {
    final res = await _api.post('$_base/attendance/$id/check-out');
    return AttendanceRecord.fromJson(res as Map<String, dynamic>);
  }
}
