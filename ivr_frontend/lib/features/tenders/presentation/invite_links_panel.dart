import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../config/api_config.dart';
import '../data/tender_models.dart';

/// Per-vendor invite link list for invite-only tenders.
class InviteLinksPanel extends StatelessWidget {
  final TenderDetail detail;
  final VoidCallback? onRefresh;

  const InviteLinksPanel({super.key, required this.detail, this.onRefresh});

  static String inviteStatusLabel(String tenderStatus, TenderInviteLink? invite) {
    if (tenderStatus == 'draft') {
      return 'Publish tender first';
    }
    if (invite == null) return 'Not invited';
    if (invite.inviteRevokedAt != null) return 'Revoked';
    if (invite.inviteSubmittedAt != null) return 'Submitted';
    if (invite.inviteOpenedAt != null) return 'Opened';
    if (invite.inviteToken != null && invite.inviteToken!.isNotEmpty) {
      return 'Ready to share';
    }
    return 'Link missing — refresh page';
  }

  TenderInviteLink? _inviteFor(int vendorId) {
    for (final row in detail.invites) {
      if (row.vendorId == vendorId) return row;
    }
    return null;
  }

  void _copyLink(BuildContext context, Vendor vendor, TenderInviteLink invite) {
    final url = ApiConfig.webUrl('/public/invite/${invite.inviteToken}');
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Invite link copied for ${vendor.name}.')),
    );
  }

  void _copyAllLinks(BuildContext context) {
    final lines = <String>[];
    for (final v in detail.invitedVendors) {
      final invite = _inviteFor(v.id);
      final token = invite?.inviteToken;
      if (token == null || token.isEmpty) continue;
      final url = ApiConfig.webUrl('/public/invite/$token');
      lines.add('${v.name}: $url');
    }
    if (lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No invite links yet. Publish the tender after adding vendors.',
          ),
        ),
      );
      return;
    }
    Clipboard.setData(ClipboardData(text: lines.join('\n')));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Copied ${lines.length} invite link(s).')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final summary = detail.summary;
    final isInviteOnly = summary.quotationAccessMode == 'invited_only';
    if (!isInviteOnly) return const SizedBox.shrink();

    final canCopyAny = summary.status != 'draft' &&
        detail.invites.any(
          (i) =>
              i.inviteToken != null &&
              i.inviteToken!.isNotEmpty &&
              i.inviteRevokedAt == null,
        );
    final needsRefresh = summary.status != 'draft' &&
        detail.invitedVendors.isNotEmpty &&
        !canCopyAny;

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Invite links (one per vendor)',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (canCopyAny)
                  TextButton.icon(
                    onPressed: () => _copyAllLinks(context),
                    icon: const Icon(Icons.copy_all_outlined, size: 18),
                    label: const Text('Copy all'),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              summary.status == 'draft'
                  ? 'Publish this tender to generate a unique link for each invited vendor. '
                      'Share each link only with that vendor.'
                  : 'Each vendor has a personal link. Opening it shows a form pre-filled for that vendor only.',
              style: const TextStyle(color: Colors.black54, fontSize: 13),
            ),
            if (needsRefresh && onRefresh != null) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh invite links'),
              ),
            ],
            const SizedBox(height: 12),
            if (detail.invitedVendors.isEmpty)
              const Text(
                'No vendors invited yet. Use “Invite vendors” below to add some.',
                style: TextStyle(color: Colors.black54),
              )
            else
              for (final v in detail.invitedVendors)
                _InviteLinkRow(
                  vendor: v,
                  invite: _inviteFor(v.id),
                  tenderStatus: summary.status,
                  onCopy: (invite) => _copyLink(context, v, invite),
                ),
          ],
        ),
      ),
    );
  }
}

class _InviteLinkRow extends StatelessWidget {
  final Vendor vendor;
  final TenderInviteLink? invite;
  final String tenderStatus;
  final void Function(TenderInviteLink invite) onCopy;

  const _InviteLinkRow({
    required this.vendor,
    required this.invite,
    required this.tenderStatus,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final status = InviteLinksPanel.inviteStatusLabel(tenderStatus, invite);
    final token = invite?.inviteToken;
    final canCopy = tenderStatus != 'draft' &&
        token != null &&
        token.isNotEmpty &&
        invite?.inviteRevokedAt == null;

    final tooltip = tenderStatus == 'draft'
        ? 'Publish tender to generate invite links'
        : (canCopy
            ? 'Copy personal invite link for ${vendor.name}'
            : 'Invite link not available');

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        child: Text(
          vendor.name.isNotEmpty ? vendor.name[0].toUpperCase() : '?',
        ),
      ),
      title: Text(vendor.name, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
        '${vendor.phoneE164}${vendor.place != null ? ' • ${vendor.place}' : ''}\n$status',
      ),
      isThreeLine: true,
      trailing: IconButton(
        tooltip: tooltip,
        onPressed: canCopy && invite != null ? () => onCopy(invite!) : null,
        icon: Icon(
          Icons.link,
          color: canCopy ? Theme.of(context).colorScheme.primary : Colors.black26,
        ),
      ),
    );
  }
}
