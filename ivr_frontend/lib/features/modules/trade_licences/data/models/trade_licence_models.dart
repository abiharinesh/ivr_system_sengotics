import 'package:flutter/material.dart';
import 'package:ivr_frontend/config/app_theme.dart';

/// Data classes for trade licences. Mirror the JSON served by
/// `src/trade-licence/`.

double? _toDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

DateTime? _toDate(dynamic v) {
  if (v == null) return null;
  return DateTime.tryParse(v.toString());
}

String titleCase(String raw) => raw
    .replaceAll('_', ' ')
    .split(' ')
    .where((p) => p.isNotEmpty)
    .map((p) => '${p[0].toUpperCase()}${p.substring(1)}')
    .join(' ');

enum LicenceStatus {
  draft,
  submitted,
  inspection,
  approved,
  rejected,
  expired,
  suspended,
  cancelled;

  static LicenceStatus parse(String? raw) {
    switch ((raw ?? '').toUpperCase()) {
      case 'SUBMITTED':
        return LicenceStatus.submitted;
      case 'INSPECTION':
        return LicenceStatus.inspection;
      case 'APPROVED':
        return LicenceStatus.approved;
      case 'REJECTED':
        return LicenceStatus.rejected;
      case 'EXPIRED':
        return LicenceStatus.expired;
      case 'SUSPENDED':
        return LicenceStatus.suspended;
      case 'CANCELLED':
        return LicenceStatus.cancelled;
      default:
        return LicenceStatus.draft;
    }
  }

  String get wire => name.toUpperCase();

  String get label {
    switch (this) {
      case LicenceStatus.draft:
        return 'Draft';
      case LicenceStatus.submitted:
        return 'Submitted';
      case LicenceStatus.inspection:
        return 'Inspection';
      case LicenceStatus.approved:
        return 'Active';
      case LicenceStatus.rejected:
        return 'Rejected';
      case LicenceStatus.expired:
        return 'Expired';
      case LicenceStatus.suspended:
        return 'Suspended';
      case LicenceStatus.cancelled:
        return 'Cancelled';
    }
  }

  Color get color {
    switch (this) {
      case LicenceStatus.approved:
        return AppTheme.accent;
      case LicenceStatus.rejected:
      case LicenceStatus.cancelled:
        return AppTheme.error;
      case LicenceStatus.suspended:
        return const Color(0xFFEA580C);
      case LicenceStatus.expired:
        return const Color(0xFF9333EA);
      case LicenceStatus.inspection:
        return AppTheme.info;
      case LicenceStatus.submitted:
        return AppTheme.primary;
      case LicenceStatus.draft:
        return AppTheme.textMuted;
    }
  }

  bool get isEditable =>
      this == LicenceStatus.draft || this == LicenceStatus.submitted;

  /// A licence in one of these states can be rolled into the next year,
  /// subject to the lapse window the backend enforces.
  bool get isRenewable =>
      this == LicenceStatus.approved || this == LicenceStatus.expired;

  bool get isTerminal =>
      this == LicenceStatus.rejected || this == LicenceStatus.cancelled;
}

/// Statutory late-renewal bands.
enum PenaltyBand {
  ontime,
  late30,
  late90,
  lapsed;

  static PenaltyBand parse(String? raw) {
    switch (raw) {
      case 'late_30':
        return PenaltyBand.late30;
      case 'late_90':
        return PenaltyBand.late90;
      case 'lapsed':
        return PenaltyBand.lapsed;
      default:
        return PenaltyBand.ontime;
    }
  }

  String get label {
    switch (this) {
      case PenaltyBand.ontime:
        return 'On time';
      case PenaltyBand.late30:
        return 'Late — penalty';
      case PenaltyBand.late90:
        return 'Late — higher penalty';
      case PenaltyBand.lapsed:
        return 'Lapsed';
    }
  }

  Color get color {
    switch (this) {
      case PenaltyBand.ontime:
        return AppTheme.accent;
      case PenaltyBand.late30:
        return AppTheme.warning;
      case PenaltyBand.late90:
        return const Color(0xFFEA580C);
      case PenaltyBand.lapsed:
        return AppTheme.error;
    }
  }
}

