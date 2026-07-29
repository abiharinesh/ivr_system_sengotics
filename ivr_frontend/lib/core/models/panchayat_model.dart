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

  // Branding fields
  final String? branchType;
  final String? softwareNameTa;
  final String? softwareNameEn;
  final String? softwareTaglineTa;
  final String? softwareTaglineEn;
  final String? logoUrl;
  final String? secondaryLogoUrl;
  final String? faviconUrl;
  final String? primaryColor;
  final String? secondaryColor;
  final String? welcomeAudioUrl;

  const PanchayatModel({
    required this.id,
    required this.name,
    this.centerLat,
    this.centerLng,
    this.ivrNumber,
    this.polesCount = 0,
    this.complaintsCount = 0,
    this.usersCount = 0,
    this.branchType,
    this.softwareNameTa,
    this.softwareNameEn,
    this.softwareTaglineTa,
    this.softwareTaglineEn,
    this.logoUrl,
    this.secondaryLogoUrl,
    this.faviconUrl,
    this.primaryColor,
    this.secondaryColor,
    this.welcomeAudioUrl,
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
      branchType: json['branch_type'] as String?,
      softwareNameTa: json['software_name_ta'] as String?,
      softwareNameEn: json['software_name_en'] as String?,
      softwareTaglineTa: json['software_tagline_ta'] as String?,
      softwareTaglineEn: json['software_tagline_en'] as String?,
      logoUrl: json['logo_url'] as String?,
      secondaryLogoUrl: json['secondary_logo_url'] as String?,
      faviconUrl: json['favicon_url'] as String?,
      primaryColor: json['primary_color'] as String?,
      secondaryColor: json['secondary_color'] as String?,
      welcomeAudioUrl: json['welcome_audio_url'] as String?,
    );
  }

  @override
  List<Object?> get props => [id, name, ivrNumber, branchType, softwareNameTa, softwareNameEn];
}
