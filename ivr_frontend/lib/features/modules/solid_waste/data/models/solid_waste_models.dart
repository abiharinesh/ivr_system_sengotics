import 'package:flutter/material.dart';
import 'package:ivr_frontend/config/app_theme.dart';

/// Data classes for solid waste management. Mirror the JSON served by
/// `src/solid-waste/`.

double? _toDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

DateTime? _toDate(dynamic v) {
  if (v == null) return null;
  return DateTime.tryParse(v.toString());
}

String titleCase(String raw) => raw
    .replaceAll('_', ' ')
    .split(' ')
    .where((p) => p.isNotEmpty)
    .map((p) => '${p[0].toUpperCase()}${p.substring(1)}')
    .join(' ');

/// Fill bands. The colour mapping lives here so the map legend, the list rows
/// and the detail sheet cannot drift apart — the backend sends `pin_colour`
/// too, and the two agree by construction.
enum BinFillLevel {
  empty,
  low,
  medium,
  high,
  overflowing;

  static BinFillLevel parse(String? raw) {
    switch ((raw ?? '').toUpperCase()) {
      case 'LOW':
        return BinFillLevel.low;
      case 'MEDIUM':
        return BinFillLevel.medium;
      case 'HIGH':
        return BinFillLevel.high;
      case 'OVERFLOWING':
        return BinFillLevel.overflowing;
      default:
        return BinFillLevel.empty;
    }
  }

  String get wire => name.toUpperCase();

  String get label {
    switch (this) {
      case BinFillLevel.empty:
        return 'Empty';
      case BinFillLevel.low:
        return 'Low';
      case BinFillLevel.medium:
        return 'Half full';
      case BinFillLevel.high:
        return 'Nearly full';
      case BinFillLevel.overflowing:
        return 'Overflowing';
    }
  }

  Color get color {
    switch (this) {
      case BinFillLevel.empty:
      case BinFillLevel.low:
        return AppTheme.accent;
      case BinFillLevel.medium:
        return AppTheme.warning;
      case BinFillLevel.high:
      case BinFillLevel.overflowing:
        return AppTheme.error;
    }
  }

  /// Google Maps marker hue for this band.
  double get markerHue {
    switch (this) {
      case BinFillLevel.empty:
      case BinFillLevel.low:
        return 120; // green
      case BinFillLevel.medium:
        return 60; // yellow
      case BinFillLevel.high:
      case BinFillLevel.overflowing:
        return 0; // red
    }
  }

  bool get needsClearance =>
      this == BinFillLevel.high || this == BinFillLevel.overflowing;
}

enum BinStatus {
  active,
  damaged,
  removed,
  relocated;

  static BinStatus parse(String? raw) {
    switch ((raw ?? '').toUpperCase()) {
      case 'DAMAGED':
        return BinStatus.damaged;
      case 'REMOVED':
        return BinStatus.removed;
      case 'RELOCATED':
        return BinStatus.relocated;
      default:
        return BinStatus.active;
    }
  }

  String get wire => name.toUpperCase();
  String get label => titleCase(name);
}

enum TripStatus {
  planned,
  inProgress,
  completed,
  abandoned;

  static TripStatus parse(String? raw) {
    switch ((raw ?? '').toUpperCase()) {
      case 'IN_PROGRESS':
        return TripStatus.inProgress;
      case 'COMPLETED':
        return TripStatus.completed;
      case 'ABANDONED':
        return TripStatus.abandoned;
      default:
        return TripStatus.planned;
    }
  }

  String get wire =>
      this == TripStatus.inProgress ? 'IN_PROGRESS' : name.toUpperCase();

  String get label {
    switch (this) {
      case TripStatus.planned:
        return 'Planned';
      case TripStatus.inProgress:
        return 'Running';
      case TripStatus.completed:
        return 'Completed';
      case TripStatus.abandoned:
        return 'Abandoned';
    }
  }

