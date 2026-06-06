import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmap;
import '../../../../config/app_theme.dart';
import '../../../../core/widgets/app_loading_state.dart';
import '../../../../core/env_maps_loader.dart';
import '../../data/water_repository.dart';
import '../../../../features/plumber/data/plumber_repository.dart';

class PipelineGridScreen extends StatefulWidget {
  const PipelineGridScreen({super.key});

  @override
  State<PipelineGridScreen> createState() => _PipelineGridScreenState();
}

class _PipelineGridScreenState extends State<PipelineGridScreen> {
  final WaterRepository _repository = WaterRepository();
  bool _isLoading = true;

  List<Map<String, dynamic>> _pipelines = [];
  List<Map<String, dynamic>> _tanks = [];
  List<Map<String, dynamic>> _valves = [];

  // Toggle Filters
  bool _showWaterLines = true;
  bool _showWaterPipeline = true;
  bool _showOverheadTanks = true;
  bool _showBorewells = true;
  bool _showValves = true;

  // Grid Controls
  bool _enableElectricalGrid = false;
  bool _enableWaterPipelineGrid = true;

  // Selected Asset Info HUD
  Map<String, dynamic>? _selectedAsset;
  String _selectedAssetType = ''; // pipeline, tank, valve

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final cachedPipelines = _repository.getCachedPipelines(1);
    final cachedTanks = _repository.getCachedTanks(1);
    final cachedValves = _repository.getCachedValves(1);
    
    final hasCache = cachedPipelines != null && cachedTanks != null && cachedValves != null;
    
    if (hasCache) {
      _pipelines = cachedPipelines;
      _tanks = cachedTanks;
      _valves = cachedValves;
      _isLoading = false;
      if (mounted) setState(() {});
    } else {
      setState(() => _isLoading = true);
    }

