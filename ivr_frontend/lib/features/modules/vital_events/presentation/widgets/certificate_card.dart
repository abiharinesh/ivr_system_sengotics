import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:ivr_frontend/config/api_config.dart';
import 'package:ivr_frontend/config/app_theme.dart';
import 'package:ivr_frontend/core/widgets/app_card.dart';
import 'package:ivr_frontend/features/modules/vital_events/data/models/vital_event_models.dart';

/// Route the printed QR code points at. Kept next to the QR builder so the two
/// can never drift apart.
///
/// Must stay under `/public/` — that is the prefix `app_router`'s auth
/// redirect exempts, and a certificate QR that bounces the scanner to a login
/// screen would be worse than no QR at all.
String certificateVerifyUrl(String token) =>
    ApiConfig.webUrl('/public/verify-certificate/$token');

/// Certificates issued against a register entry.
///
/// Every copy is its own row: the register has to be able to say who was given
/// a certificate and when, and a reissue must not erase the record of the
/// first one.
class CertificatesCard extends StatelessWidget {
  final List<VitalCertificate> certificates;
  final bool canIssue;
  final bool busy;
  final VoidCallback onIssue;
  final void Function(VitalCertificate certificate) onShowQr;
  final void Function(VitalCertificate certificate) onCancel;

  const CertificatesCard({
    super.key,
    required this.certificates,
    required this.canIssue,
    required this.onIssue,
    required this.onShowQr,
    required this.onCancel,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final df = DateFormat.yMMMd();

    return AppCard(
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.workspace_premium_rounded,
                  color: AppTheme.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Certificates issued',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              if (canIssue)
                TextButton.icon(
                  onPressed: busy ? null : onIssue,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Issue'),
                ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceSm),
          if (certificates.isEmpty)
            Text(
              canIssue
                  ? 'No certificate issued yet.'
                  : 'A certificate can only be issued once the entry is in the register.',
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
            )
          else
            ...certificates.map((c) {
              final color =
                  c.isCancelled ? AppTheme.textMuted : AppTheme.accent;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.bgSurface,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    border: Border.all(color: color.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        c.isCancelled
                            ? Icons.cancel_outlined
                            : Icons.verified_rounded,
                        size: 18,
                        color: color,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${c.copyLabel} · ${c.certificateNumber}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                                decoration: c.isCancelled
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                            Text(
                              'To ${c.issuedTo}'
                              '${c.issuedToRelation != null ? ' (${c.issuedToRelation})' : ''}'
                              '${c.issuedAt != null ? ' · ${df.format(c.issuedAt!)}' : ''}',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            if (c.purpose != null && c.purpose!.isNotEmpty)
                              Text(
                                'Purpose: ${c.purpose}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textMuted,
                                ),
                              ),
                            if (c.isCancelled && c.cancelledReason != null)
                              Text(
                                c.cancelledReason!,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.error,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (!c.isCancelled) ...[
                        IconButton(
                          tooltip: 'Show verification QR',
                          icon: const Icon(Icons.qr_code_2_rounded, size: 20),
                          onPressed: c.verificationToken == null
                              ? null
                              : () => onShowQr(c),
                        ),
                        IconButton(
                          tooltip: 'Cancel this certificate',
                          icon: const Icon(
                            Icons.block_rounded,
                            size: 18,
                            color: AppTheme.error,
                          ),
                          onPressed: busy ? null : () => onCancel(c),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

/// The QR a citizen scans. Encodes a URL rather than a bare token so a phone
/// camera opens the verification page directly, with no app needed.
class CertificateQrDialog extends StatelessWidget {
  final VitalCertificate certificate;
  final String subjectName;

  const CertificateQrDialog({
    super.key,
    required this.certificate,
    required this.subjectName,
  });

  @override
  Widget build(BuildContext context) {
    final token = certificate.verificationToken ?? '';
    final url = certificateVerifyUrl(token);

    return AlertDialog(
      title: Text(certificate.copyLabel),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              subjectName,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            Text(
              certificate.certificateNumber,
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: AppTheme.spaceMd),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(color: AppTheme.stroke),
              ),
              child: QrImageView(
                data: url,
                version: QrVersions.auto,
                size: 200,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: AppTheme.spaceMd),
            SelectableText(
              url,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
            ),
            if (certificate.sealHash != null) ...[
              const SizedBox(height: AppTheme.spaceXs),
              Text(
                'Seal ${certificate.sealHash!.substring(0, 16)}…',
                style: TextStyle(
                  fontSize: 10,
                  color: AppTheme.textMuted,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: url));
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Verification link copied')),
            );
          },
          icon: const Icon(Icons.copy_rounded, size: 18),
          label: const Text('Copy link'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ],
    );
  }
}

/// Collected result of the issue-certificate dialog.
class CertificateIssueRequest {
  final String issuedTo;
  final String? issuedToRelation;
  final String? purpose;
  final double? feeAmount;
  final String? paymentRef;

  const CertificateIssueRequest({
    required this.issuedTo,
    this.issuedToRelation,
    this.purpose,
    this.feeAmount,
    this.paymentRef,
  });
}

class IssueCertificateDialog extends StatefulWidget {
  final String subjectName;

  const IssueCertificateDialog({super.key, required this.subjectName});

  @override
  State<IssueCertificateDialog> createState() => _IssueCertificateDialogState();
}

class _IssueCertificateDialogState extends State<IssueCertificateDialog> {
  final _toCtrl = TextEditingController();
  final _relationCtrl = TextEditingController();
  final _purposeCtrl = TextEditingController();
  final _feeCtrl = TextEditingController(text: '0');
  final _refCtrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    for (final c in [
      _toCtrl,
      _relationCtrl,
      _purposeCtrl,
      _feeCtrl,
      _refCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Issue a certificate'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'For ${widget.subjectName}',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: AppTheme.spaceMd),
              TextField(
                controller: _toCtrl,
                decoration: const InputDecoration(
                  labelText: 'Issued to *',
                  hintText: 'Name of the person collecting it',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppTheme.spaceSm),
              TextField(
                controller: _relationCtrl,
                decoration: const InputDecoration(
                  labelText: 'Relationship to the subject',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppTheme.spaceSm),
              TextField(
                controller: _purposeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Purpose',
                  hintText: 'School admission, passport, insurance claim…',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppTheme.spaceSm),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _feeCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Fee (₹)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spaceSm),
                  Expanded(
                    child: TextField(
                      controller: _refCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Receipt ref',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: AppTheme.spaceSm),
                Text(
                  _error!,
                  style: const TextStyle(fontSize: 12, color: AppTheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final to = _toCtrl.text.trim();
            if (to.length < 2) {
              setState(() => _error = 'Record who the certificate is issued to');
              return;
            }
            Navigator.of(context).pop(
              CertificateIssueRequest(
                issuedTo: to,
                issuedToRelation: _relationCtrl.text.trim(),
                purpose: _purposeCtrl.text.trim(),
                feeAmount: double.tryParse(_feeCtrl.text.trim()) ?? 0,
                paymentRef: _refCtrl.text.trim(),
              ),
            );
          },
          child: const Text('Issue'),
        ),
      ],
    );
  }
}
