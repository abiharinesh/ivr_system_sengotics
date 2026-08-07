import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ivr_frontend/config/app_theme.dart';
import 'package:ivr_frontend/features/roles/super_admin/data/models/role_template_models.dart';
import 'package:ivr_frontend/features/roles/super_admin/data/rbac_repository.dart';

/// The shipped role catalogue, and what applying it here would change.
///
/// Every client owns copies of the shipped roles rather than sharing rows with
/// anyone else — an authorization decision must never depend on a row a
/// different council can edit. The cost of that is drift: without this pane,
/// improving the roster means repeating one edit per client by hand, which
/// stops being possible somewhere around the third client and silently leaves
/// the rest behind.
///
/// Nothing here applies without being shown first. "Update my roles" is not a
/// button whose effect should be a surprise, and a council that has customised
/// a role is told it was skipped rather than having its decision reverted.
class RoleTemplatesPane extends StatefulWidget {
  const RoleTemplatesPane({super.key, this.repository, this.onChanged});

  /// Injected by tests. The pane builds its own against the live API when this
  /// is null, so nothing at the call sites has to know it exists.
  final RbacRepository? repository;
  final VoidCallback? onChanged;

  @override
  State<RoleTemplatesPane> createState() => _RoleTemplatesPaneState();
}

class _RoleTemplatesPaneState extends State<RoleTemplatesPane> {
  late final _repo = widget.repository ?? RbacRepository();

  List<RoleTemplate> _templates = const [];
  SyncReport _pending = SyncReport.empty;
  bool _loading = true;
  bool _syncing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _repo.listTemplates(forceRefresh: true),
        _repo.pendingSync(),
      ]);
      if (!mounted) return;
      setState(() {
        _templates = results[0] as List<RoleTemplate>;
        _pending = results[1] as SyncReport;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _sync() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Apply catalogue updates'),
        content: Text(
          '${_pending.updated.length} role'
          '${_pending.updated.length == 1 ? '' : 's'} will be brought in line '
          'with the shipped catalogue.'
          '${_pending.skippedCustomised.isEmpty ? '' : '\n\n${_pending.skippedCustomised.length} role'
              '${_pending.skippedCustomised.length == 1 ? '' : 's'} you have '
              'customised will be left exactly as they are.'}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _syncing = true);
    try {
      final report = await _repo.syncTemplates();
      if (!mounted) return;
      setState(() => _syncing = false);
      _toast(
        report.updated.isEmpty
            ? 'Everything was already up to date.'
            : '${report.updated.length} role'
                '${report.updated.length == 1 ? '' : 's'} updated'
                '${report.skippedCustomised.isEmpty ? '' : ', '
                    '${report.skippedCustomised.length} left alone'}.',
      );
      widget.onChanged?.call();
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _syncing = false);
      _toast(_msg(e), isError: true);
    }
  }

  String _msg(Object e) {
    final s = e.toString();
    return s.startsWith('Exception: ') ? s.substring(11) : s;
  }

  void _toast(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppTheme.error : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _templates.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _templates.isEmpty) {
      return _errorState();
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _updatesBanner(),
          const SizedBox(height: 18),
          if (_pending.skippedCustomised.isNotEmpty) ...[
            _skippedCard(),
            const SizedBox(height: 18),
          ],
          _catalogueHeader(),
          const SizedBox(height: 10),
          ..._templates.map(_templateRow),
        ],
      ),
    );
  }

  Widget _errorState() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 40, color: AppTheme.error),
              const SizedBox(height: 12),
              Text(
                'Could not load the catalogue',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                _msg(_error!),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      );

  Widget _updatesBanner() {
    final count = _pending.updated.length;
    final upToDate = count == 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: upToDate
            ? AppTheme.accent.withValues(alpha: 0.07)
            : AppTheme.warning.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: (upToDate ? AppTheme.accent : AppTheme.warning)
              .withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                upToDate
                    ? Icons.check_circle_outline_rounded
                    : Icons.system_update_alt_rounded,
                size: 20,
                color: upToDate ? AppTheme.accent : AppTheme.warning,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  upToDate
                      ? 'Your roles match the shipped catalogue'
                      : '$count role${count == 1 ? '' : 's'} '
                          '${count == 1 ? 'has' : 'have'} updates available',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              if (!upToDate)
                FilledButton.icon(
                  onPressed: _syncing ? null : _sync,
                  icon: _syncing
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download_done_rounded, size: 17),
                  label: const Text('Apply updates'),
                ),
            ],
          ),
          if (!upToDate) ...[
            const SizedBox(height: 6),
            Text(
              'Nothing is applied until you confirm.',
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 14),
            ..._pending.updated.map(_pendingRow),
          ],
        ],
      ),
    );
  }

  Widget _pendingRow(SyncOutcome o) {
    Widget chips(String verb, List<String> keys, Color color, IconData icon) {
      if (keys.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(top: 5),
        child: Wrap(
          spacing: 6,
          runSpacing: 5,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Icon(icon, size: 13, color: color),
            Text(
              verb,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            for (final k in keys)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  k,
                  style: TextStyle(fontSize: 11, color: color),
                ),
              ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            o.displayName,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          chips('Gains', o.screensAdded, AppTheme.accent, Icons.add_rounded),
          chips('Loses', o.screensRemoved, AppTheme.error, Icons.remove_rounded),
          if (o.permissionsAdded.isNotEmpty || o.permissionsRemoved.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '${o.permissionsAdded.length} permission'
                '${o.permissionsAdded.length == 1 ? '' : 's'} added, '
                '${o.permissionsRemoved.length} removed',
                style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
              ),
            ),
        ],
      ),
    );
  }

  Widget _skippedCard() {
    final fmt = DateFormat('d MMM yyyy');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.bgSurface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lock_outline_rounded, size: 17, color: AppTheme.textMuted),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Yours to keep — these will not be touched',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'You changed these roles, so an update to the shipped catalogue '
            'leaves them alone.',
            style: TextStyle(fontSize: 11.5, height: 1.35, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final s in _pending.skippedCustomised)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppTheme.bgCard,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.stroke),
                  ),
                  child: Text(
                    s.customisedAt == null
                        ? s.name
                        : '${s.name} · ${fmt.format(s.customisedAt!.toLocal())}',
                    style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _catalogueHeader() => Row(
        children: [
          Expanded(
            child: Text(
              'SHIPPED CATALOGUE',
              style: TextStyle(
                fontSize: 10.5,
                letterSpacing: 0.6,
                fontWeight: FontWeight.w700,
                color: AppTheme.textMuted,
              ),
            ),
          ),
          Text(
            '${_templates.length} roles · ${_pending.unchanged} already matching'
            '${_pending.untemplated == 0 ? '' : ' · ${_pending.untemplated} your own'}',
            style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
          ),
        ],
      );

  Widget _templateRow(RoleTemplate t) {
    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.stroke),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${t.hierarchyLevel}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppTheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  '${t.screenCount} screens · ${t.permissionCount} permissions'
                  '${t.department == null ? '' : ' · ${t.department}'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Tooltip(
            message: '${t.inUseBy} client${t.inUseBy == 1 ? '' : 's'} use this role',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.bgSurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.stroke),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.apartment_rounded, size: 12, color: AppTheme.textMuted),
                  const SizedBox(width: 5),
                  Text(
                    '${t.inUseBy}',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textSecondary,
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
}