  Color get color {
    switch (this) {
      case TripStatus.completed:
        return AppTheme.accent;
      case TripStatus.inProgress:
        return AppTheme.primary;
      case TripStatus.abandoned:
        return AppTheme.error;
      case TripStatus.planned:
        return AppTheme.textMuted;
    }
  }
}

enum AttendanceStatus {
  present,
  absent,
  leave,
  halfDay;

  static AttendanceStatus parse(String? raw) {
    switch ((raw ?? '').toUpperCase()) {
      case 'ABSENT':
        return AttendanceStatus.absent;
      case 'LEAVE':
        return AttendanceStatus.leave;
      case 'HALF_DAY':
        return AttendanceStatus.halfDay;
      default:
        return AttendanceStatus.present;
    }
  }

  String get wire =>
      this == AttendanceStatus.halfDay ? 'HALF_DAY' : name.toUpperCase();

  String get label {
    switch (this) {
      case AttendanceStatus.present:
        return 'Present';
      case AttendanceStatus.absent:
        return 'Absent';
      case AttendanceStatus.leave:
        return 'On leave';
      case AttendanceStatus.halfDay:
        return 'Half day';
    }
  }

  Color get color {
    switch (this) {
      case AttendanceStatus.present:
        return AppTheme.accent;
      case AttendanceStatus.halfDay:
        return AppTheme.warning;
      case AttendanceStatus.absent:
        return AppTheme.error;
      case AttendanceStatus.leave:
        return AppTheme.textMuted;
    }
  }
}

/// Progress of a collection round.
class RouteProgress {
  final int completed;
  final int total;
  final int percent;
  final String band;

  const RouteProgress({
    required this.completed,
    required this.total,
    required this.percent,
    required this.band,
  });

  factory RouteProgress.fromJson(Map<String, dynamic> j) => RouteProgress(
    completed: (j['completed'] ?? 0) as int,
    total: (j['total'] ?? 0) as int,
    percent: (j['percent'] ?? 0) as int,
    band: (j['band'] ?? 'not_started') as String,
  );

  static const empty =
      RouteProgress(completed: 0, total: 0, percent: 0, band: 'not_started');

  double get fraction => total == 0 ? 0 : completed / total;

  Color get color {
    switch (band) {
      case 'complete':
        return AppTheme.accent;
      case 'on_track':
        return AppTheme.primary;
      case 'behind':
        return AppTheme.warning;
      default:
        return AppTheme.textMuted;
    }
  }

  String get label {
    switch (band) {
      case 'complete':
        return 'Complete';
      case 'on_track':
        return 'On track';
      case 'behind':
        return 'Behind';
      default:
        return 'Not started';
    }
  }
}

/// Weighbridge vs segregation-log reconciliation for a round.
class WeightCheck {
  final double total;
  final double segregated;
  final double unaccounted;
  final bool reconciles;

  const WeightCheck({
    required this.total,
    required this.segregated,
    required this.unaccounted,
    required this.reconciles,
  });

  static WeightCheck? fromJson(Map<String, dynamic>? j) {
    if (j == null) return null;
    return WeightCheck(
      total: _toDouble(j['total']) ?? 0,
      segregated: _toDouble(j['segregated']) ?? 0,
      unaccounted: _toDouble(j['unaccounted']) ?? 0,
      reconciles: (j['reconciles'] ?? true) as bool,
    );
  }
}

class WasteBin {
  final int id;
  final String binCode;
  final String binType;
  final int capacityLitres;
  final BinFillLevel fillLevel;
  final int fillPct;
  final BinStatus status;
  final double latitude;
  final double longitude;
  final int? zoneId;
  final String? zoneName;
  final String? wardNumber;
  final String? landmark;
  final DateTime? lastEmptiedAt;
  final DateTime? lastReadAt;

  const WasteBin({
    required this.id,
    required this.binCode,
    required this.binType,
    required this.capacityLitres,
    required this.fillLevel,
    required this.fillPct,
    required this.status,
    required this.latitude,
    required this.longitude,
    this.zoneId,
    this.zoneName,
    this.wardNumber,
    this.landmark,
    this.lastEmptiedAt,
    this.lastReadAt,
  });

