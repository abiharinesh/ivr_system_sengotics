import 'package:equatable/equatable.dart';

int _jsonInt(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v;
  if (v is double) return v.round();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

class ResolutionTrend extends Equatable {
  final List<int> currentWeek;
  final List<int> lastWeek;

  const ResolutionTrend({
    required this.currentWeek,
    required this.lastWeek,
  });

  factory ResolutionTrend.fromJson(Map<String, dynamic> json) {
    List<int> week(dynamic list) {
      if (list is! List) return List.filled(7, 0);
      final out = <int>[];
      for (var i = 0; i < 7; i++) {
        out.add(i < list.length ? _jsonInt(list[i]) : 0);
      }
      return out;
    }

    return ResolutionTrend(
      currentWeek: week(json['current_week']),
      lastWeek: week(json['last_week']),
    );
  }

  @override
  List<Object?> get props => [currentWeek, lastWeek];
}

class CategoryCount extends Equatable {
  final String label;
  final int count;

  const CategoryCount({required this.label, required this.count});

  factory CategoryCount.fromJson(Map<String, dynamic> json) {
    return CategoryCount(
      label: json['label']?.toString() ?? 'Other',
      count: _jsonInt(json['count']),
    );
  }

  @override
  List<Object?> get props => [label, count];
}

class RecentActivityItem extends Equatable {
  final String kind;
  final String title;
  final String subtitle;
  final DateTime at;
  final int complaintId;

  const RecentActivityItem({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.at,
    required this.complaintId,
  });

  factory RecentActivityItem.fromJson(Map<String, dynamic> json) {
    final atStr = json['at']?.toString() ?? '';
    DateTime at;
    try {
      at = DateTime.parse(atStr).toLocal();
    } catch (_) {
      at = DateTime.now();
    }
    return RecentActivityItem(
      kind: json['kind']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      subtitle: json['subtitle']?.toString() ?? '',
      at: at,
      complaintId: _jsonInt(json['complaint_id']),
    );
  }

  @override
  List<Object?> get props => [kind, title, subtitle, at, complaintId];
}

class DashboardInsights extends Equatable {
  final ResolutionTrend resolutionTrend;
  final List<CategoryCount> byCategory;
  final List<RecentActivityItem> recentActivity;

  const DashboardInsights({
    required this.resolutionTrend,
    required this.byCategory,
    required this.recentActivity,
  });

  factory DashboardInsights.fromJson(Map<String, dynamic> json) {
    final trendRaw = json['resolution_trend'];
    final trend = trendRaw is Map<String, dynamic>
        ? ResolutionTrend.fromJson(trendRaw)
        : const ResolutionTrend(
            currentWeek: [0, 0, 0, 0, 0, 0, 0],
            lastWeek: [0, 0, 0, 0, 0, 0, 0],
          );

    final catRaw = json['by_category'];
    final byCategory = <CategoryCount>[];
    if (catRaw is List) {
      for (final e in catRaw) {
        if (e is Map) {
          byCategory.add(
            CategoryCount.fromJson(Map<String, dynamic>.from(e)),
          );
        }
      }
    }

    final actRaw = json['recent_activity'];
    final recentActivity = <RecentActivityItem>[];
    if (actRaw is List) {
      for (final e in actRaw) {
        if (e is Map) {
          recentActivity.add(
            RecentActivityItem.fromJson(Map<String, dynamic>.from(e)),
          );
        }
      }
    }

    return DashboardInsights(
      resolutionTrend: trend,
      byCategory: byCategory,
      recentActivity: recentActivity,
    );
  }

  @override
  List<Object?> get props => [resolutionTrend, byCategory, recentActivity];
}
