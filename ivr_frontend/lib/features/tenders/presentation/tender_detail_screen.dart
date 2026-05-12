import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:intl/intl.dart';

import '../../../config/api_config.dart';
import '../data/tender_models.dart';
import '../data/tender_repository.dart';

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
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
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
                    _DocsTab(tenderId: d.summary.id, repo: _repo, initial: d.documents),
                    _FieldVerificationTab(tenderId: d.summary.id, repo: _repo, detail: d, onChanged: _reload),
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
  const _TenderHeader({required this.detail, required this.repo, required this.onAction});

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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _close(BuildContext context) async {
    try {
      await widget.repo.closeQuotations(widget.detail.summary.id);
      widget.onAction();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _onAccessModeChanged(BuildContext context, String? value) async {
    if (value == null || value == widget.detail.summary.quotationAccessMode) return;
    setState(() => _accessBusy = true);
    try {
      await widget.repo.setQuotationAccessMode(widget.detail.summary.id, value);
      if (!context.mounted) return;
      widget.onAction();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not update access: $e')));
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
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.titleEn ?? s.titleTa ?? 'Tender #${s.id}',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                if (s.titleTa != null && (s.titleEn ?? '').isNotEmpty)
                  Text(s.titleTa!, style: const TextStyle(color: Colors.black54)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Chip(label: Text(s.status)),
                    if (s.anchorDate != null) Chip(label: Text('Anchor ${df.format(s.anchorDate!)}')),
                    InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Quotation link',
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                              child: Text('Public — anyone with link + phone'),
                            ),
                          ],
                          onChanged: closed || _accessBusy ? null : (v) => _onAccessModeChanged(context, v),
                        ),
                      ),
                    ),
                    if (d.publicToken != null)
                      ActionChip(
                        avatar: const Icon(Icons.copy, size: 16),
                        label: const Text('Copy public link'),
                        onPressed: () {
                          final url = '${ApiConfig.baseUrl}/public/tenders/${d.publicToken}';
                          Clipboard.setData(ClipboardData(text: url));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Public tender link copied to clipboard.')),
                          );
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          if (s.status == 'draft')
            FilledButton.icon(
              onPressed: () => _publish(context),
              icon: const Icon(Icons.publish),
              label: const Text('Publish'),
            ),
          if (s.status == 'published') ...[
            FilledButton.icon(
              onPressed: () => _close(context),
              icon: const Icon(Icons.lock_clock),
              label: const Text('Close quotations'),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Tabs ────────────────────────────────────────────────────────────────

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
          ...detail.lineItems.map((li) => Card(
                child: ListTile(
                  leading: CircleAvatar(child: Text('${li.seq}')),
                  title: Text(li.descriptionEn ?? li.descriptionTa ?? '—'),
                  subtitle: Text([
                    if (li.quantity != null) '${li.quantity} ${li.unit ?? ''}'.trim(),
                    if (li.poleId != null) 'Pole #${li.poleId}',
                    if (li.complaintId != null) 'Complaint #${li.complaintId}',
                  ].join(' • ')),
                ),
              )),
        const SizedBox(height: 24),
        Text('Timeline', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ...detail.timeline.entries.map((e) => ListTile(
              dense: true,
              leading: const Icon(Icons.event_outlined),
              title: Text(e.key.replaceAll('_', ' ')),
              trailing: Text(e.value ?? '—'),
            )),
      ],
    );
  }
}