class LicenceRenewal {
  final int id;
  final String licenceYear;
  final DateTime validFrom;
  final DateTime validUntil;
  final int daysLate;
  final PenaltyBand penaltyBand;
  final double baseFee;
  final double areaFee;
  final double powerFee;
  final double penaltyFee;
  final double totalFee;
  final double paidAmount;
  final bool isInitialGrant;
  final DateTime? renewedAt;

  const LicenceRenewal({
    required this.id,
    required this.licenceYear,
    required this.validFrom,
    required this.validUntil,
    required this.daysLate,
    required this.penaltyBand,
    required this.baseFee,
    required this.areaFee,
    required this.powerFee,
    required this.penaltyFee,
    required this.totalFee,
    required this.paidAmount,
    required this.isInitialGrant,
    this.renewedAt,
  });

  factory LicenceRenewal.fromJson(Map<String, dynamic> j) => LicenceRenewal(
    id: j['id'] as int,
    licenceYear: (j['licence_year'] ?? '') as String,
    validFrom: _toDate(j['valid_from']) ?? DateTime.now(),
    validUntil: _toDate(j['valid_until']) ?? DateTime.now(),
    daysLate: (j['days_late'] ?? 0) as int,
    penaltyBand: PenaltyBand.parse(j['penalty_band'] as String?),
    baseFee: _toDouble(j['base_fee']) ?? 0,
    areaFee: _toDouble(j['area_fee']) ?? 0,
    powerFee: _toDouble(j['power_fee']) ?? 0,
    penaltyFee: _toDouble(j['penalty_fee']) ?? 0,
    totalFee: _toDouble(j['total_fee']) ?? 0,
    paidAmount: _toDouble(j['paid_amount']) ?? 0,
    isInitialGrant: (j['is_initial_grant'] ?? false) as bool,
    renewedAt: _toDate(j['renewed_at']),
  );

  bool get isPaid => paidAmount >= totalFee;
}

class LicenceInspection {
  final int id;
  final String inspectionType;
  final DateTime scheduledFor;
  final String status;
  final bool? isCompliant;
  final String? findings;
  final List<String> violations;
  final DateTime? inspectedAt;

  const LicenceInspection({
    required this.id,
    required this.inspectionType,
    required this.scheduledFor,
    required this.status,
    this.isCompliant,
    this.findings,
    required this.violations,
    this.inspectedAt,
  });

  factory LicenceInspection.fromJson(Map<String, dynamic> j) =>
      LicenceInspection(
        id: j['id'] as int,
        inspectionType: (j['inspection_type'] ?? '') as String,
        scheduledFor: _toDate(j['scheduled_for']) ?? DateTime.now(),
        status: (j['status'] ?? 'scheduled') as String,
        isCompliant: j['is_compliant'] as bool?,
        findings: j['findings'] as String?,
        violations:
            ((j['violations'] ?? []) as List).map((e) => e.toString()).toList(),
        inspectedAt: _toDate(j['inspected_at']),
      );

  bool get isCompleted => status == 'completed';
  String get typeLabel => titleCase(inspectionType);
}

class LicenceCertificate {
  final int id;
  final String licenceYear;
  final String certificateNumber;
  final String? verificationToken;
  final int copyNumber;
  final String? sealHash;
  final DateTime? issuedAt;
  final bool isCancelled;
  final String? cancelledReason;

  const LicenceCertificate({
    required this.id,
    required this.licenceYear,
    required this.certificateNumber,
    this.verificationToken,
    required this.copyNumber,
    this.sealHash,
    this.issuedAt,
    required this.isCancelled,
    this.cancelledReason,
  });

  factory LicenceCertificate.fromJson(Map<String, dynamic> j) =>
      LicenceCertificate(
        id: j['id'] as int,
        licenceYear: (j['licence_year'] ?? '') as String,
        certificateNumber: (j['certificate_number'] ?? '') as String,
        verificationToken: j['verification_token'] as String?,
        copyNumber: (j['copy_number'] ?? 1) as int,
        sealHash: j['seal_hash'] as String?,
        issuedAt: _toDate(j['issued_at']),
        isCancelled: (j['is_cancelled'] ?? false) as bool,
        cancelledReason: j['cancelled_reason'] as String?,
      );

