import 'package:equatable/equatable.dart';

class StatsModel extends Equatable {
  final int totalComplaints;
  final int pendingComplaints;
  final int resolvedComplaints;
  final int manualReviewComplaints;
  final int? totalPoles;
  final int? totalPanchayats;
  final int? totalAdmins;

  const StatsModel({
    required this.totalComplaints,
    required this.pendingComplaints,
    required this.resolvedComplaints,
    required this.manualReviewComplaints,
    this.totalPoles,
    this.totalPanchayats,
    this.totalAdmins,
  });

  factory StatsModel.fromJson(Map<String, dynamic> json) {
    return StatsModel(
      totalComplaints: json['total_complaints'] as int? ?? 0,
      pendingComplaints: json['pending_complaints'] as int? ?? 0,
      resolvedComplaints: json['resolved_complaints'] as int? ?? 0,
      manualReviewComplaints: json['manual_review_complaints'] as int? ?? 0,
      totalPoles: json['total_poles'] as int?,
      totalPanchayats: json['total_panchayats'] as int?,
      totalAdmins: json['total_admins'] as int?,
    );
  }

  @override
  List<Object?> get props => [totalComplaints, pendingComplaints, resolvedComplaints];
}
