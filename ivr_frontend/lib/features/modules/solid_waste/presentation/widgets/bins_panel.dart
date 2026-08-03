import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmap;
import 'package:intl/intl.dart';

import 'package:ivr_frontend/config/app_theme.dart';
import 'package:ivr_frontend/core/api/api_exceptions.dart';
import 'package:ivr_frontend/core/widgets/app_card.dart';
import 'package:ivr_frontend/core/widgets/app_empty_state.dart';
import 'package:ivr_frontend/core/widgets/app_error_state.dart';
import 'package:ivr_frontend/core/widgets/app_loading_state.dart';
import 'package:ivr_frontend/features/modules/solid_waste/data/models/solid_waste_models.dart';
import 'package:ivr_frontend/features/modules/solid_waste/data/solid_waste_repository.dart';

/// Public bin register: a GIS map with fill-level pins, and the same bins as a
/// worklist sorted fullest-first.
///
/// The pin colour comes from the band the backend assigned, not from a
/// threshold re-implemented here — the whole point of deriving the band
/// server-side is that the map and the SLA agree.
class BinsPanel extends StatefulWidget {
  final SolidWasteRepository repo;
  final VoidCallback onChanged;

  const BinsPanel({super.key, required this.repo, required this.onChanged});

  @override
  State<BinsPanel> createState() => _BinsPanelState();
}

class _BinsPanelState extends State<BinsPanel> {
  late Future<BinPage> _future;
  final _searchCtrl = TextEditingController();

  bool _needsClearanceOnly = false;
  BinFillLevel? _levelFilter;
  String _query = '';
  bool _showMap = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _reload({bool force = false}) {
    setState(() {
      _future = widget.repo.listBins(
        fillLevel: _levelFilter,
        needsClearance: _needsClearanceOnly ? true : null,
        query: _query,
        forceRefresh: force,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<BinPage>(
      future: _future,
      initialData: widget.repo.getCachedBins(
        fillLevel: _levelFilter,
        needsClearance: _needsClearanceOnly ? true : null,
        query: _query,
      ),
      builder: (context, snap) {
        if (snap.hasError) {
          return AppErrorState(
            message: userFacingMessage(snap.error!),
            onRetry: () => _reload(force: true),
          );
        }
        if (!snap.hasData) {
          return const AppLoadingState(
            message: 'Loading bins...',
            style: AppLoadingStyle.list,
          );
        }

        final bins = snap.data!.items;

        return ListView(
          padding: const EdgeInsets.all(AppTheme.spaceMd),
          children: [
            _filterBar(bins),
            const SizedBox(height: AppTheme.spaceMd),
            if (_showMap) ...[
              _BinMap(bins: bins, onTap: _openBin),
              const SizedBox(height: AppTheme.spaceMd),
            ],
            if (bins.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: AppEmptyState(
                  icon: Icons.delete_outline_rounded,
                  title: _hasFilters
                      ? 'No bins match these filters'
                      : 'No bins registered yet',
                  subtitle: _hasFilters
                      ? 'Try clearing the fill-level filter.'
                      : 'Register the public bins this body is responsible for emptying.',
                ),
              )
            else
              ...bins.map(
                (b) => _BinRow(bin: b, onTap: () => _openBin(b)),
              ),
          ],
        );
      },
    );
  }

  bool get _hasFilters =>
      _needsClearanceOnly || _levelFilter != null || _query.isNotEmpty;

  Widget _filterBar(List<WasteBin> bins) {
    final red = bins.where((b) => b.fillLevel.needsClearance).length;

    return AppCard(
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 260,
            child: TextField(
              controller: _searchCtrl,
              onSubmitted: (v) {
                _query = v.trim();
                _reload();
              },
              decoration: InputDecoration(
                hintText: 'Bin code, landmark, ward',
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
              ),
            ),
          ),
          SizedBox(
            width: 180,
            child: DropdownButtonFormField<BinFillLevel?>(
              initialValue: _levelFilter,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Fill level',
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
              ),
              items: [
                const DropdownMenuItem<BinFillLevel?>(
                  value: null,
                  child: Text('All levels'),
                ),
                ...BinFillLevel.values.map(
                  (l) => DropdownMenuItem<BinFillLevel?>(
                    value: l,
                    child: Text(l.label),
                  ),
                ),
              ],
              onChanged: (v) {
                _levelFilter = v;
                _reload();
              },
            ),
          ),
          FilterChip(
            label: Text('Needs clearing${red > 0 ? ' ($red)' : ''}'),
            selected: _needsClearanceOnly,
            onSelected: (v) {
              _needsClearanceOnly = v;
              _levelFilter = null;
              _reload();
            },
            avatar: Icon(
              Icons.priority_high_rounded,
              size: 16,
              color: _needsClearanceOnly ? AppTheme.error : null,
            ),
          ),
          IconButton(
            tooltip: _showMap ? 'Hide map' : 'Show map',
            icon: Icon(_showMap ? Icons.map_rounded : Icons.map_outlined),
            onPressed: () => setState(() => _showMap = !_showMap),
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => _reload(force: true),
          ),
        ],
      ),
    );
  }

  Future<void> _openBin(WasteBin bin) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _BinSheet(bin: bin, repo: widget.repo),
    );
    if (changed == true) {
      _reload(force: true);
      widget.onChanged();
    }
  }
}

