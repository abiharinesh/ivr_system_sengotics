/// Data classes for the birth & death register. Mirror the JSON served by
/// `src/vital-events/`.

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

enum VitalEventType {
  birth,
  death;

  static VitalEventType parse(String? raw) =>
      (raw ?? '').toUpperCase() == 'DEATH'
          ? VitalEventType.death
          : VitalEventType.birth;

  String get wire => name.toUpperCase();
  String get label => this == VitalEventType.birth ? 'Birth' : 'Death';
}

/// Lifecycle of a register entry. `registered` is the legal act; `corrected`
/// marks an amendment under s.15.
enum VitalStatus {
  reported,
  verified,
  registered,
  rejected,
  corrected;

  static VitalStatus parse(String? raw) {
    switch ((raw ?? '').toUpperCase()) {
      case 'VERIFIED':
        return VitalStatus.verified;
      case 'REGISTERED':
        return VitalStatus.registered;
      case 'REJECTED':
        return VitalStatus.rejected;
      case 'CORRECTED':
        return VitalStatus.corrected;
      default:
        return VitalStatus.reported;
    }
  }

  String get wire => name.toUpperCase();

  String get label {
    switch (this) {
      case VitalStatus.reported:
        return 'Reported';
      case VitalStatus.verified:
        return 'Verified';
      case VitalStatus.registered:
        return 'Registered';
      case VitalStatus.rejected:
        return 'Rejected';
      case VitalStatus.corrected:
        return 'Corrected';
    }
  }

  /// Particulars may only be edited freely before the entry is in the register.
  bool get isEditable =>
      this == VitalStatus.reported || this == VitalStatus.verified;

  /// A certificate can only be issued against an entry that is in the register.
  bool get isInRegister =>
      this == VitalStatus.registered || this == VitalStatus.corrected;
}

enum ReportingSource {
  hospital,
  institution,
  domiciliary,
  selfReported;

  static ReportingSource parse(String? raw) {
    switch ((raw ?? '').toUpperCase()) {
      case 'HOSPITAL':
        return ReportingSource.hospital;
      case 'INSTITUTION':
        return ReportingSource.institution;
      case 'DOMICILIARY':
        return ReportingSource.domiciliary;
      default:
        return ReportingSource.selfReported;
    }
  }

  String get wire =>
      this == ReportingSource.selfReported ? 'SELF_REPORTED' : name.toUpperCase();

  String get label {
    switch (this) {
      case ReportingSource.hospital:
        return 'Hospital';
      case ReportingSource.institution:
        return 'Institution';
      case ReportingSource.domiciliary:
        return 'Domiciliary';
      case ReportingSource.selfReported:
        return 'Self-reported';
    }
  }
}

/// Statutory late-registration bands under s.13.
enum DelayBand {
  ordinary,
  lateFee,
  authorityPermission,
  magistrateOrder;

  static DelayBand parse(String? raw) {
    switch (raw) {
      case 'late_fee':
        return DelayBand.lateFee;
      case 'authority_permission':
        return DelayBand.authorityPermission;
      case 'magistrate_order':
        return DelayBand.magistrateOrder;
      default:
        return DelayBand.ordinary;
    }
  }

  String get label {
    switch (this) {
      case DelayBand.ordinary:
        return 'Within statutory window';
      case DelayBand.lateFee:
        return 'Late fee payable';
      case DelayBand.authorityPermission:
        return 'Authority permission needed';
      case DelayBand.magistrateOrder:
        return 'Magistrate order needed';
    }
  }
}

class BirthDetail {
  final String? childName;
  final String sex;
  final double? weightKg;
  final String? deliveryType;
  final String? fatherName;
  final String? fatherAadhaar;
  final String? fatherEducation;
  final String? fatherOccupation;
  final String motherName;
  final String? motherAadhaar;
  final String? motherEducation;
  final String? motherOccupation;
  final int? motherAgeAtMarriage;
  final int? motherAgeAtBirth;
  final int? birthOrder;
  final String? addressAtBirth;
  final String? permanentAddress;
  final bool isMultipleBirth;
  final int? multipleBirthOrder;

