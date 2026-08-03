/// Data classes for the building permit module. Mirror the JSON shapes served
/// by `src/building-permit/`.
///
/// The backend converts every Prisma `Decimal` to a JSON number before it goes
/// out, so the numeric fields here parse straight through. `_toDouble` still
/// tolerates a string in case an older build is on the other end.

double? _toDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

DateTime? _toDate(dynamic v) {
  if (v == null) return null;
  return DateTime.tryParse(v.toString());
}

/// Lifecycle states, in the order a file moves through them.
enum PermitStatus {
  draft,
  submitted,
  scrutiny,
  nocPending,
  inspection,
  approved,
  rejected,
  returned,
  cancelled,
  expired;

  static PermitStatus parse(String? raw) {
    switch ((raw ?? '').toUpperCase()) {
      case 'SUBMITTED':
        return PermitStatus.submitted;
      case 'SCRUTINY':
        return PermitStatus.scrutiny;
      case 'NOC_PENDING':
        return PermitStatus.nocPending;
      case 'INSPECTION':
        return PermitStatus.inspection;
      case 'APPROVED':
        return PermitStatus.approved;
      case 'REJECTED':
        return PermitStatus.rejected;
      case 'RETURNED':
        return PermitStatus.returned;
      case 'CANCELLED':
        return PermitStatus.cancelled;
      case 'EXPIRED':
        return PermitStatus.expired;
      default:
        return PermitStatus.draft;
    }
  }

  /// The value the API expects back.
  String get wire {
    switch (this) {
      case PermitStatus.nocPending:
        return 'NOC_PENDING';
      default:
        return name.toUpperCase();
    }
  }

  String get label {
    switch (this) {
      case PermitStatus.draft:
        return 'Draft';
      case PermitStatus.submitted:
        return 'Submitted';
      case PermitStatus.scrutiny:
        return 'Scrutiny';
      case PermitStatus.nocPending:
        return 'NOC pending';
      case PermitStatus.inspection:
        return 'Site inspection';
      case PermitStatus.approved:
        return 'Approved';
      case PermitStatus.rejected:
        return 'Rejected';
      case PermitStatus.returned:
        return 'Returned';
      case PermitStatus.cancelled:
        return 'Cancelled';
      case PermitStatus.expired:
        return 'Expired';
    }
  }

  /// Statuses a clerk can move a file to from here, mirroring
  /// `ALLOWED_TRANSITIONS` in the service. Approve and reject are excluded —
  /// they have their own guarded endpoints.
  List<PermitStatus> get nextStatuses {
    switch (this) {
      case PermitStatus.submitted:
        return [PermitStatus.scrutiny, PermitStatus.returned];
      case PermitStatus.scrutiny:
        return [PermitStatus.nocPending, PermitStatus.returned];
      case PermitStatus.nocPending:
        return [PermitStatus.inspection, PermitStatus.returned];
      case PermitStatus.inspection:
        return [PermitStatus.returned];
      case PermitStatus.draft:
      case PermitStatus.returned:
      case PermitStatus.approved:
      case PermitStatus.rejected:
      case PermitStatus.cancelled:
      case PermitStatus.expired:
        return const [];
    }
  }

  bool get isEditable =>
      this == PermitStatus.draft || this == PermitStatus.returned;

  bool get isTerminal =>
      this == PermitStatus.approved ||
      this == PermitStatus.rejected ||
      this == PermitStatus.cancelled ||
      this == PermitStatus.expired;
}

enum NocState {
  pending,
  granted,
  rejected,
  notApplicable;

  static NocState parse(String? raw) {
    switch ((raw ?? '').toUpperCase()) {
      case 'GRANTED':
        return NocState.granted;
      case 'REJECTED':
        return NocState.rejected;
      case 'NOT_APPLICABLE':
        return NocState.notApplicable;
      default:
        return NocState.pending;
    }
  }

  String get wire {
    switch (this) {
      case NocState.notApplicable:
        return 'NOT_APPLICABLE';
      default:
        return name.toUpperCase();
    }
  }

