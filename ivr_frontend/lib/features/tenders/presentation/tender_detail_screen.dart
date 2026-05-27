import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:intl/intl.dart';
import 'dart:typed_data';
import 'dart:async';

import '../../../config/api_config.dart';
import '../../../core/api/api_exceptions.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading_state.dart';
import '../../../core/widgets/app_status_badge.dart';
import '../../../core/widgets/pdf_preview_surface.dart';
import '../../../core/widgets/html_preview_surface.dart';
import '../data/tender_models.dart';
import '../data/tender_repository.dart';
import 'invite_links_panel.dart';
import 'field_verification_tab.dart';

class TenderDetailScreen extends StatefulWidget {
  final int tenderId;
  const TenderDetailScreen({super.key, required this.tenderId});

  @override
  State<TenderDetailScreen> createState() => _TenderDetailScreenState();
}

class _TenderDetailScreenState extends State<TenderDetailScreen> {
  final _repo = TenderRepository();
  Future<TenderDetail>? _future;

  @override
  void initState() {
    super.initState();
    // Assign directly; setState is illegal before the element is mounted.
    _future = _repo.getTender(widget.tenderId);
  }

  void _reload() {
    if (!mounted) return;
    setState(() {
      _future = _repo.getTender(widget.tenderId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<TenderDetail>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const AppLoadingState(message: 'Loading tender details...');
        }
        if (snap.hasError) {
          return AppErrorState(
            message: userFacingMessage(snap.error!),
            onRetry: _reload,
          );
        }
        final d = snap.data!;
        return DefaultTabController(
          length: 5,
          child: Column(
            children: [
              _TenderHeader(detail: d, repo: _repo, onAction: _reload),
              const TabBar(
                tabs: [
                  Tab(text: 'Overview'),
                  Tab(text: 'Vendors & quotes'),
                  Tab(text: 'Documents'),
                  Tab(text: 'Field verification'),
                  Tab(text: 'Payment'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _OverviewTab(detail: d),
                    _VendorsTab(detail: d, repo: _repo, onChanged: _reload),
                    _DocsTab(
                      detail: d,
                      repo: _repo,
                      panchayatName:
                          ((d.raw['tender']
                                      as Map<String, dynamic>?)?['panchayat']
                                  as Map<String, dynamic>?)?['name']
                              ?.toString(),
                    ),
                    FieldVerificationTab(
                      tenderId: d.summary.id,
                      repo: _repo,
                      detail: d,
                      onChanged: _reload,
                    ),
                    _PaymentTab(detail: d, repo: _repo, onChanged: _reload),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TenderHeader extends StatefulWidget {
  final TenderDetail detail;
  final TenderRepository repo;
  final VoidCallback onAction;
  const _TenderHeader({
    required this.detail,
    required this.repo,
    required this.onAction,
  });

  @override
  State<_TenderHeader> createState() => _TenderHeaderState();
}

class _TenderHeaderState extends State<_TenderHeader> {
  bool _accessBusy = false;

  Future<void> _publish(BuildContext context) async {
    try {
      await widget.repo.publish(widget.detail.summary.id);
      widget.onAction();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _close(BuildContext context) async {
    try {
      await widget.repo.closeQuotations(widget.detail.summary.id);
      widget.onAction();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _onAccessModeChanged(BuildContext context, String? value) async {
    if (value == null || value == widget.detail.summary.quotationAccessMode)
      return;
    setState(() => _accessBusy = true);
    try {
      await widget.repo.setQuotationAccessMode(widget.detail.summary.id, value);
      if (!context.mounted) return;
      widget.onAction();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not update access: $e')));
    } finally {
      if (mounted) setState(() => _accessBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.detail;
    final s = d.summary;
    final df = DateFormat.yMMMd();
    final closed = s.status == 'closed';

    Widget? primaryAction;
    if (s.status == 'draft') {
      primaryAction = FilledButton.icon(
        onPressed: () => _publish(context),
        icon: const Icon(Icons.publish),
        label: const Text('Publish'),
      );
    } else if (s.status == 'published') {
      primaryAction = FilledButton.icon(
        onPressed: () => _close(context),
        icon: const Icon(Icons.lock_clock),
        label: const Text('Close quotations'),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 720;
        final hPad = constraints.maxWidth < 480 ? 12.0 : 16.0;
        final headerInfo = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              s.titleEn ?? s.titleTa ?? 'Tender #${s.id}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            if (s.titleTa != null && (s.titleEn ?? '').isNotEmpty)
              Text(
                s.titleTa!,
                style: const TextStyle(color: Colors.black54),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Chip(label: Text(s.status)),
                if (s.anchorDate != null)
                  Chip(label: Text('Anchor ${df.format(s.anchorDate!)}')),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: isNarrow ? constraints.maxWidth - 32 : 320,
                  ),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Quotation link',
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: s.quotationAccessMode,
                        isExpanded: true,
                        isDense: true,
                        items: const [
                          DropdownMenuItem(
                            value: 'invited_only',
                            child: Text('Invited vendors only'),
                          ),
                          DropdownMenuItem(
                            value: 'open_with_phone',
                            child: Text(
                              'Public — anyone with link + phone',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                        onChanged: closed || _accessBusy
                            ? null
                            : (v) => _onAccessModeChanged(context, v),
                      ),
                    ),
                  ),
                ),
                if (s.quotationAccessMode == 'open_with_phone' &&
                    d.publicToken != null)
                  ActionChip(
                    avatar: const Icon(Icons.copy, size: 16),
                    label: const Text('Copy public link'),
                    onPressed: () {
                      final url =
                          ApiConfig.webUrl('/public/open/${d.publicToken}');
                      Clipboard.setData(ClipboardData(text: url));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Public tender link copied to clipboard.',
                          ),
                        ),
                      );
                    },
                  ),
                if (s.quotationAccessMode == 'invited_only')
                  const Chip(
                    avatar: Icon(Icons.info_outline, size: 16),
                    label: Text(
                      'Per-vendor invite links — see Vendors tab',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ],
        );

        return Padding(
          padding: EdgeInsets.all(hPad),
          child: isNarrow
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    headerInfo,
                    if (primaryAction != null) ...[
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: primaryAction,
                      ),
                    ],
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: headerInfo),
                    if (primaryAction != null) ...[
                      const SizedBox(width: 16),
                      primaryAction,
                    ],
                  ],
                ),
        );
      },
    );
  }
}

// â”€â”€ Tabs â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _OverviewTab extends StatelessWidget {
  final TenderDetail detail;
  const _OverviewTab({required this.detail});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Line items', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (detail.lineItems.isEmpty)
          const Text('No line items.')
        else
          ...detail.lineItems.map(
            (li) => Card(
              child: ListTile(
                leading: CircleAvatar(child: Text('${li.seq}')),
                title: Text(li.descriptionEn ?? li.descriptionTa ?? '—'),
                subtitle: Text(
                  [
                    if (li.quantity != null)
                      '${li.quantity} ${li.unit ?? ''}'.trim(),
                    if (li.poleId != null) 'Pole #${li.poleId}',
                    if (li.complaintId != null) 'Complaint #${li.complaintId}',
                  ].join(' • '),
                ),
              ),
            ),
          ),
        const SizedBox(height: 24),
        Text('Timeline', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ...detail.timeline.entries.map(
          (e) => ListTile(
            dense: true,
            leading: const Icon(Icons.event_outlined),
            title: Text(e.key.replaceAll('_', ' ')),
            trailing: Text(e.value ?? '—'),
          ),
        ),
      ],
    );
  }
}

class _VendorsTab extends StatefulWidget {
  final TenderDetail detail;
  final TenderRepository repo;
  final VoidCallback onChanged;
  const _VendorsTab({
    required this.detail,
    required this.repo,
    required this.onChanged,
  });

  @override
  State<_VendorsTab> createState() => _VendorsTabState();
}

class _VendorsTabState extends State<_VendorsTab> {
  Future<void> _addOfflineQuote() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const _OfflineQuoteDialog(),
    );
    if (result == null) return;
    try {
      await widget.repo.addOfficerQuotation(widget.detail.summary.id, result);
      widget.onChanged();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _manageInvites() async {
    final List<Vendor> all;
    try {
      all = await widget.repo.listVendors(active: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not load vendors: $e')));
      return;
    }
    if (!mounted) return;
    if (all.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add vendors in the Vendor directory before inviting.'),
        ),
      );
      return;
    }
    final preselected = widget.detail.invitedVendors.map((v) => v.id).toSet();
    final result = await showDialog<Set<int>>(
      context: context,
      builder:
          (_) => _InviteVendorsDialog(
            allVendors: all,
            initiallySelected: preselected,
          ),
    );
    if (result == null) return;
    try {
      await widget.repo.setInvites(widget.detail.summary.id, result.toList());
      widget.onChanged();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _award(int quotationId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Award contract?'),
            content: Text(
              'Award quotation #$quotationId. This locks the awardee.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Award'),
              ),
            ],
          ),
    );
    if (ok != true) return;
    try {
      await widget.repo.award(widget.detail.summary.id, quotationId);
      widget.onChanged();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final active =
        widget.detail.quotations.where((q) => q.supersededById == null).toList()
          ..sort((a, b) => a.amountNum.compareTo(b.amountNum));
    final l1Id = active.isNotEmpty ? active.first.id : null;
    final isClosed = widget.detail.summary.status == 'closed';
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Quotations (${active.length})',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: isClosed ? null : _manageInvites,
                icon: const Icon(Icons.group_add_outlined),
                label: Text(
                  widget.detail.invitedVendors.isEmpty
                      ? 'Invite vendors'
                      : 'Manage invites (${widget.detail.invitedVendors.length})',
                ),
              ),
              OutlinedButton.icon(
                onPressed: isClosed ? null : _addOfflineQuote,
                icon: const Icon(Icons.note_add_outlined),
                label: const Text('Add offline quote'),
              ),
            ],
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 560;
              return ListView(
                padding: EdgeInsets.symmetric(
                  horizontal: isNarrow ? 8 : 12,
                ),
                children: [
                  InviteLinksPanel(
                    detail: widget.detail,
                    onRefresh: widget.onChanged,
                  ),
                  for (final q in active)
                    Card(
                      color: q.id == l1Id ? Colors.amber.shade50 : null,
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: isNarrow ? 12 : 16,
                          vertical: 12,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  backgroundColor: q.id == l1Id
                                      ? Colors.amber
                                      : Colors.grey.shade300,
                                  child: Text(
                                    q.id == l1Id ? 'L1' : '#${q.id}',
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        q.submitterName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${q.submitterPhoneE164} • ${q.source} • ${q.screeningOutcome}',
                                        style: const TextStyle(
                                          color: Colors.black54,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 12,
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              alignment: WrapAlignment.end,
                              children: [
                                Text(
                                  '₹ ${q.amount}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                                if (widget.detail.summary.status ==
                                        'quotations_closed' ||
                                    widget.detail.summary.status ==
                                        'vendor_selected')
                                  OutlinedButton(
                                    onPressed: () => _award(q.id),
                                    child: const Text('Award'),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
              if (active.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No quotations yet.'),
                ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _OfflineQuoteDialog extends StatefulWidget {
  const _OfflineQuoteDialog();
  @override
  State<_OfflineQuoteDialog> createState() => _OfflineQuoteDialogState();
}

class _OfflineQuoteDialogState extends State<_OfflineQuoteDialog> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _amount = TextEditingController();
  final _remarks = TextEditingController();
  String _outcome = 'pending';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add offline quotation'),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Vendor name'),
              ),
              TextField(
                controller: _phone,
                decoration: const InputDecoration(
                  labelText: 'Phone (10 digits)',
                ),
              ),
              TextField(
                controller: _amount,
                decoration: const InputDecoration(labelText: 'Amount (₹)'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: _remarks,
                decoration: const InputDecoration(labelText: 'Remarks'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _outcome,
                decoration: const InputDecoration(
                  labelText: 'Screening outcome',
                ),
                items: const [
                  DropdownMenuItem(value: 'pending', child: Text('Pending')),
                  DropdownMenuItem(value: 'approved', child: Text('Approved')),
                  DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
                ],
                onChanged: (v) => setState(() => _outcome = v ?? 'pending'),
              ),
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
          onPressed:
              () => Navigator.of(context).pop({
                'submitter_name': _name.text.trim(),
                'phone': _phone.text.trim(),
                'amount': _amount.text.trim(),
                'remarks': _remarks.text.trim(),
                'screening_outcome': _outcome,
              }),
          child: const Text('Add'),
        ),
      ],
    );
  }
}

class _InviteVendorsDialog extends StatefulWidget {
  final List<Vendor> allVendors;
  final Set<int> initiallySelected;
  const _InviteVendorsDialog({
    required this.allVendors,
    required this.initiallySelected,
  });

  @override
  State<_InviteVendorsDialog> createState() => _InviteVendorsDialogState();
}

class _InviteVendorsDialogState extends State<_InviteVendorsDialog> {
  late Set<int> _selected;

  @override
  void initState() {
    super.initState();
    _selected = {...widget.initiallySelected};
  }

  @override
  Widget build(BuildContext context) {
    final added = _selected.difference(widget.initiallySelected).length;
    final removed = widget.initiallySelected.difference(_selected).length;
    return AlertDialog(
      title: const Text('Invite vendors'),
      content: SizedBox(
        width: 420,
        height: 420,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${_selected.length} of ${widget.allVendors.length} selected'
              '${added > 0 || removed > 0 ? '  •  +$added / -$removed pending' : ''}',
              style: const TextStyle(color: Colors.black54, fontSize: 12),
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: widget.allVendors.length,
                itemBuilder: (context, i) {
                  final v = widget.allVendors[i];
                  final checked = _selected.contains(v.id);
                  return CheckboxListTile(
                    value: checked,
                    onChanged:
                        (val) => setState(() {
                          if (val == true) {
                            _selected.add(v.id);
                          } else {
                            _selected.remove(v.id);
                          }
                        }),
                    title: Text(v.name),
                    subtitle: Text(
                      '${v.phoneE164}${v.place != null ? ' • ${v.place}' : ''}',
                    ),
                    dense: true,
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_selected),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _DocsTab extends StatefulWidget {
  final TenderDetail detail;
  final TenderRepository repo;
  final String? panchayatName;
  const _DocsTab({
    required this.detail,
    required this.repo,
    this.panchayatName,
  });

  int get tenderId => detail.summary.id;

  @override
  State<_DocsTab> createState() => _DocsTabState();
}

class _DocsTabState extends State<_DocsTab> {
  late List<TenderDocumentSummary> _docs;
  final Set<String> _generating = <String>{};
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _docs = widget.detail.documents;
  }

  Future<void> _reload() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      final docs = await widget.repo.listDocuments(widget.tenderId);
      if (!mounted) return;
      setState(() => _docs = docs);
    } finally {
      _refreshing = false;
    }
  }

  /// Vendors that can receive a per-bidder quotation PDF (quotations first, then invites).
  Map<int, String> _quotationVendorOptions() {
    final options = <int, String>{};
    for (final q in widget.detail.quotations) {
      if (q.supersededById != null) continue;
      final vid = q.vendorId;
      if (vid != null) {
        options.putIfAbsent(vid, () => q.submitterName);
      }
    }
    for (final v in widget.detail.invitedVendors) {
      options.putIfAbsent(v.id, () => v.name);
    }
    return options;
  }

  Future<int?> _pickQuotationVendor() async {
    final options = _quotationVendorOptions();
    if (options.isEmpty) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Invite at least one vendor or record a quotation before generating this document.',
          ),
        ),
      );
      return null;
    }
    if (options.length == 1) return options.keys.first;

    return showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Quotation for which vendor?'),
        children: [
          for (final entry in options.entries)
            SimpleDialogOption(
              onPressed: () => Navigator.of(ctx).pop(entry.key),
              child: Text(entry.value),
            ),
        ],
      ),
    );
  }

  String _generatingKey(String tpl, {int? vendorId}) =>
      tpl == 'quotation' && vendorId != null ? '$tpl:$vendorId' : tpl;

  bool _isGeneratingTemplate(String tpl) {
    if (tpl == 'quotation') {
      return _generating.any((k) => k == tpl || k.startsWith('$tpl:'));
    }
    return _generating.contains(tpl);
  }

  Future<void> _generate(
    String tpl, {
    int? vendorId,
    Map<String, dynamic>? fieldOverrides,
  }) async {
    var resolvedVendorId = vendorId;
    if (tpl == 'quotation') {
      resolvedVendorId ??= await _pickQuotationVendor();
      if (resolvedVendorId == null) return;
    }

    final key = _generatingKey(tpl, vendorId: resolvedVendorId);
    setState(() => _generating.add(key));
    try {
      await widget.repo.generateDocument(
        widget.tenderId,
        tpl,
        vendorId: resolvedVendorId,
        fieldOverrides: fieldOverrides,
      );
      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userFacingMessage(e))));
    } finally {
      if (!mounted) return;
      setState(() => _generating.remove(key));
    }
  }

  TenderDocumentSummary? _latestForTemplate(String templateId, {int? vendorId}) {
    var matches = _docs.where((d) => d.templateId == templateId);
    if (templateId == 'quotation' && vendorId != null) {
      matches = matches.where((d) => d.vendorId == vendorId);
    }
    final list = matches.toList();
    if (list.isEmpty) return null;
    list.sort((a, b) => b.version.compareTo(a.version));
    return list.first;
  }

  String? _vendorName(int vendorId) {
    for (final v in widget.detail.invitedVendors) {
      if (v.id == vendorId) return v.name;
    }
    for (final q in widget.detail.quotations) {
      if (q.vendorId == vendorId) return q.submitterName;
    }
    return null;
  }

  Future<void> _editAndGenerate(String templateId, {int? vendorId}) async {
    int? resolvedVendorId = vendorId;
    if (templateId == 'quotation') {
      resolvedVendorId ??= await _pickQuotationVendor();
      if (resolvedVendorId == null) return;
    }
    final latest = _latestForTemplate(templateId, vendorId: resolvedVendorId);
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _DocumentEditorDialog(initial: latest?.fieldOverrides),
    );
    if (result == null) return;
    await _generate(
      templateId,
      vendorId: resolvedVendorId,
      fieldOverrides: result,
    );
  }

  String _structuredDocName(TenderDocumentSummary doc) {
    final safePanchayat = (widget.panchayatName ?? 'panchayat')
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    final when = (doc.generatedAt ?? DateTime.now()).toLocal();
    final ts = DateFormat('yyyyMMdd_HHmm').format(when);
    final ext =
        (doc.storagePath ?? '').toLowerCase().endsWith('.html')
            ? 'html'
            : 'pdf';
    return '$safePanchayat-${widget.tenderId}-${doc.templateId}-v${doc.version}-$ts.$ext';
  }

  Future<void> _openDoc(TenderDocumentSummary doc) async {
    try {
      await widget.repo.downloadDocument(
        widget.tenderId,
        doc.id,
        fallbackName: _structuredDocName(doc),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download failed: ${userFacingMessage(e)}')),
      );
    }
  }

  Future<void> _previewDoc(TenderDocumentSummary doc) async {
    try {
      final preview = await widget.repo.previewDocument(widget.tenderId, doc.id);
      final canvasState = await widget.repo.getCanvasState(widget.tenderId, doc.id);
      if (!mounted) return;
      final action = await showDialog<String>(
        context: context,
        barrierDismissible: true,
        builder:
            (_) => _DocumentPreviewDialog(
              bytes: preview.bytes,
              isHtml: preview.isHtml,
              canvasLayers: canvasState.layers,
              canEdit: canvasState.canEdit,
              lockReason: canvasState.lockedReason,
              onDownload: () async {
                await _openDoc(doc);
              },
              onEdit: () => _openCanvasEditor(doc, preview.bytes, canvasState.layers, canvasState.canEdit),
            ),
      );
      if (action == 'edited') {
        await _reload();
        final refreshed = _docs.where(
          (d) => d.templateId == doc.templateId && d.status == 'ready',
        ).toList()
          ..sort((a, b) => b.version.compareTo(a.version));
        if (refreshed.isNotEmpty) {
          await _previewDoc(refreshed.first);
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Preview failed: ${userFacingMessage(e)}')),
      );
    }
  }

  Future<bool> _openCanvasEditor(
    TenderDocumentSummary doc,
    Uint8List previewBytes,
    List<Map<String, dynamic>> initialLayers,
    bool canEdit,
  ) async {
    if (!canEdit) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Canvas editing is locked for this document template.'),
          ),
        );
      }
      return false;
    }
    final result = await showDialog<List<Map<String, dynamic>>>(
      context: context,
      barrierDismissible: false,
      builder:
          (_) => _DocumentCanvasDialog(
            bytes: previewBytes,
            initialLayers: initialLayers,
            onDraftChanged: (layers) {
              return widget.repo.saveCanvasLayers(widget.tenderId, doc.id, layers);
            },
          ),
    );
    if (result == null) return false;
    try {
      await widget.repo.saveCanvasLayers(widget.tenderId, doc.id, result);
      await widget.repo.mergeCanvasLayers(widget.tenderId, doc.id, result);
      if (!mounted) return true;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Canvas changes saved.')),
      );
      return true;
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Canvas save failed: ${userFacingMessage(e)}')),
      );
      return false;
    }
  }

  Future<void> _downloadZip() async {
    try {
      await widget.repo.downloadDocumentsZip(widget.tenderId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download failed: ${userFacingMessage(e)}')),
      );
    }
  }

  Future<void> _copyDocShareLink(TenderDocumentSummary doc) async {
    try {
      final link = await widget.repo.mintDocShareLink(widget.tenderId, doc.id);
      await Clipboard.setData(ClipboardData(text: link.url));
      if (!mounted) return;
      final expires = DateFormat.Hm().format(link.expiresAt.toLocal());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Share link copied. Expires at $expires.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Share link failed: ${userFacingMessage(e)}')),
      );
    }
  }

  Future<void> _copyZipShareLink() async {
    try {
      final link = await widget.repo.mintZipShareLink(widget.tenderId);
      await Clipboard.setData(ClipboardData(text: link.url));
      if (!mounted) return;
      final expires = DateFormat.Hm().format(link.expiresAt.toLocal());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Share link copied. Expires at $expires.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Share link failed: ${userFacingMessage(e)}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const templates = <_TemplateInfo>[
      _TemplateInfo('rfq', 'RFQ — விலைப்புள்ளி கோருதல்'),
      _TemplateInfo('quotation', 'Quotation — கொட்டேஷன்'),
      _TemplateInfo('comparative', 'Comparative — ஒப்பு நோக்கு பட்டியல்'),
      _TemplateInfo('work_order', 'Work order — வேலை உத்தரவு'),
      _TemplateInfo('so_proceedings', 'SO proceedings — நடவடிக்கைகள்'),
      _TemplateInfo('form19', 'Form 19 — செலவினச் சீட்டு'),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 720;
        final hPad = constraints.maxWidth < 480 ? 12.0 : 16.0;
        return ListView(
          padding: EdgeInsets.all(hPad),
          children: [
            _buildDocsHeader(context, isNarrow),
            const SizedBox(height: 8),
            for (final tpl in templates)
              _buildTemplateCard(context, tpl, isNarrow),
          ],
        );
      },
    );
  }

  Widget _buildDocsHeader(BuildContext context, bool isNarrow) {
    final title = Text(
      'Documents',
      style: Theme.of(context).textTheme.titleMedium,
    );
    final actions = <Widget>[
      IconButton(
        tooltip: 'Refresh',
        onPressed: _reload,
        icon: const Icon(Icons.refresh),
      ),
      OutlinedButton.icon(
        onPressed: _copyZipShareLink,
        icon: const Icon(Icons.link_outlined),
        label: const Text('Share zip link'),
      ),
      OutlinedButton.icon(
        onPressed: _downloadZip,
        icon: const Icon(Icons.archive_outlined),
        label: const Text('Download zip'),
      ),
    ];
    if (isNarrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          title,
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: actions),
        ],
      );
    }
    return Row(
      children: [
        title,
        const Spacer(),
        for (var i = 0; i < actions.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          actions[i],
        ],
      ],
    );
  }

  Widget _buildTemplateCard(
    BuildContext context,
    _TemplateInfo tpl,
    bool isNarrow,
  ) {
    final isQuotation = tpl.id == 'quotation';
    final templateDocs =
        _docs.where((d) => d.templateId == tpl.id).toList()
          ..sort((a, b) => b.version.compareTo(a.version));
    final hasReady = _docs.any(
      (d) => d.templateId == tpl.id && d.status == 'ready',
    );
    final readyMatches =
        templateDocs.where((d) => d.status == 'ready').toList();
    final readyDoc = readyMatches.isEmpty ? null : readyMatches.first;
    Widget statusBody;
    if (templateDocs.isEmpty) {
      statusBody = Text(
        isQuotation
            ? 'Not generated yet — choose vendor when generating'
            : 'Not generated yet',
      );
    } else {
      final latest = templateDocs.first;
      final statusLabel = latest.status.replaceAll('_', ' ');
      final errorText = latest.errorMessage;
      final vendorNote = isQuotation && latest.vendorId != null
          ? _vendorName(latest.vendorId!) ?? 'Vendor #${latest.vendorId}'
          : null;
      statusBody = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            vendorNote != null
                ? 'Latest v${latest.version} — $vendorNote'
                : 'Latest v${latest.version}',
          ),
          const SizedBox(height: 4),
          AppStatusBadge(status: latest.status),
          if (errorText != null && errorText.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              errorText,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.red),
            ),
          ],
          if (statusLabel == 'pending') ...[
            const SizedBox(height: 4),
            const Text('Pending. You can regenerate now.'),
          ],
        ],
      );
    }

    final busy = _isGeneratingTemplate(tpl.id);
    final actions = <Widget>[
      OutlinedButton.icon(
        onPressed: busy ? null : () => _editAndGenerate(tpl.id, vendorId: readyDoc?.vendorId),
        icon: const Icon(Icons.edit_outlined, size: 16),
        label: const Text('Edit'),
      ),
      if (hasReady && readyDoc != null) ...[
        OutlinedButton(
          onPressed: () => _previewDoc(readyDoc),
          child: const Text('Preview'),
        ),
        OutlinedButton(
          onPressed: () => _openDoc(readyDoc),
          child: const Text('Download'),
        ),
        IconButton(
          tooltip: 'Copy share link',
          icon: const Icon(Icons.link_outlined, size: 18),
          onPressed: () => _copyDocShareLink(readyDoc),
        ),
      ],
      FilledButton(
        onPressed: busy ? null : () => _generate(tpl.id),
        child: Text(busy ? 'Generating...' : 'Generate'),
      ),
    ];

    return Card(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isNarrow ? 12 : 16,
          vertical: 12,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2, right: 12),
                  child: Icon(Icons.description_outlined),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tpl.label,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      statusBody,
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: actions,
            ),
          ],
        ),
      ),
    );
  }
}