  const BirthDetail({
    this.childName,
    required this.sex,
    this.weightKg,
    this.deliveryType,
    this.fatherName,
    this.fatherAadhaar,
    this.fatherEducation,
    this.fatherOccupation,
    required this.motherName,
    this.motherAadhaar,
    this.motherEducation,
    this.motherOccupation,
    this.motherAgeAtMarriage,
    this.motherAgeAtBirth,
    this.birthOrder,
    this.addressAtBirth,
    this.permanentAddress,
    this.isMultipleBirth = false,
    this.multipleBirthOrder,
  });

  factory BirthDetail.fromJson(Map<String, dynamic> j) => BirthDetail(
    childName: j['child_name'] as String?,
    sex: (j['sex'] ?? '') as String,
    weightKg: _toDouble(j['weight_kg']),
    deliveryType: j['delivery_type'] as String?,
    fatherName: j['father_name'] as String?,
    fatherAadhaar: j['father_aadhaar'] as String?,
    fatherEducation: j['father_education'] as String?,
    fatherOccupation: j['father_occupation'] as String?,
    motherName: (j['mother_name'] ?? '') as String,
    motherAadhaar: j['mother_aadhaar'] as String?,
    motherEducation: j['mother_education'] as String?,
    motherOccupation: j['mother_occupation'] as String?,
    motherAgeAtMarriage: j['mother_age_at_marriage'] as int?,
    motherAgeAtBirth: j['mother_age_at_birth'] as int?,
    birthOrder: j['birth_order'] as int?,
    addressAtBirth: j['address_at_birth'] as String?,
    permanentAddress: j['permanent_address'] as String?,
    isMultipleBirth: (j['is_multiple_birth'] ?? false) as bool,
    multipleBirthOrder: j['multiple_birth_order'] as int?,
  );

  /// Name is frequently blank at registration — parents have a year to supply it.
  String get displayName =>
      (childName != null && childName!.isNotEmpty)
          ? childName!
          : 'Name not yet recorded';
}

class DeathDetail {
  final String deceasedName;
  final String sex;
  final int? ageYears;
  final int? ageMonths;
  final int? ageDays;
  final DateTime? dateOfBirth;
  final String? fatherName;
  final String? motherName;
  final String? spouseName;
  final String? occupation;
  final String? address;
  final String? causeOfDeath;
  final String? causeCategory;
  final bool medicallyCertified;
  final String? certifyingDoctor;
  final String? doctorRegNo;
  final String? disposalMethod;
  final String? disposalPlace;
  final DateTime? disposalDate;

  const DeathDetail({
    required this.deceasedName,
    required this.sex,
    this.ageYears,
    this.ageMonths,
    this.ageDays,
    this.dateOfBirth,
    this.fatherName,
    this.motherName,
    this.spouseName,
    this.occupation,
    this.address,
    this.causeOfDeath,
    this.causeCategory,
    this.medicallyCertified = false,
    this.certifyingDoctor,
    this.doctorRegNo,
    this.disposalMethod,
    this.disposalPlace,
    this.disposalDate,
  });

  factory DeathDetail.fromJson(Map<String, dynamic> j) => DeathDetail(
    deceasedName: (j['deceased_name'] ?? '') as String,
    sex: (j['sex'] ?? '') as String,
    ageYears: j['age_years'] as int?,
    ageMonths: j['age_months'] as int?,
    ageDays: j['age_days'] as int?,
    dateOfBirth: _toDate(j['date_of_birth']),
    fatherName: j['father_name'] as String?,
    motherName: j['mother_name'] as String?,
    spouseName: j['spouse_name'] as String?,
    occupation: j['occupation'] as String?,
    address: j['address'] as String?,
    causeOfDeath: j['cause_of_death'] as String?,
    causeCategory: j['cause_category'] as String?,
    medicallyCertified: (j['medically_certified'] ?? false) as bool,
    certifyingDoctor: j['certifying_doctor'] as String?,
    doctorRegNo: j['doctor_reg_no'] as String?,
    disposalMethod: j['disposal_method'] as String?,
    disposalPlace: j['disposal_place'] as String?,
    disposalDate: _toDate(j['disposal_date']),
  );

