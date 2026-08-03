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

/// Door-to-door collection rounds — the vehicle log, with a progress bar per
/// round and the stop list behind each one.
class RoundsPanel extends StatefulWidget {
  final SolidWasteRepository repo;
  final VoidCallback onChanged;

  const RoundsPanel({super.key, required this.repo, required this.onChanged});

  @override
  State<RoundsPanel> createState() => _RoundsPanelState();
}

class _RoundsPanelState extends State<RoundsPanel> {
  late Future<TripPage> _future;
  Future<List<CollectionRoute>>? _routesFuture;
  DateTime _date = DateTime.now();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload({bool force = false}) {
    setState(() {
      _future = widget.repo.listTrips(
        from: _date,
        to: _date,
        forceRefresh: force,
      );
      _routesFuture = widget.repo.listRoutes(forceRefresh: force);
    });
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat.yMMMEd();

    return FutureBuilder<TripPage>(
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
            message: 'Loading rounds...',
            style: AppLoadingStyle.list,
          );
        }

        final trips = snap.data!.items;

        return ListView(
          padding: const EdgeInsets.all(AppTheme.spaceMd),
          children: [
            AppCard(
              padding: const EdgeInsets.all(AppTheme.spaceMd),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          df.format(_date),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          '${trips.length} round(s) logged',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Previous day',
                    icon: const Icon(Icons.chevron_left_rounded),
                    onPressed: () {
                      _date = _date.subtract(const Duration(days: 1));
                      _reload();
                    },
                  ),
                  IconButton(
                    tooltip: 'Next day',
                    icon: const Icon(Icons.chevron_right_rounded),
                    onPressed: DateUtils.isSameDay(_date, DateTime.now())
                        ? null
                        : () {
                            _date = _date.add(const Duration(days: 1));
                            _reload();
                          },
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _busy ? null : _startRound,
                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                    label: const Text('Start round'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spaceMd),
            if (trips.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: AppEmptyState(
                  icon: Icons.local_shipping_outlined,
                  title: 'No rounds logged for this day',
                  subtitle:
                      'Start a round when a crew leaves the depot — stops are '
                      'snapshotted from the route plan so later edits cannot '
                      'rewrite what they were asked to do.',
                ),
              )
            else
              ...trips.map(
                (t) => _TripCard(
                  trip: t,
                  busy: _busy,
                  onOpen: () => _openTrip(t),
                  onClose: () => _closeRound(t),
                  onAbandon: () => _abandonRound(t),
                ),
              ),
          ],
        );
      },
    );
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
          duration: const Duration(seconds: 6),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _startRound() async {
    final routes = await (_routesFuture ?? widget.repo.listRoutes());
    final active = routes.where((r) => r.isActive && r.stopsTotal > 0).toList();

    if (!mounted) return;
    if (active.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No active route with stops — set up a route first'),
        ),
      );
      return;
    }

    final chosen = await showDialog<CollectionRoute>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Which route?'),
        children: active
            .map(
              (r) => SimpleDialogOption(
                onPressed: () => Navigator.of(ctx).pop(r),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(r.name),
                  subtitle: Text(
                    '${r.routeCode} · ${r.stopsTotal} stops · ${titleCase(r.shift)} · ${r.serviceDaysLabel}',
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
    if (chosen == null) return;

    final vehicleCtrl = TextEditingController();
    final crewCtrl = TextEditingController();
    final odoCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Start ${chosen.name}'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: vehicleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Vehicle number',
                  hintText: 'TN 38 AB 1234',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppTheme.spaceSm),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: crewCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Crew size',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spaceSm),
                  Expanded(
                    child: TextField(
                      controller: odoCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Odometer (km)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
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
            child: const Text('Start'),
          ),
        ],
      ),
    );

    final vehicle = vehicleCtrl.text.trim();
    final crew = int.tryParse(crewCtrl.text.trim());
    final odo = int.tryParse(odoCtrl.text.trim());
    vehicleCtrl.dispose();
    crewCtrl.dispose();
    odoCtrl.dispose();
    if (confirmed != true) return;

    await _run(
      () => widget.repo
          .startTrip(
            routeId: chosen.id,
            tripDate: _date,
            vehicleNumber: vehicle,
            crewSize: crew,
            odometerStartKm: odo,
          )
          .then((_) {}),
      'Round started',
    );
  }

  Future<void> _closeRound(CollectionTrip trip) async {
    final totalCtrl = TextEditingController();
    final wetCtrl = TextEditingController();
    final dryCtrl = TextEditingController();
    final odoCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Close ${trip.tripNumber}'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${trip.progress.completed} of ${trip.progress.total} stops settled.',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: AppTheme.spaceMd),
                TextField(
                  controller: totalCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Weighbridge total (kg)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: AppTheme.spaceSm),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: wetCtrl,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Wet (kg)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppTheme.spaceSm),
                    Expanded(
                      child: TextField(
                        controller: dryCtrl,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Dry (kg)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spaceSm),
                TextField(
                  controller: odoCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Closing odometer (km)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: AppTheme.spaceXs),
                Text(
                  'Wet + dry should account for the weighbridge total; a gap is '
                  'flagged rather than silently summed away.',
                  style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Close round'),
          ),
        ],
      ),
    );

    final total = double.tryParse(totalCtrl.text.trim());
    final wet = double.tryParse(wetCtrl.text.trim());
    final dry = double.tryParse(dryCtrl.text.trim());
    final odo = int.tryParse(odoCtrl.text.trim());
    for (final c in [totalCtrl, wetCtrl, dryCtrl, odoCtrl]) {
      c.dispose();
    }
    if (confirmed != true) return;

    await _run(
      () => widget.repo
          .closeTrip(
            trip.id,
            wasteCollectedKg: total,
            segregatedWetKg: wet,
            segregatedDryKg: dry,
            odometerEndKm: odo,
          )
          .then((_) {}),
      'Round closed',
    );
  }

  Future<void> _abandonRound(CollectionTrip trip) async {
    final reasonCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Abandon ${trip.tripNumber}'),
        content: SizedBox(
          width: 420,
          child: TextField(
            controller: reasonCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Why was the round abandoned?',
              hintText: 'Vehicle breakdown at stop 6',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Abandon'),
          ),
        ],
      ),
    );

    final reason = reasonCtrl.text.trim();
    reasonCtrl.dispose();
    if (confirmed != true) return;

    if (reason.length < 10) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Record why in at least 10 characters')),
      );
      return;
    }

    await _run(
      () => widget.repo.abandonTrip(trip.id, reason).then((_) {}),
      'Round marked abandoned',
    );
  }

  Future<void> _openTrip(CollectionTrip trip) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _TripStopsSheet(trip: trip, repo: widget.repo),
    );
    if (changed == true) {
      _reload(force: true);
      widget.onChanged();
    }
  }
}