  String get label {
    switch (this) {
      case NocState.pending:
        return 'Pending';
      case NocState.granted:
        return 'Granted';
      case NocState.rejected:
        return 'Refused';
      case NocState.notApplicable:
        return 'Not applicable';
    }
  }
}

class PermitNoc {
  final int id;
  final String department;
  final bool isMandatory;
  final NocState status;
  final String? referenceNo;
  final String? remarks;
  final DateTime? clearedAt;

  const PermitNoc({
    required this.id,
    required this.department,
    required this.isMandatory,
    required this.status,
    this.referenceNo,
    this.remarks,
    this.clearedAt,
  });

  factory PermitNoc.fromJson(Map<String, dynamic> j) => PermitNoc(
    id: j['id'] as int,
    department: (j['department'] ?? '') as String,
    isMandatory: (j['is_mandatory'] ?? true) as bool,
    status: NocState.parse(j['status'] as String?),
    referenceNo: j['reference_no'] as String?,
    remarks: j['remarks'] as String?,
    clearedAt: _toDate(j['cleared_at']),
  );

  String get departmentLabel {
    if (department.isEmpty) return department;
    return department[0].toUpperCase() + department.substring(1);
  }
}

class PermitInspection {
  final int id;
  final String inspectionType;
  final DateTime scheduledFor;
  final int? inspectorUserId;
  final String status;
  final bool? isCompliant;
  final String? findings;
  final DateTime? inspectedAt;

  const PermitInspection({
    required this.id,
    required this.inspectionType,
    required this.scheduledFor,
    this.inspectorUserId,
    required this.status,
    this.isCompliant,
    this.findings,
    this.inspectedAt,
  });

  factory PermitInspection.fromJson(Map<String, dynamic> j) => PermitInspection(
    id: j['id'] as int,
    inspectionType: (j['inspection_type'] ?? '') as String,
    scheduledFor: _toDate(j['scheduled_for']) ?? DateTime.now(),
    inspectorUserId: j['inspector_user_id'] as int?,
    status: (j['status'] ?? 'scheduled') as String,
    isCompliant: j['is_compliant'] as bool?,
    findings: j['findings'] as String?,
    inspectedAt: _toDate(j['inspected_at']),
  );

  bool get isCompleted => status == 'completed';

  String get typeLabel => inspectionType
      .split('_')
      .where((p) => p.isNotEmpty)
      .map((p) => '${p[0].toUpperCase()}${p.substring(1)}')
      .join(' ');
}

/// What the backend says still stands between this permit and approval.
class PermitReadiness {
  final List<String> pendingNocs;
  final List<String> rejectedNocs;
  final bool feePaid;
  final double outstandingAmount;
  final bool hasCompliantInspection;
  final bool canApprove;

  const PermitReadiness({
    required this.pendingNocs,
    required this.rejectedNocs,
    required this.feePaid,
    required this.outstandingAmount,
    required this.hasCompliantInspection,
    required this.canApprove,
  });

  factory PermitReadiness.fromJson(Map<String, dynamic> j) => PermitReadiness(
    pendingNocs: ((j['pending_nocs'] ?? []) as List).map((e) => e.toString()).toList(),
    rejectedNocs:
        ((j['rejected_nocs'] ?? []) as List).map((e) => e.toString()).toList(),
    feePaid: (j['fee_paid'] ?? false) as bool,
    outstandingAmount: _toDouble(j['outstanding_amount']) ?? 0,
    hasCompliantInspection: (j['has_compliant_inspection'] ?? false) as bool,
    canApprove: (j['can_approve'] ?? false) as bool,
  );

  /// Human-readable blockers, in the order an officer would clear them.
  List<String> get blockers => [
    if (pendingNocs.isNotEmpty)
      'Clearance pending from ${pendingNocs.join(', ')}',
    if (rejectedNocs.isNotEmpty)
      'Clearance refused by ${rejectedNocs.join(', ')}',
    if (!feePaid) 'Fees outstanding',
    if (!hasCompliantInspection) 'No compliant site inspection on record',
  ];
}

