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

  const PoleModel({
    required this.id,
    this.poleNumber,
    this.keypadId,
    this.latitude,
    this.longitude,
    this.panchayatId,
    this.landmarks = const [],
    this.complaintsCount = 0,
  });

  factory PoleModel.fromJson(Map<String, dynamic> json) {
    final count = json['_count'] as Map<String, dynamic>?;
    return PoleModel(
      id: json['id'] as int,
      poleNumber: json['pole_number'] as String?,
      keypadId: json['keypad_id'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      panchayatId: json['panchayat_id'] as int?,
      landmarks: (json['landmarks'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      complaintsCount: count?['complaints'] as int? ?? 0,
    );
  }

  @override
  List<Object?> get props => [id, poleNumber, keypadId];
}
