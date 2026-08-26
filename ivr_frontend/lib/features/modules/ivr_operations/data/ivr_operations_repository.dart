import 'package:ivr_frontend/core/api/api_client.dart';

/// Models and reads for `/api/ivr-operations`.
///
/// Field names follow the API's snake_case keys rather than being renamed on
/// the way in, so a change on either side shows up as a parse failure here
/// instead of a silently absent value.

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

DateTime? _date(dynamic v) =>
    v is String && v.isNotEmpty ? DateTime.tryParse(v) : null;

/// A recorded citizen call, with its transcript and the ticket it produced.
class VoiceCallRecord {
  final int id;
  final String? callSid;
  final String? callerNumber;
  final String? callTo;
  final DateTime? startedAt;
  final String? audioUrl;
  final String? transcript;
  final String? transcriptEnglish;
  final String status;
  final double? confidence;
  final int attempt;
  final int? complaintId;
  final String? complaintStatus;
  final String? complaintCategory;
  final String? complaintDescription;
  final String? urgency;
  final int? orgUnitId;
  final String? orgUnitName;
  final int? wardNumber;
  final String? wardName;
  final String? tenantId;

  const VoiceCallRecord({
    required this.id,
    required this.callSid,
    required this.callerNumber,
    this.callTo,
    required this.startedAt,
    required this.audioUrl,
    required this.transcript,
    required this.transcriptEnglish,
    required this.status,
    required this.confidence,
    required this.attempt,
    required this.complaintId,
    required this.complaintStatus,
    required this.complaintCategory,
    this.complaintDescription,
    required this.urgency,
    this.orgUnitId,
    this.orgUnitName,
    this.wardNumber,
    this.wardName,
    this.tenantId,
  });

  /// A call that produced a ticket is the outcome this system exists for.
  bool get raisedTicket => complaintId != null;

  factory VoiceCallRecord.fromJson(Map<String, dynamic> j) => VoiceCallRecord(
        id: _int(j['id']),
        callSid: j['call_sid'] as String?,
        callerNumber: j['caller_number'] as String?,
        callTo: j['call_to'] as String?,
        startedAt: _date(j['started_at']),
        audioUrl: j['audio_url'] as String?,
        transcript: j['transcript'] as String?,
        transcriptEnglish: j['transcript_english'] as String?,
        status: j['status'] as String? ?? 'unknown',
        confidence: _doubleOrNull(j['confidence']),
        attempt: _int(j['attempt'], 1),
        complaintId: j['complaint_id'] == null ? null : _int(j['complaint_id']),
        complaintStatus: j['complaint_status'] as String?,
        complaintCategory: j['complaint_category'] as String?,
        complaintDescription: j['complaint_description'] as String?,
        urgency: j['urgency'] as String?,
        orgUnitId: j['org_unit_id'] == null ? null : _int(j['org_unit_id']),
        orgUnitName: j['org_unit_name'] as String?,
        wardNumber: j['ward_number'] == null ? null : _int(j['ward_number']),
        wardName: j['ward_name'] as String?,
        tenantId: j['tenant_id'] as String?,
      );
}

/// One row of the IVR interaction log: what the caller pressed, where it ended.
class IvrCallRecord {
  final String callSid;
  final String? callerNumber;
  final String? callTo;
  final DateTime? startedAt;
  final int? durationSeconds;
  final bool serviceSelected;
  final List<String> selections;
  final bool pollEntered;
  final String? finalStatus;
  final bool complaintCreated;
  final int? complaintId;
  final String? phase1Status;
  final String? phase2Status;
  final String? lastError;

  const IvrCallRecord({
    required this.callSid,
    required this.callerNumber,
    required this.callTo,
    required this.startedAt,
    required this.durationSeconds,
    required this.serviceSelected,
    required this.selections,
    required this.pollEntered,
    required this.finalStatus,
    required this.complaintCreated,
    required this.complaintId,
    required this.phase1Status,
    required this.phase2Status,
    required this.lastError,
  });

  bool get hasError => lastError != null;

  factory IvrCallRecord.fromJson(Map<String, dynamic> j) => IvrCallRecord(
        callSid: j['call_sid'] as String? ?? '',
        callerNumber: j['caller_number'] as String?,
        callTo: j['call_to'] as String?,
        startedAt: _date(j['started_at']),
        durationSeconds: j['duration_seconds'] == null
            ? null
            : _int(j['duration_seconds']),
        serviceSelected: j['service_selected'] == true,
        selections:
            (j['selections'] as List? ?? []).map((e) => e.toString()).toList(),
        pollEntered: j['poll_entered'] == true,
        finalStatus: j['final_status'] as String?,
        complaintCreated: j['complaint_created'] == true,
        complaintId: j['complaint_id'] == null ? null : _int(j['complaint_id']),
        phase1Status: j['phase1_status'] as String?,
        phase2Status: j['phase2_status'] as String?,
        lastError: j['last_error'] as String?,
      );
}

/// The counters above both lists.
class IvrSummary {
  final int totalCalls;
  final int callsLast30Days;
  final int complaintsRaised;
  final int containmentPct;
  final int failedProcessing;
  final int transcribed;
  final double? avgConfidence;

  const IvrSummary({
    required this.totalCalls,
    required this.callsLast30Days,
    required this.complaintsRaised,
    required this.containmentPct,
    required this.failedProcessing,
    required this.transcribed,
    required this.avgConfidence,
  });

  static const empty = IvrSummary(
    totalCalls: 0,
    callsLast30Days: 0,
    complaintsRaised: 0,
    containmentPct: 0,
    failedProcessing: 0,
    transcribed: 0,
    avgConfidence: null,
  );

  factory IvrSummary.fromJson(Map<String, dynamic> j) => IvrSummary(
        totalCalls: _int(j['total_calls']),
        callsLast30Days: _int(j['calls_last_30_days']),
        complaintsRaised: _int(j['complaints_raised']),
        containmentPct: _int(j['containment_pct']),
        failedProcessing: _int(j['failed_processing']),
        transcribed: _int(j['transcribed']),
        avgConfidence: _doubleOrNull(j['avg_confidence']),
      );
}

class IvrOperationsRepository {
  final ApiClient _api;

  IvrOperationsRepository({ApiClient? api}) : _api = api ?? ApiClient.instance;

  static const String _base = '/api/ivr-operations';

  Future<IvrSummary> summary({bool forceRefresh = true}) async {
    final data = await _api.get('$_base/summary', forceRefresh: forceRefresh);
    return IvrSummary.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<List<VoiceCallRecord>> voiceCalls({String? search, String? status}) async {
    final data = await _api.get(
      '$_base/voice-calls',
      queryParams: {
        if (search != null && search.isNotEmpty) 'search': search,
        if (status != null && status.isNotEmpty) 'status': status,
      },
      forceRefresh: true,
    );
    return (data as List)
        .map((e) => VoiceCallRecord.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<Map<String, dynamic>> voiceCallDetail(int id) async {
    final data = await _api.get('$_base/voice-calls/$id', forceRefresh: true);
    return Map<String, dynamic>.from(data as Map);
  }

  Future<List<IvrCallRecord>> calls({String? search}) async {
    final data = await _api.get(
      '$_base/calls',
      queryParams: {if (search != null && search.isNotEmpty) 'search': search},
      forceRefresh: true,
    );
    return (data as List)
        .map((e) => IvrCallRecord.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }
}

