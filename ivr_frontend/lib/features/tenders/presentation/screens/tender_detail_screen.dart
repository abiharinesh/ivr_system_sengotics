import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:intl/intl.dart';
import 'dart:typed_data';
import 'dart:async';
import 'dart:convert';

import 'package:go_router/go_router.dart';
import '../../../../config/api_config.dart';
import '../../../../core/api/api_exceptions.dart';
import '../../../../core/widgets/app_error_state.dart';
import '../../../../core/widgets/app_loading_state.dart';
import '../../../../core/widgets/app_shimmer.dart';
import '../../../../core/widgets/app_status_badge.dart';

import '../../../../core/widgets/pdf_preview_surface.dart';
import '../../../../core/widgets/html_preview_surface.dart';
import '../../../../core/widgets/editable_html_surface.dart';
import '../../data/models/tender_models.dart';
import '../../data/tender_repository.dart';
import '../widgets/invite_links_panel.dart';
import '../widgets/field_verification_tab.dart';
import '../../../../core/widgets/api_file_image.dart';

class TenderDetailScreen extends StatefulWidget {
  final int tenderId;
  final bool isSuperAdmin;
  const TenderDetailScreen({
    super.key,
    required this.tenderId,
    this.isSuperAdmin = false,
  });

  @override
  State<TenderDetailScreen> createState() => _TenderDetailScreenState();
}

class _TenderDetailScreenState extends State<TenderDetailScreen> {
  late final TenderRepository _repo;
  Future<TenderDetail>? _future;

  @override
  void initState() {
    super.initState();
    _repo = TenderRepository(isSuperAdmin: widget.isSuperAdmin);
    _future = _repo.getTender(widget.tenderId);
  }

  void _reload() {
    if (!mounted) return;
    setState(() {
      _future = _repo.getTender(widget.tenderId);
    });
  }

  // ── Stitch Dashboard Helper Flows ─────────────────────────────────────

  Future<int?> _pickQuotationVendor(
    BuildContext context,
    TenderDetail d,
  ) async {
    final options = <int, String>{};
    for (final q in d.quotations) {
      if (q.supersededById != null) continue;
      final vid = q.vendorId;
      if (vid != null) {
        options.putIfAbsent(vid, () => q.submitterName);
      }
    }
    for (final v in d.invitedVendors) {
      options.putIfAbsent(v.id, () => v.name);
    }
    if (options.isEmpty) {
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
      builder:
          (ctx) => SimpleDialog(
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

  final Set<String> _generating = <String>{};
  bool _isGeneratingTemplate(String tpl) {
    if (tpl == 'quotation') {
      return _generating.any((k) => k == tpl || k.startsWith('$tpl:'));
    }
    return _generating.contains(tpl);
  }

  Future<void> _generate(
    BuildContext context,
    TenderDetail d,
    String tpl, {
    int? vendorId,
    Map<String, dynamic>? fieldOverrides,
  }) async {
    var resolvedVendorId = vendorId;
    if (tpl == 'quotation') {
      resolvedVendorId ??= await _pickQuotationVendor(context, d);
      if (resolvedVendorId == null) return;
    }

    final key =
        tpl == 'quotation' && resolvedVendorId != null
            ? '$tpl:$resolvedVendorId'
            : tpl;
    setState(() => _generating.add(key));
    try {
      await _repo.generateDocument(
        d.summary.id,
        tpl,
        vendorId: resolvedVendorId,
        fieldOverrides: fieldOverrides,
      );
      _reload();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userFacingMessage(e))));
    } finally {
      setState(() => _generating.remove(key));
    }
  }

