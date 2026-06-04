/// Lightweight data classes for the tender workflow. Mirror the JSON shapes
/// returned by the backend in `src/tender/`. Keep them simple and resilient
/// to nulls — government workflows often have partial data while in flight.

class Vendor {
  final int id;
  final int panchayatId;
  final String name;
  final String phoneE164;
  final String? place;
  final String? notes;
  final bool active;
  final String? panchayatName;

  const Vendor({
    required this.id,
    required this.panchayatId,
    required this.name,
    required this.phoneE164,
    this.place,
    this.notes,
    required this.active,
    this.panchayatName,
  });

  factory Vendor.fromJson(Map<String, dynamic> j) => Vendor(
    id: j['id'] as int,
    panchayatId: j['panchayat_id'] as int,
    name: (j['name'] ?? '') as String,
    phoneE164: (j['phone_e164'] ?? '') as String,
    place: j['place'] as String?,
    notes: j['notes'] as String?,
    active: (j['active'] ?? true) as bool,
    panchayatName: j['panchayat'] is Map ? (j['panchayat']['name'] as String?) : null,
  );
}

class TenderLineItem {
  final int id;
  final int seq;
  final String? descriptionTa;
  final String? descriptionEn;
  final String? quantity;
  final String? unit;
  final int? poleId;
  final int? complaintId;
  final String? poleNumber;
  final String? keypadId;

  const TenderLineItem({
    required this.id,
    required this.seq,
    this.descriptionTa,
    this.descriptionEn,
    this.quantity,
    this.unit,
    this.poleId,
    this.complaintId,
    this.poleNumber,
    this.keypadId,
  });

  factory TenderLineItem.fromJson(Map<String, dynamic> j) {
    final poleMap = j['pole'] is Map ? Map<String, dynamic>.from(j['pole'] as Map) : null;
    return TenderLineItem(
      id: j['id'] as int,
      seq: (j['seq'] ?? 1) as int,
      descriptionTa: j['description_ta'] as String?,
      descriptionEn: j['description_en'] as String?,
      quantity: j['quantity']?.toString(),
      unit: j['unit'] as String?,
      poleId: j['pole_id'] as int?,
      complaintId: j['complaint_id'] as int?,
      poleNumber: poleMap?['pole_number'] as String?,
      keypadId: poleMap?['keypad_id'] as String?,
    );
  }
}

class TenderQuotation {
  final int id;
  final int? vendorId;
  final String submitterName;
  final String submitterPhoneE164;
  final String amount;
  final String? remarks;
  final String source;
  final String screeningOutcome;
  final int? supersededById;
  final String? attachmentUrl;
  final DateTime? submittedAt;

  const TenderQuotation({
    required this.id,
    required this.vendorId,
    required this.submitterName,
    required this.submitterPhoneE164,
    required this.amount,
    this.remarks,
    required this.source,
    required this.screeningOutcome,
    this.supersededById,
    this.attachmentUrl,
    this.submittedAt,
  });

  factory TenderQuotation.fromJson(Map<String, dynamic> j) => TenderQuotation(
    id: j['id'] as int,
    vendorId: j['vendor_id'] as int?,
    submitterName: (j['submitter_name'] ?? '') as String,
    submitterPhoneE164: (j['submitter_phone_e164'] ?? '') as String,
    amount: (j['amount'] ?? '0').toString(),
    remarks: j['remarks'] as String?,
    source: (j['source'] ?? 'officer_entry') as String,
    screeningOutcome: (j['screening_outcome'] ?? 'pending') as String,
    supersededById: j['superseded_by_id'] as int?,
    attachmentUrl: j['attachment_url'] as String?,
    submittedAt:
        j['submitted_at'] != null
            ? DateTime.tryParse(j['submitted_at'].toString())
            : null,
  );

  double get amountNum => double.tryParse(amount) ?? 0;
}

class TenderDocumentSummary {
  final int id;
  final int tenderId;
  final String templateId;
  final int? vendorId;
  final int version;
  final String status;
  final String? storagePath;
  final String? errorMessage;
  final DateTime? generatedAt;
  final Map<String, dynamic>? fieldOverrides;

  const TenderDocumentSummary({
    required this.id,
    required this.tenderId,
    required this.templateId,
    required this.vendorId,
    required this.version,
    required this.status,
    this.storagePath,
    this.errorMessage,
    this.generatedAt,
    this.fieldOverrides,
  });

