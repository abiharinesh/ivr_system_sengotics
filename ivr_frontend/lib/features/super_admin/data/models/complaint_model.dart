import 'package:equatable/equatable.dart';

class ComplaintModel extends Equatable {
  final int id;
  final int? voiceCallId;
  final int? poleId;
  final int? pipelineId;
  final int? tankId;
  final int? panchayatId;
  final String? complaintType;
  final String? description;
  final String? audioUrl;
  final String? callerLanguage;
  final String? callerEmotion;
  final String? urgencyLevel;
  final String status;
  final DateTime createdAt;
  final int? assignedElectricianId;
  final int? assignedPlumberId;

  // Nested
  final PoleInfo? pole;
  final PanchayatInfo? panchayat;
  final VoiceCallInfo? voiceCall;
  final PipelineInfo? pipeline;
  final TankInfo? tank;
  final StaffInfo? assignedElectrician;
  final StaffInfo? assignedPlumber;

  const ComplaintModel({
    required this.id,
    this.voiceCallId,
    this.poleId,
    this.pipelineId,
    this.tankId,
    this.panchayatId,
    this.complaintType,
    this.description,
    this.audioUrl,
    this.callerLanguage,
    this.callerEmotion,
    this.urgencyLevel,
    required this.status,
    required this.createdAt,
    this.assignedElectricianId,
    this.assignedPlumberId,
    this.pole,
    this.panchayat,
    this.voiceCall,
    this.pipeline,
    this.tank,
    this.assignedElectrician,
    this.assignedPlumber,
  });

  factory ComplaintModel.fromJson(Map<String, dynamic> json) {
    return ComplaintModel(
      id: json['id'] as int,
      voiceCallId: json['voice_call_id'] as int?,
      poleId: json['pole_id'] as int?,
      pipelineId: json['pipeline_id'] as int?,
      tankId: json['tank_id'] as int?,
      panchayatId: json['panchayat_id'] as int?,
      complaintType: json['complaint_type'] as String?,
      description: json['description'] as String?,
      audioUrl: json['audio_url'] as String?,
      callerLanguage: json['caller_language'] as String?,
      callerEmotion: json['caller_emotion'] as String?,
      urgencyLevel: json['urgency_level'] as String?,
      status: json['status'] as String? ?? 'pending',
      createdAt: DateTime.parse(json['created_at'] as String),
      assignedElectricianId: json['assigned_electrician_id'] as int?,
      assignedPlumberId: json['assigned_plumber_id'] as int?,
      pole:
          json['pole'] != null
              ? PoleInfo.fromJson(json['pole'] as Map<String, dynamic>)
              : null,
      panchayat:
          json['panchayat'] != null
              ? PanchayatInfo.fromJson(
                json['panchayat'] as Map<String, dynamic>,
              )
              : null,
      voiceCall:
          json['voice_call'] != null
              ? VoiceCallInfo.fromJson(
                json['voice_call'] as Map<String, dynamic>,
              )
              : null,
      pipeline:
          json['pipeline'] != null
              ? PipelineInfo.fromJson(json['pipeline'] as Map<String, dynamic>)
              : null,
      tank:
          json['tank'] != null
              ? TankInfo.fromJson(json['tank'] as Map<String, dynamic>)
              : null,
      assignedElectrician:
          json['assigned_electrician'] != null
              ? StaffInfo.fromJson(json['assigned_electrician'] as Map<String, dynamic>)
              : null,
      assignedPlumber:
          json['assigned_plumber'] != null
              ? StaffInfo.fromJson(json['assigned_plumber'] as Map<String, dynamic>)
              : null,
    );
  }

