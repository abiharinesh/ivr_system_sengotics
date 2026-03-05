import 'package:flutter/material.dart';
import '../../config/app_theme.dart';

class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _getColor().withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _getColor().withValues(alpha: 0.4)),
      ),
      child: Text(
        _getLabel(),
        style: TextStyle(
          color: _getColor(),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Color _getColor() {
    switch (status) {
      case 'pending':
        return AppTheme.warning;
      case 'in_progress':
        return AppTheme.info;
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
      case 'in_progress':
        return 'In Progress';
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