  factory TenderDocumentSummary.fromJson(Map<String, dynamic> j) =>
      TenderDocumentSummary(
        id: j['id'] as int,
        tenderId: j['tender_id'] as int,
        templateId: (j['template_id'] ?? '') as String,
        vendorId: j['vendor_id'] as int?,
        version: (j['version'] ?? 1) as int,
        status: (j['status'] ?? 'pending') as String,
        storagePath: j['storage_path'] as String?,
        errorMessage: j['error_message'] as String?,
        generatedAt:
            j['generated_at'] != null
                ? DateTime.tryParse(j['generated_at'].toString())
                : null,
        fieldOverrides:
            j['field_overrides'] is Map<String, dynamic>
                ? j['field_overrides'] as Map<String, dynamic>
                : (j['field_overrides'] is Map
                    ? Map<String, dynamic>.from(j['field_overrides'] as Map)
                    : null),
      );
}

class FieldVerificationSession {
  final int id;
  final int tenderId;
  final String? label;
  final DateTime? expiresAt;
  final List<int> poleSubsetIds;
  final DateTime? confirmedAt;
  final int uploadCount;
  final String? token;

  const FieldVerificationSession({
    required this.id,
    required this.tenderId,
    this.label,
    this.expiresAt,
    required this.poleSubsetIds,
    this.confirmedAt,
    required this.uploadCount,
    this.token,
  });

  factory FieldVerificationSession.fromJson(Map<String, dynamic> j) {
    final counts = j['_count'];
    return FieldVerificationSession(
      id: j['id'] as int,
      tenderId: j['tender_id'] as int,
      label: j['label'] as String?,
      expiresAt:
          j['expires_at'] != null
              ? DateTime.tryParse(j['expires_at'].toString())
              : null,
      poleSubsetIds:
          ((j['pole_subset_ids'] ?? []) as List).map((e) => e as int).toList(),
      confirmedAt:
          j['confirmed_at'] != null
              ? DateTime.tryParse(j['confirmed_at'].toString())
              : null,
      uploadCount: counts is Map ? (counts['uploads'] as num?)?.toInt() ?? 0 : 0,
      token: j['token'] as String?,
    );
  }
}

class FieldVerificationUpload {
  final int id;
  final int sessionId;
  final String imageUrl;
  final double? matchedLat;
  final double? matchedLng;
  final double? distanceMeters;
  final String matchConfidence;
  final String? coordSource;
  final String? notes;
  final int? matchedPoleId;
  final int? manualPoleId;
  final String? ocrPoleNumber;
  final String? sessionLabel;

  const FieldVerificationUpload({
    required this.id,
    required this.sessionId,
    required this.imageUrl,
    this.matchedLat,
    this.matchedLng,
    this.distanceMeters,
    required this.matchConfidence,
    this.coordSource,
    this.notes,
    this.matchedPoleId,
    this.manualPoleId,
    this.ocrPoleNumber,
    this.sessionLabel,
  });

  factory FieldVerificationUpload.fromJson(Map<String, dynamic> j) {
    final session = j['session'];
    return FieldVerificationUpload(
      id: j['id'] as int,
      sessionId: j['session_id'] as int,
      imageUrl: (j['image_url'] ?? '') as String,
      matchedLat: (j['matched_lat'] as num?)?.toDouble(),
      matchedLng: (j['matched_lng'] as num?)?.toDouble(),
      distanceMeters: (j['distance_meters'] as num?)?.toDouble(),
      matchConfidence: (j['match_confidence'] ?? 'unmatched') as String,
      coordSource: j['coord_source'] as String?,
      notes: j['notes'] as String?,
      matchedPoleId: j['matched_pole_id'] as int?,
      manualPoleId: j['manual_pole_id'] as int?,
      ocrPoleNumber: j['ocr_pole_number'] as String?,
      sessionLabel: session is Map ? session['label'] as String? : null,
    );
  }

  bool get needsReview =>
      matchConfidence == 'conflict' ||
      matchConfidence == 'ambiguous' ||
      matchConfidence == 'unmatched';
}

class VerificationProgress {
  final int done;
  final int total;

  const VerificationProgress({required this.done, required this.total});

  factory VerificationProgress.fromJson(Map<String, dynamic> j) =>
      VerificationProgress(
        done: (j['done'] as num?)?.toInt() ?? 0,
        total: (j['total'] as num?)?.toInt() ?? 0,
      );
}

