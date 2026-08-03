import 'package:flutter/material.dart';
import 'package:ivr_frontend/config/app_theme.dart';
import 'package:ivr_frontend/features/modules/building_permits/data/models/building_permit_models.dart';

/// Status pill for a permit.
///
/// `AppStatusBadge` maps a handful of generic strings (`approved`, `pending`,
/// `draft`…) and greys out everything else, which would render four of the ten
/// permit states identically. This keeps the same visual shape but gives the
/// in-flight states their own colours, so an officer can read a list at a
/// glance.
class PermitStatusBadge extends StatelessWidget {
  final PermitStatus status;
  final bool compact;

  const PermitStatusBadge({
    super.key,
    required this.status,
    this.compact = false,
  });

  static Color colorFor(PermitStatus status) {
    switch (status) {
      case PermitStatus.approved:
        return AppTheme.accent;
      case PermitStatus.rejected:
      case PermitStatus.cancelled:
        return AppTheme.error;
      case PermitStatus.expired:
        return const Color(0xFF9333EA);
      case PermitStatus.returned:
        return const Color(0xFFEA580C);
      case PermitStatus.nocPending:
      case PermitStatus.scrutiny:
        return AppTheme.warning;
      case PermitStatus.inspection:
        return AppTheme.info;
      case PermitStatus.submitted:
        return AppTheme.primary;
      case PermitStatus.draft:
        return AppTheme.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = colorFor(status);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: color,
          fontSize: compact ? 10 : 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Clearance state pill, used inside the NOC checklist.
class NocStatusBadge extends StatelessWidget {
  final NocState state;

  const NocStatusBadge({super.key, required this.state});

  static Color colorFor(NocState state) {
    switch (state) {
      case NocState.granted:
        return AppTheme.accent;
      case NocState.rejected:
        return AppTheme.error;
      case NocState.notApplicable:
        return AppTheme.textMuted;
      case NocState.pending:
        return AppTheme.warning;
    }
  }

  static IconData iconFor(NocState state) {
    switch (state) {
      case NocState.granted:
        return Icons.check_circle_rounded;
      case NocState.rejected:
        return Icons.cancel_rounded;
      case NocState.notApplicable:
        return Icons.remove_circle_outline_rounded;
      case NocState.pending:
        return Icons.hourglass_top_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = colorFor(state);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(iconFor(state), size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            state.label,
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