  /// An infant death is counted in days, not a rounded-down zero years.
  String get ageLabel {
    if (ageYears != null && ageYears! > 0) {
      return '$ageYears yr${ageYears == 1 ? '' : 's'}';
    }
    if (ageMonths != null && ageMonths! > 0) {
      return '$ageMonths mo';
    }
    if (ageDays != null) return '$ageDays day${ageDays == 1 ? '' : 's'}';
    return 'Age not recorded';
  }
}

class VitalCertificate {
  final int id;
  final String certificateNumber;
  final String? verificationToken;
  final int copyNumber;
  final String issuedTo;
  final String? issuedToRelation;
  final String? purpose;
  final double feeAmount;
  final String? paymentRef;
  final String? sealHash;
  final DateTime? issuedAt;
  final bool isCancelled;
  final String? cancelledReason;

  const VitalCertificate({
    required this.id,
    required this.certificateNumber,
    this.verificationToken,
    required this.copyNumber,
    required this.issuedTo,
    this.issuedToRelation,
    this.purpose,
    required this.feeAmount,
    this.paymentRef,
    this.sealHash,
    this.issuedAt,
    required this.isCancelled,
    this.cancelledReason,
  });

  factory VitalCertificate.fromJson(Map<String, dynamic> j) => VitalCertificate(
    id: j['id'] as int,
    certificateNumber: (j['certificate_number'] ?? '') as String,
    verificationToken: j['verification_token'] as String?,
    copyNumber: (j['copy_number'] ?? 1) as int,
    issuedTo: (j['issued_to'] ?? '') as String,
    issuedToRelation: j['issued_to_relation'] as String?,
    purpose: j['purpose'] as String?,
    feeAmount: _toDouble(j['fee_amount']) ?? 0,
    paymentRef: j['payment_ref'] as String?,
    sealHash: j['seal_hash'] as String?,
    issuedAt: _toDate(j['issued_at']),
    isCancelled: (j['is_cancelled'] ?? false) as bool,
    cancelledReason: j['cancelled_reason'] as String?,
  );

  String get copyLabel =>
      copyNumber == 1 ? 'Original' : 'Certified copy $copyNumber';
}

/// What stands between this entry and registration.
class VitalReadiness {
  final int delayDays;
  final DelayBand delayBand;
  final String delayReason;
  final bool requiresApprovalRef;
  final bool hasApprovalRef;
  final List<String> blockers;
  final bool canRegister;

  const VitalReadiness({
    required this.delayDays,
    required this.delayBand,
    required this.delayReason,
    required this.requiresApprovalRef,
    required this.hasApprovalRef,
    required this.blockers,
    required this.canRegister,
  });

  factory VitalReadiness.fromJson(Map<String, dynamic> j) => VitalReadiness(
    delayDays: (j['delay_days'] ?? 0) as int,
    delayBand: DelayBand.parse(j['delay_band'] as String?),
    delayReason: (j['delay_reason'] ?? '') as String,
    requiresApprovalRef: (j['requires_approval_ref'] ?? false) as bool,
    hasApprovalRef: (j['has_approval_ref'] ?? false) as bool,
    blockers:
        ((j['blockers'] ?? []) as List).map((e) => e.toString()).toList(),
    canRegister: (j['can_register'] ?? false) as bool,
  );
}

/// Row shape for the registry list.
class VitalEventSummary {
  final int id;
  final int orgUnitId;
  final String? orgUnitName;
  final VitalEventType eventType;
  final VitalStatus status;
  final String? registrationNumber;
  final DateTime eventDate;
  final String? eventTime;
  final String placeType;
  final String? placeName;
  final ReportingSource reportingSource;
  final String informantName;
  final String informantRelation;
  final String? informantPhone;
  final bool isLateRegistration;
  final int delayDays;
  final DateTime? registeredAt;
  final BirthDetail? birth;
  final DeathDetail? death;
  final int certificateCount;