/// Row shape for the list screen.
class BuildingPermitSummary {
  final int id;
  final String permitNumber;
  final int orgUnitId;
  final String? orgUnitName;
  final String applicantName;
  final String? applicantPhone;
  final String surveyNumber;
  final String? doorNumber;
  final String? streetName;
  final String constructionType;
  final String workNature;
  final double builtUpAreaSqm;
  final double plotAreaSqm;
  final int floorsProposed;
  final double totalFee;
  final double paidAmount;
  final String paymentStatus;
  final PermitStatus status;
  final DateTime? submittedAt;
  final DateTime? createdAt;
  final List<PermitNoc> nocs;
  final int inspectionCount;

  const BuildingPermitSummary({
    required this.id,
    required this.permitNumber,
    required this.orgUnitId,
    this.orgUnitName,
    required this.applicantName,
    this.applicantPhone,
    required this.surveyNumber,
    this.doorNumber,
    this.streetName,
    required this.constructionType,
    required this.workNature,
    required this.builtUpAreaSqm,
    required this.plotAreaSqm,
    required this.floorsProposed,
    required this.totalFee,
    required this.paidAmount,
    required this.paymentStatus,
    required this.status,
    this.submittedAt,
    this.createdAt,
    required this.nocs,
    required this.inspectionCount,
  });

  factory BuildingPermitSummary.fromJson(Map<String, dynamic> j) {
    final orgUnit = j['org_unit'] is Map
        ? Map<String, dynamic>.from(j['org_unit'] as Map)
        : null;
    final countMap =
        j['_count'] is Map ? Map<String, dynamic>.from(j['_count'] as Map) : null;

    return BuildingPermitSummary(
      id: j['id'] as int,
      permitNumber: (j['permit_number'] ?? '') as String,
      orgUnitId: (j['org_unit_id'] ?? 0) as int,
      orgUnitName: orgUnit?['name'] as String?,
      applicantName: (j['applicant_name'] ?? '') as String,
      applicantPhone: j['applicant_phone'] as String?,
      surveyNumber: (j['survey_number'] ?? '') as String,
      doorNumber: j['door_number'] as String?,
      streetName: j['street_name'] as String?,
      constructionType: (j['construction_type'] ?? '') as String,
      workNature: (j['work_nature'] ?? 'new') as String,
      builtUpAreaSqm: _toDouble(j['built_up_area_sqm']) ?? 0,
      plotAreaSqm: _toDouble(j['plot_area_sqm']) ?? 0,
      floorsProposed: (j['floors_proposed'] ?? 1) as int,
      totalFee: _toDouble(j['total_fee']) ?? 0,
      paidAmount: _toDouble(j['paid_amount']) ?? 0,
      paymentStatus: (j['payment_status'] ?? 'unpaid') as String,
      status: PermitStatus.parse(j['status'] as String?),
      submittedAt: _toDate(j['submitted_at']),
      createdAt: _toDate(j['created_at']),
      nocs: ((j['nocs'] ?? []) as List)
          .map((e) => PermitNoc.fromJson(e as Map<String, dynamic>))
          .toList(),
      inspectionCount: (countMap?['inspections'] ?? 0) as int,
    );
  }

  /// Site line for list rows — door + street, falling back to the survey number.
  String get siteLabel {
    final parts = [
      if (doorNumber != null && doorNumber!.isNotEmpty) doorNumber,
      if (streetName != null && streetName!.isNotEmpty) streetName,
    ];
    if (parts.isEmpty) return 'S.No. $surveyNumber';
    return '${parts.join(', ')} · S.No. $surveyNumber';
  }

  int get nocsGranted => nocs
      .where((n) => n.status == NocState.granted || n.status == NocState.notApplicable)
      .length;

  int get nocsTotal => nocs.length;
}

/// A single approval step from the workflow engine.
class PermitWorkflowStep {
  final int stepOrder;
  final String roleName;
  final String actionType;
  final bool isCurrent;
  final String? action;
  final String? comments;
  final DateTime? actedAt;

