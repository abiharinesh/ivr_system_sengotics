import 'package:ivr_frontend/core/api/api_client.dart';

/// Data models for Exotel Management module.

class ExotelPhoneNumberRecord {
  final int id;
  final String phoneNumber;
  final String? friendlyName;
  final String? exotelSid;
  final bool isActive;
  final int? assignedOrgId;
  final String? assignedOrgName;
  final String? assignedOrgType;
  final String? assignedByUserEmail;
  final DateTime? assignedAt;
  final DateTime createdAt;
  final List<ExotelBotAssignmentRecord> botAssignments;

  const ExotelPhoneNumberRecord({
    required this.id,
    required this.phoneNumber,
    this.friendlyName,
    this.exotelSid,
    this.isActive = true,
    this.assignedOrgId,
    this.assignedOrgName,
    this.assignedOrgType,
    this.assignedByUserEmail,
    this.assignedAt,
    required this.createdAt,
    this.botAssignments = const [],
  });

  factory ExotelPhoneNumberRecord.fromJson(Map<String, dynamic> j) {
    final org = j['assigned_org'] as Map? ?? {};
    final user = j['assigned_by_user'] as Map? ?? {};
    return ExotelPhoneNumberRecord(
      id: j['id'] as int,
      phoneNumber: j['phone_number'] as String? ?? '',
      friendlyName: j['friendly_name'] as String?,
      exotelSid: j['exotel_sid'] as String?,
      isActive: j['is_active'] != false,
      assignedOrgId: j['assigned_org_id'] as int?,
      assignedOrgName: org['name'] as String?,
      assignedOrgType: org['branch_type'] as String?,
      assignedByUserEmail: user['email'] as String?,
      assignedAt: j['assigned_at'] != null
          ? DateTime.tryParse(j['assigned_at'].toString())
          : null,
      createdAt: DateTime.tryParse(j['created_at']?.toString() ?? '') ??
          DateTime.now(),
      botAssignments: (j['bot_assignments'] as List? ?? [])
          .map((e) => ExotelBotAssignmentRecord.fromJson(
              Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }
}

class ExotelBotRecord {
  final int id;
  final String botId;
  final String botName;
  final String? botVersion;
  final String? description;
  final bool isActive;
  final DateTime createdAt;

  const ExotelBotRecord({
    required this.id,
    required this.botId,
    required this.botName,
    this.botVersion,
    this.description,
    this.isActive = true,
    required this.createdAt,
  });

  factory ExotelBotRecord.fromJson(Map<String, dynamic> j) => ExotelBotRecord(
        id: j['id'] as int,
        botId: j['bot_id'] as String? ?? '',
        botName: j['bot_name'] as String? ?? '',
        botVersion: j['bot_version'] as String?,
        description: j['description'] as String?,
        isActive: j['is_active'] != false,
        createdAt: DateTime.tryParse(j['created_at']?.toString() ?? '') ??
            DateTime.now(),
      );
}

class ExotelBotAssignmentRecord {
  final int id;
  final int botId;
  final String botName;
  final String exotelBotId;
  final int phoneNumberId;
  final String phoneNumber;
  final int orgUnitId;
  final String orgUnitName;
  final bool isActive;
  final DateTime createdAt;

  const ExotelBotAssignmentRecord({
    required this.id,
    required this.botId,
    required this.botName,
    required this.exotelBotId,
    required this.phoneNumberId,
    required this.phoneNumber,
    required this.orgUnitId,
    required this.orgUnitName,
    this.isActive = true,
    required this.createdAt,
  });

  factory ExotelBotAssignmentRecord.fromJson(Map<String, dynamic> j) {
    final bot = j['bot'] as Map? ?? {};
    final phone = j['phone_number'] as Map? ?? {};
    final org = j['org_unit'] as Map? ?? {};
    return ExotelBotAssignmentRecord(
      id: j['id'] as int,
      botId: j['bot_id'] as int? ?? (bot['id'] as int? ?? 0),
      botName: bot['bot_name'] as String? ?? 'AI Bot',
      exotelBotId: bot['bot_id'] as String? ?? '',
      phoneNumberId: j['phone_number_id'] as int? ?? (phone['id'] as int? ?? 0),
      phoneNumber: phone['phone_number'] as String? ?? '',
      orgUnitId: j['org_unit_id'] as int? ?? (org['id'] as int? ?? 0),
      orgUnitName: org['name'] as String? ?? '',
      isActive: j['is_active'] != false,
      createdAt: DateTime.tryParse(j['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

class ExotelInteractionRecord {
  final int id;
  final String interactionId;
  final String? botId;
  final String? callSid;
  final String? customerNumber;
  final String? botName;
  final String? botVersion;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final int? durationSeconds;
  final String? audioUrl;
  final dynamic transcriptJson;
  final String? transcriptText;
  final String? status;
  final dynamic metadata;
  final DateTime syncedAt;

  const ExotelInteractionRecord({
    required this.id,
    required this.interactionId,
    this.botId,
    this.callSid,
    this.customerNumber,
    this.botName,
    this.botVersion,
    this.startedAt,
    this.endedAt,
    this.durationSeconds,
    this.audioUrl,
    this.transcriptJson,
    this.transcriptText,
    this.status,
    this.metadata,
    required this.syncedAt,
  });

  factory ExotelInteractionRecord.fromJson(Map<String, dynamic> j) =>
      ExotelInteractionRecord(
        id: j['id'] as int,
        interactionId: j['interaction_id'] as String? ?? '',
        botId: j['bot_id'] as String?,
        callSid: j['call_sid'] as String?,
        customerNumber: j['customer_number'] as String?,
        botName: j['bot_name'] as String?,
        botVersion: j['bot_version'] as String?,
        startedAt: j['started_at'] != null
            ? DateTime.tryParse(j['started_at'].toString())
            : null,
        endedAt: j['ended_at'] != null
            ? DateTime.tryParse(j['ended_at'].toString())
            : null,
        durationSeconds: j['duration_seconds'] as int?,
        audioUrl: j['audio_url'] as String?,
        transcriptJson: j['transcript_json'],
        transcriptText: j['transcript_text'] as String?,
        status: j['status'] as String?,
        metadata: j['metadata'],
        syncedAt: DateTime.tryParse(j['synced_at']?.toString() ?? '') ??
            DateTime.now(),
      );
}

class ExotelDashboardStats {
  final int totalInteractions;
  final int interactionsLast30Days;
  final int activePhoneNumbers;
  final int activeBots;
  final int activeAssignments;

  const ExotelDashboardStats({
    this.totalInteractions = 0,
    this.interactionsLast30Days = 0,
    this.activePhoneNumbers = 0,
    this.activeBots = 0,
    this.activeAssignments = 0,
  });

  factory ExotelDashboardStats.fromJson(Map<String, dynamic> j) =>
      ExotelDashboardStats(
        totalInteractions: j['total_interactions'] as int? ?? 0,
        interactionsLast30Days: j['interactions_last_30_days'] as int? ?? 0,
        activePhoneNumbers: j['active_phone_numbers'] as int? ?? 0,
        activeBots: j['active_bots'] as int? ?? 0,
        activeAssignments: j['active_assignments'] as int? ?? 0,
      );
}

/// Repository for Exotel Management operations.
class ExotelManagementRepository {
  final ApiClient _api;

  ExotelManagementRepository({ApiClient? api}) : _api = api ?? ApiClient.instance;

  static const String _base = '/api/superadmin/exotel';

  // ── Phone Numbers ────────────────────────────────────────────────────────

  Future<List<ExotelPhoneNumberRecord>> listPhoneNumbers() async {
    final data = await _api.get('$_base/phone-numbers', forceRefresh: true);
    return (data as List)
        .map((e) => ExotelPhoneNumberRecord.fromJson(
            Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<Map<String, dynamic>> syncPhoneNumbers() async {
    final data = await _api.post('$_base/phone-numbers/sync');
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> assignPhoneNumber(int phoneId, int? orgUnitId) async {
    final data = await _api.patch('$_base/phone-numbers/$phoneId/assign', data: {
      'org_unit_id': orgUnitId,
    });
    return Map<String, dynamic>.from(data as Map);
  }

  // ── Bots ─────────────────────────────────────────────────────────────────

  Future<List<ExotelBotRecord>> listBots() async {
    final data = await _api.get('$_base/bots', forceRefresh: true);
    return (data as List)
        .map((e) =>
            ExotelBotRecord.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<Map<String, dynamic>> syncBots() async {
    final data = await _api.post('$_base/bots/sync');
    return Map<String, dynamic>.from(data as Map);
  }

  // ── Bot Assignments ──────────────────────────────────────────────────────

  Future<List<ExotelBotAssignmentRecord>> listAssignments({int? orgUnitId}) async {
    final data = await _api.get(
      '$_base/assignments',
      queryParams: {
        if (orgUnitId != null) 'org_unit_id': orgUnitId.toString(),
      },
      forceRefresh: true,
    );
    return (data as List)
        .map((e) => ExotelBotAssignmentRecord.fromJson(
            Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<Map<String, dynamic>> createAssignment({
    required int botId,
    required int phoneNumberId,
    required int orgUnitId,
  }) async {
    final data = await _api.post('$_base/assignments', data: {
      'bot_id': botId,
      'phone_number_id': phoneNumberId,
      'org_unit_id': orgUnitId,
    });
    return Map<String, dynamic>.from(data as Map);
  }

  Future<void> deleteAssignment(int id) async {
    await _api.delete('$_base/assignments/$id');
  }

  // ── Dashboard & Interactions ─────────────────────────────────────────────

  Future<ExotelDashboardStats> getDashboardStats() async {
    final data = await _api.get('$_base/dashboard', forceRefresh: true);
    return ExotelDashboardStats.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<List<ExotelInteractionRecord>> listInteractions({
    String? botId,
    String? phone,
    String? status,
    String? dateFrom,
    String? dateTo,
    int? take,
  }) async {
    final data = await _api.get(
      '$_base/interactions',
      queryParams: {
        if (botId != null) 'bot_id': botId,
        if (phone != null) 'phone': phone,
        if (status != null) 'status': status,
        if (dateFrom != null) 'date_from': dateFrom,
        if (dateTo != null) 'date_to': dateTo,
        if (take != null) 'take': take.toString(),
      },
      forceRefresh: true,
    );
    return (data as List)
        .map((e) => ExotelInteractionRecord.fromJson(
            Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<ExotelInteractionRecord> getInteractionDetail(int id) async {
    final data = await _api.get('$_base/interactions/$id', forceRefresh: true);
    return ExotelInteractionRecord.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<Map<String, dynamic>> syncInteractions({
    String? dateFrom,
    String? dateTo,
  }) async {
    final data = await _api.post('$_base/interactions/sync', data: {
      if (dateFrom != null) 'date_from': dateFrom,
      if (dateTo != null) 'date_to': dateTo,
    });
    return Map<String, dynamic>.from(data as Map);
  }

  String getAudioProxyUrl(int interactionId) {
    return '$_base/interactions/$interactionId/audio';
  }
}
