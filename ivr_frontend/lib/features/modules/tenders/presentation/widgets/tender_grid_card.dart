import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:ivr_frontend/features/modules/tenders/data/models/tender_models.dart';

class TenderGridCard extends StatefulWidget {
  final TenderSummary t;
  final bool isSuperAdmin;
  const TenderGridCard({
    super.key,
    required this.t,
    required this.isSuperAdmin,
  });

  @override
  State<TenderGridCard> createState() => _TenderGridCardState();
}

class _TenderGridCardState extends State<TenderGridCard> {
  bool _hovered = false;

  Color _getStatusColor(String status) {
    switch (status) {
      case 'draft':
        return const Color(0xFFF59E0B); // Amber
      case 'published':
        return const Color(0xFF0F766E); // Teal
      case 'quotations_closed':
        return const Color(0xFF3B82F6); // Blue
      case 'vendor_selected':
        return const Color(0xFF8B5CF6); // Purple
      case 'field_verification':
        return const Color(0xFF6366F1); // Indigo
      case 'closed':
        return const Color(0xFF64748B); // Slate
      default:
        return const Color(0xFF64748B);
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'draft':
        return 'Draft';
      case 'published':
        return 'Active';
      case 'quotations_closed':
        return 'Bids Closed';
      case 'vendor_selected':
        return 'L1 Selected';
      case 'field_verification':
        return 'Inspection';
      case 'closed':
        return 'Closed';
      default:
        return status.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    final df = DateFormat.yMMMd();
    final statusColor = _getStatusColor(t.status);
    final statusLabel = _getStatusLabel(t.status);

    final isInvited = t.quotationAccessMode == 'invited_only';
    final double verificationProgress =
        (t.verificationProgress != null && t.verificationProgress!.total > 0)
            ? t.verificationProgress!.done / t.verificationProgress!.total
            : 0.0;

    final detailUrl =
        widget.isSuperAdmin
            ? '/superadmin/tenders/${t.id}'
            : '/tenders/${t.id}';

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color:
                _hovered
                    ? statusColor.withValues(alpha: 0.5)
                    : const Color(0xFFE2E8F0),
            width: _hovered ? 1.5 : 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color:
                  _hovered
                      ? statusColor.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.02),
              blurRadius: _hovered ? 12 : 6,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => context.go(detailUrl),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Card Header
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          t.titleEn ?? t.titleTa ?? 'Tender #${t.id}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: statusColor.withValues(alpha: 0.2),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          statusLabel,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Card Body Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildRow('Reference', 'GT/M/24-${t.id}'),
                        if (t.verificationProgress != null &&
                            t.verificationProgress!.total > 0) ...[
                          const SizedBox(height: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Progress Bar',
                                    style: TextStyle(
                                      color: Color(0xFF64748B),
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    '${(verificationProgress * 100).toStringAsFixed(0)}%',
                                    style: TextStyle(
                                      color: statusColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: verificationProgress,
                                  backgroundColor: const Color(0xFFF1F5F9),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    statusColor,
                                  ),
                                  minHeight: 6,
                                ),
                              ),
                            ],
                          ),
                        ] else ...[
                          _buildRow(
                            'Progress Bar',
                            'Not started',
                            valueColor: const Color(0xFF94A3B8),
                          ),
                        ],
                        _buildRow(
                          'Vendors',
                          t.quotationsCount > 0
                              ? '${t.quotationsCount} Applications'
                              : '${t.invitesCount} Invited',
                        ),
                        _buildRow(
                          'Deadline',
                          t.anchorDate != null
                              ? df.format(t.anchorDate!)
                              : 'Not set',
                        ),
                        _buildRow(
                          'Access Badge',
                          isInvited ? 'Invited Only' : 'Open Public',
                          valueWidget: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  isInvited
                                      ? const Color(0xFFEFF6FF)
                                      : const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isInvited ? 'Invited' : 'Open',
                              style: TextStyle(
                                color:
                                    isInvited
                                        ? const Color(0xFF2563EB)
                                        : const Color(0xFF059669),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        if (t.orgUnitName != null)
                          _buildRow('Panchayat', t.orgUnitName!),
                      ],
                    ),
                  ),
                  const Divider(color: Color(0xFFE2E8F0), height: 24),
                  // Card Footer Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildFooterButton(context, 'View Details', detailUrl),
                      _buildFooterButton(context, 'Bid / Manage', detailUrl),
                      _buildFooterButton(context, 'Audit', detailUrl),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRow(
    String label,
    String value, {
    Color? valueColor,
    Widget? valueWidget,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
          ),
          valueWidget ??
              Text(
                value,
                style: TextStyle(
                  color: valueColor ?? const Color(0xFF334155),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildFooterButton(
    BuildContext context,
    String text,
    String targetUrl,
  ) {
    return TextButton(
      onPressed: () => context.go(targetUrl),
      style: TextButton.styleFrom(
        foregroundColor: const Color(0xFF475569),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
      ),
      child: Text(text),
    );
  }
}