  const PermitWorkflowStep({
    required this.stepOrder,
    required this.roleName,
    required this.actionType,
    required this.isCurrent,
    this.action,
    this.comments,
    this.actedAt,
  });
}

/// The workflow instance plus its steps, flattened for rendering.
class PermitWorkflow {
  final int instanceId;
  final String status;
  final String templateName;
  final List<PermitWorkflowStep> steps;

  const PermitWorkflow({
    required this.instanceId,
    required this.status,
    required this.templateName,
    required this.steps,
  });

  static PermitWorkflow? fromJson(Map<String, dynamic>? j) {
    if (j == null) return null;
    final template = j['template'] is Map
        ? Map<String, dynamic>.from(j['template'] as Map)
        : const <String, dynamic>{};
    final actions = ((j['actions'] ?? []) as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final currentOrder = (j['current_step_order'] ?? 1) as int;

    final steps = ((template['steps'] ?? []) as List).map((raw) {
      final s = Map<String, dynamic>.from(raw as Map);
      final stepId = s['id'] as int?;
      final acted = actions.where((a) => a['step_id'] == stepId).toList();
      final last = acted.isNotEmpty ? acted.last : null;
      final order = (s['step_order'] ?? 0) as int;

      return PermitWorkflowStep(
        stepOrder: order,
        roleName: (s['role_name'] ?? '') as String,
        actionType: (s['action_type'] ?? '') as String,
        isCurrent: order == currentOrder && j['status'] == 'in_progress',
        action: last?['action'] as String?,
        comments: last?['comments'] as String?,
        actedAt: _toDate(last?['acted_at']),
      );
    }).toList()
      ..sort((a, b) => a.stepOrder.compareTo(b.stepOrder));

    return PermitWorkflow(
      instanceId: (j['id'] ?? 0) as int,
      status: (j['status'] ?? '') as String,
      templateName: (template['name'] ?? '') as String,
      steps: steps,
    );
  }
}

class PermitDocument {
  final int id;
  final String title;
  final String fileName;
  final String? fileUrl;
  final String? mimeType;
  final int version;
  final DateTime? createdAt;

  const PermitDocument({
    required this.id,
    required this.title,
    required this.fileName,
    this.fileUrl,
    this.mimeType,
    required this.version,
    this.createdAt,
  });

  factory PermitDocument.fromJson(Map<String, dynamic> j) => PermitDocument(
    id: j['id'] as int,
    title: (j['title'] ?? '') as String,
    fileName: (j['file_name'] ?? '') as String,
    fileUrl: j['file_url'] as String?,
    mimeType: j['mime_type'] as String?,
    version: (j['version'] ?? 1) as int,
    createdAt: _toDate(j['created_at']),
  );

  bool get isPdf => (mimeType ?? '').contains('pdf');
}

/// Live SLA clock for the permit, if a policy is configured.
class PermitSla {
  final String status;
  final DateTime targetAt;
  final DateTime breachAt;
  final DateTime? resolvedAt;

  const PermitSla({
    required this.status,
    required this.targetAt,
    required this.breachAt,
    this.resolvedAt,
  });

  static PermitSla? fromJson(Map<String, dynamic>? j) {
    if (j == null) return null;
    final target = _toDate(j['target_at']);
    final breach = _toDate(j['breach_at']);
    if (target == null || breach == null) return null;
    return PermitSla(
      status: (j['status'] ?? 'on_track') as String,
      targetAt: target,
      breachAt: breach,
      resolvedAt: _toDate(j['resolved_at']),
    );
  }

  bool get isBreached => status == 'breached';
  bool get isAtRisk => status == 'warning' || status == 'escalated';
}

/// One entry from the immutable audit trail.
class PermitHistoryEntry {
  final String id;
  final String action;
  final int? userId;
  final DateTime? createdAt;

  const PermitHistoryEntry({
    required this.id,
    required this.action,
    this.userId,
    this.createdAt,
  });