class _DocumentPreviewDialog extends StatelessWidget {
  final Uint8List bytes;
  final bool isHtml;
  final List<Map<String, dynamic>> canvasLayers;
  final bool canEdit;
  final String? lockReason;
  final Future<void> Function() onDownload;
  final Future<bool> Function() onEdit;

  const _DocumentPreviewDialog({
    required this.bytes,
    this.isHtml = false,
    required this.canvasLayers,
    required this.canEdit,
    this.lockReason,
    required this.onDownload,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context).size;
    final inset = media.width < 480 ? 8.0 : 24.0;
    final maxWidth = (media.width - inset * 2).clamp(280.0, 1100.0);
    final maxHeight = (media.height - inset * 2).clamp(320.0, 760.0);
    final isNarrow = maxWidth < 560;
    final closeBtn = TextButton(
      onPressed: () => Navigator.of(context).pop(),
      child: const Text('Close'),
    );
    final downloadBtn = OutlinedButton.icon(
      onPressed: () async {
        await onDownload();
      },
      icon: const Icon(Icons.download_outlined),
      label: const Text('Download'),
    );
    final editBtn = FilledButton.icon(
      onPressed: !canEdit
          ? null
          : () async {
              final saved = await onEdit();
              if (!saved) return;
              if (!context.mounted) return;
              Navigator.of(context).pop('edited');
            },
      icon: const Icon(Icons.edit_outlined),
      label: Text(canEdit ? 'Edit' : 'Edit (locked)'),
    );

    return Dialog(
      insetPadding: EdgeInsets.all(inset),
      child: SizedBox(
        width: maxWidth,
        height: maxHeight,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Document preview',
                      style: TextStyle(fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (isHtml)
                    HtmlPreviewSurface(html: String.fromCharCodes(bytes))
                  else
                    PdfPreviewSurface(bytes: bytes),
                  _CanvasLayerOverlay(
                    layers: canvasLayers,
                    editable: false,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!canEdit && (lockReason ?? '').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        lockReason!,
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment:
                        isNarrow ? WrapAlignment.start : WrapAlignment.end,
                    children: [closeBtn, downloadBtn, editBtn],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CanvasLayerOverlay extends StatelessWidget {
  final List<Map<String, dynamic>> layers;
  final bool editable;
  final void Function(int index, double x, double y)? onMove;
  final void Function(int index)? onEdit;

  const _CanvasLayerOverlay({
    required this.layers,
    required this.editable,
    this.onMove,
    this.onEdit,
  });

  double _asDouble(dynamic value, double fallback) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  @override
  Widget build(BuildContext context) {
    if (layers.isEmpty) return const SizedBox.shrink();
    return IgnorePointer(
      ignoring: !editable,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth <= 0 ? 1.0 : constraints.maxWidth;
          final height = constraints.maxHeight <= 0 ? 1.0 : constraints.maxHeight;
          return Stack(
            children: [
              for (var i = 0; i < layers.length; i++)
                Builder(
                  builder: (context) {
                    final layer = layers[i];
                    final x = _asDouble(layer['x'], 0.5).clamp(0.0, 1.0);
                    final y = _asDouble(layer['y'], 0.5).clamp(0.0, 1.0);
                    final fontSize = _asDouble(layer['fontSize'], 16).clamp(10.0, 40.0);
                    final text = (layer['text'] ?? '').toString();
                    return Positioned(
                      left: x * width,
                      top: y * height,
                      child: GestureDetector(
                        onTap: editable ? () => onEdit?.call(i) : null,
                        onPanUpdate:
                            editable
                                ? (details) {
                                  final nx = ((x * width) + details.delta.dx) / width;
                                  final ny = ((y * height) + details.delta.dy) / height;
                                  onMove?.call(
                                    i,
                                    nx.clamp(0.0, 0.98),
                                    ny.clamp(0.0, 0.98),
                                  );
                                }
                                : null,
                        child: Container(
                          decoration: BoxDecoration(
                            color:
                                editable
                                    ? Colors.black.withValues(alpha: 0.06)
                                    : Colors.black.withValues(alpha: 0.03),
                            border: Border.all(
                              color:
                                  editable
                                      ? Colors.deepOrange.withValues(alpha: 0.75)
                                      : Colors.blueGrey.withValues(alpha: 0.35),
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          child: Text(
                            text,
                            style: TextStyle(
                              fontSize: fontSize,
                              color: Color(
                                int.tryParse(
                                      (layer['color'] ?? '#111111')
                                          .toString()
                                          .replaceFirst('#', '0xff'),
                                    ) ??
                                    0xff111111,
                              ),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}

class _DocumentCanvasDialog extends StatefulWidget {
  final Uint8List bytes;
  final List<Map<String, dynamic>> initialLayers;
  final Future<void> Function(List<Map<String, dynamic>> layers)? onDraftChanged;
  const _DocumentCanvasDialog({
    required this.bytes,
    required this.initialLayers,
    this.onDraftChanged,
  });

  @override
  State<_DocumentCanvasDialog> createState() => _DocumentCanvasDialogState();
}

class _DocumentCanvasDialogState extends State<_DocumentCanvasDialog> {
  late List<Map<String, dynamic>> _layers;
  Timer? _autosaveTimer;
  bool _autosaveBusy = false;
  bool _autosavePending = false;

  @override
  void initState() {
    super.initState();
    _layers = widget.initialLayers
        .map((e) => {
              'id': (e['id'] ?? DateTime.now().microsecondsSinceEpoch).toString(),
              'text': (e['text'] ?? '').toString(),
              'x': (e['x'] is num) ? (e['x'] as num).toDouble() : 0.5,
              'y': (e['y'] is num) ? (e['y'] as num).toDouble() : 0.5,
              'fontSize': (e['fontSize'] is num) ? (e['fontSize'] as num).toDouble() : 16.0,
              'color': (e['color'] ?? '#111111').toString(),
            })
        .toList();
  }

  void _scheduleAutosave() {
    if (widget.onDraftChanged == null) return;
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(const Duration(milliseconds: 700), _runAutosave);
  }

  Future<void> _runAutosave() async {
    if (widget.onDraftChanged == null) return;
    if (_autosaveBusy) {
      _autosavePending = true;
      return;
    }
    _autosaveBusy = true;
    try {
      await widget.onDraftChanged!.call(List<Map<String, dynamic>>.from(_layers));
    } catch (_) {
      // Keep autosave best-effort; explicit Save remains source of truth.
    } finally {
      _autosaveBusy = false;
      if (_autosavePending) {
        _autosavePending = false;
        _scheduleAutosave();
      }
    }
  }

  Future<String?> _askText({String initial = ''}) async {
    final ctrl = TextEditingController(text: initial);
    final out = await showDialog<String>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Canvas text'),
            content: TextField(
              controller: ctrl,
              autofocus: true,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Text',
                hintText: 'Enter overlay text',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(ctrl.text.trim()),
                child: const Text('OK'),
              ),
            ],
          ),
    );
    ctrl.dispose();
    return out;
  }

  Future<void> _addLayer() async {
    final text = await _askText();
    if (text == null || text.isEmpty) return;
    setState(() {
      _layers.add({
        'id': DateTime.now().microsecondsSinceEpoch.toString(),
        'text': text,
        'x': 0.45,
        'y': 0.45,
        'fontSize': 16.0,
        'color': '#111111',
      });
    });
    _scheduleAutosave();
  }

  Future<void> _editLayer(int index) async {
    if (index < 0 || index >= _layers.length) return;
    final existing = _layers[index];
    final text = await _askText(initial: (existing['text'] ?? '').toString());
    if (text == null) return;
    setState(() {
      _layers[index] = {...existing, 'text': text};
    });
    _scheduleAutosave();
  }

  @override
  void dispose() {
    _autosaveTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context).size;
    final inset = media.width < 480 ? 8.0 : 16.0;
    final maxWidth = (media.width - inset * 2).clamp(280.0, 1200.0);
    final maxHeight = (media.height - inset * 2).clamp(320.0, 820.0);
    final isNarrow = maxWidth < 600;
    final titleAndMeta = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Canvas editor',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(width: 12),
        Text(
          '${_layers.length} layer(s)',
          style: const TextStyle(color: Colors.black54),
        ),
      ],
    );
    final actions = <Widget>[
      OutlinedButton.icon(
        onPressed: _addLayer,
        icon: const Icon(Icons.add),
        label: const Text('Add text'),
      ),
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Close'),
      ),
      FilledButton.icon(
        onPressed: () => Navigator.of(context).pop(_layers),
        icon: const Icon(Icons.save_outlined),
        label: const Text('Save'),
      ),
    ];

    return Dialog(
      insetPadding: EdgeInsets.all(inset),
      child: SizedBox(
        width: maxWidth,
        height: maxHeight,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: isNarrow
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        titleAndMeta,
                        if (widget.onDraftChanged != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              _autosaveBusy
                                  ? 'Autosaving...'
                                  : 'Draft autosave on',
                              style: const TextStyle(
                                color: Colors.black54,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        const SizedBox(height: 8),
                        Wrap(spacing: 8, runSpacing: 8, children: actions),
                      ],
                    )
                  : Row(
                      children: [
                        titleAndMeta,
                        if (widget.onDraftChanged != null) ...[
                          const SizedBox(width: 12),
                          Text(
                            _autosaveBusy
                                ? 'Autosaving...'
                                : 'Draft autosave on',
                            style: const TextStyle(
                              color: Colors.black54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                        const Spacer(),
                        for (var i = 0; i < actions.length; i++) ...[
                          if (i > 0) const SizedBox(width: 8),
                          actions[i],
                        ],
                      ],
                    ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  PdfPreviewSurface(bytes: widget.bytes),
                  _CanvasLayerOverlay(
                    layers: _layers,
                    editable: true,
                    onMove: (index, x, y) {
                      if (index < 0 || index >= _layers.length) return;
                      setState(() {
                        _layers[index] = {..._layers[index], 'x': x, 'y': y};
                      });
                      _scheduleAutosave();
                    },
                    onEdit: (index) {
                      _editLayer(index);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TemplateInfo {
  final String id;
  final String label;
  const _TemplateInfo(this.id, this.label);
}

class _DocumentEditorDialog extends StatefulWidget {
  final Map<String, dynamic>? initial;
  const _DocumentEditorDialog({this.initial});

  @override
  State<_DocumentEditorDialog> createState() => _DocumentEditorDialogState();
}

class _DocumentEditorDialogState extends State<_DocumentEditorDialog> {
  late final TextEditingController _noteTa;
  late final TextEditingController _noteEn;
  late final TextEditingController _conditions;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial ?? const <String, dynamic>{};
    _noteTa = TextEditingController(
      text: (initial['editor_text_ta'] ?? '').toString(),
    );
    _noteEn = TextEditingController(
      text: (initial['editor_text_en'] ?? '').toString(),
    );
    final existingConditions = initial['conditions'];
    if (existingConditions is List) {
      _conditions = TextEditingController(
        text: existingConditions.map((e) => e.toString()).join('\n'),
      );
    } else {
      _conditions = TextEditingController();
    }
  }

  @override
  void dispose() {
    _noteTa.dispose();
    _noteEn.dispose();
    _conditions.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('PDF editor'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Edit text and regenerate a PDF.'),
              const SizedBox(height: 10),
              TextField(
                controller: _noteTa,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Tamil note',
                  hintText: 'Visible note to include in the PDF',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _noteEn,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'English note',
                  hintText: 'Visible note to include in the PDF',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _conditions,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Work order conditions (one line each, optional)',
                ),
              ),
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
            final conditions =
                _conditions.text
                    .split('\n')
                    .map((e) => e.trim())
                    .where((e) => e.isNotEmpty)
                    .toList();
            Navigator.of(context).pop({
              if (_noteTa.text.trim().isNotEmpty)
                'editor_text_ta': _noteTa.text.trim(),
              if (_noteEn.text.trim().isNotEmpty)
                'editor_text_en': _noteEn.text.trim(),
              if (conditions.isNotEmpty) 'conditions': conditions,
            });
          },
          child: const Text('Generate PDF'),
        ),
      ],
    );
  }
}

class _PaymentTab extends StatefulWidget {
  final TenderDetail detail;
  final TenderRepository repo;
  final VoidCallback onChanged;
  const _PaymentTab({
    required this.detail,
    required this.repo,
    required this.onChanged,
  });

  @override
  State<_PaymentTab> createState() => _PaymentTabState();
}

class _PaymentTabState extends State<_PaymentTab> {
  final _amount = TextEditingController();
  final _voucherSerial = TextEditingController();
  final _nkNumber = TextEditingController();
  final _expenseHead = TextEditingController();
  final _tnpassRef = TextEditingController();
  String _method = 'tnpass';
  DateTime? _soDate;
  DateTime? _voucherDate;

  @override
  void initState() {
    super.initState();
    final pm =
        widget.detail.raw['tender']?['payment_meta'] as Map<String, dynamic>?;
    if (pm != null) {
      _amount.text = pm['payment_amount']?.toString() ?? '';
      _voucherSerial.text = pm['voucher_serial']?.toString() ?? '';
      _nkNumber.text = pm['nk_number']?.toString() ?? '';
      _expenseHead.text = pm['expense_head']?.toString() ?? '';
      _tnpassRef.text = pm['tnpass_ref']?.toString() ?? '';
      _method = (pm['payment_method'] ?? 'tnpass') as String;
    }
  }

  Future<void> _save({required bool close}) async {
    try {
      await widget.repo.recordPayment(widget.detail.summary.id, {
        'payment_method': _method,
        if (_amount.text.isNotEmpty)
          'payment_amount': double.tryParse(_amount.text),
        if (_voucherSerial.text.isNotEmpty)
          'voucher_serial': _voucherSerial.text,
        if (_nkNumber.text.isNotEmpty) 'nk_number': _nkNumber.text,
        if (_expenseHead.text.isNotEmpty) 'expense_head': _expenseHead.text,
        if (_tnpassRef.text.isNotEmpty) 'tnpass_ref': _tnpassRef.text,
        if (_soDate != null)
          'so_proceedings_date': _soDate!.toIso8601String().substring(0, 10),
        if (_voucherDate != null)
          'voucher_date': _voucherDate!.toIso8601String().substring(0, 10),
      }, close: close);
      widget.onChanged();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _amount,
          decoration: const InputDecoration(labelText: 'Payment amount (₹)'),
          keyboardType: TextInputType.number,
        ),
        DropdownButtonFormField<String>(
          initialValue: _method,
          decoration: const InputDecoration(labelText: 'Payment method'),
          items: const [
            DropdownMenuItem(value: 'tnpass', child: Text('TNPASS')),
            DropdownMenuItem(value: 'cheque', child: Text('Cheque')),
            DropdownMenuItem(value: 'cash', child: Text('Cash')),
            DropdownMenuItem(value: 'other', child: Text('Other')),
          ],
          onChanged: (v) => setState(() => _method = v ?? 'tnpass'),
        ),
        if (_method == 'tnpass')
          TextField(
            controller: _tnpassRef,
            decoration: const InputDecoration(labelText: 'TNPASS reference'),
          ),
        TextField(
          controller: _voucherSerial,
          decoration: const InputDecoration(
            labelText: 'Voucher serial (auto if blank)',
          ),
        ),
        TextField(
          controller: _nkNumber,
          decoration: const InputDecoration(labelText: 'NK number'),
        ),
        TextField(
          controller: _expenseHead,
          decoration: const InputDecoration(labelText: 'Expense head'),
        ),
        ListTile(
          leading: const Icon(Icons.event),
          title: const Text('SO proceedings date'),
          trailing: Text(_soDate?.toIso8601String().substring(0, 10) ?? '—'),
          onTap: () async {
            final d = await showDatePicker(
              context: context,
              initialDate: _soDate ?? DateTime.now(),
              firstDate: DateTime(2024),
              lastDate: DateTime(2030),
            );
            if (d != null) setState(() => _soDate = d);
          },
        ),
        ListTile(
          leading: const Icon(Icons.event_available),
          title: const Text('Voucher date'),
          trailing: Text(
            _voucherDate?.toIso8601String().substring(0, 10) ?? '—',
          ),
          onTap: () async {
            final d = await showDatePicker(
              context: context,
              initialDate: _voucherDate ?? DateTime.now(),
              firstDate: DateTime(2024),
              lastDate: DateTime(2030),
            );
            if (d != null) setState(() => _voucherDate = d);
          },
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton(
              onPressed: () => _save(close: false),
              child: const Text('Save'),
            ),
            FilledButton.tonal(
              onPressed: () => _save(close: true),
              child: const Text('Save & close tender'),
            ),
          ],
        ),
      ],
    );
  }
}
