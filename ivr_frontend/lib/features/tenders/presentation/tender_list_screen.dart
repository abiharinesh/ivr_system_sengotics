import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../config/app_theme.dart';
import '../../../core/api/api_exceptions.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading_state.dart';
import '../../../core/widgets/app_status_badge.dart';
import '../../../core/widgets/list_screen_shell.dart';
import '../data/tender_models.dart';
import '../data/tender_repository.dart';

class TenderListScreen extends StatefulWidget {
  const TenderListScreen({super.key});

  @override
  State<TenderListScreen> createState() => _TenderListScreenState();
}

class _TenderListScreenState extends State<TenderListScreen> {
  final _repo = TenderRepository();
  String? _statusFilter;
  late Future<List<TenderSummary>> _future;

  @override
  void initState() {
    super.initState();
    _future = _repo.listTenders();
  }

  void _reload() {
    setState(() {
      _future = _repo.listTenders(status: _statusFilter);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListScreenShell(
      title: 'Tenders',
      subtitle: 'Manage lifecycle from draft to closure',
      countLabel:
          _statusFilter == null
              ? 'All tenders'
              : 'Filtered by ${_statusFilter!.replaceAll('_', ' ')}',
      action: FilledButton.icon(
        onPressed: () => context.go('/tenders/new'),
        icon: const Icon(Icons.add),
        label: const Text('New tender'),
      ),
      filters: DropdownButton<String?>(
        value: _statusFilter,
        hint: const Text('All statuses'),
        items: const [
          DropdownMenuItem(value: null, child: Text('All statuses')),
          DropdownMenuItem(value: 'draft', child: Text('Draft')),
          DropdownMenuItem(value: 'published', child: Text('Published')),
          DropdownMenuItem(
            value: 'quotations_closed',
            child: Text('Quotations closed'),
          ),
          DropdownMenuItem(
            value: 'vendor_selected',
            child: Text('Vendor selected'),
          ),
          DropdownMenuItem(
            value: 'field_verification',
            child: Text('Field verification'),
          ),
          DropdownMenuItem(value: 'closed', child: Text('Closed')),
        ],
        onChanged: (v) {
          setState(() => _statusFilter = v);
          _reload();
        },
      ),
      child: FutureBuilder<List<TenderSummary>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const AppLoadingState(
              message: 'Loading tenders...',
              skeletonLines: 5,
            );
          }
          if (snap.hasError) {
            return AppErrorState(
              message: userFacingMessage(snap.error!),
              onRetry: _reload,
            );
          }
          final tenders = snap.data ?? [];
          if (tenders.isEmpty) {
            return AppEmptyState(
              icon: Icons.assignment_outlined,
              title: 'No tenders yet',
              subtitle: 'Create your first tender to get started.',
              action: FilledButton.icon(
                onPressed: () => context.go('/tenders/new'),
                icon: const Icon(Icons.add),
                label: const Text('Create tender'),
              ),
            );
          }
          return ListView.separated(
            itemCount: tenders.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) => _TenderRow(t: tenders[i]),
          );
        },
      ),
    );
  }
}

class _TenderRow extends StatefulWidget {
  final TenderSummary t;
  const _TenderRow({required this.t});

  @override
  State<_TenderRow> createState() => _TenderRowState();
}

class _TenderRowState extends State<_TenderRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final df = DateFormat.yMMMd();
    final t = widget.t;
    final accessChip = Chip(
      label: Text(
        t.quotationAccessMode == 'invited_only' ? 'Invited' : 'Open',
      ),
      backgroundColor: t.quotationAccessMode == 'invited_only'
          ? Colors.blueGrey.shade100
          : Colors.lightGreen.shade100,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 560;
        return MouseRegion(
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: AnimatedContainer(
            duration: AppTheme.durationFast,
            curve: Curves.easeOutCubic,
            margin: EdgeInsets.symmetric(
              horizontal: isNarrow ? 4 : 8,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: _hovered
                  ? AppTheme.primary.withValues(alpha: 0.04)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(
                color: _hovered
                    ? AppTheme.primary.withValues(alpha: 0.18)
                    : Colors.transparent,
              ),
            ),
            child: ListTile(
              contentPadding: EdgeInsets.symmetric(
                horizontal: isNarrow ? 12 : 16,
                vertical: 4,
              ),
              leading: const CircleAvatar(child: Icon(Icons.assignment_outlined)),
              title: Text(
                (t.titleEn ?? t.titleTa ?? 'Tender #${t.id}'),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    AppStatusBadge(status: t.status),
                    if (t.status == 'field_verification' &&
                        t.verificationProgress != null &&
                        t.verificationProgress!.total > 0)
                      Chip(
                        label: Text(
                          'Verification: ${t.verificationProgress!.done}/${t.verificationProgress!.total}',
                        ),
                        backgroundColor: Colors.teal.shade50,
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    if (t.anchorDate != null)
                      Text('Anchor: ${df.format(t.anchorDate!)}'),
                    Text('Items: ${t.lineItemsCount}'),
                    Text('Quotes: ${t.quotationsCount}'),
                    Text('Docs: ${t.documentsCount}'),
                    if (isNarrow) accessChip,
                  ],
                ),
              ),
              trailing: isNarrow ? null : accessChip,
              isThreeLine: isNarrow,
              onTap: () => context.go('/tenders/${t.id}'),
            ),
          ),
        );
      },
    );
  }
}