class _VendorsTab extends StatefulWidget {
  final TenderDetail detail;
  final TenderRepository repo;
  final VoidCallback onChanged;
  const _VendorsTab({required this.detail, required this.repo, required this.onChanged});

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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _manageInvites() async {
    final List<Vendor> all;
    try {
      all = await widget.repo.listVendors(active: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not load vendors: $e')));
      return;
    }
    if (!mounted) return;
    if (all.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add vendors in the Vendor directory before inviting.')),
      );
      return;
    }
    final preselected = widget.detail.invitedVendors.map((v) => v.id).toSet();
    final result = await showDialog<Set<int>>(
      context: context,
      builder: (_) => _InviteVendorsDialog(
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _award(int quotationId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Award contract?'),
        content: Text('Award quotation #$quotationId. This locks the awardee.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Award')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.repo.award(widget.detail.summary.id, quotationId);
      widget.onChanged();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.detail.quotations.where((q) => q.supersededById == null).toList()
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
              Text('Quotations (${active.length})', style: Theme.of(context).textTheme.titleMedium),
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
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              for (final q in active)
                Card(
                  color: q.id == l1Id ? Colors.amber.shade50 : null,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: q.id == l1Id ? Colors.amber : Colors.grey.shade300,
                      child: Text(q.id == l1Id ? 'L1' : '#${q.id}'),
                    ),
                    title: Text(q.submitterName),
                    subtitle: Text('${q.submitterPhoneE164} • ${q.source} • ${q.screeningOutcome}'),
                    trailing: Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text('₹ ${q.amount}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                        if (widget.detail.summary.status == 'quotations_closed' ||
                            widget.detail.summary.status == 'vendor_selected')
                          OutlinedButton(onPressed: () => _award(q.id), child: const Text('Award')),
                      ],
                    ),
                  ),
                ),
              if (active.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No quotations yet.'),
                ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('Invited vendors', style: Theme.of(context).textTheme.titleMedium),
              ),
              if (widget.detail.invitedVendors.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    "No vendors invited yet. Tap 'Invite vendors' to add some.",
                    style: TextStyle(color: Colors.black54),
                  ),
                )
              else
                for (final v in widget.detail.invitedVendors)
                  ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: Text(v.name),
                    subtitle: Text('${v.phoneE164}${v.place != null ? ' • ${v.place}' : ''}'),
                  ),
            ],
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
              TextField(controller: _name, decoration: const InputDecoration(labelText: 'Vendor name')),
              TextField(controller: _phone, decoration: const InputDecoration(labelText: 'Phone (10 digits)')),
              TextField(
                controller: _amount,
                decoration: const InputDecoration(labelText: 'Amount (₹)'),
                keyboardType: TextInputType.number,
              ),
              TextField(controller: _remarks, decoration: const InputDecoration(labelText: 'Remarks')),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _outcome,
                decoration: const InputDecoration(labelText: 'Screening outcome'),
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
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.of(context).pop({
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
                    onChanged: (val) => setState(() {
                      if (val == true) {
                        _selected.add(v.id);
                      } else {
                        _selected.remove(v.id);
                      }
                    }),
                    title: Text(v.name),
                    subtitle: Text('${v.phoneE164}${v.place != null ? ' • ${v.place}' : ''}'),
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
  final int tenderId;
  final TenderRepository repo;
  final List<TenderDocumentSummary> initial;
  const _DocsTab({required this.tenderId, required this.repo, required this.initial});

  @override
  State<_DocsTab> createState() => _DocsTabState();
}

class _DocsTabState extends State<_DocsTab> {
  late List<TenderDocumentSummary> _docs;

  @override
  void initState() {
    super.initState();
    _docs = widget.initial;
  }

  Future<void> _reload() async {
    final docs = await widget.repo.listDocuments(widget.tenderId);
    if (!mounted) return;
    setState(() => _docs = docs);
  }

  Future<void> _generate(String tpl, {int? vendorId}) async {
    try {
      await widget.repo.generateDocument(widget.tenderId, tpl, vendorId: vendorId);
      // Allow background processing.
      await Future.delayed(const Duration(seconds: 1));
      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _openDoc(TenderDocumentSummary doc) async {
    try {
      await widget.repo.downloadDocument(
        widget.tenderId,
        doc.id,
        fallbackName: 'tender-${widget.tenderId}-${doc.templateId}-v${doc.version}.pdf',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Download failed: $e')));
    }
  }

  Future<void> _downloadZip() async {
    try {
      await widget.repo.downloadDocumentsZip(widget.tenderId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Download failed: $e')));
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Share link failed: $e')));
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Share link failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    const templates = <_TemplateInfo>[
      _TemplateInfo('rfq', 'RFQ — விலைப்புள்ளி கோருதல்'),
      _TemplateInfo('comparative', 'Comparative — ஒப்பு நோக்கு பட்டியல்'),
      _TemplateInfo('work_order', 'Work order — வேலை உத்தரவு'),
      _TemplateInfo('so_proceedings', 'SO proceedings — நடவடிக்கைகள்'),
      _TemplateInfo('form19', 'Form 19 — செலவினச் சீட்டு'),
    ];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Text('Documents', style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: _copyZipShareLink,
              icon: const Icon(Icons.link_outlined),
              label: const Text('Share zip link'),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _downloadZip,
              icon: const Icon(Icons.archive_outlined),
              label: const Text('Download zip'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final tpl in templates)
          Card(
            child: ListTile(
              leading: const Icon(Icons.description_outlined),
              title: Text(tpl.label),
              subtitle: Text(_docs.where((d) => d.templateId == tpl.id).isEmpty
                  ? 'Not generated yet'
                  : 'Latest v${_docs.where((d) => d.templateId == tpl.id).first.version} — ${_docs.where((d) => d.templateId == tpl.id).first.status}'),
              trailing: Wrap(
                spacing: 6,
                children: [
                  if (_docs.where((d) => d.templateId == tpl.id && d.status == 'ready').isNotEmpty) ...[
                    OutlinedButton(
                      onPressed: () {
                        final doc = _docs.firstWhere((d) => d.templateId == tpl.id && d.status == 'ready');
                        _openDoc(doc);
                      },
                      child: const Text('Open'),
                    ),
                    IconButton(
                      tooltip: 'Copy share link',
                      icon: const Icon(Icons.link_outlined, size: 18),
                      onPressed: () {
                        final doc = _docs.firstWhere((d) => d.templateId == tpl.id && d.status == 'ready');
                        _copyDocShareLink(doc);
                      },
                    ),
                  ],
                  FilledButton(
                    onPressed: () => _generate(tpl.id),
                    child: const Text('Generate'),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _TemplateInfo {
  final String id;
  final String label;
  const _TemplateInfo(this.id, this.label);
}

class _FieldVerificationTab extends StatefulWidget {
  final int tenderId;
  final TenderRepository repo;
  final TenderDetail detail;
  final VoidCallback onChanged;
  const _FieldVerificationTab({
    required this.tenderId,
    required this.repo,
    required this.detail,
    required this.onChanged,
  });

  @override
  State<_FieldVerificationTab> createState() => _FieldVerificationTabState();
}

class _FieldVerificationTabState extends State<_FieldVerificationTab> {
  Future<List<ChecklistItem>>? _checklistFuture;

  @override
  void initState() {
    super.initState();
    _checklistFuture = widget.repo.getChecklist(widget.tenderId);
  }

  void _refresh() {
    if (!mounted) return;
    setState(() {
      _checklistFuture = widget.repo.getChecklist(widget.tenderId);
    });
  }

  Future<void> _newSession() async {
    try {
      final s = await widget.repo.createSession(widget.tenderId);
      if (!mounted) return;
      final url = '${ApiConfig.baseUrl}/public/field-sessions/${s.token ?? ''}';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Session created. Field link: $url')));
      widget.onChanged();
      _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _confirm() async {
    try {
      await widget.repo.confirmVerification(widget.tenderId);
      widget.onChanged();
      _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Text('Sessions (${widget.detail.sessions.length})',
                style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: _newSession,
              icon: const Icon(Icons.qr_code_outlined),
              label: const Text('New session'),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: _confirm,
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Confirm verification'),
            ),
          ],
        ),
        for (final s in widget.detail.sessions)
          Card(
            child: ListTile(
              leading: const Icon(Icons.location_on_outlined),
              title: Text('Session #${s.id} — ${s.uploadCount} upload(s)'),
              subtitle: Text(
                  'Expires ${s.expiresAt?.toIso8601String().substring(0, 10) ?? '—'} • Poles: ${s.poleSubsetIds.length}'),
            ),
          ),
        const Divider(height: 32),
        Text('Checklist', style: Theme.of(context).textTheme.titleMedium),
        FutureBuilder<List<ChecklistItem>>(
          future: _checklistFuture,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Padding(padding: EdgeInsets.all(16), child: LinearProgressIndicator());
            }
            if (snap.hasError) return Text('Error: ${snap.error}');
            final items = snap.data ?? [];
            if (items.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Text('No checklist items. Create a verification session to seed them.'),
              );
            }
            return Column(
              children: [
                for (final it in items)
                  CheckboxListTile(
                    value: it.isDone,
                    onChanged: (v) async {
                      try {
                        await widget.repo.patchChecklistItem(widget.tenderId, it.id, isDone: v ?? false);
                        _refresh();
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text('Error: $e')));
                      }
                    },
                    title: Text('Item #${it.id}${it.poleId != null ? ' • Pole #${it.poleId}' : ''}'),
                    subtitle: Text(it.notes ?? (it.upload != null ? 'Upload attached' : 'No proof yet')),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _PaymentTab extends StatefulWidget {
  final TenderDetail detail;
  final TenderRepository repo;
  final VoidCallback onChanged;
  const _PaymentTab({required this.detail, required this.repo, required this.onChanged});

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
    final pm = widget.detail.raw['tender']?['payment_meta'] as Map<String, dynamic>?;
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
      await widget.repo.recordPayment(
        widget.detail.summary.id,
        {
          'payment_method': _method,
          if (_amount.text.isNotEmpty) 'payment_amount': double.tryParse(_amount.text),
          if (_voucherSerial.text.isNotEmpty) 'voucher_serial': _voucherSerial.text,
          if (_nkNumber.text.isNotEmpty) 'nk_number': _nkNumber.text,
          if (_expenseHead.text.isNotEmpty) 'expense_head': _expenseHead.text,
          if (_tnpassRef.text.isNotEmpty) 'tnpass_ref': _tnpassRef.text,
          if (_soDate != null) 'so_proceedings_date': _soDate!.toIso8601String().substring(0, 10),
          if (_voucherDate != null) 'voucher_date': _voucherDate!.toIso8601String().substring(0, 10),
        },
        close: close,
      );
      widget.onChanged();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
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
          decoration: const InputDecoration(labelText: 'Voucher serial (auto if blank)'),
        ),
        TextField(controller: _nkNumber, decoration: const InputDecoration(labelText: 'NK number')),
        TextField(controller: _expenseHead, decoration: const InputDecoration(labelText: 'Expense head')),
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
          trailing: Text(_voucherDate?.toIso8601String().substring(0, 10) ?? '—'),
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
        Row(
          children: [
            FilledButton(onPressed: () => _save(close: false), child: const Text('Save')),
            const SizedBox(width: 8),
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
