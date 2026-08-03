import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:ivr_frontend/config/app_theme.dart';
import 'package:ivr_frontend/core/api/api_exceptions.dart';
import 'package:ivr_frontend/core/widgets/app_card.dart';
import 'package:ivr_frontend/features/modules/vital_events/data/models/vital_event_models.dart';
import 'package:ivr_frontend/features/modules/vital_events/data/vital_event_repository.dart';

/// Public landing page for a scanned certificate QR code.
///
/// Rendered outside the authenticated shell: whoever scans this — a bank
/// clerk, a school admissions officer — has no account here, and the whole
/// point of the QR is that they don't need one.
///
/// The verdict is deliberately the largest thing on the page. Someone holding
/// a piece of paper wants one answer, and reading it should not require
/// interpreting a data table.
class CertificateVerificationScreen extends StatefulWidget {
  final String token;

  const CertificateVerificationScreen({super.key, required this.token});

  @override
  State<CertificateVerificationScreen> createState() =>
      _CertificateVerificationScreenState();
}

class _CertificateVerificationScreenState
    extends State<CertificateVerificationScreen> {
  final _repo = VitalEventRepository();
  late Future<CertificateVerification> _future;

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
              child: FutureBuilder<CertificateVerification>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(64),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snap.hasError) {
                    return _verdictCard(
                      color: AppTheme.error,
                      icon: Icons.gpp_bad_rounded,
                      headline: 'Not verified',
                      detail: userFacingMessage(snap.error!),
                      rows: const [],
                    );
                  }

                  final v = snap.data!;
                  if (!v.valid) {
                    return _verdictCard(
                      color: AppTheme.error,
                      icon: Icons.gpp_bad_rounded,
                      headline: 'This certificate has been cancelled',
                      detail: v.cancelledReason ??
                          'It is no longer a valid document. Ask the holder for a current copy.',
                      rows: _rowsFor(v),
                    );
                  }

                  return _verdictCard(
                    color: AppTheme.accent,
                    icon: Icons.verified_user_rounded,
                    headline: 'Genuine certificate',
                    detail:
                        'Issued by ${v.issuingAuthority} and matching the entry in its register.',
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

  List<({String label, String value})> _rowsFor(CertificateVerification v) {
    final df = DateFormat.yMMMd();
    final isBirth = v.eventType == VitalEventType.birth;

    return [
      (label: isBirth ? 'Name of child' : 'Name of deceased', value: v.subjectName),
      if (v.sex != null) (label: 'Sex', value: titleCase(v.sex!)),
      if (isBirth && v.motherName != null)
        (label: 'Mother', value: v.motherName!),
      if (isBirth && v.fatherName != null)
        (label: 'Father', value: v.fatherName!),
      if (v.eventDate != null)
        (
          label: isBirth ? 'Date of birth' : 'Date of death',
          value: df.format(v.eventDate!),
        ),
      if (v.placeName != null && v.placeName!.isNotEmpty)
        (label: 'Place', value: v.placeName!),
      if (v.registrationNumber != null)
        (label: 'Registration number', value: v.registrationNumber!),
      if (v.registeredAt != null)
        (label: 'Registered on', value: df.format(v.registeredAt!)),
      (label: 'Certificate number', value: v.certificateNumber),
      (
        label: 'Copy',
        value: v.copyNumber == 1 ? 'Original' : 'Certified copy ${v.copyNumber}',
      ),
      if (v.issuedAt != null)
        (label: 'Issued on', value: df.format(v.issuedAt!)),
      (label: 'Issuing authority', value: v.issuingAuthority),
    ];
  }

  Widget _verdictCard({
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
                  'Compare these particulars against the document in your hand. '
                  'If anything differs, the document is not the one this code was '
                  'printed on.',
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