  factory WasteBin.fromJson(Map<String, dynamic> j) {
    final zone = j['zone'] is Map ? Map<String, dynamic>.from(j['zone'] as Map) : null;
    return WasteBin(
      id: j['id'] as int,
      binCode: (j['bin_code'] ?? '') as String,
      binType: (j['bin_type'] ?? '') as String,
      capacityLitres: (j['capacity_litres'] ?? 0) as int,
      fillLevel: BinFillLevel.parse(j['fill_level'] as String?),
      fillPct: (j['fill_pct'] ?? 0) as int,
      status: BinStatus.parse(j['status'] as String?),
      latitude: _toDouble(j['latitude']) ?? 0,
      longitude: _toDouble(j['longitude']) ?? 0,
      zoneId: j['zone_id'] as int?,
      zoneName: zone?['name'] as String?,
      wardNumber: j['ward_number'] as String?,
      landmark: j['landmark'] as String?,
      lastEmptiedAt: _toDate(j['last_emptied_at']),
      lastReadAt: _toDate(j['last_read_at']),
    );
  }

  String get placeLabel {
    final parts = [
      if (landmark != null && landmark!.isNotEmpty) landmark,
      if (wardNumber != null && wardNumber!.isNotEmpty) 'Ward $wardNumber',
      if (zoneName != null) zoneName,
    ];
    return parts.isEmpty ? binCode : parts.join(' · ');
  }
}

class BinReading {
  final int id;
  final BinFillLevel fillLevel;
  final int fillPct;
  final bool emptied;
  final String? remarks;
  final DateTime? recordedAt;

  const BinReading({
    required this.id,
    required this.fillLevel,
    required this.fillPct,
    required this.emptied,
    this.remarks,
    this.recordedAt,
  });

  factory BinReading.fromJson(Map<String, dynamic> j) => BinReading(
    id: j['id'] as int,
    fillLevel: BinFillLevel.parse(j['fill_level'] as String?),
    fillPct: (j['fill_pct'] ?? 0) as int,
    emptied: (j['emptied'] ?? false) as bool,
    remarks: j['remarks'] as String?,
    recordedAt: _toDate(j['recorded_at']),
  );
}

class WasteBinDetail {
  final WasteBin bin;
  final List<BinReading> readings;
  final Map<String, dynamic>? clearanceSla;

  const WasteBinDetail({
    required this.bin,
    required this.readings,
    this.clearanceSla,
  });

  factory WasteBinDetail.fromJson(Map<String, dynamic> j) => WasteBinDetail(
    bin: WasteBin.fromJson(j),
    readings: ((j['readings'] ?? []) as List)
        .map((e) => BinReading.fromJson(e as Map<String, dynamic>))
        .toList(),
    clearanceSla: j['clearance_sla'] is Map
        ? Map<String, dynamic>.from(j['clearance_sla'] as Map)
        : null,
  );
}

class CollectionRoute {
  final int id;
  final String routeCode;
  final String name;
  final int? zoneId;
  final String? zoneName;
  final String? wardNumber;
  final List<int> serviceDays;
  final String shift;
  final int? householdCount;
  final double? distanceKm;
  final bool isActive;
  final int stopsTotal;

  const CollectionRoute({
    required this.id,
    required this.routeCode,
    required this.name,
    this.zoneId,
    this.zoneName,
    this.wardNumber,
    required this.serviceDays,
    required this.shift,
    this.householdCount,
    this.distanceKm,
    required this.isActive,
    required this.stopsTotal,
  });