/// GIS map of bins, pinned by fill level.
class _BinMap extends StatelessWidget {
  final List<WasteBin> bins;
  final void Function(WasteBin bin) onTap;

  const _BinMap({required this.bins, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final located = bins
        .where((b) => b.latitude != 0 || b.longitude != 0)
        .toList();

    if (located.isEmpty) {
      return AppCard(
        padding: const EdgeInsets.all(AppTheme.spaceXl),
        child: Column(
          children: [
            Icon(Icons.map_outlined, size: 40, color: AppTheme.textMuted),
            const SizedBox(height: AppTheme.spaceSm),
            Text(
              'No bins have coordinates yet',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
          ],
        ),
      );
    }

    final centerLat =
        located.map((b) => b.latitude).reduce((a, b) => a + b) / located.length;
    final centerLng =
        located.map((b) => b.longitude).reduce((a, b) => a + b) / located.length;

    final markers = located
        .map(
          (b) => gmap.Marker(
            markerId: gmap.MarkerId('bin_${b.id}'),
            position: gmap.LatLng(b.latitude, b.longitude),
            icon: gmap.BitmapDescriptor.defaultMarkerWithHue(
              b.fillLevel.markerHue,
            ),
            infoWindow: gmap.InfoWindow(
              title: '${b.binCode} — ${b.fillLevel.label}',
              snippet: '${b.fillPct}% of ${b.capacityLitres}L · ${b.placeLabel}',
            ),
            onTap: () => onTap(b),
          ),
        )
        .toSet();

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppTheme.radiusLg),
            ),
            child: SizedBox(
              height: 380,
              child: gmap.GoogleMap(
                initialCameraPosition: gmap.CameraPosition(
                  target: gmap.LatLng(centerLat, centerLng),
                  zoom: 13,
                ),
                markers: markers,
                myLocationButtonEnabled: false,
                mapToolbarEnabled: false,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppTheme.spaceSm),
            child: Wrap(
              spacing: 16,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: [
                _legend(AppTheme.accent, 'Empty / low'),
                _legend(AppTheme.warning, 'Half full'),
                _legend(AppTheme.error, 'Needs clearing'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _legend(Color color, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
          ),
        ],
      );
}

class _BinRow extends StatelessWidget {
  final WasteBin bin;
  final VoidCallback onTap;

  const _BinRow({required this.bin, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final df = DateFormat.MMMd().add_jm();
    final color = bin.fillLevel.color;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        padding: const EdgeInsets.all(AppTheme.spaceMd),
        onTap: onTap,
        child: Row(
          children: [
            SizedBox(
              width: 44,
              height: 44,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: bin.fillPct / 100,
                    strokeWidth: 4,
                    backgroundColor: AppTheme.bgSurface,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                  Center(
                    child: Text(
                      '${bin.fillPct}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
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
                          bin.binCode,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: color.withValues(alpha: 0.35)),
                        ),
                        child: Text(
                          bin.fillLevel.label,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: color,
                          ),
                        ),
                      ),
                      if (bin.status != BinStatus.active) ...[
                        const SizedBox(width: 6),
                        Text(
                          bin.status.label,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    bin.placeLabel,
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  Text(
                    '${titleCase(bin.binType)} · ${bin.capacityLitres}L'
                    '${bin.lastEmptiedAt != null ? ' · emptied ${df.format(bin.lastEmptiedAt!)}' : ''}',
                    style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
          ],
        ),
      ),
    );
  }
}

/// Bin detail sheet — recent readings, and the two actions a field worker takes.
class _BinSheet extends StatefulWidget {
  final WasteBin bin;
  final SolidWasteRepository repo;

  const _BinSheet({required this.bin, required this.repo});

  @override
  State<_BinSheet> createState() => _BinSheetState();
}

class _BinSheetState extends State<_BinSheet> {
  late Future<WasteBinDetail> _future;
  bool _busy = false;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _future = widget.repo.getBin(widget.bin.id);
  }

  Future<void> _record(int pct, {bool emptied = false}) async {
    setState(() => _busy = true);
    try {
      await widget.repo.recordReading(
        widget.bin.id,
        fillPct: pct,
        emptied: emptied,
      );
      _changed = true;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(emptied ? 'Bin marked emptied' : 'Reading recorded'),
        ),
      );
      setState(() {
        _future = widget.repo.getBin(widget.bin.id, forceRefresh: true);
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
    final df = DateFormat.MMMd().add_jm();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      builder: (context, controller) => FutureBuilder<WasteBinDetail>(
        future: _future,
        builder: (context, snap) {
          final bin = snap.data?.bin ?? widget.bin;
          final readings = snap.data?.readings ?? const <BinReading>[];

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
                            bin.binCode,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            bin.placeLabel,
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
                child: ListView(
                  controller: controller,
                  padding: const EdgeInsets.all(AppTheme.spaceLg),
                  children: [
                    Text(
                      'Record what you see',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceSm),
                    // Percentages a worker can judge from the kerbside, rather
                    // than a slider nobody can set accurately from a vehicle.
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final pct in [0, 25, 50, 75, 100])
                          OutlinedButton(
                            onPressed: _busy ? null : () => _record(pct),
                            style: OutlinedButton.styleFrom(
                              foregroundColor:
                                  BinFillLevelX.fromPct(pct).color,
                            ),
                            child: Text('$pct%'),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spaceMd),
                    FilledButton.icon(
                      onPressed: _busy ? null : () => _record(0, emptied: true),
                      icon: const Icon(Icons.cleaning_services_rounded, size: 18),
                      label: const Text('Mark emptied'),
                    ),
                    const SizedBox(height: AppTheme.spaceLg),
                    Text(
                      'Recent readings',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceSm),
                    if (readings.isEmpty)
                      Text(
                        'No readings recorded yet.',
                        style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                      )
                    else
                      ...readings.map(
                        (r) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          leading: Icon(
                            r.emptied
                                ? Icons.cleaning_services_rounded
                                : Icons.visibility_outlined,
                            size: 18,
                            color: r.fillLevel.color,
                          ),
                          title: Text(
                            r.emptied
                                ? 'Emptied'
                                : '${r.fillPct}% — ${r.fillLevel.label}',
                            style: const TextStyle(fontSize: 13),
                          ),
                          subtitle: r.recordedAt != null
                              ? Text(
                                  df.format(r.recordedAt!),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textMuted,
                                  ),
                                )
                              : null,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Local helper so the quick-record buttons can colour themselves without
/// duplicating the band thresholds.
extension BinFillLevelX on BinFillLevel {
  static BinFillLevel fromPct(int pct) {
    if (pct >= 100) return BinFillLevel.overflowing;
    if (pct >= 75) return BinFillLevel.high;
    if (pct >= 40) return BinFillLevel.medium;
    if (pct >= 10) return BinFillLevel.low;
    return BinFillLevel.empty;
  }
}