  factory PermitHistoryEntry.fromJson(Map<String, dynamic> j) =>
      PermitHistoryEntry(
        id: j['id'].toString(),
        action: (j['action'] ?? '') as String,
        userId: j['user_id'] as int?,
        createdAt: _toDate(j['created_at']),
      );

  String get label => action
      .replaceAll('_', ' ')
      .split(' ')
      .where((p) => p.isNotEmpty)
      .map((p) => '${p[0].toUpperCase()}${p.substring(1)}')
      .join(' ');
}

/// The full permit file, as returned by `GET /api/building-permits/:id`.
class BuildingPermitDetail {
  final BuildingPermitSummary summary;

  final String? applicantEmail;
  final String? applicantAddress;
  final String? applicantAadhaar;
  final bool isOwner;
  final String? powerOfAttorney;

  final String? subdivisionNo;
  final String? wardNumber;
  final double? latitude;
  final double? longitude;

  final double? heightM;
  final double? setbackFrontM;
  final double? setbackRearM;
  final double? setbackLeftM;
  final double? setbackRightM;
  final double? estimatedCost;
  final String? architectName;
  final String? architectLicence;

  final double scrutinyFee;
  final double permitFee;
  final double developmentFee;
  final String? paymentRef;

  final String? rejectionReason;
  final DateTime? approvedAt;
  final DateTime? validUntil;

  final List<PermitNoc> nocs;
  final List<PermitInspection> inspections;
  final List<PermitDocument> documents;
  final List<PermitHistoryEntry> history;
  final PermitWorkflow? workflow;
  final PermitSla? sla;
  final PermitReadiness readiness;

  const BuildingPermitDetail({
    required this.summary,
    this.applicantEmail,
    this.applicantAddress,
    this.applicantAadhaar,
    required this.isOwner,
    this.powerOfAttorney,
    this.subdivisionNo,
    this.wardNumber,
    this.latitude,
    this.longitude,
    this.heightM,
    this.setbackFrontM,
    this.setbackRearM,
    this.setbackLeftM,
    this.setbackRightM,
    this.estimatedCost,
    this.architectName,
    this.architectLicence,
    required this.scrutinyFee,
    required this.permitFee,
    required this.developmentFee,
    this.paymentRef,
    this.rejectionReason,
    this.approvedAt,
    this.validUntil,
    required this.nocs,
    required this.inspections,
    required this.documents,
    required this.history,
    this.workflow,
    this.sla,
    required this.readiness,
  });

  factory BuildingPermitDetail.fromJson(Map<String, dynamic> j) {
    return BuildingPermitDetail(
      summary: BuildingPermitSummary.fromJson(j),
      applicantEmail: j['applicant_email'] as String?,
      applicantAddress: j['applicant_address'] as String?,
      applicantAadhaar: j['applicant_aadhaar'] as String?,
      isOwner: (j['is_owner'] ?? true) as bool,
      powerOfAttorney: j['power_of_attorney'] as String?,
      subdivisionNo: j['subdivision_no'] as String?,
      wardNumber: j['ward_number'] as String?,
      latitude: _toDouble(j['latitude']),
      longitude: _toDouble(j['longitude']),
      heightM: _toDouble(j['height_m']),
      setbackFrontM: _toDouble(j['setback_front_m']),
      setbackRearM: _toDouble(j['setback_rear_m']),
      setbackLeftM: _toDouble(j['setback_left_m']),
      setbackRightM: _toDouble(j['setback_right_m']),
      estimatedCost: _toDouble(j['estimated_cost']),
      architectName: j['architect_name'] as String?,
      architectLicence: j['architect_licence'] as String?,
      scrutinyFee: _toDouble(j['scrutiny_fee']) ?? 0,
      permitFee: _toDouble(j['permit_fee']) ?? 0,
      developmentFee: _toDouble(j['development_fee']) ?? 0,
      paymentRef: j['payment_ref'] as String?,
      rejectionReason: j['rejection_reason'] as String?,
      approvedAt: _toDate(j['approved_at']),
      validUntil: _toDate(j['valid_until']),
      nocs: ((j['nocs'] ?? []) as List)
          .map((e) => PermitNoc.fromJson(e as Map<String, dynamic>))
          .toList(),
      inspections: ((j['inspections'] ?? []) as List)
          .map((e) => PermitInspection.fromJson(e as Map<String, dynamic>))
          .toList(),
      documents: ((j['documents'] ?? []) as List)
          .map((e) => PermitDocument.fromJson(e as Map<String, dynamic>))
          .toList(),
      history: ((j['history'] ?? []) as List)
          .map((e) => PermitHistoryEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      workflow: PermitWorkflow.fromJson(
        j['workflow'] is Map ? Map<String, dynamic>.from(j['workflow'] as Map) : null,
      ),
      sla: PermitSla.fromJson(
        j['sla'] is Map ? Map<String, dynamic>.from(j['sla'] as Map) : null,
      ),
      readiness: PermitReadiness.fromJson(
        j['readiness'] is Map
            ? Map<String, dynamic>.from(j['readiness'] as Map)
            : const <String, dynamic>{},
      ),
    );
  }

  int get id => summary.id;
  PermitStatus get status => summary.status;
  double get outstanding => summary.totalFee - summary.paidAmount;
}

/// KPI counters for the list screen header.
class BuildingPermitStats {
  final int total;
  final int pendingAction;
  final int approved;
  final int rejected;
  final double feesCollected;
  final int slaAtRisk;
  final Map<String, int> byStatus;