  factory CollectionRoute.fromJson(Map<String, dynamic> j) {
    final zone = j['zone'] is Map ? Map<String, dynamic>.from(j['zone'] as Map) : null;
    final countMap =
        j['_count'] is Map ? Map<String, dynamic>.from(j['_count'] as Map) : null;
    return CollectionRoute(
      id: j['id'] as int,
      routeCode: (j['route_code'] ?? '') as String,
      name: (j['name'] ?? '') as String,
      zoneId: j['zone_id'] as int?,
      zoneName: zone?['name'] as String?,
      wardNumber: j['ward_number'] as String?,
      serviceDays:
          ((j['service_days'] ?? []) as List).map((e) => e as int).toList(),
      shift: (j['shift'] ?? 'morning') as String,
      householdCount: j['household_count'] as int?,
      distanceKm: _toDouble(j['distance_km']),
      isActive: (j['is_active'] ?? true) as bool,
      stopsTotal: (j['stops_total'] ?? countMap?['stops'] ?? 0) as int,
    );
  }

  static const _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  String get serviceDaysLabel {
    if (serviceDays.length == 7) return 'Daily';
    return serviceDays
        .where((d) => d >= 1 && d <= 7)
        .map((d) => _dayNames[d - 1])
        .join(', ');
  }
}

class CollectionTrip {
  final int id;
  final String tripNumber;
  final int routeId;
  final String? routeName;
  final String? routeCode;
  final DateTime tripDate;
  final String shift;
  final TripStatus status;
  final String? vehicleNumber;
  final int? crewSize;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final double? wasteCollectedKg;
  final double? segregatedWetKg;
  final double? segregatedDryKg;
  final RouteProgress progress;
  final WeightCheck? weights;
  final String? abandonReason;

  const CollectionTrip({
    required this.id,
    required this.tripNumber,
    required this.routeId,
    this.routeName,
    this.routeCode,
    required this.tripDate,
    required this.shift,
    required this.status,
    this.vehicleNumber,
    this.crewSize,
    this.startedAt,
    this.endedAt,
    this.wasteCollectedKg,
    this.segregatedWetKg,
    this.segregatedDryKg,
    required this.progress,
    this.weights,
    this.abandonReason,
  });

  factory CollectionTrip.fromJson(Map<String, dynamic> j) {
    final route =
        j['route'] is Map ? Map<String, dynamic>.from(j['route'] as Map) : null;
    return CollectionTrip(
      id: j['id'] as int,
      tripNumber: (j['trip_number'] ?? '') as String,
      routeId: (j['route_id'] ?? 0) as int,
      routeName: route?['name'] as String?,
      routeCode: route?['route_code'] as String?,
      tripDate: _toDate(j['trip_date']) ?? DateTime.now(),
      shift: (j['shift'] ?? 'morning') as String,
      status: TripStatus.parse(j['status'] as String?),
      vehicleNumber: j['vehicle_number'] as String?,
      crewSize: j['crew_size'] as int?,
      startedAt: _toDate(j['started_at']),
      endedAt: _toDate(j['ended_at']),
      wasteCollectedKg: _toDouble(j['waste_collected_kg']),
      segregatedWetKg: _toDouble(j['segregated_wet_kg']),
      segregatedDryKg: _toDouble(j['segregated_dry_kg']),
      progress: j['progress'] is Map
          ? RouteProgress.fromJson(Map<String, dynamic>.from(j['progress'] as Map))
          : RouteProgress.empty,
      weights: WeightCheck.fromJson(
        j['weights'] is Map ? Map<String, dynamic>.from(j['weights'] as Map) : null,
      ),
      abandonReason: j['abandon_reason'] as String?,
    );
  }
}

class TripStop {
  final int id;
  final int seq;
  final String label;
  final bool completed;
  final bool skipped;
  final String? skipReason;
  final int? binId;
  final DateTime? completedAt;

  const TripStop({
    required this.id,
    required this.seq,
    required this.label,
    required this.completed,
    required this.skipped,
    this.skipReason,
    this.binId,
    this.completedAt,
  });

