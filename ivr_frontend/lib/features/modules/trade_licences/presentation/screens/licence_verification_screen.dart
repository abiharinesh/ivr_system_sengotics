import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:ivr_frontend/config/app_theme.dart';
import 'package:ivr_frontend/core/api/api_exceptions.dart';
import 'package:ivr_frontend/core/widgets/app_card.dart';
import 'package:ivr_frontend/features/modules/trade_licences/data/models/trade_licence_models.dart';
import 'package:ivr_frontend/features/modules/trade_licences/data/trade_licence_repository.dart';

/// Public landing page for a scanned trade licence QR.
///
/// Rendered outside the authenticated shell — a customer standing in a shop, or
/// an inspector from another department, has no account here.
///
/// The verdict distinguishes three cases, because they are three different
/// findings: genuine and current, genuine but lapsed, and not recognised at
/// all. Collapsing the middle case into "invalid" would tell a customer a real
/// shop was operating on a forged licence.
class LicenceVerificationScreen extends StatefulWidget {
  final String token;

  const LicenceVerificationScreen({super.key, required this.token});

  @override
  State<LicenceVerificationScreen> createState() =>
      _LicenceVerificationScreenState();
}

class _LicenceVerificationScreenState extends State<LicenceVerificationScreen> {
  final _repo = TradeLicenceRepository();
  late Future<LicenceVerification> _future;

  @override
  void initState() {
    super.initState();
    _future = _repo.verifyByToken(widget.token);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppTheme.spaceLg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: FutureBuilder<LicenceVerification>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(64),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snap.hasError) {
                    return _verdict(
                      color: AppTheme.error,
                      icon: Icons.gpp_bad_rounded,
                      headline: 'Not recognised',
                      detail: userFacingMessage(snap.error!),
                      rows: const [],
                    );
                  }

                  final v = snap.data!;

                  if (v.valid) {
                    return _verdict(
                      color: AppTheme.accent,
                      icon: Icons.verified_user_rounded,
                      headline: 'Licence is current',
                      detail:
                          'Issued by ${v.issuingAuthority} and valid for ${v.licenceYear}.',
                      rows: _rowsFor(v),
                    );
                  }

                  if (v.lapsed) {
                    return _verdict(
                      color: AppTheme.warning,
                      icon: Icons.gpp_maybe_rounded,
                      headline: 'Licence has lapsed',
                      detail:
                          'This is a genuine licence issued by ${v.issuingAuthority}, '
                          'but it has not been renewed for the current year.',
                      rows: _rowsFor(v),
                    );
                  }

                  return _verdict(
                    color: AppTheme.error,
                    icon: Icons.gpp_bad_rounded,
                    headline: 'Licence is not valid',
                    detail: v.cancelledReason ??
                        'This licence has been cancelled or suspended by the issuing authority.',
                    rows: _rowsFor(v),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<({String label, String value})> _rowsFor(LicenceVerification v) {
    final df = DateFormat.yMMMd();
    return [
      (label: 'Trade name', value: v.tradeName),
      (label: 'Category', value: titleCase(v.tradeCategory)),
      (label: 'Owner', value: v.ownerName),
      if (v.premises.isNotEmpty) (label: 'Premises', value: v.premises),
      (label: 'Licence number', value: v.licenceNumber),
      (label: 'Licence year', value: v.licenceYear),
      if (v.validFrom != null && v.validUntil != null)
        (
          label: 'Valid',
          value: '${df.format(v.validFrom!)} – ${df.format(v.validUntil!)}',
        ),
      (label: 'Certificate number', value: v.certificateNumber),
      (
        label: 'Copy',
        value: v.copyNumber == 1 ? 'Original' : 'Duplicate ${v.copyNumber}',
      ),
      (label: 'Issuing authority', value: v.issuingAuthority),
    ];
  }

  Widget _verdict({
    required Color color,
    required IconData icon,
    required String headline,
    required String detail,
    required List<({String label, String value})> rows,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          padding: const EdgeInsets.all(AppTheme.spaceXl),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 44, color: color),
              ),
              const SizedBox(height: AppTheme.spaceMd),
              Text(
                headline,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              const SizedBox(height: AppTheme.spaceXs),
              Text(
                detail,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
        if (rows.isNotEmpty) ...[
          const SizedBox(height: AppTheme.spaceMd),
          AppCard(
            padding: const EdgeInsets.all(AppTheme.spaceLg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'What the register says',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: AppTheme.spaceSm),
                ...rows.map(
                  (r) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 150,
                          child: Text(
                            r.label,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            r.value,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.spaceSm),
                Text(
                  'Compare these against the licence displayed on the premises. '
                  'If the trade name or address differs, the document does not '
                  'belong to this shop.',
                  style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