  const VitalEventSummary({
    required this.id,
    required this.orgUnitId,
    this.orgUnitName,
    required this.eventType,
    required this.status,
    this.registrationNumber,
    required this.eventDate,
    this.eventTime,
    required this.placeType,
    this.placeName,
    required this.reportingSource,
    required this.informantName,
    required this.informantRelation,
    this.informantPhone,
    required this.isLateRegistration,
    required this.delayDays,
    this.registeredAt,
    this.birth,
    this.death,
    required this.certificateCount,
  });

  factory VitalEventSummary.fromJson(Map<String, dynamic> j) {
    final orgUnit =
        j['org_unit'] is Map ? Map<String, dynamic>.from(j['org_unit'] as Map) : null;
    final countMap =
        j['_count'] is Map ? Map<String, dynamic>.from(j['_count'] as Map) : null;

    return VitalEventSummary(
      id: j['id'] as int,
      orgUnitId: (j['org_unit_id'] ?? 0) as int,
      orgUnitName: orgUnit?['name'] as String?,
      eventType: VitalEventType.parse(j['event_type'] as String?),
      status: VitalStatus.parse(j['status'] as String?),
      registrationNumber: j['registration_number'] as String?,
      eventDate: _toDate(j['event_date']) ?? DateTime.now(),
      eventTime: j['event_time'] as String?,
      placeType: (j['place_type'] ?? '') as String,
      placeName: j['place_name'] as String?,
      reportingSource: ReportingSource.parse(j['reporting_source'] as String?),
      informantName: (j['informant_name'] ?? '') as String,
      informantRelation: (j['informant_relation'] ?? '') as String,
      informantPhone: j['informant_phone'] as String?,
      isLateRegistration: (j['is_late_registration'] ?? false) as bool,
      delayDays: (j['delay_days'] ?? 0) as int,
      registeredAt: _toDate(j['registered_at']),
      birth: j['birth'] is Map
          ? BirthDetail.fromJson(Map<String, dynamic>.from(j['birth'] as Map))
          : null,
      death: j['death'] is Map
          ? DeathDetail.fromJson(Map<String, dynamic>.from(j['death'] as Map))
          : null,
      certificateCount: (countMap?['certificates'] ?? 0) as int,
    );
  }

  /// Whose entry this is — the child, or the deceased.
  String get subjectName {
    if (eventType == VitalEventType.birth) {
      return birth?.displayName ?? 'Name not yet recorded';
    }
    return death?.deceasedName ?? 'Name not recorded';
  }

  String get secondaryLine {
    if (eventType == VitalEventType.birth) {
      final mother = birth?.motherName;
      return mother != null && mother.isNotEmpty
          ? 'Mother: $mother'
          : 'Informant: $informantName';
    }
    return death != null ? death!.ageLabel : 'Informant: $informantName';
  }
}

class VitalEventDetail {
  final VitalEventSummary summary;
  final String? placeAddress;
  final String? hospitalName;
  final String? hospitalRegNo;
  final DateTime? reportedAt;
  final String? informantAddress;
  final String? informantAadhaar;
  final String? delayApprovalRef;
  final String? rejectionReason;
  final String? correctionNote;
  final List<VitalCertificate> certificates;
  final List<VitalDocument> documents;
  final List<VitalHistoryEntry> history;
  final VitalReadiness readiness;

  const VitalEventDetail({
    required this.summary,
    this.placeAddress,
    this.hospitalName,
    this.hospitalRegNo,
    this.reportedAt,
    this.informantAddress,
    this.informantAadhaar,
    this.delayApprovalRef,
    this.rejectionReason,
    this.correctionNote,
    required this.certificates,
    required this.documents,
    required this.history,
    required this.readiness,
  });

