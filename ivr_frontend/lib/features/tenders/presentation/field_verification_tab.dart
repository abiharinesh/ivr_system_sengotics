import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

import '../../../config/api_config.dart';
import '../../../config/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/api_file_image.dart';
import '../data/tender_models.dart';
import '../data/tender_repository.dart';

class FieldVerificationTab extends StatefulWidget {
  final int tenderId;
  final TenderRepository repo;
  final TenderDetail detail;
  final VoidCallback onChanged;

  const FieldVerificationTab({
    super.key,
    required this.tenderId,
    required this.repo,
    required this.detail,
    required this.onChanged,
  });

  @override
  State<FieldVerificationTab> createState() => _FieldVerificationTabState();
}

class _FieldVerificationTabState extends State<FieldVerificationTab> {
  Future<List<ChecklistItem>>? _checklistFuture;
  bool _linksExpanded = false;
  int? _busyItemId;

  @override
  void initState() {
    super.initState();
    _checklistFuture = widget.repo.getChecklist(widget.tenderId);
  }

  void _refresh({bool reloadSessions = false}) {
    if (!mounted) return;
    setState(() {
      _checklistFuture = widget.repo.getChecklist(widget.tenderId);
    });
    if (reloadSessions) widget.onChanged();
  }

  List<({int poleId, String label})> _poleOptions() {
    final seen = <int>{};
    final options = <({int poleId, String label})>[];
    for (final li in widget.detail.lineItems) {
      final poleId = li.poleId;
      if (poleId == null || seen.contains(poleId)) continue;
      seen.add(poleId);
      final desc =
          li.descriptionEn ?? li.descriptionTa ?? 'Work item #${li.id}';
      final details = <String>[];
      if (li.poleNumber != null && li.poleNumber!.isNotEmpty) {
        details.add('No: ${li.poleNumber}');
      }
      if (li.keypadId != null && li.keypadId!.isNotEmpty) {
        details.add('Keypad: ${li.keypadId}');
      }
      final poleLabel = details.isEmpty ? 'Pole #$poleId' : 'Pole #$poleId (${details.join(' • ')})';
      options.add((poleId: poleId, label: '$poleLabel — $desc'));
    }
    options.sort((a, b) => a.poleId.compareTo(b.poleId));
    return options;
  }