class ChecklistItem {
  final int id;
  final int tenderId;
  final int? poleId;
  final int? lineItemId;
  final bool isDone;
  final int? verifiedUploadId;
  final String? notes;
  final Map<String, dynamic>? upload;
  final FieldVerificationUpload? verifiedUpload;
  final Map<String, dynamic>? lineItem;

  const ChecklistItem({
    required this.id,
    required this.tenderId,
    this.poleId,
    this.lineItemId,
    required this.isDone,
    this.verifiedUploadId,
    this.notes,
    this.upload,
    this.verifiedUpload,
    this.lineItem,
  });

  factory ChecklistItem.fromJson(Map<String, dynamic> j) {
    final uploadMap = j['verified_upload'];
    return ChecklistItem(
      id: j['id'] as int,
      tenderId: j['tender_id'] as int,
      poleId: j['pole_id'] as int?,
      lineItemId: j['line_item_id'] as int?,
      isDone: (j['is_done'] ?? false) as bool,
      verifiedUploadId: j['verified_upload_id'] as int?,
      notes: j['notes'] as String?,
      upload: uploadMap as Map<String, dynamic>?,
      verifiedUpload: uploadMap is Map<String, dynamic>
          ? FieldVerificationUpload.fromJson(uploadMap)
          : null,
      lineItem: j['line_item'] as Map<String, dynamic>?,
    );
  }

  int get reviewSortKey {
    if (isDone) return 2;
    if (verifiedUpload != null && verifiedUpload!.needsReview) return 0;
    if (verifiedUpload != null) return 1;
    return 1;
  }
}

class TenderSummary {
  final int id;
  final String status;
  final String? titleEn;
  final String? titleTa;
  final DateTime? anchorDate;
  final String quotationAccessMode;
  final int lineItemsCount;
  final int quotationsCount;
  final int documentsCount;
  final int invitesCount;
  final TenderQuotation? awarded;
  final VerificationProgress? verificationProgress;
  final String? panchayatName;

  const TenderSummary({
    required this.id,
    required this.status,
    this.titleEn,
    this.titleTa,
    this.anchorDate,
    required this.quotationAccessMode,
    required this.lineItemsCount,
    required this.quotationsCount,
    required this.documentsCount,
    required this.invitesCount,
    this.awarded,
    this.verificationProgress,
    this.panchayatName,
  });

  factory TenderSummary.fromJson(Map<String, dynamic> j) {
    final counts = j['_count'];
    Map<String, dynamic>? toMap(dynamic v) =>
        v is Map ? Map<String, dynamic>.from(v) : null;
    final awardedMap = toMap(j['awarded_quotation']);
    final vpMap = toMap(j['verification_progress']);
    return TenderSummary(
      id: j['id'] as int,
      status: (j['status'] ?? 'draft') as String,
      titleEn: j['title_en'] as String?,
      titleTa: j['title_ta'] as String?,
      anchorDate:
          j['anchor_date'] != null
              ? DateTime.tryParse(j['anchor_date'].toString())
              : null,
      quotationAccessMode:
          (j['quotation_access_mode'] ?? 'invited_only') as String,
      lineItemsCount: counts is Map ? ((counts['line_items'] ?? 0) as int) : 0,
      quotationsCount: counts is Map ? ((counts['quotations'] ?? 0) as int) : 0,
      documentsCount: counts is Map ? ((counts['documents'] ?? 0) as int) : 0,
      invitesCount: counts is Map ? ((counts['invites'] ?? 0) as int) : 0,
      awarded:
          awardedMap == null
              ? null
              : TenderQuotation.fromJson({
                ...awardedMap,
                'submitter_name': awardedMap['submitter_name'] ?? '',
                'submitter_phone_e164':
                    awardedMap['submitter_phone_e164'] ?? '',
                'amount': awardedMap['amount'] ?? '0',
              }),
      verificationProgress:
          vpMap == null ? null : VerificationProgress.fromJson(vpMap),
      panchayatName: j['panchayat'] is Map ? (j['panchayat']['name'] as String?) : null,
    );
  }
}

class TenderDetail {
  final Map<String, dynamic> raw;
  final TenderSummary summary;
  final List<TenderLineItem> lineItems;
  final List<TenderQuotation> quotations;
  final List<TenderInviteLink> invites;
  final List<Vendor> invitedVendors;
  final List<TenderDocumentSummary> documents;
  final List<FieldVerificationSession> sessions;
  final Map<String, String?> timeline;
  final String? publicToken;
  
