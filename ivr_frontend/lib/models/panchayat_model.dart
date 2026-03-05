import 'package:equatable/equatable.dart';

class PanchayatModel extends Equatable {
  final int id;
  final String name;
  final double? centerLat;
  final double? centerLng;
  final String? ivrNumber;
  final int polesCount;
  final int complaintsCount;
  final int usersCount;

  const PanchayatModel({
    required this.id,
    required this.name,
    this.centerLat,
    this.centerLng,
    this.ivrNumber,
    this.polesCount = 0,
    this.complaintsCount = 0,
    this.usersCount = 0,
  });

  factory PanchayatModel.fromJson(Map<String, dynamic> json) {
    final count = json['_count'] as Map<String, dynamic>?;
    return PanchayatModel(
      id: json['id'] as int,
      name: json['name'] as String,
      centerLat: (json['center_lat'] as num?)?.toDouble(),
      centerLng: (json['center_lng'] as num?)?.toDouble(),
      ivrNumber: json['ivr_number'] as String?,
      polesCount: count?['electric_poles'] as int? ?? 0,
      complaintsCount: count?['complaints'] as int? ?? 0,
      usersCount: count?['users'] as int? ?? 0,
    );
  }

  @override
  List<Object?> get props => [id, name, ivrNumber];
}