  String get copyLabel =>
      copyNumber == 1 ? 'Original' : 'Duplicate $copyNumber';
}

/// What stands between this licence and approval or renewal.
class LicenceReadiness {
  final bool feePaid;
  final double outstandingAmount;
  final bool requiresInspection;
  final bool hasCompliantInspection;
  final List<String> expiredReferences;
  final List<String> blockers;
  final bool canApprove;

  const LicenceReadiness({
    required this.feePaid,
    required this.outstandingAmount,
    required this.requiresInspection,
    required this.hasCompliantInspection,
    required this.expiredReferences,
    required this.blockers,
    required this.canApprove,
  });

  factory LicenceReadiness.fromJson(Map<String, dynamic> j) => LicenceReadiness(
    feePaid: (j['fee_paid'] ?? false) as bool,
    outstandingAmount: _toDouble(j['outstanding_amount']) ?? 0,
    requiresInspection: (j['requires_inspection'] ?? false) as bool,
    hasCompliantInspection: (j['has_compliant_inspection'] ?? false) as bool,
    expiredReferences: ((j['expired_references'] ?? []) as List)
        .map((e) => e.toString())
        .toList(),
    blockers: ((j['blockers'] ?? []) as List).map((e) => e.toString()).toList(),
    canApprove: (j['can_approve'] ?? false) as bool,
  );
}

/// Row shape for the register.
class TradeLicenceSummary {
  final int id;
  final String licenceNumber;
  final int orgUnitId;
  final String? orgUnitName;
  final LicenceStatus status;
  final String tradeName;
  final String tradeCategory;
  final String? tradeSubCategory;
  final double? motivePowerHp;
  final String ownerName;
  final String? ownerPhone;
  final String? doorNumber;
  final String? streetName;
  final String? wardNumber;
  final double areaSqft;
  final String? licenceYear;
  final DateTime? validFrom;
  final DateTime? validUntil;
  final double totalFee;
  final double paidAmount;
  final String paymentStatus;
  final int renewalCount;
  final int inspectionCount;

  const TradeLicenceSummary({
    required this.id,
    required this.licenceNumber,
    required this.orgUnitId,
    this.orgUnitName,
    required this.status,
    required this.tradeName,
    required this.tradeCategory,
    this.tradeSubCategory,
    this.motivePowerHp,
    required this.ownerName,
    this.ownerPhone,
    this.doorNumber,
    this.streetName,
    this.wardNumber,
    required this.areaSqft,
    this.licenceYear,
    this.validFrom,
    this.validUntil,
    required this.totalFee,
    required this.paidAmount,
    required this.paymentStatus,
    required this.renewalCount,
    required this.inspectionCount,
  });

  factory TradeLicenceSummary.fromJson(Map<String, dynamic> j) {
    final orgUnit =
        j['org_unit'] is Map ? Map<String, dynamic>.from(j['org_unit'] as Map) : null;
    final countMap =
        j['_count'] is Map ? Map<String, dynamic>.from(j['_count'] as Map) : null;

    return TradeLicenceSummary(
      id: j['id'] as int,
      licenceNumber: (j['licence_number'] ?? '') as String,
      orgUnitId: (j['org_unit_id'] ?? 0) as int,
      orgUnitName: orgUnit?['name'] as String?,
      status: LicenceStatus.parse(j['status'] as String?),
      tradeName: (j['trade_name'] ?? '') as String,
      tradeCategory: (j['trade_category'] ?? '') as String,
      tradeSubCategory: j['trade_sub_category'] as String?,
      motivePowerHp: _toDouble(j['motive_power_hp']),
      ownerName: (j['owner_name'] ?? '') as String,
      ownerPhone: j['owner_phone'] as String?,
      doorNumber: j['door_number'] as String?,
      streetName: j['street_name'] as String?,
      wardNumber: j['ward_number'] as String?,
      areaSqft: _toDouble(j['area_sqft']) ?? 0,
      licenceYear: j['licence_year'] as String?,
      validFrom: _toDate(j['valid_from']),
      validUntil: _toDate(j['valid_until']),
      totalFee: _toDouble(j['total_fee']) ?? 0,
      paidAmount: _toDouble(j['paid_amount']) ?? 0,
      paymentStatus: (j['payment_status'] ?? 'unpaid') as String,
      renewalCount: (countMap?['renewals'] ?? 0) as int,
      inspectionCount: (countMap?['inspections'] ?? 0) as int,
    );
  }