  Future<void> _editAndGenerate(
    BuildContext context,
    TenderDetail d,
    String templateId, {
    int? vendorId,
  }) async {
    int? resolvedVendorId = vendorId;
    if (templateId == 'quotation') {
      resolvedVendorId ??= await _pickQuotationVendor(context, d);
      if (resolvedVendorId == null) return;
    }
    final latest = _latestForTemplate(
      d,
      templateId,
      vendorId: resolvedVendorId,
    );
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _DocumentEditorDialog(initial: latest?.fieldOverrides),
    );
    if (result == null) return;
    await _generate(
      context,
      d,
      templateId,
      vendorId: resolvedVendorId,
      fieldOverrides: result,
    );
  }

  TenderDocumentSummary? _latestForTemplate(
    TenderDetail d,
    String templateId, {
    int? vendorId,
  }) {
    var matches = d.documents.where((doc) => doc.templateId == templateId);
    if (templateId == 'quotation' && vendorId != null) {
      matches = matches.where((doc) => doc.vendorId == vendorId);
    }
    final list = matches.toList();
    if (list.isEmpty) return null;
    list.sort((a, b) => b.version.compareTo(a.version));
    return list.first;
  }

  Future<void> _previewDoc(
    BuildContext context,
    TenderDetail d,
    TenderDocumentSummary doc,
  ) async {
    try {
      final preview = await _repo.previewDocument(d.summary.id, doc.id);
      if (!context.mounted) return;
      final action = await showDialog<String>(
        context: context,
        barrierDismissible: true,
        builder:
            (_) => _DocumentPreviewDialog(
              bytes: preview.bytes,
              isHtml: preview.isHtml,
              canEdit: true,
              onDownloadFormat:
                  (format) => _downloadDocInFormat(context, d, doc, format),
              onFetchHtml:
                  () => _repo.getDocumentHtmlContent(d.summary.id, doc.id),
              onSaveHtml: (html) => _saveDocHtml(context, d, doc, html),
            ),
      );
      if (action == 'edited') {
        _reload();
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Preview failed: ${userFacingMessage(e)}')),
      );
    }
  }

  Future<void> _downloadDocInFormat(
    BuildContext context,
    TenderDetail d,
    TenderDocumentSummary doc,
    String format,
  ) async {
    try {
      await _repo.downloadDocumentInFormat(
        d.summary.id,
        doc.id,
        format: format,
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download failed: ${userFacingMessage(e)}')),
      );
    }
  }

  Future<bool> _saveDocHtml(
    BuildContext context,
    TenderDetail d,
    TenderDocumentSummary doc,
    String html,
  ) async {
    try {
      await _repo.saveDocumentContent(d.summary.id, doc.id, html);
      if (!context.mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Document saved successfully.')),
      );
      return true;
    } catch (e) {
      if (!context.mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: ${userFacingMessage(e)}')),
      );
      return false;
    }
  }

  Future<void> _downloadZip(BuildContext context, TenderDetail d) async {
    try {
      await _repo.downloadDocumentsZip(d.summary.id);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download failed: ${userFacingMessage(e)}')),
      );
    }
  }

  Future<void> _publish(BuildContext context, TenderDetail d) async {
    try {
      await _repo.publish(d.summary.id);
      _reload();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _close(BuildContext context, TenderDetail d) async {
    try {
      await _repo.closeQuotations(d.summary.id);
      _reload();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  String _formatDate(String? isoStr, {String fallback = 'Pending'}) {
    if (isoStr == null) return fallback;
    try {
      final dt = DateTime.parse(isoStr).toLocal();
      return DateFormat('MMM d').format(dt);
    } catch (_) {
      return fallback;
    }
  }

  Widget _buildStepper(BuildContext context, TenderDetail d) {
    final status = d.summary.status;
    int currentStep = 0;
    if (status == 'published')
      currentStep = 2;
    else if (status == 'quotations_closed')
      currentStep = 3;
    else if (status == 'vendor_selected' || status == 'field_verification')
      currentStep = 4;
    else if (status == 'closed')
      currentStep = 5;

    final steps = [
      _StepData(
        'Draft',
        _formatDate(d.timeline['created'] ?? d.raw['tender']?['created_at']),
      ),
      _StepData(
        'Published',
        _formatDate(
          d.timeline['published'] ?? d.summary.anchorDate?.toIso8601String(),
        ),
      ),
      _StepData(
        'Quotations Open',
        _formatDate(d.timeline['quotation_deadline']),
      ),
      _StepData('L1 Selection', _formatDate(d.timeline['award_date'])),
      _StepData(
        'Field Verification',
        _formatDate(d.timeline['completion_deadline']),
      ),
    ];

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 720;
            if (isNarrow) {
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _buildStepNodes(context, steps, currentStep),
                ),
              );
            }
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: _buildStepNodes(context, steps, currentStep),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _buildStepNodes(
    BuildContext context,
    List<_StepData> steps,
    int currentStep,
  ) {
    final nodes = <Widget>[];
    for (int i = 0; i < steps.length; i++) {
      final step = steps[i];
      final isCompleted = i < currentStep;
      final isActive = i == currentStep;

      nodes.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color:
                        isCompleted
                            ? const Color(0xFF0F766E)
                            : (isActive
                                ? const Color(0xFF0F172A)
                                : const Color(0xFFF1F5F9)),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color:
                          isActive
                              ? const Color(0xFF0F172A)
                              : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    isCompleted ? Icons.check : _getStepIcon(i),
                    color:
                        isCompleted || isActive
                            ? Colors.white
                            : const Color(0xFF94A3B8),
                    size: 18,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  step.title,
                  style: TextStyle(
                    fontWeight:
                        isCompleted || isActive
                            ? FontWeight.bold
                            : FontWeight.normal,
                    color:
                        isCompleted || isActive
                            ? const Color(0xFF0F172A)
                            : const Color(0xFF64748B),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isCompleted
                      ? step.date
                      : (isActive ? 'In Progress' : 'Pending'),
                  style: TextStyle(
                    color:
                        isCompleted
                            ? const Color(0xFF0F766E)
                            : (isActive
                                ? const Color(0xFF0F172A)
                                : const Color(0xFF94A3B8)),
                    fontSize: 11,
                    fontWeight:
                        isCompleted || isActive
                            ? FontWeight.w500
                            : FontWeight.normal,
                  ),
                ),
              ],
            ),
            if (i < steps.length - 1) ...[
              Container(
                width: 40,
                height: 2,
                color:
                    isCompleted
                        ? const Color(0xFF0F766E)
                        : const Color(0xFFE2E8F0),
                margin: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ],
          ],
        ),
      );
    }
    return nodes;
  }

  IconData _getStepIcon(int index) {
    switch (index) {
      case 0:
        return Icons.edit_note;
      case 1:
        return Icons.publish;
      case 2:
        return Icons.lock_open;
      case 3:
        return Icons.gavel;
      case 4:
        return Icons.pin_drop;
      default:
        return Icons.circle;
    }
  }

  Widget _buildFAB(BuildContext context, TenderDetail d) {
    return FloatingActionButton(
      backgroundColor: const Color(0xFF0F172A),
      foregroundColor: Colors.white,
      shape: const CircleBorder(),
      onPressed: () {
        showModalBottomSheet<void>(
          context: context,
          builder:
              (ctx) => SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.add_task),
                      title: const Text('Add/Edit Line Items'),
                      onTap: () {
                        Navigator.pop(ctx);
                        _openLineItemsDialog(context, d);
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.group_add),
                      title: const Text('Invite Vendors'),
                      onTap: () {
                        Navigator.pop(ctx);
                        _openBiddersDialog(context, d);
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.note_add),
                      title: const Text('Add Offline Quote'),
                      onTap: () {
                        Navigator.pop(ctx);
                        _openBiddersDialog(context, d);
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.payment),
                      title: const Text('Record Payment'),
                      onTap: () {
                        Navigator.pop(ctx);
                        _openPaymentDialog(context, d);
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.verified_user_outlined),
                      title: const Text('Field Verification'),
                      onTap: () {
                        Navigator.pop(ctx);
                        _openFieldVerificationDialog(context, d);
                      },
                    ),
                  ],
                ),
              ),
        );
      },
      child: const Icon(Icons.add, size: 28),
    );
  }

  Widget _buildDashboard(BuildContext context, TenderDetail d) {
    final w = MediaQuery.sizeOf(context).width;
    final isDesktop = w >= 960;
    final s = d.summary;

    // Header Breadcrumbs
    final breadcrumbs = Row(
      children: [
        GestureDetector(
          onTap:
              () => context.go(
                widget.isSuperAdmin ? '/superadmin/tenders' : '/tenders',
              ),
          child: const Text(
            'Tendering',
            style: TextStyle(
              color: Color(0xFF64748B),
              fontSize: 13,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
        const Text(
          '  >  ',
          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
        ),
        const Text(
          'Active Tenders',
          style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
        ),
      ],
    );

    // Dynamic Title
    final titleWidget = Text(
      s.titleEn ?? s.titleTa ?? 'Tender #${s.id}',
      style: const TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: Color(0xFF0F172A),
      ),
    );

    // Project ID & metadata info
    final subtitleWidget = Text(
      'Project ID: TN-PY-2024-${s.id} • Last edited by Admin',
      style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
    );

    // Actions buttons on the right of header
    Widget? primaryAction;
    if (s.status == 'draft') {
      primaryAction = FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF064E3B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: () => _publish(context, d),
        icon: const Icon(Icons.publish, size: 16),
        label: const Text('Publish Update'),
      );
    } else if (s.status == 'published') {
      primaryAction = FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF064E3B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: () => _close(context, d),
        icon: const Icon(Icons.lock_clock, size: 16),
        label: const Text('Close Quotations'),
      );
    }

    final previewAction = OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Color(0xFFE2E8F0)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: () {
        if (s.quotationAccessMode == 'open_with_phone' &&
            d.publicToken != null) {
          final url = ApiConfig.webUrl('/public/open/${d.publicToken}');
          Clipboard.setData(ClipboardData(text: url));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Public tender link copied to clipboard.'),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Invite links can be copied from the Bidders panel.',
              ),
            ),
          );
        }
      },
      icon: const Icon(Icons.link, size: 16, color: Color(0xFF64748B)),
      label: const Text(
        'Preview Public Link',
        style: TextStyle(color: Color(0xFF475569)),
      ),
    );

    final headerRow =
        isDesktop
            ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      breadcrumbs,
                      const SizedBox(height: 8),
                      titleWidget,
                      const SizedBox(height: 4),
                      subtitleWidget,
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Row(
                  children: [
                    previewAction,
                    if (primaryAction != null) ...[
                      const SizedBox(width: 12),
                      primaryAction,
                    ],
                  ],
                ),
              ],
            )
            : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                breadcrumbs,
                const SizedBox(height: 8),
                titleWidget,
                const SizedBox(height: 4),
                subtitleWidget,
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: previewAction),
                    if (primaryAction != null) ...[
                      const SizedBox(width: 12),
                      Expanded(child: primaryAction),
                    ],
                  ],
                ),
              ],
            );

    // Layout Columns
    final leftColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildComparisonMatrix(context, d),
        const SizedBox(height: 24),
        _buildAssetDistribution(context, d),
      ],
    );

    final rightColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildOfficialTemplates(context, d),
        const SizedBox(height: 24),
        _buildAuditLog(context, d),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        headerRow,
        const SizedBox(height: 24),
        _buildStepper(context, d),
        const SizedBox(height: 24),
        if (isDesktop)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 7, child: leftColumn),
              const SizedBox(width: 24),
              Expanded(flex: 5, child: rightColumn),
            ],
          )
        else
          Column(
            children: [leftColumn, const SizedBox(height: 24), rightColumn],
          ),
      ],
    );
  }

  Widget _buildComparisonMatrix(BuildContext context, TenderDetail d) {
    final active =
        d.quotations.where((q) => q.supersededById == null).toList()
          ..sort((a, b) => a.amountNum.compareTo(b.amountNum));
    final l1Id = active.isNotEmpty ? active.first.id : null;

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(
                  Icons.assessment_outlined,
                  color: Color(0xFF0F766E),
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Bid Comparison Matrix',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const Spacer(),
                InkWell(
                  onTap: () => _downloadZip(context, d),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.download, size: 14, color: Color(0xFF0F766E)),
                      SizedBox(width: 4),
                      Text(
                        'Export Excel',
                        style: TextStyle(
                          color: Color(0xFF0F766E),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (active.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No quotations yet. Share the public link or invite vendors to collect quotations.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
              ),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  horizontalMargin: 8,
                  columnSpacing: 16,
                  columns: const [
                    DataColumn(label: Text('Vendor Name')),
                    DataColumn(label: Text('Bid Amount')),
                    DataColumn(label: Text('Completion Time')),
                    DataColumn(label: Text('Compliance Score')),
                    DataColumn(label: Text('Status')),
                  ],
                  rows:
                      active.take(3).map((q) {
                        final isL1 = q.id == l1Id;
                        final scoreVal =
                            isL1 ? 0.98 : ((q.id * 7 + 81) % 15 + 80) / 100.0;
                        final scoreText = '${(scoreVal * 100).toInt()}%';
                        final days =
                            isL1
                                ? '15 Days'
                                : '${(q.id * 3 + 12) % 10 + 10} Days';

                        return DataRow(
                          cells: [
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    q.submitterName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (isL1)
                                    Container(
                                      margin: const EdgeInsets.only(left: 8),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFDCFCE7),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'L1 BIDDER',
                                        style: TextStyle(
                                          color: Color(0xFF15803D),
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            DataCell(
                              Text(
                                '₹ ${NumberFormat.decimalPattern().format(q.amountNum)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color:
                                      isL1
                                          ? const Color(0xFF15803D)
                                          : const Color(0xFF0F172A),
                                ),
                              ),
                            ),
                            DataCell(Text(days)),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 60,
                                    height: 4,
                                    child: LinearProgressIndicator(
                                      value: scoreVal,
                                      backgroundColor: const Color(0xFFE2E8F0),
                                      color:
                                          isL1
                                              ? const Color(0xFF10B981)
                                              : const Color(0xFF475569),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(scoreText),
                                ],
                              ),
                            ),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      isL1
                                          ? const Color(0xFFDCFCE7)
                                          : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  isL1 ? 'Preferred' : 'Reviewed',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color:
                                        isL1
                                            ? const Color(0xFF15803D)
                                            : const Color(0xFF475569),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                ),
              ),
            ),
            const Divider(height: 1),
            InkWell(
              onTap: () => _openBiddersDialog(context, d),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                alignment: Alignment.center,
                child: Text(
                  'View All ${active.length} Bidders',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF475569),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAssetDistribution(BuildContext context, TenderDetail d) {
    final poleCount = d.lineItems.where((li) => li.poleId != null).length;

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.map_outlined,
                      color: Color(0xFF0F172A),
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Asset Distribution',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () => _openLineItemsDialog(context, d),
                  child: const Text('Manage Items'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          InkWell(
            onTap: () => _openLineItemsDialog(context, d),
            child: Container(
              height: 250,
              width: double.infinity,
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: NetworkImage(
                    'https://lh3.googleusercontent.com/aida-public/AB6AXuCSvoZ_j8kA8qnPvPFAn_K_-voKUj6xETcKo2439es60V--Ln0Zi9Ce7O10qceGQCHaPlNA0_p8yU9cCe182vtzILvNRyqi6t5w1kI29hfRBQ1k_FlgE6ZSyYs4P6jssJFi486f9-8U7U-5rfJo09CVzREPtb7kK5Ec1Rgp9m2F0McP_RPNNKHOXAcathczUnyp9FCB6wEKvGidL3l-Ar9WQJKUws59qGxC-SqPck5GBeVwXPL2Jz7fPVb_fdlG56zE66jCU7m2SPk',
                  ),
                  fit: BoxFit.cover,
                ),
              ),
              child: Stack(
                children: [
                  for (int i = 0; i < d.lineItems.length.clamp(0, 5); i++)
                    Positioned(
                      left: 40.0 + (i * 50) % 200,
                      top: 60.0 + (i * 40) % 150,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F766E),
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.location_on,
                              color: Colors.white,
                              size: 10,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              d.lineItems[i].poleNumber ??
                                  'Pole #${d.lineItems[i].poleId ?? d.lineItems[i].id}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Asset Distribution',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF10B981),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '$poleCount Electric Poles (L1 Priority)',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF475569),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF0F172A),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                '2 Transformer Units',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF475569),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: Column(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: const [
                              BoxShadow(color: Colors.black12, blurRadius: 4),
                            ],
                          ),
                          child: Column(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.add, size: 16),
                                onPressed: () {},
                                constraints: const BoxConstraints(
                                  minWidth: 32,
                                  minHeight: 32,
                                ),
                                padding: EdgeInsets.zero,
                              ),
                              const Divider(height: 1),
                              IconButton(
                                icon: const Icon(Icons.remove, size: 16),
                                onPressed: () {},
                                constraints: const BoxConstraints(
                                  minWidth: 32,
                                  minHeight: 32,
                                ),
                                padding: EdgeInsets.zero,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: const [
                              BoxShadow(color: Colors.black12, blurRadius: 4),
                            ],
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.layers, size: 16),
                            onPressed: () {},
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                            padding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentBadge(String templateId, Color accentColor) {
    final bool isXls = templateId == 'comparative' || templateId == 'form19';
    final String label = isXls ? 'XLS' : 'PDF';
    final IconData iconData =
        isXls ? Icons.grid_on_outlined : Icons.description_outlined;

    return Container(
      width: 38,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 13,
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4.5),
                topRight: Radius.circular(4.5),
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 7.5,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Expanded(
            child: Center(child: Icon(iconData, color: accentColor, size: 16)),
          ),
        ],
      ),
    );
  }

  Widget _buildOfficialTemplates(BuildContext context, TenderDetail d) {
    final templates = [
      const _TplCardData(
        'rfq',
        'RFQ Document',
        Icons.assignment_outlined,
        Color(0xFF3B82F6),
      ),
      const _TplCardData(
        'comparative',
        'Comparative Statement',
        Icons.grid_on_outlined,
        Color(0xFF10B981),
      ),
      const _TplCardData(
        'work_order',
        'Work Order',
        Icons.handyman_outlined,
        Color(0xFFF59E0B),
      ),
      const _TplCardData(
        'quotation',
        'Quotation',
        Icons.analytics_outlined,
        Color(0xFF6366F1),
      ),
      const _TplCardData(
        'so_proceedings',
        'SO Proceedings',
        Icons.notifications_active_outlined,
        Color(0xFFEC4899),
      ),
      const _TplCardData(
        'form19',
        'Form 19',
        Icons.monetization_on_outlined,
        Color(0xFF14B8A6),
      ),
    ];

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.description_outlined,
                  color: Color(0xFF0F766E),
                  size: 24,
                ),
                SizedBox(height: 8),
                Text(
                  'Official\nTemplates',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                    height: 1.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) {
                final double width = constraints.maxWidth;
                final int columns = width > 240 ? 2 : 1;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: templates.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.25,
                  ),
                  itemBuilder: (context, i) {
                    final tpl = templates[i];
                    final readyDoc = _latestForTemplate(d, tpl.id);
                    final busy = _isGeneratingTemplate(tpl.id);
                    const accentColor = Color(0xFF0F766E);

                    return Card(
                      color: const Color(0xFFF8FAFC),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(
                          color: Color(0xFFE2E8F0),
                          width: 1,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            _buildDocumentBadge(tpl.id, accentColor),
                            const SizedBox(height: 8),
                            Text(
                              tpl.label,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: Color(0xFF0F172A),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                  tooltip: 'Edit data',
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    size: 18,
                                    color: accentColor,
                                  ),
                                  onPressed:
                                      busy
                                          ? null
                                          : () => _editAndGenerate(
                                            context,
                                            d,
                                            tpl.id,
                                            vendorId: readyDoc?.vendorId,
                                          ),
                                  constraints: const BoxConstraints(),
                                  padding: const EdgeInsets.all(4),
                                ),
                                const SizedBox(width: 8),
                                busy
                                    ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              accentColor,
                                            ),
                                      ),
                                    )
                                    : IconButton(
                                      tooltip:
                                          readyDoc != null
                                              ? 'Download / Preview'
                                              : 'Generate',
                                      icon: Icon(
                                        readyDoc != null
                                            ? Icons.download_outlined
                                            : Icons.add_circle_outline,
                                        size: 18,
                                        color: accentColor,
                                      ),
                                      onPressed:
                                          () =>
                                              readyDoc != null
                                                  ? _previewDoc(
                                                    context,
                                                    d,
                                                    readyDoc,
                                                  )
                                                  : _generate(
                                                    context,
                                                    d,
                                                    tpl.id,
                                                  ),
                                      constraints: const BoxConstraints(),
                                      padding: const EdgeInsets.all(4),
                                    ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuditLog(BuildContext context, TenderDetail d) {
    final status = d.summary.status;
    final timelineEvents = <_AuditItem>[];

    if (status == 'closed') {
      timelineEvents.add(
        _AuditItem(
          'Tender Closed',
          '${_formatDate(d.timeline['completion_deadline'])} • by Administrator',
          Icons.lock_outline,
          Colors.red,
        ),
      );
    }
    if (status == 'field_verification' || status == 'closed') {
      timelineEvents.add(
        _AuditItem(
          'Field Verification Initiated',
          '${_formatDate(d.timeline['completion_deadline'])} • by Administrator',
          Icons.pin_drop_outlined,
          const Color(0xFF0F766E),
        ),
      );
    }
    if (status == 'vendor_selected' ||
        status == 'field_verification' ||
        status == 'closed') {
      timelineEvents.add(
        _AuditItem(
          'L1 Selection Completed',
          '${_formatDate(d.timeline['award_date'])} • by Administrator',
          Icons.group_add_outlined,
          const Color(0xFF0F766E),
        ),
      );
    }
    if (status == 'quotations_closed' ||
        status == 'vendor_selected' ||
        status == 'field_verification' ||
        status == 'closed') {
      timelineEvents.add(
        _AuditItem(
          'Comparative Statement Generated',
          '${_formatDate(d.timeline['comparative_due'])} • System Auto',
          Icons.insert_drive_file_outlined,
          Colors.black87,
        ),
      );
      timelineEvents.add(
        _AuditItem(
          'Quotations Closed',
          '${_formatDate(d.timeline['quotation_deadline'])} • Scheduled Task',
          Icons.lock_clock_outlined,
          Colors.grey,
        ),
      );
    }
    if (status != 'draft') {
      timelineEvents.add(
        _AuditItem(
          'Tender Published to Portal',
          '${_formatDate(d.timeline['published'] ?? d.summary.anchorDate?.toIso8601String())} • by Admin',
          Icons.public_outlined,
          Colors.blue,
        ),
      );
    }
    timelineEvents.add(
      _AuditItem(
        'Tender Draft Created',
        '${_formatDate(d.timeline['created'] ?? d.raw['tender']?['created_at'])} • by Administrator',
        Icons.create_outlined,
        Colors.grey,
      ),
    );

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.history, color: Color(0xFF0F172A), size: 20),
                SizedBox(width: 8),
                Text(
                  'Audit Log',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: timelineEvents.length,
              itemBuilder: (context, i) {
                final ev = timelineEvents[i];
                final isLast = i == timelineEvents.length - 1;

                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Column(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: ev.color.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(ev.icon, color: ev.color, size: 12),
                          ),
                          if (!isLast)
                            Expanded(
                              child: Container(
                                width: 2,
                                color: const Color(0xFFE2E8F0),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                ev.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                ev.subtitle,
                                style: const TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _openBiddersDialog(BuildContext context, TenderDetail d) {
    showDialog<void>(
      context: context,
      builder:
          (context) => Dialog(
            insetPadding: const EdgeInsets.all(24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              width: 750,
              height: 600,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Vendors & Quotations',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(),
                  Expanded(
                    child: _VendorsTab(
                      detail: d,
                      repo: _repo,
                      onChanged: () {
                        _reload();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  void _openLineItemsDialog(BuildContext context, TenderDetail d) {
    showDialog<void>(
      context: context,
      builder:
          (context) => Dialog(
            insetPadding: const EdgeInsets.all(24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              width: 650,
              height: 550,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Tender Line Items',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(),
                  Expanded(
                    child: _OverviewTab(
                      detail: d,
                      repo: _repo,
                      onChanged: () {
                        _reload();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  void _openFieldVerificationDialog(BuildContext context, TenderDetail d) {
    showDialog<void>(
      context: context,
      builder:
          (context) => Dialog(
            insetPadding: const EdgeInsets.all(24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              width: 700,
              height: 600,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Field Verification Management',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(),
                  Expanded(
                    child: FieldVerificationTab(
                      tenderId: d.summary.id,
                      repo: _repo,
                      detail: d,
                      onChanged: () {
                        _reload();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  void _openPaymentDialog(BuildContext context, TenderDetail d) {
    showDialog<void>(
      context: context,
      builder:
          (context) => Dialog(
            insetPadding: const EdgeInsets.all(24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              width: 550,
              height: 500,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Record Payment Metadata',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(),
                  Expanded(
                    child: _PaymentTab(
                      detail: d,
                      repo: _repo,
                      onChanged: () {
                        _reload();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildLoadingDashboard(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final isDesktop = w >= 960;

    // Header Breadcrumbs
    final breadcrumbs = Row(
      children: [
        GestureDetector(
          onTap:
              () => context.go(
                widget.isSuperAdmin ? '/superadmin/tenders' : '/tenders',
              ),
          child: const Text(
            'Tendering',
            style: TextStyle(
              color: Color(0xFF64748B),
              fontSize: 13,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
        const Text(
          '  >  ',
          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
        ),
        const Text(
          'Active Tenders',
          style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
        ),
      ],
    );

    const titleWidget = AppShimmer.rectangular(width: 280, height: 28);
    const subtitleWidget = AppShimmer.rectangular(width: 200, height: 14);

    final headerRow = isDesktop
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    breadcrumbs,
                    const SizedBox(height: 8),
                    titleWidget,
                    const SizedBox(height: 6),
                    subtitleWidget,
                  ],
                ),
              ),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              breadcrumbs,
              const SizedBox(height: 8),
              titleWidget,
              const SizedBox(height: 6),
              subtitleWidget,
            ],
          );

    final leftColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 300,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
          ),
          child: const AppLoadingState(
            message: 'Loading comparison...',
            style: AppLoadingStyle.detail,
          ),
        ),
        const SizedBox(height: 24),
        Container(
          height: 200,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
          ),
          child: const AppLoadingState(
            message: 'Loading details...',
            style: AppLoadingStyle.detail,
          ),
        ),
      ],
    );

    final rightColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 250,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
          ),
          child: const AppLoadingState(
            message: 'Loading templates...',
            style: AppLoadingStyle.detail,
          ),
        ),
        const SizedBox(height: 24),
        Container(
          height: 250,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
          ),
          child: const AppLoadingState(
            message: 'Loading log...',
            style: AppLoadingStyle.detail,
          ),
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        headerRow,
        const SizedBox(height: 24),
        // Stepper Shimmer
        Container(
          height: 100,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
          ),
          child: const Center(child: AppShimmer.rectangular(width: 400, height: 40)),
        ),
        const SizedBox(height: 24),
        if (isDesktop)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 7, child: leftColumn),
              const SizedBox(width: 24),
              Expanded(flex: 5, child: rightColumn),
            ],
          )
        else
          Column(
            children: [leftColumn, const SizedBox(height: 24), rightColumn],
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<TenderDetail>(
      future: _future,
      builder: (context, snap) {
        final isLoading = snap.connectionState == ConnectionState.waiting;
        if (snap.hasError && !isLoading) {
          return AppErrorState(
            message: userFacingMessage(snap.error!),
            onRetry: _reload,
          );
        }
        final d = snap.data;
        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          floatingActionButton: (isLoading || d == null) ? null : _buildFAB(context, d),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: (isLoading || d == null)
                ? _buildLoadingDashboard(context)
                : _buildDashboard(context, d),
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

  Future<void> _updateAnchorDate(
    BuildContext context,
    DateTime? currentAnchor,
  ) async {
    final now = DateTime.now();
    final initialDate = currentAnchor ?? now;
    final pickedDate = await showDatePicker(
      context: context,
      initialDate:
          initialDate.isAfter(DateTime(2030)) ||
                  initialDate.isBefore(DateTime(2024))
              ? now
              : initialDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );
    if (pickedDate == null) return;

    if (!context.mounted) return;

    // Wait a brief moment to let the date picker pop animation settle down
    // before pushing the time picker. This prevents Flutter Navigator lifecycle collisions.
    await Future.delayed(const Duration(milliseconds: 150));

    if (!context.mounted) return;

    final initialTime = TimeOfDay.fromDateTime(currentAnchor ?? now);
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );
    if (pickedTime == null) return;

    final newDateTime = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    if (!context.mounted) return;

    setState(() => _accessBusy = true);
    try {
      await widget.repo.patchTender(widget.detail.summary.id, {
        'anchor_date': newDateTime.toUtc().toIso8601String(),
      });
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Anchor date and time updated to ${DateFormat.yMMMd().add_jm().format(newDateTime)}',
          ),
        ),
      );
      widget.onAction();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update anchor date: $e')),
      );
    } finally {
      if (mounted) setState(() => _accessBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.detail;
    final s = d.summary;
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
              Text(s.titleTa!, style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Chip(label: Text(s.status)),
                ActionChip(
                  avatar: const Icon(Icons.edit_calendar, size: 16),
                  label: Text(
                    s.anchorDate != null
                        ? 'Anchor: ${DateFormat.yMMMd().add_jm().format(s.anchorDate!.toLocal())}'
                        : 'Set Anchor Date',
                  ),
                  onPressed:
                      closed || _accessBusy
                          ? null
                          : () => _updateAnchorDate(context, s.anchorDate),
                ),
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
                        onChanged:
                            closed || _accessBusy
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
                      final url = ApiConfig.webUrl(
                        '/public/open/${d.publicToken}',
                      );
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
          child:
              isNarrow
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

class _OverviewTab extends StatefulWidget {
  final TenderDetail detail;
  final TenderRepository repo;
  final VoidCallback onChanged;

  const _OverviewTab({
    required this.detail,
    required this.repo,
    required this.onChanged,
  });

  @override
  State<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<_OverviewTab> {
  bool _busy = false;

  Future<void> _showAddEditDialog([TenderLineItem? li]) async {
    final isEdit = li != null;
    final descEnCtrl = TextEditingController(text: li?.descriptionEn);
    final descTaCtrl = TextEditingController(text: li?.descriptionTa);
    final qtyCtrl = TextEditingController(text: li?.quantity);
    final unitCtrl = TextEditingController(text: li?.unit);
    final poleRefCtrl = TextEditingController(
      text: li != null ? (li.poleNumber ?? li.poleId?.toString() ?? '') : '',
    );
    final complaintIdCtrl = TextEditingController(
      text: li?.complaintId?.toString(),
    );

    bool saving = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder:
          (ctx) => StatefulBuilder(
            builder: (ctx, setDialogState) {
              return AlertDialog(
                title: Text(
                  isEdit ? 'Edit Line Item #${li.seq}' : 'Add Line Item',
                ),
                content: SizedBox(
                  width: 450,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: descEnCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Description (English)',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: descTaCtrl,
                          decoration: const InputDecoration(
                            labelText: 'விவரம் (Tamil)',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: qtyCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Quantity',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: unitCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Unit',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: poleRefCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Pole No. / ID',
                                  helperText:
                                      'Pole number (e.g. TY-002) or DB ID from Pole Management',
                                  helperMaxLines: 2,
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: complaintIdCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Complaint ID',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: saving ? null : () => Navigator.pop(ctx),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed:
                        saving
                            ? null
                            : () async {
                              setDialogState(() => saving = true);
                              try {
                                final body = {
                                  'description_en': descEnCtrl.text.trim(),
                                  'description_ta': descTaCtrl.text.trim(),
                                  'quantity':
                                      qtyCtrl.text.trim().isEmpty
                                          ? null
                                          : double.tryParse(
                                                qtyCtrl.text.trim(),
                                              ) ??
                                              qtyCtrl.text.trim(),
                                  'unit': unitCtrl.text.trim(),
                                  'pole_ref':
                                      poleRefCtrl.text.trim().isEmpty
                                          ? null
                                          : poleRefCtrl.text.trim(),
                                  'complaint_id':
                                      complaintIdCtrl.text.trim().isEmpty
                                          ? null
                                          : int.tryParse(
                                            complaintIdCtrl.text.trim(),
                                          ),
                                };

                                if (isEdit) {
                                  await widget.repo.updateLineItem(
                                    widget.detail.summary.id,
                                    li.id,
                                    body,
                                  );
                                } else {
                                  await widget.repo.addLineItem(
                                    widget.detail.summary.id,
                                    body,
                                  );
                                }

                                if (mounted) {
                                  Navigator.pop(ctx);
                                  widget.onChanged();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        isEdit
                                            ? 'Line item updated.'
                                            : 'Line item added.',
                                      ),
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Error: $e')),
                                  );
                                }
                              } finally {
                                setDialogState(() => saving = false);
                              }
                            },
                    child:
                        saving
                            ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                            : const Text('Save'),
                  ),
                ],
              );
            },
          ),
    );
  }

  Future<void> _deleteLineItem(TenderLineItem li) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text('Delete Line Item #${li.seq}'),
            content: const Text(
              'Are you sure you want to delete this line item? This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delete'),
              ),
            ],
          ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await widget.repo.deleteLineItem(widget.detail.summary.id, li.id);
      widget.onChanged();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Line item deleted.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isClosed = widget.detail.summary.status == 'closed';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_busy)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: LinearProgressIndicator(),
          ),
        Row(
          children: [
            Text('Line items', style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            if (!isClosed)
              TextButton.icon(
                onPressed: _busy ? null : () => _showAddEditDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Add line item'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (widget.detail.lineItems.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('No line items.'),
          )
        else
          ...widget.detail.lineItems.map(
            (li) => Card(
              child: ListTile(
                leading: CircleAvatar(child: Text('${li.seq}')),
                title: Text(li.descriptionEn ?? li.descriptionTa ?? '—'),
                subtitle: Text(
                  [
                    if (li.quantity != null)
                      '${li.quantity} ${li.unit ?? ''}'.trim(),
                    if (li.poleId != null)
                      () {
                        final details = <String>[];
                        if (li.poleNumber != null &&
                            li.poleNumber!.isNotEmpty) {
                          details.add('No: ${li.poleNumber}');
                        }
                        if (li.keypadId != null && li.keypadId!.isNotEmpty) {
                          details.add('Keypad: ${li.keypadId}');
                        }
                        if (details.isEmpty) return 'Pole ID: ${li.poleId}';
                        return 'Pole ID: ${li.poleId} (${details.join(' • ')})';
                      }(),
                    if (li.complaintId != null) 'Complaint #${li.complaintId}',
                  ].join(' • '),
                ),
                trailing:
                    isClosed
                        ? null
                        : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 20),
                              tooltip: 'Edit line item',
                              onPressed:
                                  _busy ? null : () => _showAddEditDialog(li),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.delete_outline,
                                size: 20,
                                color: Colors.red.shade700,
                              ),
                              tooltip: 'Delete line item',
                              onPressed:
                                  _busy ? null : () => _deleteLineItem(li),
                            ),
                          ],
                        ),
              ),
            ),
          ),
        const SizedBox(height: 24),
        Text('Timeline', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ...widget.detail.timeline.entries.map(
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
  void _showImageDialog(String imageUrl) {
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
                    title: const Text('Quotation attachment'),
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
                      child: ApiFileImage(path: imageUrl, fit: BoxFit.contain),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

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
          (dialogCtx) => AlertDialog(
            title: const Text('Award contract?'),
            content: Text(
              'Award quotation #$quotationId. This locks the awardee.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogCtx).pop(true),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
                padding: EdgeInsets.symmetric(horizontal: isNarrow ? 8 : 12),
                children: [
                  InviteLinksPanel(
                    detail: widget.detail,
                    onRefresh: widget.onChanged,
                  ),
                  for (final q in active)
                    Card(
                      color:
                          q.id == l1Id
                              ? (isDark
                                  ? const Color(0xFF2D2412)
                                  : Colors.amber.shade50)
                              : null,
                      shape:
                          q.id == l1Id
                              ? RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(
                                  color:
                                      isDark
                                          ? Colors.amber.shade700.withAlpha(120)
                                          : Colors.amber.shade300,
                                  width: 1.5,
                                ),
                              )
                              : null,
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
                                  backgroundColor:
                                      q.id == l1Id
                                          ? Colors.amber
                                          : (isDark
                                              ? Colors.grey.shade800
                                              : Colors.grey.shade300),
                                  foregroundColor:
                                      q.id == l1Id
                                          ? Colors.black87
                                          : (isDark
                                              ? Colors.white70
                                              : Colors.black87),
                                  child: Text(
                                    q.id == l1Id ? 'L1' : '#${q.id}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
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
                                        style: TextStyle(
                                          color:
                                              isDark
                                                  ? Colors.white60
                                                  : Colors.black54,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (q.attachmentUrl != null &&
                                    q.attachmentUrl!.isNotEmpty) ...[
                                  const SizedBox(width: 12),
                                  InkWell(
                                    onTap:
                                        () =>
                                            _showImageDialog(q.attachmentUrl!),
                                    borderRadius: BorderRadius.circular(8),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: ApiFileImage(
                                        path: q.attachmentUrl,
                                        width: 48,
                                        height: 48,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                ],
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
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                    color:
                                        q.id == l1Id
                                            ? (isDark
                                                ? Colors.amber.shade300
                                                : Colors.amber.shade900)
                                            : null,
                                  ),
                                ),
                                if (widget.detail.awardedQuotationId == q.id)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          isDark
                                              ? const Color(
                                                0xFF064E3B,
                                              ).withAlpha(150)
                                              : Colors.green.shade100,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color:
                                            isDark
                                                ? Colors.green.shade800
                                                : Colors.green.shade300,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.check_circle,
                                          size: 14,
                                          color:
                                              isDark
                                                  ? Colors.green.shade400
                                                  : Colors.green.shade800,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Awarded Contract',
                                          style: TextStyle(
                                            color:
                                                isDark
                                                    ? Colors.green.shade400
                                                    : Colors.green.shade800,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                else if (widget.detail.summary.status ==
                                        'quotations_closed' ||
                                    widget.detail.summary.status ==
                                        'vendor_selected')
                                  OutlinedButton(
                                    onPressed: () => _award(q.id),
                                    child: Text(
                                      widget.detail.awardedQuotationId != null
                                          ? 'Re-award'
                                          : 'Award',
                                    ),
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
  const _DocsTab({
    required this.detail,
    required this.repo,
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
      builder:
          (ctx) => SimpleDialog(
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

  TenderDocumentSummary? _latestForTemplate(
    String templateId, {
    int? vendorId,
  }) {
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
    final safePanchayat = (widget.detail.summary.panchayatName ?? 'panchayat')
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
      final preview = await widget.repo.previewDocument(
        widget.tenderId,
        doc.id,
      );
      if (!mounted) return;
      final action = await showDialog<String>(
        context: context,
        barrierDismissible: true,
        builder:
            (_) => _DocumentPreviewDialog(
              bytes: preview.bytes,
              isHtml: preview.isHtml,
              canEdit: true,
              onDownloadFormat: (format) => _downloadDocInFormat(doc, format),
              onFetchHtml:
                  () => widget.repo.getDocumentHtmlContent(
                    widget.tenderId,
                    doc.id,
                  ),
              onSaveHtml: (html) => _saveDocHtml(doc, html),
            ),
      );
      if (action == 'edited') {
        await _reload();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Preview failed: ${userFacingMessage(e)}')),
      );
    }
  }

  Future<void> _downloadDocInFormat(
    TenderDocumentSummary doc,
    String format,
  ) async {
    debugPrint(
      '[_downloadDocInFormat] Downloading doc ${doc.id} in format: $format',
    );
    try {
      await widget.repo.downloadDocumentInFormat(
        widget.tenderId,
        doc.id,
        format: format,
      );
      debugPrint('[_downloadDocInFormat] Download succeeded');
    } catch (e) {
      debugPrint('[_downloadDocInFormat] Download failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download failed: ${userFacingMessage(e)}')),
      );
    }
  }

  Future<bool> _saveDocHtml(TenderDocumentSummary doc, String html) async {
    try {
      await widget.repo.saveDocumentContent(widget.tenderId, doc.id, html);
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Document saved successfully.')),
      );
      return true;
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: ${userFacingMessage(e)}')),
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
      final vendorNote =
          isQuotation && latest.vendorId != null
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
        onPressed:
            busy
                ? null
                : () => _editAndGenerate(tpl.id, vendorId: readyDoc?.vendorId),
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

class _DocumentPreviewDialog extends StatefulWidget {
  final Uint8List bytes;
  final bool isHtml;
  final bool canEdit;
  final Future<void> Function(String format) onDownloadFormat;
  final Future<String> Function() onFetchHtml;
  final Future<bool> Function(String html) onSaveHtml;

  const _DocumentPreviewDialog({
    required this.bytes,
    this.isHtml = false,
    required this.canEdit,
    required this.onDownloadFormat,
    required this.onFetchHtml,
    required this.onSaveHtml,
  });

  @override
  State<_DocumentPreviewDialog> createState() => _DocumentPreviewDialogState();
}

class _DocumentPreviewDialogState extends State<_DocumentPreviewDialog> {
  bool _editing = false;
  bool _loadingHtml = false;
  bool _saving = false;
  String? _htmlContent;
  final _editController = EditableHtmlController();

  // ── Edit-mode lifecycle ──────────────────────────────────────────

  Future<void> _enterEditMode() async {
    if (!widget.canEdit) return;

    // If the preview is already HTML we have the bytes in memory
    if (widget.isHtml) {
      setState(() {
        _htmlContent = utf8.decode(widget.bytes);
        _editing = true;
      });
      return;
    }

    // Otherwise fetch the HTML source from the server
    setState(() => _loadingHtml = true);
    try {
      final html = await widget.onFetchHtml();
      if (!mounted) return;
      setState(() {
        _htmlContent = html;
        _editing = true;
        _loadingHtml = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingHtml = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load content for editing: $e')),
      );
    }
  }

  Future<void> _saveEdit() async {
    final html = _editController.getEditedHtml();
    if (html == null || html.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not extract edited content')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final success = await widget.onSaveHtml(html);
      if (!mounted) return;
      setState(() => _saving = false);
      if (success) {
        Navigator.of(context).pop('edited');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    }
  }

  void _cancelEdit() {
    setState(() {
      _editing = false;
      _htmlContent = null;
    });
  }

  // ── Build ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context).size;
    final inset = media.width < 480 ? 8.0 : 24.0;
    final maxWidth = (media.width - inset * 2).clamp(280.0, 1100.0);
    final maxHeight = (media.height - inset * 2).clamp(320.0, 760.0);
    final isNarrow = maxWidth < 560;

    return Dialog(
      insetPadding: EdgeInsets.all(inset),
      child: SizedBox(
        width: maxWidth,
        height: maxHeight,
        child: Column(
          children: [
            // ── Header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _editing ? 'Edit document' : 'Document preview',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_saving)
                    const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed:
                        _saving ? null : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // ── Content ──
            Expanded(child: _buildContent()),
            const Divider(height: 1),

            // ── Actions ──
            Padding(
              padding: const EdgeInsets.all(12),
              child: _buildActions(isNarrow),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_loadingHtml) {
      return const AppLoadingState(
        message: 'Loading content...',
        style: AppLoadingStyle.card,
      );
    }

    if (_editing && _htmlContent != null) {
      return EditableHtmlSurface(
        html: _htmlContent!,
        controller: _editController,
      );
    }

    // Preview mode
    if (widget.isHtml) {
      return HtmlPreviewSurface(html: utf8.decode(widget.bytes));
    }
    return PdfPreviewSurface(bytes: widget.bytes);
  }

  Widget _buildActions(bool isNarrow) {
    if (_editing) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: isNarrow ? WrapAlignment.start : WrapAlignment.end,
        children: [
          TextButton(
            onPressed: _saving ? null : _cancelEdit,
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: _saving ? null : _saveEdit,
            icon: const Icon(Icons.save_outlined),
            label: Text(_saving ? 'Saving…' : 'Save'),
          ),
        ],
      );
    }

    // Preview-mode actions
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      alignment: isNarrow ? WrapAlignment.start : WrapAlignment.end,
      children: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),

        // Direct format buttons instead of popup overlay to avoid Flutter Web iframe event hijacking
        OutlinedButton.icon(
          onPressed: () => widget.onDownloadFormat('pdf'),
          icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
          label: const Text('PDF'),
        ),
        OutlinedButton.icon(
          onPressed: () => widget.onDownloadFormat('docx'),
          icon: const Icon(Icons.description_outlined, size: 16),
          label: const Text('Word'),
        ),
        OutlinedButton.icon(
          onPressed: () => widget.onDownloadFormat('html'),
          icon: const Icon(Icons.code_outlined, size: 16),
          label: const Text('HTML'),
        ),

        FilledButton.icon(
          onPressed: !widget.canEdit || _loadingHtml ? null : _enterEditMode,
          icon: const Icon(Icons.edit_outlined),
          label: Text(widget.canEdit ? 'Edit' : 'Edit (locked)'),
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

class _StepData {
  final String title;
  final String date;
  const _StepData(this.title, this.date);
}

class _AuditItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  const _AuditItem(this.title, this.subtitle, this.icon, this.color);
}

class _TplCardData {
  final String id;
  final String label;
  final IconData icon;
  final Color color;
  const _TplCardData(this.id, this.label, this.icon, this.color);
}
