import 'package:ivr_frontend/core/api/api_client.dart';

/// Models and reads for `/api/admin/reports/service-analytics`.

int _int(dynamic v, [int fallback = 0]) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? fallback;
  return fallback;
}

double? _doubleOrNull(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

Map<String, dynamic> _map(dynamic v) =>
    v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

List<Map<String, dynamic>> _maps(dynamic v) => v is List
    ? v.map((e) => Map<String, dynamic>.from(e as Map)).toList()
    : const [];

class CountBucket {
  final String label;
  final int count;

  const CountBucket({required this.label, required this.count});
}

/// Median resolution time for one complaint category.
class CategoryResolution {
  final String category;
  final int medianHours;
  final int resolved;

  const CategoryResolution({
    required this.category,
    required this.medianHours,
    required this.resolved,
  });
}

class ServiceAnalytics {
  final int windowDays;

  final int allTime;
  final int inWindow;
  final int open;
  final int resolved;
  final int resolutionRatePct;

  /// The median is the headline rather than the mean: one complaint left open
  /// for a year drags an average far past what anybody actually experiences.
  final int avgHours;
  final int medianHours;
  final int p90Hours;
  final int sample;

  final int slaTracked;
  final int slaBreached;
  final int slaCompliancePct;
  final List<CountBucket> slaByStatus;

  final double? satisfaction;
  final int satisfactionResponses;

  final List<CountBucket> byCategory;
  final List<CountBucket> byUrgency;
  final List<CategoryResolution> resolutionByCategory;
  final List<CountBucket> dailyVolume;

  const ServiceAnalytics({
    required this.windowDays,
    required this.allTime,
    required this.inWindow,
    required this.open,
    required this.resolved,
    required this.resolutionRatePct,
    required this.avgHours,
    required this.medianHours,
    required this.p90Hours,
    required this.sample,
    required this.slaTracked,
    required this.slaBreached,
    required this.slaCompliancePct,
    required this.slaByStatus,
    required this.satisfaction,
    required this.satisfactionResponses,
    required this.byCategory,
    required this.byUrgency,
    required this.resolutionByCategory,
    required this.dailyVolume,
  });

  static const empty = ServiceAnalytics(
    windowDays: 30,
    allTime: 0,
    inWindow: 0,
    open: 0,
    resolved: 0,
    resolutionRatePct: 0,
    avgHours: 0,
    medianHours: 0,
    p90Hours: 0,
    sample: 0,
    slaTracked: 0,
    slaBreached: 0,
    slaCompliancePct: 100,
    slaByStatus: [],
    satisfaction: null,
    satisfactionResponses: 0,
    byCategory: [],
    byUrgency: [],
    resolutionByCategory: [],
    dailyVolume: [],
  );

  bool get isEmpty => allTime == 0 && slaTracked == 0;

  factory ServiceAnalytics.fromJson(Map<String, dynamic> j) {
    final totals = _map(j['totals']);
    final res = _map(j['resolution_hours']);
    final sla = _map(j['sla']);
    final sat = _map(j['satisfaction']);

    return ServiceAnalytics(
      windowDays: _int(j['window_days'], 30),
      allTime: _int(totals['all_time']),
      inWindow: _int(totals['in_window']),
      open: _int(totals['open']),
      resolved: _int(totals['resolved']),
      resolutionRatePct: _int(totals['resolution_rate_pct']),
      avgHours: _int(res['average']),
      medianHours: _int(res['median']),
      p90Hours: _int(res['p90']),
      sample: _int(res['sample']),
      slaTracked: _int(sla['tracked']),
      slaBreached: _int(sla['breached']),
      slaCompliancePct: _int(sla['compliance_pct'], 100),
      slaByStatus: _maps(sla['by_status'])
          .map((e) => CountBucket(
                label: e['status'] as String? ?? '',
                count: _int(e['count']),
              ))
          .toList(),
      satisfaction: _doubleOrNull(sat['average']),
      satisfactionResponses: _int(sat['responses']),
      byCategory: _maps(j['by_category'])
          .map((e) => CountBucket(
                label: e['category'] as String? ?? '',
                count: _int(e['count']),
              ))
          .toList(),
      byUrgency: _maps(j['by_urgency'])
          .map((e) => CountBucket(
                label: e['urgency'] as String? ?? '',
                count: _int(e['count']),
              ))
          .toList(),
      resolutionByCategory: _maps(j['resolution_by_category'])
          .map((e) => CategoryResolution(
                category: e['category'] as String? ?? '',
                medianHours: _int(e['median_hours']),
                resolved: _int(e['resolved']),
              ))
          .toList(),
      dailyVolume: _maps(j['daily_volume'])
          .map((e) => CountBucket(
                label: e['date'] as String? ?? '',
                count: _int(e['count']),
              ))
          .toList(),
    );
  }
}

class ServiceAnalyticsRepository {
  final ApiClient _api;

  ServiceAnalyticsRepository({ApiClient? api}) : _api = api ?? ApiClient.instance;

  Future<ServiceAnalytics> overview({int days = 30}) async {
    final data = await _api.get(
      '/api/admin/reports/service-analytics',
      queryParams: {'days': '$days'},
      forceRefresh: true,
    );
    return ServiceAnalytics.fromJson(Map<String, dynamic>.from(data as Map));
  }
}