  factory TripStop.fromJson(Map<String, dynamic> j) {
    final routeStop = j['route_stop'] is Map
        ? Map<String, dynamic>.from(j['route_stop'] as Map)
        : null;
    return TripStop(
      id: j['id'] as int,
      seq: (j['seq'] ?? 0) as int,
      label: (routeStop?['label'] ?? 'Stop ${j['seq']}') as String,
      completed: (j['completed'] ?? false) as bool,
      skipped: (j['skipped'] ?? false) as bool,
      skipReason: j['skip_reason'] as String?,
      binId: routeStop?['bin_id'] as int?,
      completedAt: _toDate(j['completed_at']),
    );
  }

  bool get settled => completed || skipped;
}

class CollectionTripDetail {
  final CollectionTrip trip;
  final List<TripStop> stops;

  const CollectionTripDetail({required this.trip, required this.stops});

  factory CollectionTripDetail.fromJson(Map<String, dynamic> j) =>
      CollectionTripDetail(
        trip: CollectionTrip.fromJson(j),
        stops: ((j['stops'] ?? []) as List)
            .map((e) => TripStop.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class AttendanceRecord {
  final int id;
  final String workerName;
  final String? workerPhone;
  final bool isContract;
  final String shift;
  final AttendanceStatus status;
  final int? routeId;
  final DateTime? checkInAt;
  final DateTime? checkOutAt;
  final String? remarks;

  const AttendanceRecord({
    required this.id,
    required this.workerName,
    this.workerPhone,
    required this.isContract,
    required this.shift,
    required this.status,
    this.routeId,
    this.checkInAt,
    this.checkOutAt,
    this.remarks,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> j) => AttendanceRecord(
    id: j['id'] as int,
    workerName: (j['worker_name'] ?? '') as String,
    workerPhone: j['worker_phone'] as String?,
    isContract: (j['is_contract'] ?? false) as bool,
    shift: (j['shift'] ?? 'morning') as String,
    status: AttendanceStatus.parse(j['status'] as String?),
    routeId: j['route_id'] as int?,
    checkInAt: _toDate(j['check_in_at']),
    checkOutAt: _toDate(j['check_out_at']),
    remarks: j['remarks'] as String?,
  );

  bool get isOnDuty => checkInAt != null && checkOutAt == null;
}

class AttendanceSheet {
  final String date;
  final String shift;
  final int totalMarked;
  final int present;
  final int absent;
  final int onLeave;
  final List<AttendanceRecord> items;

  const AttendanceSheet({
    required this.date,
    required this.shift,
    required this.totalMarked,
    required this.present,
    required this.absent,
    required this.onLeave,
    required this.items,
  });

  factory AttendanceSheet.fromJson(Map<String, dynamic> j) => AttendanceSheet(
    date: (j['date'] ?? '') as String,
    shift: (j['shift'] ?? 'all') as String,
    totalMarked: (j['total_marked'] ?? 0) as int,
    present: (j['present'] ?? 0) as int,
    absent: (j['absent'] ?? 0) as int,
    onLeave: (j['on_leave'] ?? 0) as int,
    items: ((j['items'] ?? []) as List)
        .map((e) => AttendanceRecord.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  static const empty = AttendanceSheet(
    date: '',
    shift: 'all',
    totalMarked: 0,
    present: 0,
    absent: 0,
    onLeave: 0,
    items: [],
  );
}

/// Dashboard counters — bins by pin colour, today's rounds, worker head count.
class SolidWasteSummary {
  final int binsActive;
  final int binsGreen;
  final int binsYellow;
  final int binsRed;
  final int binsOverflowing;
  final int binsSlaAtRisk;

  final String todayDate;
  final int roundsTotal;
  final int roundsCompleted;
  final int roundsInProgress;
  final int roundsAbandoned;
  final RouteProgress todayProgress;
  final double wasteCollectedKg;

  final int workersPresent;
  final int workersAbsent;
  final int workersOnLeave;
  final int workersMarked;

  const SolidWasteSummary({
    required this.binsActive,
    required this.binsGreen,
    required this.binsYellow,
    required this.binsRed,
    required this.binsOverflowing,
    required this.binsSlaAtRisk,
    required this.todayDate,
    required this.roundsTotal,
    required this.roundsCompleted,
    required this.roundsInProgress,
    required this.roundsAbandoned,
    required this.todayProgress,
    required this.wasteCollectedKg,
    required this.workersPresent,
    required this.workersAbsent,
    required this.workersOnLeave,
    required this.workersMarked,
  });

  factory SolidWasteSummary.fromJson(Map<String, dynamic> j) {
    final bins = j['bins'] is Map
        ? Map<String, dynamic>.from(j['bins'] as Map)
        : const <String, dynamic>{};
    final today = j['today'] is Map
        ? Map<String, dynamic>.from(j['today'] as Map)
        : const <String, dynamic>{};
    final workers = j['workers'] is Map
        ? Map<String, dynamic>.from(j['workers'] as Map)
        : const <String, dynamic>{};

    return SolidWasteSummary(
      binsActive: (bins['total_active'] ?? 0) as int,
      binsGreen: (bins['green'] ?? 0) as int,
      binsYellow: (bins['yellow'] ?? 0) as int,
      binsRed: (bins['red'] ?? 0) as int,
      binsOverflowing: (bins['overflowing'] ?? 0) as int,
      binsSlaAtRisk: (bins['sla_at_risk'] ?? 0) as int,
      todayDate: (today['date'] ?? '') as String,
      roundsTotal: (today['rounds_total'] ?? 0) as int,
      roundsCompleted: (today['rounds_completed'] ?? 0) as int,
      roundsInProgress: (today['rounds_in_progress'] ?? 0) as int,
      roundsAbandoned: (today['rounds_abandoned'] ?? 0) as int,
      todayProgress: today['progress'] is Map
          ? RouteProgress.fromJson(
              Map<String, dynamic>.from(today['progress'] as Map),
            )
          : RouteProgress.empty,
      wasteCollectedKg: _toDouble(today['waste_collected_kg']) ?? 0,
      workersPresent: (workers['present'] ?? 0) as int,
      workersAbsent: (workers['absent'] ?? 0) as int,
      workersOnLeave: (workers['on_leave'] ?? 0) as int,
      workersMarked: (workers['total_marked'] ?? 0) as int,
    );
  }

  static const empty = SolidWasteSummary(
    binsActive: 0,
    binsGreen: 0,
    binsYellow: 0,
    binsRed: 0,
    binsOverflowing: 0,
    binsSlaAtRisk: 0,
    todayDate: '',
    roundsTotal: 0,
    roundsCompleted: 0,
    roundsInProgress: 0,
    roundsAbandoned: 0,
    todayProgress: RouteProgress.empty,
    wasteCollectedKg: 0,
    workersPresent: 0,
    workersAbsent: 0,
    workersOnLeave: 0,
    workersMarked: 0,
  );
}

class BinPage {
  final int total;
  final List<WasteBin> items;

  const BinPage({required this.total, required this.items});

  factory BinPage.fromJson(Map<String, dynamic> j) => BinPage(
    total: (j['total'] ?? 0) as int,
    items: ((j['items'] ?? []) as List)
        .map((e) => WasteBin.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  static const empty = BinPage(total: 0, items: []);
}

class TripPage {
  final int total;
  final List<CollectionTrip> items;

  const TripPage({required this.total, required this.items});

  factory TripPage.fromJson(Map<String, dynamic> j) => TripPage(
    total: (j['total'] ?? 0) as int,
    items: ((j['items'] ?? []) as List)
        .map((e) => CollectionTrip.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  static const empty = TripPage(total: 0, items: []);
}

// ── Option lists, kept in sync with the backend DTO constants ──────────────

const kBinTypes = <String>[
  'community',
  'litter',
  'segregated_wet',
  'segregated_dry',
  'compactor',
];

const kShifts = <String>['morning', 'afternoon', 'night'];
