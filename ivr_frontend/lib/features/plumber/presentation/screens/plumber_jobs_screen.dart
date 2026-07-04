import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/api/api_exceptions.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_error_state.dart';
import '../../../../core/widgets/app_loading_state.dart';
import '../../../../core/widgets/list_screen_shell.dart';
import '../../../../config/app_theme.dart';
import '../../data/plumber_self_repository.dart';

class PlumberJobsScreen extends StatefulWidget {
  final String initialSearch;

  const PlumberJobsScreen({super.key, this.initialSearch = ''});

  @override
  State<PlumberJobsScreen> createState() => _PlumberJobsScreenState();
}

class _PlumberJobsScreenState extends State<PlumberJobsScreen> {
  final _repo = PlumberSelfRepository();
  List<dynamic> _items = [];
  String _searchTerm = '';
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _searchTerm = widget.initialSearch.trim().toLowerCase();
    _load();
  }

  @override
  void didUpdateWidget(covariant PlumberJobsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.initialSearch.trim().toLowerCase();
    if (next != oldWidget.initialSearch.trim().toLowerCase()) {
      setState(() => _searchTerm = next);
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _repo.listComplaints();
      setState(() {
        _items = list;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredItems =
        _items.where((raw) {
          if (_searchTerm.isEmpty) return true;
          final c = Map<String, dynamic>.from(raw as Map);
          final id = (c['id'] ?? '').toString().toLowerCase();
          final status = (c['status'] ?? '').toString().toLowerCase();
          final complaintType =
              (c['complaint_type'] ?? '').toString().toLowerCase();
          final desc = (c['description'] ?? '').toString().toLowerCase();
          return id.contains(_searchTerm) ||
              status.contains(_searchTerm) ||
              complaintType.contains(_searchTerm) ||
              desc.contains(_searchTerm);
        }).toList();

    return ListScreenShell(
      title: 'My complaints',
      subtitle: 'Assigned plumbing complaints',
      countLabel:
          _searchTerm.isEmpty
              ? '${filteredItems.length} items'
              : 'Filtered by "$_searchTerm"',
      action: IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
      child: Builder(
        builder: (_) {
          if (_loading) {
            return const AppLoadingState(
              message: 'Loading complaints...',
              skeletonLines: 6,
              style: AppLoadingStyle.list,
            );
          }
          if (_error != null) {
            return AppErrorState(
              message: userFacingMessage(_error!),
              onRetry: _load,
            );
          }
          if (filteredItems.isEmpty) {
            return const AppEmptyState(
              icon: Icons.inbox_outlined,
              title: 'No complaints found',
              subtitle: 'You currently have no complaints for this filter.',
            );
          }
          return ListView.separated(
            itemCount: filteredItems.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final c = Map<String, dynamic>.from(filteredItems[i] as Map);
              final id = c['id'] as int;
              final st = c['status']?.toString() ?? '';
              final pole = c['pole'] as Map<String, dynamic>?;
              final poleLabel = pole == null ? '—' : '#${pole['id']}';
              return _ComplaintRow(id: id, poleLabel: poleLabel, status: st);
            },
          );
        },
      ),
    );
  }
}

class _ComplaintRow extends StatefulWidget {
  final int id;
  final String poleLabel;
  final String status;

  const _ComplaintRow({
    required this.id,
    required this.poleLabel,
    required this.status,
  });

  @override
  State<_ComplaintRow> createState() => _ComplaintRowState();
}

class _ComplaintRowState extends State<_ComplaintRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: AppTheme.durationFast,
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color:
              _hovered
                  ? AppTheme.primary.withValues(alpha: 0.04)
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
            color:
                _hovered
                    ? AppTheme.primary.withValues(alpha: 0.18)
                    : Colors.transparent,
          ),
        ),
        child: ListTile(
          title: Text('Complaint #${widget.id} · Pole ${widget.poleLabel}'),
          subtitle: Text(widget.status),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/plumber/jobs/${widget.id}'),
        ),
      ),
    );
  }
}
