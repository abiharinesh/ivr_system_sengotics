import 'package:flutter/material.dart';
import 'package:ivr_frontend/config/app_theme.dart';

class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final color = _getColor();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        _getLabel(),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Color _getColor() {
    switch (status) {
      case 'pending':
        return AppTheme.warning;
      case 'assigned':
        return AppTheme.info;
      case 'in_progress':
        return AppTheme.info;
      case 'resolved_pending_confirmation':
        return AppTheme.primaryLight;
      case 'reassign_required':
        return AppTheme.warning;
      case 'resolved':
        return AppTheme.accent;
      case 'manual_review':
        return AppTheme.primaryLight;
      case 'rejected':
        return AppTheme.error;
      default:
        return AppTheme.textMuted;
    }
  }

  String _getLabel() {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'assigned':
        return 'Assigned';
      case 'in_progress':
        return 'In Progress';
      case 'resolved_pending_confirmation':
        return 'Awaiting confirmation';
      case 'reassign_required':
        return 'Reassign required';
      case 'resolved':
        return 'Resolved';
      case 'manual_review':
        return 'Manual Review';
      case 'rejected':
        return 'Rejected';
      default:
        return status;
    }
  }
}