  String get premisesLabel {
    final parts = [
      if (doorNumber != null && doorNumber!.isNotEmpty) doorNumber,
      if (streetName != null && streetName!.isNotEmpty) streetName,
      if (wardNumber != null && wardNumber!.isNotEmpty) 'Ward $wardNumber',
    ];
    return parts.isEmpty ? 'Premises not recorded' : parts.join(', ');
  }

  double get outstanding => totalFee - paidAmount;

  /// Days until expiry — negative once it has already lapsed. Null when the
  /// licence was never granted.
  int? get daysToExpiry {
    if (validUntil == null) return null;
    final today = DateTime.now();
    return DateTime(validUntil!.year, validUntil!.month, validUntil!.day)
        .difference(DateTime(today.year, today.month, today.day))
        .inDays;
  }

  bool get isExpiringSoon {
    final d = daysToExpiry;
    return status == LicenceStatus.approved && d != null && d >= 0 && d <= 30;
  }

  bool get isOverdue {
    final d = daysToExpiry;
    return d != null && d < 0 && !status.isTerminal;
  }
}

class TradeLicenceDetail {
  final TradeLicenceSummary summary;
  final String? description;
  final String? ownershipType;
  final String? signatoryName;
  final String? ownerEmail;
  final String? ownerAddress;
  final String? ownerAadhaar;
  final int? workerCount;
  final String? operatingHours;
  final String? surveyNumber;
  final bool isRented;
  final String? landlordName;
  final String? fssaiNumber;
  final DateTime? fssaiExpiry;
  final String? gstNumber;
  final String? fireNocRef;
  final DateTime? fireNocExpiry;
  final String? pollutionConsentRef;
  final DateTime? pollutionConsentExpiry;
  final double baseFee;
  final double areaFee;
  final double powerFee;
  final double penaltyFee;
  final String? paymentRef;
  final String? rejectionReason;
  final String? suspensionReason;
  final String? cancelledReason;
  final DateTime? approvedAt;
  final List<LicenceRenewal> renewals;
  final List<LicenceInspection> inspections;
  final List<LicenceCertificate> certificates;
  final List<LicenceHistoryEntry> history;
  final LicenceReadiness readiness;

  const TradeLicenceDetail({
    required this.summary,
    this.description,
    this.ownershipType,
    this.signatoryName,
    this.ownerEmail,
    this.ownerAddress,
    this.ownerAadhaar,
    this.workerCount,
    this.operatingHours,
    this.surveyNumber,
    required this.isRented,
    this.landlordName,
    this.fssaiNumber,
    this.fssaiExpiry,
    this.gstNumber,
    this.fireNocRef,
    this.fireNocExpiry,
    this.pollutionConsentRef,
    this.pollutionConsentExpiry,
    required this.baseFee,
    required this.areaFee,
    required this.powerFee,
    required this.penaltyFee,
    this.paymentRef,
    this.rejectionReason,
    this.suspensionReason,
    this.cancelledReason,
    this.approvedAt,
    required this.renewals,
    required this.inspections,
    required this.certificates,
    required this.history,
    required this.readiness,
  });

