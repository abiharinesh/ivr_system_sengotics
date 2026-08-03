import 'package:flutter/material.dart';
import 'package:ivr_frontend/config/app_theme.dart';
import 'package:ivr_frontend/features/modules/vital_events/data/models/vital_event_models.dart';

/// Status pill for a register entry.
class VitalStatusBadge extends StatelessWidget {
  final VitalStatus status;

  const VitalStatusBadge({super.key, required this.status});

  static Color colorFor(VitalStatus status) {
    switch (status) {
      case VitalStatus.registered:
        return AppTheme.accent;
      case VitalStatus.corrected:
        return AppTheme.info;
      case VitalStatus.rejected:
        return AppTheme.error;
      case VitalStatus.verified:
        return AppTheme.primary;
      case VitalStatus.reported:
        return AppTheme.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = colorFor(status);
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

/// Marks how far past the statutory window a report is, and what sanction that
/// now requires. Colour escalates with the band, because a magistrate's order
/// is a materially different problem from a late fee.
class DelayBandChip extends StatelessWidget {
  final DelayBand band;
  final int delayDays;

  const DelayBandChip({
    super.key,
    required this.band,
    required this.delayDays,
  });

  static Color colorFor(DelayBand band) {
    switch (band) {
      case DelayBand.ordinary:
        return AppTheme.accent;
      case DelayBand.lateFee:
        return AppTheme.warning;
      case DelayBand.authorityPermission:
        return const Color(0xFFEA580C);
      case DelayBand.magistrateOrder:
        return AppTheme.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = colorFor(band);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            band == DelayBand.ordinary
                ? Icons.check_circle_outline_rounded
                : Icons.schedule_rounded,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            band == DelayBand.ordinary
                ? '${delayDays}d — in time'
                : '${delayDays}d — ${band.label}',
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Small type marker so births and deaths are distinguishable in a mixed list.
class EventTypeChip extends StatelessWidget {
  final VitalEventType type;

  const EventTypeChip({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    final isBirth = type == VitalEventType.birth;
    final color = isBirth ? AppTheme.primary : AppTheme.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isBirth ? Icons.child_care_rounded : Icons.local_florist_rounded,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            type.label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
