import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

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
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('Tenders', style: Theme.of(context).textTheme.headlineSmall),
              const Spacer(),
              DropdownButton<String?>(
                value: _statusFilter,
                hint: const Text('All statuses'),
                items: const [
                  DropdownMenuItem(value: null, child: Text('All statuses')),
                  DropdownMenuItem(value: 'draft', child: Text('Draft')),
                  DropdownMenuItem(value: 'published', child: Text('Published')),
                  DropdownMenuItem(value: 'quotations_closed', child: Text('Quotations closed')),
                  DropdownMenuItem(value: 'vendor_selected', child: Text('Vendor selected')),
                  DropdownMenuItem(value: 'field_verification', child: Text('Field verification')),
                  DropdownMenuItem(value: 'closed', child: Text('Closed')),
                ],
                onChanged: (v) {
                  setState(() => _statusFilter = v);
                  _reload();
                },
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: () => context.go('/tenders/new'),
                icon: const Icon(Icons.add),
                label: const Text('New tender'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: FutureBuilder<List<TenderSummary>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('Error: ${snap.error}'));
                }
                final tenders = snap.data ?? [];
                if (tenders.isEmpty) {
                  return const Center(
                    child: Text('No tenders yet. Create one to get started.'),
                  );
                }
                return ListView.separated(
                  itemCount: tenders.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) => _TenderRow(t: tenders[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TenderRow extends StatelessWidget {
  final TenderSummary t;
  const _TenderRow({required this.t});

  @override
  Widget build(BuildContext context) {
    final df = DateFormat.yMMMd();
    final color = _statusColor(t.status);
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.15),
        child: Icon(Icons.assignment_outlined, color: color),
      ),
      title: Text(
        (t.titleEn ?? t.titleTa ?? 'Tender #${t.id}'),
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Wrap(
        spacing: 12,
        children: [
          Text('Status: ${t.status}'),
          if (t.anchorDate != null) Text('Anchor: ${df.format(t.anchorDate!)}'),
          Text('Items: ${t.lineItemsCount}'),
          Text('Quotes: ${t.quotationsCount}'),
          Text('Docs: ${t.documentsCount}'),
        ],
      ),
      trailing: Chip(
        label: Text(t.quotationAccessMode == 'invited_only' ? 'Invited' : 'Open'),
        backgroundColor: t.quotationAccessMode == 'invited_only'
            ? Colors.blueGrey.shade100
            : Colors.lightGreen.shade100,
      ),
      onTap: () => context.go('/tenders/${t.id}'),
    );
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'draft':
        return Colors.grey;
      case 'published':
        return Colors.blue;
      case 'quotations_closed':
        return Colors.deepPurple;
      case 'vendor_selected':
        return Colors.indigo;
      case 'field_verification':
        return Colors.orange;
      case 'closed':
        return Colors.green;
      default:
        return Colors.black;
    }
  }
}
