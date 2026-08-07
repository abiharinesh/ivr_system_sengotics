import 'package:ivr_frontend/core/api/api_client.dart';

/// Models and reads for `/api/contractor` — a contractor's own view.
///
/// Everything here resolves from the caller's login on the server. There is no
/// contractor id to pass and no branch to choose: a contractor can only ever
/// read the tenders they were invited to.

int _asInt(dynamic v, [int fallback = 0]) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse('$v') ?? fallback;
}

double _asDouble(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse('$v') ?? 0;
}

DateTime? _asDate(dynamic v) =>
    v == null ? null : DateTime.tryParse(v.toString());

/// Where an invitation has got to.
enum InviteState {
  /// They have not answered yet, and the deadline has not passed.
  awaitingQuote,
  submitted,

  /// The deadline passed without a quotation.
  closed,

  /// The council withdrew the invitation.
  withdrawn;

  static InviteState parse(String? raw) => switch (raw) {
        'submitted' => InviteState.submitted,
        'closed' => InviteState.closed,
        'withdrawn' => InviteState.withdrawn,
        _ => InviteState.awaitingQuote,
      };
}

/// What this contractor offered on a tender.
class MyQuote {
  const MyQuote({
    required this.amount,
    required this.submittedAt,
    required this.outcome,
  });

  final double amount;
  final DateTime? submittedAt;
  final String outcome;

  factory MyQuote.fromJson(Map<String, dynamic> json) => MyQuote(
        amount: _asDouble(json['amount']),
        submittedAt: _asDate(json['submitted_at']),
        outcome: json['outcome'] as String? ?? 'pending',
      );
}

/// One tender this contractor was invited to.
class InvitedTender {
  const InvitedTender({
    required this.tenderId,
    required this.title,
    required this.titleTa,
    required this.status,
    required this.branch,
    required this.district,
    required this.lineItemCount,
    required this.invitedAt,
    required this.expiresAt,
    required this.submittedAt,
    required this.state,
    required this.myQuote,
    required this.won,
  });

  final int tenderId;
  final String title;
  final String? titleTa;
  final String status;
  final String? branch;
  final String? district;
  final int lineItemCount;
  final DateTime? invitedAt;
  final DateTime? expiresAt;
  final DateTime? submittedAt;
  final InviteState state;
  final MyQuote? myQuote;
  final bool won;

  /// Whole days until the deadline; negative once it has passed.
  int? get daysLeft {
    final due = expiresAt;
    if (due == null) return null;
    return due.difference(DateTime.now()).inHours ~/ 24;
  }

  /// Needs answering, and soon.
  bool get isUrgent {
    if (state != InviteState.awaitingQuote) return false;
    final d = daysLeft;
    return d != null && d <= 3;
  }

  factory InvitedTender.fromJson(Map<String, dynamic> json) => InvitedTender(
        tenderId: _asInt(json['tender_id']),
        title: json['title'] as String? ?? '',
        titleTa: json['title_ta'] as String?,
        status: json['status'] as String? ?? '',
        branch: json['branch'] as String?,
        district: json['district'] as String?,
        lineItemCount: _asInt(json['line_item_count']),
        invitedAt: _asDate(json['invited_at']),
        expiresAt: _asDate(json['expires_at']),
        submittedAt: _asDate(json['submitted_at']),
        state: InviteState.parse(json['state'] as String?),
        myQuote: json['my_quote'] == null
            ? null
            : MyQuote.fromJson(Map<String, dynamic>.from(json['my_quote'] as Map)),
        won: json['won'] == true,
      );
}

/// The portal's whole payload.
class ContractorPortal {
  const ContractorPortal({
    required this.contractorName,
    required this.blacklisted,
    required this.invited,
    required this.awaiting,
    required this.submitted,
    required this.closed,
    required this.tenders,
  });

  final String contractorName;
  final bool blacklisted;
  final int invited;
  final int awaiting;
  final int submitted;
  final int closed;
  final List<InvitedTender> tenders;

  static const empty = ContractorPortal(
    contractorName: '',
    blacklisted: false,
    invited: 0,
    awaiting: 0,
    submitted: 0,
    closed: 0,
    tenders: [],
  );

  factory ContractorPortal.fromJson(Map<String, dynamic> json) {
    final totals = Map<String, dynamic>.from(
        (json['totals'] as Map?) ?? const <String, dynamic>{});
    final contractor = Map<String, dynamic>.from(
        (json['contractor'] as Map?) ?? const <String, dynamic>{});
    return ContractorPortal(
      contractorName: contractor['name'] as String? ?? '',
      blacklisted: json['blacklisted'] == true,
      invited: _asInt(totals['invited']),
      awaiting: _asInt(totals['awaiting']),
      submitted: _asInt(totals['submitted']),
      closed: _asInt(totals['closed']),
      tenders: (json['tenders'] as List? ?? [])
          .map((e) => InvitedTender.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }
}

class ContractorPortalRepository {
  ContractorPortalRepository({ApiClient? api}) : _api = api ?? ApiClient.instance;

  final ApiClient _api;

  static const String _base = '/api/contractor';

  Future<ContractorPortal> myTenders({bool forceRefresh = true}) async {
    final data = await _api.get('$_base/tenders', forceRefresh: forceRefresh);
    return ContractorPortal.fromJson(Map<String, dynamic>.from(data as Map));
  }
}