  factory VitalEventDetail.fromJson(Map<String, dynamic> j) => VitalEventDetail(
    summary: VitalEventSummary.fromJson(j),
    placeAddress: j['place_address'] as String?,
    hospitalName: j['hospital_name'] as String?,
    hospitalRegNo: j['hospital_reg_no'] as String?,
    reportedAt: _toDate(j['reported_at']),
    informantAddress: j['informant_address'] as String?,
    informantAadhaar: j['informant_aadhaar'] as String?,
    delayApprovalRef: j['delay_approval_ref'] as String?,
    rejectionReason: j['rejection_reason'] as String?,
    correctionNote: j['correction_note'] as String?,
    certificates: ((j['certificates'] ?? []) as List)
        .map((e) => VitalCertificate.fromJson(e as Map<String, dynamic>))
        .toList(),
    documents: ((j['documents'] ?? []) as List)
        .map((e) => VitalDocument.fromJson(e as Map<String, dynamic>))
        .toList(),
    history: ((j['history'] ?? []) as List)
        .map((e) => VitalHistoryEntry.fromJson(e as Map<String, dynamic>))
        .toList(),
    readiness: VitalReadiness.fromJson(
      j['readiness'] is Map
          ? Map<String, dynamic>.from(j['readiness'] as Map)
          : const <String, dynamic>{},
    ),
  );

  int get id => summary.id;
  VitalStatus get status => summary.status;
  VitalEventType get eventType => summary.eventType;
  BirthDetail? get birth => summary.birth;
  DeathDetail? get death => summary.death;

  List<VitalCertificate> get liveCertificates =>
      certificates.where((c) => !c.isCancelled).toList();
}

class VitalDocument {
  final int id;
  final String title;
  final String fileName;
  final String? fileUrl;
  final String? mimeType;
  final DateTime? createdAt;

  const VitalDocument({
    required this.id,
    required this.title,
    required this.fileName,
    this.fileUrl,
    this.mimeType,
    this.createdAt,
  });

  factory VitalDocument.fromJson(Map<String, dynamic> j) => VitalDocument(
    id: j['id'] as int,
    title: (j['title'] ?? '') as String,
    fileName: (j['file_name'] ?? '') as String,
    fileUrl: j['file_url'] as String?,
    mimeType: j['mime_type'] as String?,
    createdAt: _toDate(j['created_at']),
  );

  bool get isPdf => (mimeType ?? '').contains('pdf');
}

class VitalHistoryEntry {
  final String id;
  final String action;
  final int? userId;
  final DateTime? createdAt;

  const VitalHistoryEntry({
    required this.id,
    required this.action,
    this.userId,
    this.createdAt,
  });

  factory VitalHistoryEntry.fromJson(Map<String, dynamic> j) =>
      VitalHistoryEntry(
        id: j['id'].toString(),
        action: (j['action'] ?? '') as String,
        userId: j['user_id'] as int?,
        createdAt: _toDate(j['created_at']),
      );

  String get label => titleCase(action);
}

/// Result of a public QR verification. Deliberately narrow — the backend
/// withholds informant contact details and Aadhaar fragments.
class CertificateVerification {
  final bool valid;
  final String? cancelledReason;
  final String certificateNumber;
  final int copyNumber;
  final DateTime? issuedAt;
  final String? sealHash;
  final VitalEventType eventType;
  final String? registrationNumber;
  final DateTime? registeredAt;
  final DateTime? eventDate;
  final String? placeName;
  final String issuingAuthority;
  final String subjectName;
  final String? sex;
  final String? motherName;
  final String? fatherName;

  const CertificateVerification({
    required this.valid,
    this.cancelledReason,
    required this.certificateNumber,
    required this.copyNumber,
    this.issuedAt,
    this.sealHash,
    required this.eventType,
    this.registrationNumber,
    this.registeredAt,
    this.eventDate,
    this.placeName,
    required this.issuingAuthority,
    required this.subjectName,
    this.sex,
    this.motherName,
    this.fatherName,
  });

  factory CertificateVerification.fromJson(Map<String, dynamic> j) =>
      CertificateVerification(
        valid: (j['valid'] ?? false) as bool,
        cancelledReason: j['cancelled_reason'] as String?,
        certificateNumber: (j['certificate_number'] ?? '') as String,
        copyNumber: (j['copy_number'] ?? 1) as int,
        issuedAt: _toDate(j['issued_at']),
        sealHash: j['seal_hash'] as String?,
        eventType: VitalEventType.parse(j['event_type'] as String?),
        registrationNumber: j['registration_number'] as String?,
        registeredAt: _toDate(j['registered_at']),
        eventDate: _toDate(j['event_date']),
        placeName: j['place_name'] as String?,
        issuingAuthority: (j['issuing_authority'] ?? '') as String,
        subjectName: (j['subject_name'] ?? '') as String,
        sex: j['sex'] as String?,
        motherName: j['mother_name'] as String?,
        fatherName: j['father_name'] as String?,
      );
}

