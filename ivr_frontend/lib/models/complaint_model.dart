import 'package:equatable/equatable.dart';

class ComplaintModel extends Equatable {
  final int id;
  final int? voiceCallId;
  final int? poleId;
  final int? panchayatId;
  final String? complaintType;
  final String? description;
  final String? audioUrl;
  final String status;
  final DateTime createdAt;

  // Nested
  final PoleInfo? pole;
  final PanchayatInfo? panchayat;
  final VoiceCallInfo? voiceCall;

  const ComplaintModel({
    required this.id,
    this.voiceCallId,
    this.poleId,
    this.panchayatId,
    this.complaintType,
    this.description,
    this.audioUrl,
    required this.status,
    required this.createdAt,
    this.pole,
    this.panchayat,
    this.voiceCall,
  });

  factory ComplaintModel.fromJson(Map<String, dynamic> json) {
    return ComplaintModel(
      id: json['id'] as int,
      voiceCallId: json['voice_call_id'] as int?,
      poleId: json['pole_id'] as int?,
      panchayatId: json['panchayat_id'] as int?,
      complaintType: json['complaint_type'] as String?,
      description: json['description'] as String?,
      audioUrl: json['audio_url'] as String?,
      status: json['status'] as String? ?? 'pending',
      createdAt: DateTime.parse(json['created_at'] as String),
      pole: json['pole'] != null
          ? PoleInfo.fromJson(json['pole'] as Map<String, dynamic>)
          : null,
      panchayat: json['panchayat'] != null
          ? PanchayatInfo.fromJson(json['panchayat'] as Map<String, dynamic>)
          : null,
      voiceCall: json['voice_call'] != null
          ? VoiceCallInfo.fromJson(json['voice_call'] as Map<String, dynamic>)
          : null,
    );
  }

  String get statusLabel {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'in_progress':
        return 'In Progress';
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
  List<Object?> get props => [id, status];
}

class PoleInfo {
  final int id;
  final String? poleNumber;
  final String? keypadId;

  PoleInfo({required this.id, this.poleNumber, this.keypadId});

  factory PoleInfo.fromJson(Map<String, dynamic> json) {
    return PoleInfo(
      id: json['id'] as int,
      poleNumber: json['pole_number'] as String?,
      keypadId: json['keypad_id'] as String?,
    );
  }
}

class PanchayatInfo {
  final int id;
  final String name;

  PanchayatInfo({required this.id, required this.name});

  factory PanchayatInfo.fromJson(Map<String, dynamic> json) {
    return PanchayatInfo(
      id: json['id'] as int,
      name: json['name'] as String,
    );
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