class _TripCard extends StatelessWidget {
  final CollectionTrip trip;
  final bool busy;
  final VoidCallback onOpen;
  final VoidCallback onClose;
  final VoidCallback onAbandon;

  const _TripCard({
    required this.trip,
    required this.busy,
    required this.onOpen,
    required this.onClose,
    required this.onAbandon,
  });

  @override
  Widget build(BuildContext context) {
    final p = trip.progress;
    final running = trip.status == TripStatus.inProgress;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spaceSm),
      child: AppCard(
        padding: const EdgeInsets.all(AppTheme.spaceMd),
        onTap: onOpen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trip.routeName ?? trip.tripNumber,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        '${trip.tripNumber} · ${titleCase(trip.shift)}'
                        '${trip.vehicleNumber != null ? ' · ${trip.vehicleNumber}' : ''}'
                        '${trip.crewSize != null ? ' · crew ${trip.crewSize}' : ''}',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: trip.status.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: trip.status.color.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    trip.status.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: trip.status.color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spaceSm),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: p.fraction,
                      minHeight: 8,
                      backgroundColor: AppTheme.bgSurface,
                      valueColor: AlwaysStoppedAnimation<Color>(p.color),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${p.completed}/${p.total}  ${p.percent}%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: p.color,
                  ),
                ),
              ],
            ),
            if (trip.wasteCollectedKg != null ||
                trip.weights != null ||
                trip.abandonReason != null) ...[
              const SizedBox(height: AppTheme.spaceSm),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  if (trip.wasteCollectedKg != null)
                    Text(
                      '${trip.wasteCollectedKg!.toStringAsFixed(0)} kg collected',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  if (trip.weights != null && !trip.weights!.reconciles)
                    Text(
                      '⚠ ${trip.weights!.unaccounted.abs().toStringAsFixed(0)} kg unaccounted',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.error,
                      ),
                    ),
                  if (trip.abandonReason != null)
                    Text(
                      'Abandoned: ${trip.abandonReason}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.error,
                      ),
                    ),
                ],
              ),
            ],
            if (running) ...[
              const SizedBox(height: AppTheme.spaceSm),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: busy ? null : onOpen,
                    icon: const Icon(Icons.checklist_rtl_rounded, size: 18),
                    label: const Text('Stops'),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: busy ? null : onAbandon,
                    child: const Text(
                      'Abandon',
                      style: TextStyle(color: AppTheme.error),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonal(
                    onPressed: busy ? null : onClose,
                    child: const Text('Close round'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Stop-by-stop checklist for a running round.
class _TripStopsSheet extends StatefulWidget {
  final CollectionTrip trip;
  final SolidWasteRepository repo;

  const _TripStopsSheet({required this.trip, required this.repo});

  @override
  State<_TripStopsSheet> createState() => _TripStopsSheetState();
}

class _TripStopsSheetState extends State<_TripStopsSheet> {
  late Future<CollectionTripDetail> _future;
  bool _busy = false;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _future = widget.repo.getTrip(widget.trip.id);
  }

  Future<void> _settle(TripStop stop, {bool skipped = false}) async {
    String? reason;
    if (skipped) {
      final ctrl = TextEditingController();
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Skip ${stop.label}'),
          content: TextField(
            controller: ctrl,
            decoration: const InputDecoration(
              labelText: 'Why is this stop being skipped?',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Skip'),
            ),
          ],
        ),
      );
      reason = ctrl.text.trim();
      ctrl.dispose();
      if (ok != true) return;
      if (reason.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('A skipped stop must record why')),
        );
        return;
      }
    }

    setState(() => _busy = true);
    try {
      await widget.repo.completeStop(
        widget.trip.id,
        stop.id,
        skipped: skipped,
        skipReason: reason,
      );
      _changed = true;
      setState(() {
        _future = widget.repo.getTrip(widget.trip.id, forceRefresh: true);
      });
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
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      builder: (context, controller) => FutureBuilder<CollectionTripDetail>(
        future: _future,
        builder: (context, snap) {
          final stops = snap.data?.stops ?? const <TripStop>[];
          final trip = snap.data?.trip ?? widget.trip;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            trip.routeName ?? trip.tripNumber,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '${trip.progress.completed} of ${trip.progress.total} stops settled',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(_changed),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: snap.hasData
                    ? ListView.builder(
                        controller: controller,
                        padding: const EdgeInsets.all(AppTheme.spaceMd),
                        itemCount: stops.length,
                        itemBuilder: (context, i) {
                          final s = stops[i];
                          final done = s.completed;
                          final colour = done
                              ? AppTheme.accent
                              : s.skipped
                                  ? AppTheme.warning
                                  : AppTheme.textMuted;

                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              radius: 14,
                              backgroundColor: colour.withValues(alpha: 0.14),
                              child: Text(
                                '${s.seq}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: colour,
                                ),
                              ),
                            ),
                            title: Text(
                              s.label,
                              style: TextStyle(
                                fontSize: 13,
                                decoration: s.settled
                                    ? TextDecoration.lineThrough
                                    : null,
                                color: s.settled
                                    ? AppTheme.textMuted
                                    : AppTheme.textPrimary,
                              ),
                            ),
                            subtitle: s.skipped
                                ? Text(
                                    'Skipped: ${s.skipReason ?? ''}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.warning,
                                    ),
                                  )
                                : s.binId != null
                                    ? Text(
                                        'Has a bin — collecting marks it emptied',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppTheme.textMuted,
                                        ),
                                      )
                                    : null,
                            trailing: s.settled
                                ? Icon(
                                    done
                                        ? Icons.check_circle_rounded
                                        : Icons.remove_circle_outline_rounded,
                                    color: colour,
                                  )
                                : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      TextButton(
                                        onPressed: _busy
                                            ? null
                                            : () => _settle(s, skipped: true),
                                        child: const Text('Skip'),
                                      ),
                                      FilledButton(
                                        onPressed:
                                            _busy ? null : () => _settle(s),
                                        child: const Text('Done'),
                                      ),
                                    ],
                                  ),
                          );
                        },
                      )
                    : const AppLoadingState(
                        message: 'Loading stops...',
                        style: AppLoadingStyle.list,
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