    try {
      final pipelines = await _repository.getPipelines(1, forceRefresh: !hasCache);
      final tanks = await _repository.getTanks(1, forceRefresh: !hasCache);
      final valves = await _repository.getValves(1, forceRefresh: !hasCache);
      if (mounted) {
        setState(() {
          _pipelines = pipelines;
          _tanks = tanks;
          _valves = valves;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.sizeOf(context).width;
    final bool isMobile = width < 600;

    // Define polylines from pipeline coordinates
    final Set<gmap.Polyline> polylines = {};
    if (!_isLoading && _enableWaterPipelineGrid && _showWaterLines) {
      for (final pipeline in _pipelines) {
        final geo = pipeline['path_geojson'] as Map;
        final coords = geo['coordinates'] as List;
        final points = coords.map((c) => gmap.LatLng(c[1] as double, c[0] as double)).toList();

        final isLeak = pipeline['status'] == 'leak_alert';
        polylines.add(
          gmap.Polyline(
            polylineId: gmap.PolylineId('pipe_${pipeline['id']}'),
            points: points,
            color: isLeak ? AppTheme.error : AppTheme.primary,
            width: isLeak ? 6 : 4,
            patterns: isLeak ? [gmap.PatternItem.dash(20), gmap.PatternItem.gap(10)] : [],
            consumeTapEvents: true,
            onTap: () {
              setState(() {
                _selectedAsset = pipeline;
                _selectedAssetType = 'pipeline';
              });
            },
          ),
        );
      }
    }

    // Define markers for tanks, borewells, valves
    final Set<gmap.Marker> markers = {};

    if (!_isLoading && (_showOverheadTanks || _showBorewells)) {
      for (final tank in _tanks) {
        final isTank = tank['type'] == 'overhead_tank';
        if (isTank && !_showOverheadTanks) continue;
        if (!isTank && !_showBorewells) continue;

        markers.add(
          gmap.Marker(
            markerId: gmap.MarkerId('tank_${tank['id']}'),
            position: gmap.LatLng(tank['latitude'] as double, tank['longitude'] as double),
            icon: gmap.BitmapDescriptor.defaultMarkerWithHue(
              isTank ? gmap.BitmapDescriptor.hueCyan : gmap.BitmapDescriptor.hueViolet,
            ),
            infoWindow: gmap.InfoWindow(
              title: tank['name'] as String,
              snippet: isTank
                  ? 'Capacity: ${tank['capacity_liters']}L | Level: ${tank['current_level_pct']}%'
                  : 'Borewell pump: ${tank['pump_status']}',
            ),
            onTap: () {
              setState(() {
                _selectedAsset = tank;
                _selectedAssetType = 'tank';
              });
            },
          ),
        );
      }
    }

    if (!_isLoading && _showValves) {
      for (final valve in _valves) {
        markers.add(
          gmap.Marker(
            markerId: gmap.MarkerId('valve_${valve['id']}'),
            position: gmap.LatLng(valve['latitude'] as double, valve['longitude'] as double),
            icon: gmap.BitmapDescriptor.defaultMarkerWithHue(
              gmap.BitmapDescriptor.hueYellow,
            ),
            onTap: () {
              setState(() {
                _selectedAsset = valve;
                _selectedAssetType = 'valve';
              });
            },
          ),
        );
      }
    }

    // Default center at Annur coordinates
    const center = gmap.LatLng(11.12, 77.08);

    return Scaffold(
      body: Stack(
        children: [
          // 1. Google Maps or Loader
          Positioned.fill(
            child: _isLoading
                ? const AppLoadingState(
                    message: 'Mapping pipeline network (GIS)...',
                    style: AppLoadingStyle.dashboard,
                  )
                : gmap.GoogleMap(
                    mapId: googleMapsMapId,
                    markerType: googleMapsMarkerType,
                    initialCameraPosition: const gmap.CameraPosition(
                      target: center,
                      zoom: 11.5,
                    ),
                    polylines: polylines,
                    markers: markers,
                    mapType: gmap.MapType.normal,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: true,
                  ),
          ),

          // 2. Floating Header Info
          Positioned(
            top: 20,
            left: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.bgCard.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.stroke),
                boxShadow: AppTheme.softShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Annur Pipeline Grid (GIS View)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Monitoring live flow, pressure, and leakage indicators',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. Map Control Overlay (Top Right)
          Positioned(
            top: 20,
            right: 20,
            child: Container(
              width: 220,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.bgCard.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.stroke),
                boxShadow: AppTheme.softShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        'Map Control',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      Icon(Icons.layers, size: 16, color: AppTheme.textMuted),
                    ],
                  ),
                  const Divider(height: 12),
                  _switchRow('Electrical Grid', _enableElectricalGrid, _isLoading ? null : (v) {
                    setState(() => _enableElectricalGrid = v);
                  }),
                  _switchRow('Water Pipeline Grid', _enableWaterPipelineGrid, _isLoading ? null : (v) {
                    setState(() => _enableWaterPipelineGrid = v);
                  }),
                ],
              ),
            ),
          ),

          // 4. Legend Overlay (Bottom Left)
          Positioned(
            bottom: 20,
            left: 20,
            child: Container(
              width: 220,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.bgCard.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.stroke),
                boxShadow: AppTheme.softShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Legend Filter',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textMuted,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const Divider(height: 10),
                  _checkRow('Water Lines', _showWaterLines, AppTheme.primary, _isLoading ? null : (v) {
                    setState(() => _showWaterLines = v ?? true);
                  }),
                  _checkRow('Water Pipeline', _showWaterPipeline, AppTheme.accent, _isLoading ? null : (v) {
                    setState(() => _showWaterPipeline = v ?? true);
                  }),
                  _checkRow('Overhead Tanks', _showOverheadTanks, Colors.cyan, _isLoading ? null : (v) {
                    setState(() => _showOverheadTanks = v ?? true);
                  }),
                  _checkRow('Borewell Pumps', _showBorewells, Colors.purple, _isLoading ? null : (v) {
                    setState(() => _showBorewells = v ?? true);
                  }),
                  _checkRow('Valve Nodes', _showValves, Colors.amber, _isLoading ? null : (v) {
                    setState(() => _showValves = v ?? true);
                  }),
                ],
              ),
            ),
          ),

          // 5. Selected Asset Info Panel (Bottom Right / Centered on Mobile)
          if (_selectedAsset != null)
            Positioned(
              bottom: 20,
              right: isMobile ? 20 : 20,
              left: isMobile ? 20 : null,
              child: Container(
                width: isMobile ? null : 320,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.bgCard.withValues(alpha: 0.96),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.stroke),
                  boxShadow: AppTheme.softShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: _assetColor().withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(_assetIcon(), size: 16, color: _assetColor()),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _selectedAsset!['name'] ?? _selectedAsset!['valve_number'] ?? 'Asset Node',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 16),
                          onPressed: () => setState(() => _selectedAsset = null),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          color: AppTheme.textMuted,
                        )
                      ],
                    ),
                    const Divider(height: 16),
                    _buildDetailsSection(),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.plumbing_rounded, size: 14),
                            label: const Text('Assign Plumber', style: TextStyle(fontSize: 12)),
                            onPressed: () => _showPlumberDialog(context),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                        if (_selectedAssetType == 'pipeline' && _selectedAsset!['status'] != 'leak_alert') ...[
                          const SizedBox(width: 8),
                          OutlinedButton(
                            child: const Text('Sim Leak', style: TextStyle(fontSize: 12)),
                            onPressed: () async {
                              await _repository.simulateLeak(_selectedAsset!['id'] as int);
                              _loadData();
                              setState(() => _selectedAsset = null);
                            },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                          ),
                        ]
                      ],
                    ),
                  ],
                ),
              ),
            )
        ],
      ),
    );
  }

  Color _assetColor() {
    if (_selectedAssetType == 'pipeline') {
      return _selectedAsset!['status'] == 'leak_alert' ? AppTheme.error : AppTheme.primary;
    }
    if (_selectedAssetType == 'tank') {
      return _selectedAsset!['type'] == 'overhead_tank' ? Colors.cyan : Colors.purple;
    }
    return Colors.amber;
  }

  IconData _assetIcon() {
    if (_selectedAssetType == 'pipeline') return Icons.settings_input_composite;
    if (_selectedAssetType == 'tank') {
      return _selectedAsset!['type'] == 'overhead_tank' ? Icons.opacity_rounded : Icons.water_rounded;
    }
    return Icons.filter_tilt_shift_rounded;
  }

  Widget _buildRealtimeSensorChart(bool isCritical) {
    final values = isCritical
        ? [35, 32, 28, 25, 20, 18, 15, 12, 10, 12, 11, 10, 9]
        : [22, 24, 23, 25, 24, 26, 25, 27, 26, 28, 27, 29, 28];

    final color = isCritical ? AppTheme.error : AppTheme.accent;

    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.bgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.stroke, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'REAL-TIME SENSOR TELEMETRY',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textMuted,
                  letterSpacing: 0.8,
                ),
              ),
              const Spacer(),
              Text(
                isCritical ? 'Flow Dropping' : 'Telemetry OK',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 48,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(values.length, (i) {
                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                    height: values[i].toDouble() * 1.5,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: (i / values.length) * 0.7 + 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('15 mins ago', style: TextStyle(fontSize: 8, color: AppTheme.textMuted)),
              Text('Now', style: TextStyle(fontSize: 8, color: AppTheme.textMuted, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('FLOW RATE', style: TextStyle(fontSize: 8, color: AppTheme.textMuted, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      isCritical ? '2.1 LPS' : '5.4 LPS',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: isCritical ? AppTheme.error : AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('PRESSURE', style: TextStyle(fontSize: 8, color: AppTheme.textMuted, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      isCritical ? '0.6 Bar' : '1.8 Bar',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: isCritical ? AppTheme.error : AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsSection() {
    if (_selectedAssetType == 'pipeline') {
      final isLeak = _selectedAsset!['status'] == 'leak_alert';
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _detailsRow('Diameter:', '${_selectedAsset!['diameter_mm']} mm'),
          _detailsRow('Material:', '${_selectedAsset!['material']}'),
          _detailsRow('Status:', isLeak ? 'CRITICAL LEAK ALERT' : 'Normal Operational', color: isLeak ? AppTheme.error : AppTheme.accent),
          _buildRealtimeSensorChart(isLeak),
          if (isLeak) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.error.withValues(alpha: 0.2), width: 0.8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: AppTheme.error, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'AI Alert: Pipeline leak detected! Flow rate dropped to 2.1 LPS.',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.error,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      );
    }
    if (_selectedAssetType == 'tank') {
      final isTank = _selectedAsset!['type'] == 'overhead_tank';
      final pumpOff = _selectedAsset!['pump_status'] != 'on';
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _detailsRow('Type:', isTank ? 'Overhead Reservoir' : 'Groundwater Borewell'),
          if (isTank) ...[
            _detailsRow('Capacity:', '${_selectedAsset!['capacity_liters']} L'),
            _detailsRow('Storage Level:', '${_selectedAsset!['current_level_pct']}%', color: AppTheme.accent),
          ],
          _detailsRow('Pump Status:', '${_selectedAsset!['pump_status'] ?? 'off'}'.toUpperCase(), color: _selectedAsset!['pump_status'] == 'on' ? AppTheme.accent : AppTheme.textMuted),
          _buildRealtimeSensorChart(pumpOff && !isTank),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _detailsRow('Type:', 'Pipeline Control Valve'),
        _detailsRow('Valve Tag:', '${_selectedAsset!['valve_number']}'),
        _detailsRow('Flow Status:', '${_selectedAsset!['status']}'.toUpperCase(), color: _selectedAsset!['status'] == 'open' ? AppTheme.accent : AppTheme.error),
      ],
    );
  }

  Widget _detailsRow(String label, String val, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w500)),
          Text(val, style: TextStyle(fontSize: 12, color: color ?? AppTheme.textPrimary, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _switchRow(String label, bool value, ValueChanged<bool>? onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
          SizedBox(
            height: 24,
            child: Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: AppTheme.primary,
            ),
          )
        ],
      ),
    );
  }

  Widget _checkRow(String label, bool value, Color indicatorColor, ValueChanged<bool?>? onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.0),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: indicatorColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
            ),
          ),
          SizedBox(
            width: 24,
            height: 24,
            child: Checkbox(
              value: value,
              onChanged: onChanged,
              activeColor: AppTheme.primary,
            ),
          )
        ],
      ),
    );
  }

  void _showPlumberDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.plumbing_rounded, color: AppTheme.primary),
            const SizedBox(width: 8),
            const Text('Assign Plumber Staff'),
          ],
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: FutureBuilder<List<dynamic>>(
          future: PlumberRepository().listPlumbers(),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              return Text('Error: ${snapshot.error}', style: const TextStyle(color: AppTheme.error));
            }
            final list = snapshot.data ?? [];
            if (list.isEmpty) {
              return const Text('No plumbers found.');
            }
            return SizedBox(
              width: 380,
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: list.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, idx) {
                  final map = Map<String, dynamic>.from(list[idx] as Map);
                  final id = map['id'] as int;
                  final email = map['email']?.toString() ?? 'Plumber #$id';
                  final phone = map['phone_e164']?.toString() ?? 'No WhatsApp';
                  final name = email.split('@').first;
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                      child: Icon(Icons.person, color: AppTheme.primary, size: 20),
                    ),
                    title: Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(phone, style: TextStyle(color: AppTheme.textMuted)),
                    ),
                    trailing: FilledButton(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Assign', style: TextStyle(fontSize: 12)),
                      onPressed: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Leak assigned successfully to $name.',
                            ),
                            backgroundColor: AppTheme.accent,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
