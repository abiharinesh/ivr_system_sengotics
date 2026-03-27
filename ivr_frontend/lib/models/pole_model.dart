import 'package:equatable/equatable.dart';

class PoleModel extends Equatable {
  final int id;
  final String? poleNumber;
  final String? keypadId;
  final double? latitude;
  final double? longitude;
  final int? panchayatId;
  final List<String> landmarks;
  final int complaintsCount;
  final Map<String, int> complaintStatusCounts;

  const PoleModel({
    required this.id,
    this.poleNumber,
    this.keypadId,
    this.latitude,
    this.longitude,
    this.panchayatId,
    this.landmarks = const [],
    this.complaintsCount = 0,
    this.complaintStatusCounts = const {},
  });

  factory PoleModel.fromJson(Map<String, dynamic> json) {
    final count = json['_count'] as Map<String, dynamic>?;
    final complaints = json['complaints'] as List<dynamic>?;
    final statusCounts = <String, int>{};
    if (complaints != null) {
      for (final row in complaints) {
        if (row is Map<String, dynamic>) {
          final status = row['status']?.toString();
          if (status == null || status.isEmpty) continue;
          statusCounts[status] = (statusCounts[status] ?? 0) + 1;
        }
      }
    }

    final totalComplaints =
        count?['complaints'] as int? ?? complaints?.length ?? 0;

    return PoleModel(
      id: json['id'] as int,
      poleNumber: json['pole_number'] as String?,
      keypadId: json['keypad_id'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      panchayatId: json['panchayat_id'] as int?,
      landmarks:
          (json['landmarks'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      complaintsCount: totalComplaints,
      complaintStatusCounts: statusCounts,
    );
  }

  int _statusCount(String status) => complaintStatusCounts[status] ?? 0;

  int get pendingComplaints => _statusCount('pending');
  int get inProgressComplaints => _statusCount('in_progress');
  int get manualReviewComplaints => _statusCount('manual_review');
  int get openComplaints =>
      pendingComplaints + inProgressComplaints + manualReviewComplaints;

  bool get hasCriticalIssues => pendingComplaints > 0 || inProgressComplaints > 0;
  bool get hasManualReviewIssues => manualReviewComplaints > 0;
  bool get hasOpenIssues => openComplaints > 0;

  @override
  List<Object?> get props => [id, poleNumber, keypadId];
}
