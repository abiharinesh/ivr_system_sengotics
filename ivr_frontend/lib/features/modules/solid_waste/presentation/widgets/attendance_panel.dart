import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:ivr_frontend/config/app_theme.dart';
import 'package:ivr_frontend/core/api/api_exceptions.dart';
import 'package:ivr_frontend/core/widgets/app_card.dart';
import 'package:ivr_frontend/core/widgets/app_empty_state.dart';
import 'package:ivr_frontend/core/widgets/app_error_state.dart';
import 'package:ivr_frontend/core/widgets/app_loading_state.dart';
import 'package:ivr_frontend/features/modules/solid_waste/data/models/solid_waste_models.dart';
import 'package:ivr_frontend/features/modules/solid_waste/data/solid_waste_repository.dart';

/// Sanitation worker attendance for a shift.
///
/// The number a sanitary inspector actually wants is "how many workers do I
/// have on the ground this morning", so the head count leads and the roll
/// follows.
class AttendancePanel extends StatefulWidget {
  final SolidWasteRepository repo;
  final VoidCallback onChanged;

  const AttendancePanel({
    super.key,
    required this.repo,
    required this.onChanged,
  });

  @override
  State<AttendancePanel> createState() => _AttendancePanelState();
}

class _AttendancePanelState extends State<AttendancePanel> {
  late Future<AttendanceSheet> _future;
  DateTime _date = DateTime.now();
  String _shift = 'morning';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload({bool force = false}) {
    setState(() {
      _future = widget.repo.listAttendance(
        date: _date,
        shift: _shift,
        forceRefresh: force,
      );
    });
  }

  Future<void> _run(Future<void> Function() action, String message) async {
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
      _reload(force: true);
      widget.onChanged();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(userFacingMessage(e)),
          backgroundColor: AppTheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat.yMMMEd();

    return FutureBuilder<AttendanceSheet>(
      future: _future,
      builder: (context, snap) {
        if (snap.hasError) {
          return AppErrorState(
            message: userFacingMessage(snap.error!),
            onRetry: () => _reload(force: true),
          );
        }
        if (!snap.hasData) {
          return const AppLoadingState(
            message: 'Loading roll...',
            style: AppLoadingStyle.list,
          );
        }

        final sheet = snap.data!;

        return ListView(
          padding: const EdgeInsets.all(AppTheme.spaceMd),
          children: [
            AppCard(
              padding: const EdgeInsets.all(AppTheme.spaceLg),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          df.format(_date),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_left_rounded),
                        onPressed: () {
                          _date = _date.subtract(const Duration(days: 1));
                          _reload();
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right_rounded),
                        onPressed: DateUtils.isSameDay(_date, DateTime.now())
                            ? null
                            : () {
                                _date = _date.add(const Duration(days: 1));
                                _reload();
                              },
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spaceSm),
                  SegmentedButton<String>(
                    segments: kShifts
                        .map(
                          (s) => ButtonSegment<String>(
                            value: s,
                            label: Text(titleCase(s)),
                          ),
                        )
                        .toList(),
                    selected: {_shift},
                    onSelectionChanged: (sel) {
                      _shift = sel.first;
                      _reload();
                    },
                  ),
                  const SizedBox(height: AppTheme.spaceLg),
                  Row(
                    children: [
                      _count('On duty', sheet.present, AppTheme.accent),
                      _count('Absent', sheet.absent, AppTheme.error),
                      _count('On leave', sheet.onLeave, AppTheme.textMuted),
                      _count('Marked', sheet.totalMarked, AppTheme.primary),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spaceMd),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: _busy ? null : _markWorker,
                icon: const Icon(Icons.person_add_alt_rounded, size: 18),
                label: const Text('Mark a worker'),
              ),
            ),
            const SizedBox(height: AppTheme.spaceMd),
            if (sheet.items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: AppEmptyState(
                  icon: Icons.groups_outlined,
                  title: 'No roll taken for this shift',
                  subtitle: 'Mark workers as they report for duty.',
                ),
              )
            else
              ...sheet.items.map(_workerRow),
          ],
        );
      },
    );
  }

  Widget _count(String label, int value, Color color) => Expanded(
        child: Column(
          children: [
            Text(
              '$value',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
            ),
          ],
        ),
      );

  Widget _workerRow(AttendanceRecord r) {
    final tf = DateFormat.jm();

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: AppCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spaceMd,
          vertical: 10,
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: r.status.color.withValues(alpha: 0.14),
              child: Icon(Icons.person_rounded, size: 16, color: r.status.color),
            ),
            const SizedBox(width: AppTheme.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          r.workerName,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      if (r.isContract) ...[
                        const SizedBox(width: 6),
                        Text(
                          'contract',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    [
                      r.status.label,
                      if (r.checkInAt != null) 'in ${tf.format(r.checkInAt!)}',
                      if (r.checkOutAt != null) 'out ${tf.format(r.checkOutAt!)}',
                    ].join(' · '),
                    style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
            if (r.isOnDuty)
              TextButton(
                onPressed: _busy
                    ? null
                    : () => _run(
                          () => widget.repo.checkOut(r.id).then((_) {}),
                          '${r.workerName} checked out',
                        ),
                child: const Text('Check out'),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _markWorker() async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    var status = AttendanceStatus.present;
    var isContract = false;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Mark attendance'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Worker name *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: AppTheme.spaceSm),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Mobile number',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: AppTheme.spaceSm),
                Wrap(
                  spacing: 8,
                  children: AttendanceStatus.values
                      .map(
                        (s) => ChoiceChip(
                          label: Text(s.label),
                          selected: status == s,
                          onSelected: (_) => setLocal(() => status = s),
                          selectedColor: s.color.withValues(alpha: 0.16),
                        ),
                      )
                      .toList(),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: isContract,
                  onChanged: (v) => setLocal(() => isContract = v ?? false),
                  title: const Text('Engaged on contract'),
                  subtitle: Text(
                    'Contract workers have no employee record',
                    style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                  ),
                ),
                Text(
                  'Marking the same worker again for this shift corrects the '
                  'first entry rather than double-counting.',
                  style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Mark'),
            ),
          ],
        ),
      ),
    );

    final name = nameCtrl.text.trim();
    final phone = phoneCtrl.text.trim();
    nameCtrl.dispose();
    phoneCtrl.dispose();
    if (confirmed != true) return;

    if (name.length < 2) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the worker\'s name')),
      );
      return;
    }

    await _run(
      () => widget.repo
          .markAttendance(
            workerName: name,
            status: status,
            workerPhone: phone,
            isContract: isContract,
            date: _date,
            shift: _shift,
          )
          .then((_) {}),
      '$name marked ${status.label.toLowerCase()}',
    );
  }
}