  const BuildingPermitStats({
    required this.total,
    required this.pendingAction,
    required this.approved,
    required this.rejected,
    required this.feesCollected,
    required this.slaAtRisk,
    required this.byStatus,
  });

  factory BuildingPermitStats.fromJson(Map<String, dynamic> j) {
    final raw = j['by_status'] is Map
        ? Map<String, dynamic>.from(j['by_status'] as Map)
        : const <String, dynamic>{};
    return BuildingPermitStats(
      total: (j['total'] ?? 0) as int,
      pendingAction: (j['pending_action'] ?? 0) as int,
      approved: (j['approved'] ?? 0) as int,
      rejected: (j['rejected'] ?? 0) as int,
      feesCollected: _toDouble(j['fees_collected']) ?? 0,
      slaAtRisk: (j['sla_at_risk'] ?? 0) as int,
      byStatus: raw.map((k, v) => MapEntry(k, (v ?? 0) as int)),
    );
  }

  static const empty = BuildingPermitStats(
    total: 0,
    pendingAction: 0,
    approved: 0,
    rejected: 0,
    feesCollected: 0,
    slaAtRisk: 0,
    byStatus: {},
  );
}

/// Paged list response.
class BuildingPermitPage {
  final int total;
  final List<BuildingPermitSummary> items;

  const BuildingPermitPage({required this.total, required this.items});

  factory BuildingPermitPage.fromJson(Map<String, dynamic> j) =>
      BuildingPermitPage(
        total: (j['total'] ?? 0) as int,
        items: ((j['items'] ?? []) as List)
            .map((e) => BuildingPermitSummary.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  static const empty = BuildingPermitPage(total: 0, items: []);
}

/// Option lists kept in sync with the DTO constants on the backend.
const kConstructionTypes = <String>[
  'residential',
  'commercial',
  'industrial',
  'institutional',
  'mixed',
];

const kWorkNatures = <String>[
  'new',
  'extension',
  'alteration',
  'reconstruction',
];

const kNocDepartments = <String>[
  'fire',
  'traffic',
  'electricity',
  'highways',
  'pollution',
  'airport',
  'water',
  'health',
];

const kInspectionTypes = <String>[
  'site_verification',
  'plinth_level',
  'completion',
];

String titleCase(String raw) => raw
    .replaceAll('_', ' ')
    .split(' ')
    .where((p) => p.isNotEmpty)
    .map((p) => '${p[0].toUpperCase()}${p.substring(1)}')
    .join(' ');