  int? get awardedQuotationId {
    final tender = raw['tender'];
    if (tender is Map) {
      final val = tender['awarded_quotation_id'];
      if (val != null) {
        return int.tryParse(val.toString()) ?? (val is num ? val.toInt() : null);
      }
    }
    return null;
  }

  const TenderDetail({
    required this.raw,
    required this.summary,
    required this.lineItems,
    required this.quotations,
    required this.invites,
    required this.invitedVendors,
    required this.documents,
    required this.sessions,
    required this.timeline,
    required this.publicToken,
  });

  factory TenderDetail.fromJson(Map<String, dynamic> j) {
    final tender = (j['tender'] ?? {}) as Map<String, dynamic>;
    final summaryJson = {
      ...tender,
      '_count': {
        'line_items': (j['line_items'] as List?)?.length ?? 0,
        'quotations': (j['quotations'] as List?)?.length ?? 0,
        'documents': (j['documents'] as List?)?.length ?? 0,
        'invites': (j['invites'] as List?)?.length ?? 0,
      },
      'awarded_quotation': null,
    };
    final timelineRaw = (j['timeline']?['dates'] ?? {}) as Map<String, dynamic>;
    final timeline = timelineRaw.map((k, v) => MapEntry(k, v as String?));

    final invites =
        ((j['invites'] ?? []) as List)
            .map(
              (e) => Vendor.fromJson(
                ((e as Map<String, dynamic>)['vendor']) as Map<String, dynamic>,
              ),
            )
            .toList();
    final inviteLinks =
        ((j['invites'] ?? []) as List)
            .whereType<Map>()
            .map((e) => TenderInviteLink.fromJson(Map<String, dynamic>.from(e)))
            .toList();

    return TenderDetail(
      raw: j,
      summary: TenderSummary.fromJson(summaryJson),
      lineItems:
          ((j['line_items'] ?? []) as List)
              .map((e) => TenderLineItem.fromJson(e as Map<String, dynamic>))
              .toList(),
      quotations:
          ((j['quotations'] ?? []) as List)
              .map((e) => TenderQuotation.fromJson(e as Map<String, dynamic>))
              .toList(),
      invites: inviteLinks,
      invitedVendors: invites,
      documents:
          ((j['documents'] ?? []) as List)
              .map(
                (e) =>
                    TenderDocumentSummary.fromJson(e as Map<String, dynamic>),
              )
              .toList(),
      sessions:
          ((j['verification_sessions'] ?? []) as List)
              .map(
                (e) => FieldVerificationSession.fromJson(
                  e as Map<String, dynamic>,
                ),
              )
              .toList(),
      timeline: timeline,
      publicToken: tender['public_token'] as String?,
    );
  }
}

class TenderInviteLink {
  final int id;
  final int tenderId;
  final int vendorId;
  final String? inviteToken;
  final DateTime? inviteExpiresAt;
  final DateTime? inviteRevokedAt;
  final DateTime? inviteOpenedAt;
  final DateTime? inviteSubmittedAt;

  const TenderInviteLink({
    required this.id,
    required this.tenderId,
    required this.vendorId,
    required this.inviteToken,
    this.inviteExpiresAt,
    this.inviteRevokedAt,
    this.inviteOpenedAt,
    this.inviteSubmittedAt,
  });

  factory TenderInviteLink.fromJson(Map<String, dynamic> j) => TenderInviteLink(
    id: j['id'] as int,
    tenderId: j['tender_id'] as int,
    vendorId: j['vendor_id'] as int,
    inviteToken: j['invite_token']?.toString(),
    inviteExpiresAt:
        j['invite_expires_at'] != null
            ? DateTime.tryParse(j['invite_expires_at'].toString())
            : null,
    inviteRevokedAt:
        j['invite_revoked_at'] != null
            ? DateTime.tryParse(j['invite_revoked_at'].toString())
            : null,
    inviteOpenedAt:
        j['invite_opened_at'] != null
            ? DateTime.tryParse(j['invite_opened_at'].toString())
            : null,
    inviteSubmittedAt:
        j['invite_submitted_at'] != null
            ? DateTime.tryParse(j['invite_submitted_at'].toString())
            : null,
  );
}
