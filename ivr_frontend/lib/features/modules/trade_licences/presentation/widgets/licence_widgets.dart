import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:ivr_frontend/config/api_config.dart';
import 'package:ivr_frontend/config/app_theme.dart';
import 'package:ivr_frontend/features/modules/trade_licences/data/models/trade_licence_models.dart';

/// Where the QR printed on the displayed licence points.
///
/// Must stay under `/public/` — that is the prefix `app_router`'s auth
/// redirect exempts, and a licence QR that bounces a customer to a login
/// screen is worse than no QR at all.
String licenceVerifyUrl(String token) =>
    ApiConfig.webUrl('/public/verify-licence/$token');

class LicenceStatusBadge extends StatelessWidget {
  final LicenceStatus status;

  const LicenceStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final color = status.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Countdown to expiry. Silent while a licence has months left; loud once it
/// is inside thirty days, because that is the whole point of the module.
class ExpiryChip extends StatelessWidget {
  final TradeLicenceSummary licence;

  const ExpiryChip({super.key, required this.licence});

  @override
  Widget build(BuildContext context) {
    final days = licence.daysToExpiry;
    if (days == null) return const SizedBox.shrink();

    final df = DateFormat.yMMMd();
    final Color color;
    final String label;

    if (days < 0) {
      color = AppTheme.error;
      label = 'Lapsed ${-days}d ago';
    } else if (days == 0) {
      color = AppTheme.error;
      label = 'Expires today';
    } else if (days <= 30) {
      color = AppTheme.warning;
      label = 'Expires in ${days}d';
    } else {
      color = AppTheme.textMuted;
      label = 'Valid to ${df.format(licence.validUntil!)}';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.event_busy_rounded, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class CategoryChip extends StatelessWidget {
  final String category;

  const CategoryChip({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        titleCase(category),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppTheme.primary,
        ),
      ),
    );
  }
}

/// The QR a shopkeeper displays. Encodes a URL so a phone camera opens the
/// verification page with no app needed.
class LicenceQrDialog extends StatelessWidget {
  final LicenceCertificate certificate;
  final String tradeName;

  const LicenceQrDialog({
    super.key,
    required this.certificate,
    required this.tradeName,
  });

  @override
  Widget build(BuildContext context) {
    final url = licenceVerifyUrl(certificate.verificationToken ?? '');

    return AlertDialog(
      title: Text('${certificate.copyLabel} · ${certificate.licenceYear}'),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              tradeName,
              textAlign: TextAlign.center,
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