  Future<void> _showCreateSectionDialog() async {
    final options = _poleOptions();
    if (options.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Add line items with poles before creating a section link.',
          ),
        ),
      );
      return;
    }

    final labelCtrl = TextEditingController();
    final selected = <int>{...options.map((o) => o.poleId)};
    int expiryDays = 14;

    final ok = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            builder:
                (ctx, setDialog) => AlertDialog(
                  title: const Text('Create section link'),
                  content: SizedBox(
                    width: 420,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: labelCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Section name',
                              hintText: 'e.g. North ward',
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Poles in this section (${selected.length}/${options.length})',
                            style: Theme.of(ctx).textTheme.labelLarge,
                          ),
                          const SizedBox(height: 8),
                          for (final o in options)
                            CheckboxListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              value: selected.contains(o.poleId),
                              onChanged: (v) {
                                setDialog(() {
                                  if (v == true) {
                                    selected.add(o.poleId);
                                  } else {
                                    selected.remove(o.poleId);
                                  }
                                });
                              },
                              title: Text(
                                o.label,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<int>(
                            initialValue: expiryDays,
                            decoration: const InputDecoration(
                              labelText: 'Link expires in',
                            ),
                            items: const [
                              DropdownMenuItem(value: 7, child: Text('7 days')),
                              DropdownMenuItem(
                                value: 14,
                                child: Text('14 days'),
                              ),
                              DropdownMenuItem(
                                value: 30,
                                child: Text('30 days'),
                              ),
                            ],
                            onChanged:
                                (v) => setDialog(() => expiryDays = v ?? 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed:
                          selected.isEmpty
                              ? null
                              : () => Navigator.pop(ctx, true),
                      child: const Text('Create link'),
                    ),
                  ],
                ),
          ),
    );

    if (ok != true || !mounted) return;
    try {
      final s = await widget.repo.createSession(
        widget.tenderId,
        label: labelCtrl.text,
        poleSubsetIds: selected.toList(),
        expiresInDays: expiryDays,
      );
      if (!mounted) return;
      final url = ApiConfig.webUrl('/public/field/${s.token ?? ''}');
      await Clipboard.setData(ClipboardData(text: url));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Section link copied${s.label != null ? ' (${s.label})' : ''}.',
          ),
        ),
      );
      widget.onChanged();
      _refresh(reloadSessions: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _copyLink(FieldVerificationSession s) {
    final token = s.token;
    if (token == null || token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Link token missing — refresh tender detail.'),
        ),
      );
      return;
    }
    final url = ApiConfig.webUrl('/public/field/$token');
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Link copied${s.label != null ? ' for ${s.label}' : ''}.',
        ),
      ),
    );
  }

  void _copyAllLinks() {
    final lines = <String>[];
    for (final s in widget.detail.sessions) {
      final token = s.token;
      if (token == null || token.isEmpty) continue;
      final name =
          s.label?.trim().isNotEmpty == true
              ? s.label!.trim()
              : 'Session #${s.id}';
      lines.add('$name: ${ApiConfig.webUrl('/public/field/$token')}');
    }
    if (lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No section links to copy yet.')),
      );
      return;
    }
    Clipboard.setData(ClipboardData(text: lines.join('\n')));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Copied ${lines.length} section link(s).')),
    );
  }

  Future<void> _confirm() async {
    try {
      await widget.repo.confirmVerification(widget.tenderId);
      widget.onChanged();
      _refresh(reloadSessions: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Field verification confirmed.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _approveItem(ChecklistItem item) async {
    setState(() => _busyItemId = item.id);
    try {
      await widget.repo.patchChecklistItem(
        widget.tenderId,
        item.id,
        isDone: true,
      );
      _refresh(reloadSessions: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _busyItemId = null);
    }
  }

  Future<void> _rejectItem(ChecklistItem item) async {
    setState(() => _busyItemId = item.id);
    try {
      await widget.repo.patchChecklistItem(
        widget.tenderId,
        item.id,
        isDone: false,
        clearVerifiedUpload: true,
      );
      _refresh(reloadSessions: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _busyItemId = null);
    }
  }

  Future<void> _reassignPole(ChecklistItem item, int poleId) async {
    final upload = item.verifiedUpload;
    if (upload == null || item.poleId == poleId) return;
    setState(() => _busyItemId = item.id);
    try {
      await widget.repo.assignUpload(widget.tenderId, upload.id, poleId);
      _refresh(reloadSessions: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Photo reassigned to Pole #$poleId.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _busyItemId = null);
    }
  }

  void _showImageDialog(FieldVerificationUpload upload) {
    showDialog<void>(
      context: context,
      builder:
          (ctx) => Dialog(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900, maxHeight: 700),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppBar(
                    title: const Text('Field photo'),
                    automaticallyImplyLeading: false,
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  Expanded(
                    child: InteractiveViewer(
                      child: ApiFileImage(
                        path: upload.imageUrl,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  String _workTitle(ChecklistItem item) {
    final li = item.lineItem;
    final desc = li?['description_en'] ?? li?['description_ta'];
    final pole = li?['pole'];
    final poleMap = pole is Map ? pole : null;
    final poleNum = poleMap?['pole_number'];
    final poleRef = poleNum != null ? 'Pole $poleNum' : (item.poleId != null ? 'Pole #${item.poleId}' : null);

    if (desc != null && desc.toString().isNotEmpty) {
      return '${desc}${poleRef != null ? ' • $poleRef' : ''}';
    }
    return 'Item #${item.id}${poleRef != null ? ' • $poleRef' : ''}';
  }

  Color _matchColor(String confidence) {
    switch (confidence) {
      case 'verified_dual':
      case 'single_nearest':
        return Colors.green.shade700;
      case 'manual':
        return AppTheme.primary;
      case 'conflict':
      case 'ambiguous':
        return Colors.orange.shade800;
      default:
        return Colors.grey.shade600;
    }
  }

  @override
  Widget build(BuildContext context) {
    final canCopyAny = widget.detail.sessions.any(
      (s) => s.token != null && s.token!.isNotEmpty,
    );
    final poleOptions = _poleOptions();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ExpansionTile(
          initiallyExpanded: _linksExpanded,
          onExpansionChanged: (v) => setState(() => _linksExpanded = v),
          title: Text(
            'Section links (${widget.detail.sessions.length})',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                IconButton(
                  tooltip: 'Refresh uploads',
                  onPressed: () => _refresh(reloadSessions: true),
                  icon: const Icon(Icons.refresh),
                ),
                if (canCopyAny)
                  OutlinedButton.icon(
                    onPressed: _copyAllLinks,
                    icon: const Icon(Icons.copy_all_outlined),
                    label: const Text('Copy all links'),
                  ),
                OutlinedButton.icon(
                  onPressed: _showCreateSectionDialog,
                  icon: const Icon(Icons.add_link),
                  label: const Text('Create section link'),
                ),
                FilledButton.icon(
                  onPressed: _confirm,
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Confirm verification'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (widget.detail.sessions.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'No section links yet. Create one and share with field staff.',
                ),
              ),
            for (final s in widget.detail.sessions)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.link),
                  title: Text(
                    s.label?.trim().isNotEmpty == true
                        ? s.label!
                        : 'Session #${s.id}',
                  ),
                  subtitle: Text(
                    '${s.uploadCount} upload(s) • ${s.poleSubsetIds.length} pole(s) • '
                    'Expires ${s.expiresAt?.toIso8601String().substring(0, 10) ?? '—'}',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.copy_outlined),
                    tooltip: 'Copy link',
                    onPressed: () => _copyLink(s),
                  ),
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
        const SizedBox(height: 16),
        Text('Review queue', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        FutureBuilder<List<ChecklistItem>>(
          future: _checklistFuture,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: LinearProgressIndicator(),
              );
            }
            if (snap.hasError) return Text('Error: ${snap.error}');
            final items = [...(snap.data ?? [])]..sort((a, b) {
              final cmp = a.reviewSortKey.compareTo(b.reviewSortKey);
              if (cmp != 0) return cmp;
              return (a.poleId ?? a.id).compareTo(b.poleId ?? b.id);
            });

            if (items.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'No checklist items. Create a section link to seed them.',
                ),
              );
            }

            final approved = items.where((i) => i.isDone).length;
            final needsReview =
                items.where((i) {
                  if (i.isDone) return false;
                  final u = i.verifiedUpload;
                  return u != null && u.needsReview;
                }).length;
            final pending = items.length - approved - needsReview;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppCard(
                  child: Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      Text(
                        '$approved / ${items.length} poles approved',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      if (needsReview > 0)
                        Text(
                          '$needsReview needs review',
                          style: TextStyle(color: Colors.orange.shade800),
                        ),
                      if (pending > 0) Text('$pending awaiting upload'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                for (final item in items)
                  _FieldVerificationReviewCard(
                    item: item,
                    title: _workTitle(item),
                    poleOptions: poleOptions,
                    busy: _busyItemId == item.id,
                    matchColor: _matchColor,
                    onImageTap:
                        item.verifiedUpload != null
                            ? () => _showImageDialog(item.verifiedUpload!)
                            : null,
                    onApprove:
                        item.verifiedUpload != null && !item.isDone
                            ? () => _approveItem(item)
                            : null,
                    onReject:
                        item.verifiedUpload != null
                            ? () => _rejectItem(item)
                            : null,
                    onPoleChanged:
                        item.verifiedUpload != null
                            ? (poleId) => _reassignPole(item, poleId)
                            : null,
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _FieldVerificationReviewCard extends StatelessWidget {
  final ChecklistItem item;
  final String title;
  final List<({int poleId, String label})> poleOptions;
  final bool busy;
  final Color Function(String) matchColor;
  final VoidCallback? onImageTap;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final ValueChanged<int>? onPoleChanged;

  const _FieldVerificationReviewCard({
    required this.item,
    required this.title,
    required this.poleOptions,
    required this.busy,
    required this.matchColor,
    this.onImageTap,
    this.onApprove,
    this.onReject,
    this.onPoleChanged,
  });

  @override
  Widget build(BuildContext context) {
    final upload = item.verifiedUpload;
    final borderColor =
        item.isDone
            ? Colors.green.shade400
            : (upload?.needsReview == true
                ? Colors.orange.shade400
                : Colors.grey.shade300);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        padding: const EdgeInsets.all(12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(color: borderColor, width: item.isDone ? 2 : 1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final narrow = constraints.maxWidth < 640;
                final thumb = _buildThumbnail(upload);
                final meta = _buildMeta(context, upload);
                final actions = _buildActions(context);

                if (narrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          thumb,
                          const SizedBox(width: 12),
                          Expanded(child: meta),
                        ],
                      ),
                      const SizedBox(height: 12),
                      actions,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    thumb,
                    const SizedBox(width: 16),
                    Expanded(child: meta),
                    const SizedBox(width: 12),
                    SizedBox(width: 200, child: actions),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail(FieldVerificationUpload? upload) {
    if (upload == null) {
      return Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(
          Icons.image_not_supported_outlined,
          color: Colors.grey,
        ),
      );
    }
    return InkWell(
      onTap: onImageTap,
      borderRadius: BorderRadius.circular(8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: ApiFileImage(
          path: upload.imageUrl,
          width: 120,
          height: 120,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _buildMeta(BuildContext context, FieldVerificationUpload? upload) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 6),
        if (item.isDone)
          Text(
            'Approved',
            style: TextStyle(
              color: Colors.green.shade700,
              fontWeight: FontWeight.w600,
            ),
          )
        else if (upload == null)
          Text('No proof yet', style: TextStyle(color: Colors.grey.shade600))
        else ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: matchColor(upload.matchConfidence).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              upload.matchConfidence.replaceAll('_', ' '),
              style: TextStyle(
                color: matchColor(upload.matchConfidence),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 6),
          if (upload.distanceMeters != null)
            Text('Distance: ${upload.distanceMeters!.toStringAsFixed(0)} m'),
          if (upload.matchedLat != null && upload.matchedLng != null)
            Text(
              'GPS: ${upload.matchedLat!.toStringAsFixed(5)}, ${upload.matchedLng!.toStringAsFixed(5)}',
              style: const TextStyle(fontSize: 12),
            ),
          if (upload.coordSource != null)
            Text(
              'Source: ${upload.coordSource}',
              style: const TextStyle(fontSize: 12),
            ),
          if (upload.ocrPoleNumber != null && upload.ocrPoleNumber!.isNotEmpty)
            Text(
              'Tag: ${upload.ocrPoleNumber}',
              style: const TextStyle(fontSize: 12),
            ),
          if (upload.notes != null && upload.notes!.isNotEmpty)
            Text(
              'Field notes: ${upload.notes}',
              style: const TextStyle(fontSize: 12),
            ),
          if (upload.sessionLabel != null && upload.sessionLabel!.isNotEmpty)
            Text(
              'Section: ${upload.sessionLabel}',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
        ],
      ],
    );
  }

  Widget _buildActions(BuildContext context) {
    final upload = item.verifiedUpload;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (upload != null && onPoleChanged != null && poleOptions.isNotEmpty)
          DropdownButtonFormField<int>(
            initialValue: item.poleId,
            decoration: const InputDecoration(
              labelText: 'Match pole',
              isDense: true,
              border: OutlineInputBorder(),
            ),
            items: [
              for (final o in poleOptions)
                DropdownMenuItem(
                  value: o.poleId,
                  child: Text(
                    o.label,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged:
                busy
                    ? null
                    : (v) {
                      if (v != null) onPoleChanged!(v);
                    },
          ),
        if (upload != null) ...[
          const SizedBox(height: 8),
          if (onApprove != null)
            FilledButton.icon(
              onPressed: busy ? null : onApprove,
              icon:
                  busy
                      ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(Icons.check, size: 18),
              label: const Text('Approve'),
            ),
          if (onReject != null) ...[
            const SizedBox(height: 6),
            OutlinedButton.icon(
              onPressed: busy ? null : onReject,
              icon: const Icon(Icons.close, size: 18),
              label: const Text('Reject'),
            ),
          ],
        ],
      ],
    );
  }
}