  factory TradeLicenceDetail.fromJson(Map<String, dynamic> j) =>
      TradeLicenceDetail(
        summary: TradeLicenceSummary.fromJson(j),
        description: j['description'] as String?,
        ownershipType: j['ownership_type'] as String?,
        signatoryName: j['signatory_name'] as String?,
        ownerEmail: j['owner_email'] as String?,
        ownerAddress: j['owner_address'] as String?,
        ownerAadhaar: j['owner_aadhaar'] as String?,
        workerCount: j['worker_count'] as int?,
        operatingHours: j['operating_hours'] as String?,
        surveyNumber: j['survey_number'] as String?,
        isRented: (j['is_rented'] ?? false) as bool,
        landlordName: j['landlord_name'] as String?,
        fssaiNumber: j['fssai_number'] as String?,
        fssaiExpiry: _toDate(j['fssai_expiry']),
        gstNumber: j['gst_number'] as String?,
        fireNocRef: j['fire_noc_ref'] as String?,
        fireNocExpiry: _toDate(j['fire_noc_expiry']),
        pollutionConsentRef: j['pollution_consent_ref'] as String?,
        pollutionConsentExpiry: _toDate(j['pollution_consent_expiry']),
        baseFee: _toDouble(j['base_fee']) ?? 0,
        areaFee: _toDouble(j['area_fee']) ?? 0,
        powerFee: _toDouble(j['power_fee']) ?? 0,
        penaltyFee: _toDouble(j['penalty_fee']) ?? 0,
        paymentRef: j['payment_ref'] as String?,
        rejectionReason: j['rejection_reason'] as String?,
        suspensionReason: j['suspension_reason'] as String?,
        cancelledReason: j['cancelled_reason'] as String?,
        approvedAt: _toDate(j['approved_at']),
        renewals: ((j['renewals'] ?? []) as List)
            .map((e) => LicenceRenewal.fromJson(e as Map<String, dynamic>))
            .toList(),
        inspections: ((j['inspections'] ?? []) as List)
            .map((e) => LicenceInspection.fromJson(e as Map<String, dynamic>))
            .toList(),
        certificates: ((j['certificates'] ?? []) as List)
            .map((e) => LicenceCertificate.fromJson(e as Map<String, dynamic>))
            .toList(),
        history: ((j['history'] ?? []) as List)
            .map((e) => LicenceHistoryEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
        readiness: LicenceReadiness.fromJson(
          j['readiness'] is Map
              ? Map<String, dynamic>.from(j['readiness'] as Map)
              : const <String, dynamic>{},
        ),
      );

  int get id => summary.id;
  LicenceStatus get status => summary.status;

  List<LicenceCertificate> get liveCertificates =>
      certificates.where((c) => !c.isCancelled).toList();

  /// Statutory references the trade holds, with whether each has lapsed.
  List<({String label, String? ref, DateTime? expiry})> get statutoryRefs => [
        if (fssaiNumber != null) (label: 'FSSAI', ref: fssaiNumber, expiry: fssaiExpiry),
        if (gstNumber != null) (label: 'GSTIN', ref: gstNumber, expiry: null),
        if (fireNocRef != null)
          (label: 'Fire NOC', ref: fireNocRef, expiry: fireNocExpiry),
        if (pollutionConsentRef != null)
          (
            label: 'Pollution consent',
            ref: pollutionConsentRef,
            expiry: pollutionConsentExpiry,
          ),
      ];
}

class LicenceHistoryEntry {
  final String id;
  final String action;
  final int? userId;
  final DateTime? createdAt;

  const LicenceHistoryEntry({
    required this.id,
    required this.action,
    this.userId,
    this.createdAt,
  });

  factory LicenceHistoryEntry.fromJson(Map<String, dynamic> j) =>
      LicenceHistoryEntry(
        id: j['id'].toString(),
        action: (j['action'] ?? '') as String,
        userId: j['user_id'] as int?,
        createdAt: _toDate(j['created_at']),
      );

  String get label => titleCase(action);
}

/// Result of a public QR verification.
class LicenceVerification {
  final bool valid;
  final bool lapsed;
  final String status;
  final String? cancelledReason;
  final String certificateNumber;
  final String licenceNumber;
  final String licenceYear;
  final int copyNumber;
  final String? sealHash;
  final String tradeName;
  final String tradeCategory;
  final String ownerName;
  final String premises;
  final DateTime? validFrom;
  final DateTime? validUntil;
  final String issuingAuthority;