class VitalEventStats {
  final int birthsRegistered;
  final int deathsRegistered;
  final int pendingAction;
  final int lateRegistrations;
  final int certificatesIssuedThisYear;
  final int total;
  final Map<String, int> byStatus;

  const VitalEventStats({
    required this.birthsRegistered,
    required this.deathsRegistered,
    required this.pendingAction,
    required this.lateRegistrations,
    required this.certificatesIssuedThisYear,
    required this.total,
    required this.byStatus,
  });

  factory VitalEventStats.fromJson(Map<String, dynamic> j) {
    final raw = j['by_status'] is Map
        ? Map<String, dynamic>.from(j['by_status'] as Map)
        : const <String, dynamic>{};
    return VitalEventStats(
      birthsRegistered: (j['births_registered'] ?? 0) as int,
      deathsRegistered: (j['deaths_registered'] ?? 0) as int,
      pendingAction: (j['pending_action'] ?? 0) as int,
      lateRegistrations: (j['late_registrations'] ?? 0) as int,
      certificatesIssuedThisYear:
          (j['certificates_issued_this_year'] ?? 0) as int,
      total: (j['total'] ?? 0) as int,
      byStatus: raw.map((k, v) => MapEntry(k, (v ?? 0) as int)),
    );
  }

  static const empty = VitalEventStats(
    birthsRegistered: 0,
    deathsRegistered: 0,
    pendingAction: 0,
    lateRegistrations: 0,
    certificatesIssuedThisYear: 0,
    total: 0,
    byStatus: {},
  );
}

class VitalEventPage {
  final int total;
  final List<VitalEventSummary> items;

  const VitalEventPage({required this.total, required this.items});

  factory VitalEventPage.fromJson(Map<String, dynamic> j) => VitalEventPage(
    total: (j['total'] ?? 0) as int,
    items: ((j['items'] ?? []) as List)
        .map((e) => VitalEventSummary.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  static const empty = VitalEventPage(total: 0, items: []);
}

/// Result of a bulk hospital feed submission.
class HospitalFeedResult {
  final int submitted;
  final int accepted;
  final int rejected;
  final List<({int index, String reason})> failures;

  const HospitalFeedResult({
    required this.submitted,
    required this.accepted,
    required this.rejected,
    required this.failures,
  });

  factory HospitalFeedResult.fromJson(Map<String, dynamic> j) =>
      HospitalFeedResult(
        submitted: (j['submitted'] ?? 0) as int,
        accepted: (j['accepted'] ?? 0) as int,
        rejected: (j['rejected'] ?? 0) as int,
        failures: ((j['failures'] ?? []) as List).map((e) {
          final m = Map<String, dynamic>.from(e as Map);
          return (
            index: (m['index'] ?? 0) as int,
            reason: (m['reason'] ?? '') as String,
          );
        }).toList(),
      );
}

// ── Option lists, kept in sync with the backend DTO constants ──────────────

const kSexes = <String>['male', 'female', 'transgender'];

const kPlaceTypes = <String>[
  'hospital',
  'home',
  'institution',
  'vehicle',
  'public_place',
];

const kInformantRelations = <String>[
  'father',
  'mother',
  'husband',
  'wife',
  'son',
  'daughter',
  'brother',
  'sister',
  'hospital_official',
  'institution_head',
  'other',
];

const kDeliveryTypes = <String>['normal', 'caesarean', 'forceps', 'other'];

const kCauseCategories = <String>[
  'natural',
  'accident',
  'suicide',
  'homicide',
  'pending_investigation',
];

const kDisposalMethods = <String>['burial', 'cremation', 'donation'];