  String get statusLabel {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'assigned':
        return 'Assigned';
      case 'in_progress':
        return 'In Progress';
      case 'resolved_pending_confirmation':
        return 'Awaiting confirmation';
      case 'reassign_required':
        return 'Reassign required';
      case 'resolved':
        return 'Resolved';
      case 'manual_review':
        return 'Manual Review';
      case 'rejected':
        return 'Rejected';
      default:
        return status;
    }
  }

  @override
  List<Object?> get props => [id, status, assignedElectricianId, assignedPlumberId];
}

class PoleInfo {
  final int id;
  final String? poleNumber;
  final String? keypadId;
  final double? latitude;
  final double? longitude;

  PoleInfo({required this.id, this.poleNumber, this.keypadId, this.latitude, this.longitude});

  factory PoleInfo.fromJson(Map<String, dynamic> json) {
    return PoleInfo(
      id: json['id'] as int,
      poleNumber: json['pole_number'] as String?,
      keypadId: json['keypad_id'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );
  }
}

class PipelineInfo {
  final int id;
  final String? name;
  final String? material;
  final double? diameterMm;
  final String status;

  PipelineInfo({
    required this.id,
    this.name,
    this.material,
    this.diameterMm,
    required this.status,
  });

  factory PipelineInfo.fromJson(Map<String, dynamic> json) {
    return PipelineInfo(
      id: json['id'] as int,
      name: json['name'] as String?,
      material: json['material'] as String?,
      diameterMm: (json['diameter_mm'] as num?)?.toDouble(),
      status: json['status'] as String? ?? 'active',
    );
  }
}

class TankInfo {
  final int id;
  final String name;
  final String type;
  final double latitude;
  final double longitude;
  final double? capacityLiters;
  final double currentLevelPct;
  final String status;
  final String? pumpStatus;

  TankInfo({
    required this.id,
    required this.name,
    required this.type,
    required this.latitude,
    required this.longitude,
    this.capacityLiters,
    required this.currentLevelPct,
    required this.status,
    this.pumpStatus,
  });

  factory TankInfo.fromJson(Map<String, dynamic> json) {
    return TankInfo(
      id: json['id'] as int,
      name: json['name'] as String,
      type: json['type'] as String? ?? 'overhead_tank',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 11.0168,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 76.9558,
      capacityLiters: (json['capacity_liters'] as num?)?.toDouble(),
      currentLevelPct: (json['current_level_pct'] as num?)?.toDouble() ?? 100.0,
      status: json['status'] as String? ?? 'active',
      pumpStatus: json['pump_status'] as String?,
    );
  }
}

class StaffInfo {
  final int id;
  final String email;

  StaffInfo({required this.id, required this.email});

  factory StaffInfo.fromJson(Map<String, dynamic> json) {
    return StaffInfo(
      id: json['id'] as int,
      email: json['email'] as String? ?? '',
    );
  }
}

class PanchayatInfo {
  final int id;
  final String name;

  PanchayatInfo({required this.id, required this.name});

  factory PanchayatInfo.fromJson(Map<String, dynamic> json) {
    return PanchayatInfo(id: json['id'] as int, name: json['name'] as String);
  }
}

class VoiceCallInfo {
  final int id;
  final String? callSid;
  final String? audioUrl;
  final String? transcript;
  final String? transcriptEnglish;
  final Map<String, dynamic>? aiExtractedJson;
  final String processingStatus;

  VoiceCallInfo({
    required this.id,
    this.callSid,
    this.audioUrl,
    this.transcript,
    this.transcriptEnglish,
    this.aiExtractedJson,
    this.processingStatus = 'pending',
  });

  factory VoiceCallInfo.fromJson(Map<String, dynamic> json) {
    return VoiceCallInfo(
      id: json['id'] as int,
      callSid: json['call_sid'] as String?,
      audioUrl: json['audio_url'] as String?,
      transcript: json['transcript'] as String?,
      transcriptEnglish: json['transcript_english'] as String?,
      aiExtractedJson: json['ai_extracted_json'] as Map<String, dynamic>?,
      processingStatus: json['processing_status'] as String? ?? 'pending',
    );
  }
}