  const LicenceVerification({
    required this.valid,
    required this.lapsed,
    required this.status,
    this.cancelledReason,
    required this.certificateNumber,
    required this.licenceNumber,
    required this.licenceYear,
    required this.copyNumber,
    this.sealHash,
    required this.tradeName,
    required this.tradeCategory,
    required this.ownerName,
    required this.premises,
    this.validFrom,
    this.validUntil,
    required this.issuingAuthority,
  });

  factory LicenceVerification.fromJson(Map<String, dynamic> j) =>
      LicenceVerification(
        valid: (j['valid'] ?? false) as bool,
        lapsed: (j['lapsed'] ?? false) as bool,
        status: (j['status'] ?? '') as String,
        cancelledReason: j['cancelled_reason'] as String?,
        certificateNumber: (j['certificate_number'] ?? '') as String,
        licenceNumber: (j['licence_number'] ?? '') as String,
        licenceYear: (j['licence_year'] ?? '') as String,
        copyNumber: (j['copy_number'] ?? 1) as int,
        sealHash: j['seal_hash'] as String?,
        tradeName: (j['trade_name'] ?? '') as String,
        tradeCategory: (j['trade_category'] ?? '') as String,
        ownerName: (j['owner_name'] ?? '') as String,
        premises: (j['premises'] ?? '') as String,
        validFrom: _toDate(j['valid_from']),
        validUntil: _toDate(j['valid_until']),
        issuingAuthority: (j['issuing_authority'] ?? '') as String,
      );
}

class TradeLicenceStats {
  final String licenceYear;
  final int total;
  final int active;
  final int pendingAction;
  final int expiringSoon;
  final int overdue;
  final int suspended;
  final double feesCollected;
  final Map<String, int> byStatus;

  const TradeLicenceStats({
    required this.licenceYear,
    required this.total,
    required this.active,
    required this.pendingAction,
    required this.expiringSoon,
    required this.overdue,
    required this.suspended,
    required this.feesCollected,
    required this.byStatus,
  });

  factory TradeLicenceStats.fromJson(Map<String, dynamic> j) {
    final raw = j['by_status'] is Map
        ? Map<String, dynamic>.from(j['by_status'] as Map)
        : const <String, dynamic>{};
    return TradeLicenceStats(
      licenceYear: (j['licence_year'] ?? '') as String,
      total: (j['total'] ?? 0) as int,
      active: (j['active'] ?? 0) as int,
      pendingAction: (j['pending_action'] ?? 0) as int,
      expiringSoon: (j['expiring_soon'] ?? 0) as int,
      overdue: (j['overdue'] ?? 0) as int,
      suspended: (j['suspended'] ?? 0) as int,
      feesCollected: _toDouble(j['fees_collected']) ?? 0,
      byStatus: raw.map((k, v) => MapEntry(k, (v ?? 0) as int)),
    );
  }

  static const empty = TradeLicenceStats(
    licenceYear: '',
    total: 0,
    active: 0,
    pendingAction: 0,
    expiringSoon: 0,
    overdue: 0,
    suspended: 0,
    feesCollected: 0,
    byStatus: {},
  );
}

class TradeLicencePage {
  final int total;
  final List<TradeLicenceSummary> items;

  const TradeLicencePage({required this.total, required this.items});

  factory TradeLicencePage.fromJson(Map<String, dynamic> j) => TradeLicencePage(
    total: (j['total'] ?? 0) as int,
    items: ((j['items'] ?? []) as List)
        .map((e) => TradeLicenceSummary.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  static const empty = TradeLicencePage(total: 0, items: []);
}

// ── Option lists, kept in sync with the backend DTO constants ──────────────

const kTradeCategories = <String>[
  'eatery',
  'provision_store',
  'workshop',
  'godown',
  'clinic',
  'salon',
  'bakery',
  'laundry',
  'timber_depot',
  'other',
];

const kOwnershipTypes = <String>[
  'PROPRIETOR',
  'PARTNERSHIP',
  'PRIVATE_LIMITED',
  'PUBLIC_LIMITED',
  'SOCIETY',
  'TRUST',
  'COOPERATIVE',
];

const kLicenceInspectionTypes = <String>[
  'pre_licence',
  'annual',
  'complaint_driven',
  're_inspection',
];
