import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmap;
import 'package:pointer_interceptor/pointer_interceptor.dart';
import '../../../../config/app_theme.dart';
import '../../../../core/widgets/app_loading_state.dart';
import '../../../../core/env_maps_loader.dart';
import '../../data/water_repository.dart';
import '../../../../features/plumber/data/plumber_repository.dart';

import '../../../../core/storage/secure_storage.dart';

class PipelineGridScreen extends StatefulWidget {
  const PipelineGridScreen({super.key});

  @override
  State<PipelineGridScreen> createState() => _PipelineGridScreenState();
}

class _PipelineGridScreenState extends State<PipelineGridScreen> {
  final WaterRepository _repository = WaterRepository();
  gmap.GoogleMapController? _mapController;
  bool _isLoading = true;
  int _panchayatId = 27; // Default fallback to 27 (Thayanur)

  List<Map<String, dynamic>> _pipelines = [];
  List<Map<String, dynamic>> _tanks = [];
  List<Map<String, dynamic>> _valves = [];

  // Drawing Mode Controls
  bool _isDrawingMode = false;
  final List<gmap.LatLng> _newPipelinePoints = [];

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
    _initAndLoad();
  }

  Future<void> _initAndLoad() async {
    final savedId = await SecureStorageService.getPanchayatId();
    if (savedId != null) {
      _panchayatId = savedId;
    }
    await _loadData();
  }

  Future<void> _loadData() async {
    final cachedPipelines = _repository.getCachedPipelines(_panchayatId);
    final cachedTanks = _repository.getCachedTanks(_panchayatId);
    final cachedValves = _repository.getCachedValves(_panchayatId);
    
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
      final pipelines = await _repository.getPipelines(_panchayatId, forceRefresh: !hasCache);
      final tanks = await _repository.getTanks(_panchayatId, forceRefresh: !hasCache);
      final valves = await _repository.getValves(_panchayatId, forceRefresh: !hasCache);
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

  // ── GIS Stitching & Telemetry Utilities ──────────────────────────────

  /// Calculates Haversine distance in meters between two lat/long points
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0; // Earth radius in meters
    final dLat = (lat2 - lat1) * math.pi / 180.0;
    final dLon = (lon2 - lon1) * math.pi / 180.0;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180.0) *
            math.cos(lat2 * math.pi / 180.0) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  /// Calculates total length of active drawing path in meters
  double _calculatePathLength(List<gmap.LatLng> points) {
    double total = 0.0;
    for (int i = 0; i < points.length - 1; i++) {
      total += _calculateDistance(
        points[i].latitude,
        points[i].longitude,
        points[i + 1].latitude,
        points[i + 1].longitude,
      );
    }
    return total;
  }

  String _formatLength(double meters) {
    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)} m';
    }
    return '${(meters / 1000.0).toStringAsFixed(2)} km';
  }

  /// Combines all tanks, borewells, and valves into a unified list of connectable anchors
  List<Map<String, dynamic>> get _allStitchableAssets {
    final list = <Map<String, dynamic>>[];
    for (final tank in _tanks) {
      list.add({
        'id': tank['id'],
        'name': tank['name'] ?? 'Unnamed Reservoir',
        'latitude': (tank['latitude'] as num).toDouble(),
        'longitude': (tank['longitude'] as num).toDouble(),
        'type': tank['type'] == 'overhead_tank' ? 'Overhead Tank' : 'Borewell Pump',
        'icon': tank['type'] == 'overhead_tank' ? Icons.opacity_rounded : Icons.water_rounded,
        'color': tank['type'] == 'overhead_tank' ? Colors.cyan : Colors.purple,
      });
    }
    for (final valve in _valves) {
      list.add({
        'id': valve['id'],
        'name': valve['valve_number'] ?? 'Unnamed Valve',
        'latitude': (valve['latitude'] as num).toDouble(),
        'longitude': (valve['longitude'] as num).toDouble(),
        'type': 'Control Valve',
        'icon': Icons.filter_tilt_shift_rounded,
        'color': Colors.amber,
      });
    }
    return list;
  }

  void _stitchStartAsset(Map<String, dynamic> asset) {
    final latLng = gmap.LatLng((asset['latitude'] as num).toDouble(), (asset['longitude'] as num).toDouble());
    setState(() {
      if (_newPipelinePoints.isEmpty) {
        _newPipelinePoints.add(latLng);
      } else {
        _newPipelinePoints[0] = latLng;
      }
    });
    _zoomToPoint(latLng);
  }

  void _stitchEndAsset(Map<String, dynamic> asset) {
    final latLng = gmap.LatLng((asset['latitude'] as num).toDouble(), (asset['longitude'] as num).toDouble());
    setState(() {
      if (_newPipelinePoints.isEmpty) {
        _newPipelinePoints.add(latLng);
      } else if (_newPipelinePoints.length == 1) {
        _newPipelinePoints.add(latLng);
      } else {
        _newPipelinePoints[_newPipelinePoints.length - 1] = latLng;
      }
    });
    _zoomToPoint(latLng);
  }

  void _autoSnapNearbyPoints() {
    bool snappedAny = false;
    final assets = _allStitchableAssets;
    
    setState(() {
      for (int i = 0; i < _newPipelinePoints.length; i++) {
        final pt = _newPipelinePoints[i];
        double minDistance = double.infinity;
        gmap.LatLng? nearestLatLng;
        
        for (final asset in assets) {
          final dist = _calculateDistance(
            pt.latitude, pt.longitude,
            asset['latitude'], asset['longitude']
          );
          if (dist < 150.0 && dist < minDistance) { // snap threshold of 150 meters
            minDistance = dist;
            nearestLatLng = gmap.LatLng(asset['latitude'], asset['longitude']);
          }
        }
        
        if (nearestLatLng != null) {
          _newPipelinePoints[i] = nearestLatLng;
          snappedAny = true;
        }
      }
    });
    
    if (snappedAny) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Route points snapped to nearby infrastructure assets!'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No assets found within 150m of route points.'),
          backgroundColor: Colors.amber,
        ),
      );
    }
  }

  void _snapIndividualPoint(int index) {
    final pt = _newPipelinePoints[index];
    final assets = _allStitchableAssets;
    double minDistance = double.infinity;
    Map<String, dynamic>? nearestAsset;
    
    for (final asset in assets) {
      final dist = _calculateDistance(
        pt.latitude, pt.longitude,
        asset['latitude'], asset['longitude']
      );
      if (dist < minDistance) {
        minDistance = dist;
        nearestAsset = asset;
      }
    }
    
    if (nearestAsset != null && minDistance < 150.0) {
      final asset = nearestAsset;
      setState(() {
        _newPipelinePoints[index] = gmap.LatLng(
          (asset['latitude'] as num).toDouble(),
          (asset['longitude'] as num).toDouble(),
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Snapped to ${nearestAsset['name']} (${_formatLength(minDistance)} away)'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            nearestAsset != null 
                ? 'Nearest asset ${nearestAsset['name']} is too far (${_formatLength(minDistance)}, threshold is 150m).'
                : 'No nearby assets found.',
          ),
          backgroundColor: Colors.amber,
        ),
      );
    }
  }

  void _autoSnapPointsBeforeSave() {
    final assets = _allStitchableAssets;
    setState(() {
      for (int i = 0; i < _newPipelinePoints.length; i++) {
        final pt = _newPipelinePoints[i];
        double minDistance = double.infinity;
        gmap.LatLng? nearestLatLng;
        
        for (final asset in assets) {
          final dist = _calculateDistance(
            pt.latitude, pt.longitude,
            (asset['latitude'] as num).toDouble(), (asset['longitude'] as num).toDouble()
          );
          if (dist < 150.0 && dist < minDistance) {
            minDistance = dist;
            nearestLatLng = gmap.LatLng((asset['latitude'] as num).toDouble(), (asset['longitude'] as num).toDouble());
          }
        }
        
        if (nearestLatLng != null) {
          _newPipelinePoints[i] = nearestLatLng;
        }
      }
    });
  }

  void _zoomToPoint(gmap.LatLng point) {
    if (_mapController != null) {
      _mapController!.animateCamera(
        gmap.CameraUpdate.newLatLngZoom(point, 16.0),
      );
    }
  }

  /// Fly camera to show the entire pipeline route
  void _zoomToPipelineBounds(Map<String, dynamic> pipeline) {
    final geo = pipeline['path_geojson'] as Map;
    final coords = geo['coordinates'] as List;
    if (coords.isEmpty || _mapController == null) return;

    double minLat = double.infinity, maxLat = -double.infinity;
    double minLng = double.infinity, maxLng = -double.infinity;

    for (final c in coords) {
      final lat = (c[1] as num).toDouble();
      final lng = (c[0] as num).toDouble();
      if (lat < minLat) minLat = lat;
      if (lat > maxLat) maxLat = lat;
      if (lng < minLng) minLng = lng;
      if (lng > maxLng) maxLng = lng;
    }

    final bounds = gmap.LatLngBounds(
      southwest: gmap.LatLng(minLat, minLng),
      northeast: gmap.LatLng(maxLat, maxLng),
    );
    _mapController!.animateCamera(
      gmap.CameraUpdate.newLatLngBounds(bounds, 80),
    );
  }

  /// Marker creation wrapper ensuring Google Maps AdvancedMarker Web configuration compliance
  gmap.Marker _buildMarker({
    required gmap.MarkerId markerId,
    required gmap.LatLng position,
    gmap.BitmapDescriptor? icon,
    gmap.InfoWindow? infoWindow,
    VoidCallback? onTap,
  }) {
    final effectiveIcon = icon ?? gmap.BitmapDescriptor.defaultMarker;
    final effectiveInfoWindow = infoWindow ?? gmap.InfoWindow.noText;

    if (googleMapsMarkerType == gmap.GoogleMapMarkerType.advancedMarker) {
      return gmap.AdvancedMarker(
        markerId: markerId,
        position: position,
        icon: effectiveIcon,
        infoWindow: effectiveInfoWindow,
        onTap: onTap,
      );
    } else {
      return gmap.Marker(
        markerId: markerId,
        position: position,
        icon: effectiveIcon,
        infoWindow: effectiveInfoWindow,
        onTap: onTap,
      );
    }
  }

  // ── Delete / Edit / Toggle helpers ─────────────────────────────────

  Future<void> _deletePipeline(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.error),
            SizedBox(width: 8),
            Text('Delete Pipeline'),
          ],
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: const Text(
          'This will permanently delete this pipeline and all its related flow logs and complaints. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await _repository.deletePipeline(id);
      setState(() {
        _selectedAsset = null;
        _selectedAssetType = '';
      });
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pipeline deleted successfully.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete pipeline: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  void _showEditPipelineDialog(BuildContext context) {
    if (_selectedAsset == null || _selectedAssetType != 'pipeline') return;

    final nameController = TextEditingController(text: _selectedAsset!['name']?.toString() ?? '');
    final diameterController = TextEditingController(text: _selectedAsset!['diameter_mm']?.toString() ?? '110');
    String selectedMaterial = _selectedAsset!['material']?.toString() ?? 'PVC';

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (builderCtx, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.edit_rounded, color: AppTheme.primary),
              const SizedBox(width: 8),
              const Text('Edit Pipeline'),
            ],
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Pipeline Name',
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: selectedMaterial,
                  decoration: const InputDecoration(
                    labelText: 'Pipe Material',
                  ),
                  items: const [
                    DropdownMenuItem(value: 'PVC', child: Text('PVC (Polyvinyl Chloride)')),
                    DropdownMenuItem(value: 'HDPE', child: Text('HDPE (High Density Polyethylene)')),
                    DropdownMenuItem(value: 'Cast Iron', child: Text('Cast Iron (Metallic)')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => selectedMaterial = val);
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: diameterController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Pipe Diameter (mm)',
                    suffixText: 'mm',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final diameter = double.tryParse(diameterController.text.trim()) ?? 110.0;
                if (name.isEmpty) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(content: Text('Please enter a pipeline name.')),
                  );
                  return;
                }

                Navigator.pop(dialogCtx);
                setState(() => _isLoading = true);
                try {
                  await _repository.updatePipeline(_selectedAsset!['id'] as int, {
                    'name': name,
                    'diameter_mm': diameter,
                    'material': selectedMaterial,
                  });
                  setState(() {
                    _selectedAsset = null;
                    _selectedAssetType = '';
                  });
                  _loadData();
                  if (mounted) {
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      const SnackBar(
                        content: Text('Pipeline updated successfully.'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  setState(() => _isLoading = false);
                  if (mounted) {
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to update pipeline: $e'),
                        backgroundColor: AppTheme.error,
                      ),
                    );
                  }
                }
              },
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleValveStatus() async {
    if (_selectedAsset == null || _selectedAssetType != 'valve') return;

    final currentStatus = _selectedAsset!['status']?.toString() ?? 'closed';
    final newStatus = currentStatus == 'open' ? 'closed' : 'open';

    setState(() => _isLoading = true);
    try {
      await _repository.toggleValve(_selectedAsset!['id'] as int, newStatus);
      setState(() {
        _selectedAsset = null;
        _selectedAssetType = '';
      });
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Valve toggled to ${newStatus.toUpperCase()}.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to toggle valve: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  // ── UI Overhaul & Styled Elements ──────────────────────────────────

  Widget _buildGlassContainer({
    required Widget child,
    double? width,
    double? height,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
    BorderRadius? borderRadius,
    Color? borderColor,
  }) {
    final br = borderRadius ?? BorderRadius.circular(16);
    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        boxShadow: AppTheme.softShadow,
      ),
      child: ClipRRect(
        borderRadius: br,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: AppTheme.bgCard.withValues(alpha: 0.85),
              borderRadius: br,
              border: Border.all(
                color: borderColor ?? AppTheme.stroke.withValues(alpha: 0.5),
                width: 1.5,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.sizeOf(context).width;
    final bool isMobile = width < 768;

    // Define polylines from pipeline coordinates
    final Set<gmap.Polyline> polylines = {};
    if (!_isLoading && _enableWaterPipelineGrid && _showWaterLines) {
      for (final pipeline in _pipelines) {
        final geo = pipeline['path_geojson'] as Map;
        final coords = geo['coordinates'] as List;
        final points = coords.map((c) => gmap.LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble())).toList();

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
              _zoomToPipelineBounds(pipeline);
            },
          ),
        );
      }
    }

    if (_isDrawingMode && _newPipelinePoints.isNotEmpty) {
      polylines.add(
        gmap.Polyline(
          polylineId: const gmap.PolylineId('new_pipeline_preview'),
          points: _newPipelinePoints,
          color: AppTheme.accent,
          width: 5,
        ),
      );
    }

    // Define markers (Tanks, Valves, Drawing points)
    final Set<gmap.Marker> markers = {};

    if (_isDrawingMode) {
      for (int i = 0; i < _newPipelinePoints.length; i++) {
        markers.add(
          _buildMarker(
            markerId: gmap.MarkerId('new_pipe_point_$i'),
            position: _newPipelinePoints[i],
            icon: gmap.BitmapDescriptor.defaultMarkerWithHue(gmap.BitmapDescriptor.hueCyan),
            infoWindow: gmap.InfoWindow(title: 'Point ${i + 1}'),
          ),
        );
      }
    }

    if (!_isLoading && (_showOverheadTanks || _showBorewells)) {
      for (final tank in _tanks) {
        final isTank = tank['type'] == 'overhead_tank';
        if (isTank && !_showOverheadTanks) continue;
        if (!isTank && !_showBorewells) continue;

        markers.add(
          _buildMarker(
            markerId: gmap.MarkerId('tank_${tank['id']}'),
            position: gmap.LatLng((tank['latitude'] as num).toDouble(), (tank['longitude'] as num).toDouble()),
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
          _buildMarker(
            markerId: gmap.MarkerId('valve_${valve['id']}'),
            position: gmap.LatLng((valve['latitude'] as num).toDouble(), (valve['longitude'] as num).toDouble()),
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
          // 1. Google Maps
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
                    onMapCreated: (controller) {
                      _mapController = controller;
                    },
                    onTap: _isDrawingMode
                        ? (latLng) {
                            setState(() {
                              _newPipelinePoints.add(latLng);
                            });
                          }
                        : null,
                  ),
          ),

          // 2. Drawing Mode top indicator chip
          if (_isDrawingMode)
            Positioned(
              top: 20,
              left: 0,
              right: 0,
              child: Center(
                child: PointerInterceptor(
                  child: MouseRegion(
                    cursor: SystemMouseCursors.basic,
                    child: _buildGlassContainer(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      borderColor: AppTheme.accent.withValues(alpha: 0.6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: AppTheme.accent,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.accent.withValues(alpha: 0.5),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: '📍 Drawing Mode',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.accent,
                                    ),
                                  ),
                                  TextSpan(
                                    text: ' — Tap map to plot points',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.textSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // 3. Responsive Drawing Designer Panel
          if (_isDrawingMode) _buildDrawingEditorPanel(isMobile),

          // 4. Normal Mode floating header (Annur GIS Title)
          if (!_isDrawingMode)
            Positioned(
              top: 20,
              left: 20,
              child: PointerInterceptor(
                child: MouseRegion(
                  cursor: SystemMouseCursors.basic,
                  child: _buildGlassContainer(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: AppTheme.accent,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.accent.withValues(alpha: 0.5),
                                    blurRadius: 6,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Annur Pipeline Grid',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Monitoring live flow, pressure, and leakage indicators',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // 5. Layers Control Overlay (Top Right)
          if (!_isDrawingMode)
            Positioned(
              top: 20,
              right: 20,
              child: PointerInterceptor(
                child: MouseRegion(
                  cursor: SystemMouseCursors.basic,
                  child: _buildGlassContainer(
                    width: 230,
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.layers_rounded, size: 16, color: AppTheme.primaryLight),
                            const SizedBox(width: 6),
                            Text(
                              'Layers Control',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 12),
                        _switchRow('Electrical Grid', _enableElectricalGrid, _isLoading ? null : (v) {
                          setState(() => _enableElectricalGrid = v);
                        }),
                        _switchRow('Water Pipeline Grid', _enableWaterPipelineGrid, _isLoading ? null : (v) {
                          setState(() => _enableWaterPipelineGrid = v);
                        }),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.add_road_rounded, size: 14),
                            label: const Text('Add Pipeline', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            onPressed: _isLoading ? null : () {
                              setState(() {
                                _isDrawingMode = true;
                                _newPipelinePoints.clear();
                                _selectedAsset = null;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // 6. Legend Overlay (Bottom Left)
          if (!_isDrawingMode && !isMobile)
            Positioned(
              bottom: 20,
              left: 20,
              child: PointerInterceptor(
                child: MouseRegion(
                  cursor: SystemMouseCursors.basic,
                  child: _buildGlassContainer(
                    width: 220,
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'LEGEND FILTERS',
                          style: TextStyle(
                            fontSize: 10,
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
              ),
            ),

          // 7. Selected Asset Details Panel (Bottom Right / Bottom Floating on Mobile)
          if (_selectedAsset != null)
            Positioned(
              bottom: 20,
              right: isMobile ? 20 : 20,
              left: isMobile ? 20 : null,
              child: PointerInterceptor(
                child: MouseRegion(
                  cursor: SystemMouseCursors.basic,
                  child: _buildGlassContainer(
                    width: isMobile ? null : 350,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _assetColor().withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(_assetIcon(), size: 18, color: _assetColor()),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _selectedAsset!['name'] ?? _selectedAsset!['valve_number'] ?? 'Asset Node',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    _selectedAssetType.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.textMuted,
                                    ),
                                  ),
                                ],
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
                        // Action buttons row
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.plumbing_rounded, size: 14),
                                label: const Text('Assign Plumber', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                onPressed: () => _showPlumberDialog(context),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ]
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Secondary action row (edit, delete, valve toggle)
                        Row(
                          children: [
                            if (_selectedAssetType == 'pipeline') ...[
                              Expanded(
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.edit_rounded, size: 14),
                                  label: const Text('Edit', style: TextStyle(fontSize: 12)),
                                  onPressed: () => _showEditPipelineDialog(context),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.delete_outline_rounded, size: 14, color: AppTheme.error),
                                  label: const Text('Delete', style: TextStyle(fontSize: 12, color: AppTheme.error)),
                                  onPressed: () => _deletePipeline(_selectedAsset!['id'] as int),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    side: const BorderSide(color: AppTheme.error),
                                  ),
                                ),
                              ),
                            ],
                            if (_selectedAssetType == 'valve') ...[
                              Expanded(
                                child: FilledButton.icon(
                                  icon: Icon(
                                    _selectedAsset!['status'] == 'open'
                                        ? Icons.block_rounded
                                        : Icons.check_circle_outline_rounded,
                                    size: 14,
                                  ),
                                  label: Text(
                                    _selectedAsset!['status'] == 'open' ? 'Close Valve' : 'Open Valve',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                  onPressed: _toggleValveStatus,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: _selectedAsset!['status'] == 'open'
                                        ? AppTheme.error
                                        : AppTheme.accent,
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
        ],
      ),
    );
  }

  // ── Sub-panels and widget builders ─────────────────────────────────

  Widget _buildDrawingEditorPanel(bool isMobile) {
    if (isMobile) {
      final double pathLen = _calculatePathLength(_newPipelinePoints);
      final String formattedLen = _formatLength(pathLen);
      return Positioned(
        bottom: 20,
        left: 20,
        right: 20,
        child: PointerInterceptor(
          child: MouseRegion(
            cursor: SystemMouseCursors.basic,
            child: _buildGlassContainer(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(Icons.edit_road_rounded, color: AppTheme.accent, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'PIPELINE GIS DESIGNER',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.accent),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Pts: ${_newPipelinePoints.length} | Dist: $formattedLen',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                      ),
                    ],
                  ),
                  const Divider(height: 12),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton(
                        onPressed: _newPipelinePoints.isEmpty ? null : _autoSnapNearbyPoints,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        child: const Text('Auto-Snap', style: TextStyle(fontSize: 11)),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _isDrawingMode = false;
                            _newPipelinePoints.clear();
                          });
                        },
                        child: const Text('Cancel', style: TextStyle(fontSize: 11)),
                      ),
                      FilledButton(
                        onPressed: _newPipelinePoints.length < 2
                            ? null
                            : () {
                                _autoSnapPointsBeforeSave();
                                _showPipelineSaveDialog(context);
                              },
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.accent,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                        child: const Text('Save Route', style: TextStyle(fontSize: 11)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 110,
                    child: _newPipelinePoints.isEmpty
                        ? Center(
                            child: Text(
                              'Tap map to place route points.',
                              style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                            ),
                          )
                        : ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _newPipelinePoints.length,
                            itemBuilder: (context, index) {
                              final pt = _newPipelinePoints[index];
                              return Container(
                                width: 130,
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppTheme.bgSurface.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppTheme.stroke),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        CircleAvatar(
                                          radius: 9,
                                          backgroundColor: AppTheme.accent,
                                          child: Text('${index + 1}', style: const TextStyle(fontSize: 8, color: Colors.white)),
                                        ),
                                        GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              _newPipelinePoints.removeAt(index);
                                            });
                                          },
                                          child: const Icon(Icons.close, size: 12, color: AppTheme.error),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '${pt.latitude.toStringAsFixed(4)}, ${pt.longitude.toStringAsFixed(4)}',
                                      style: TextStyle(fontSize: 9, color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    } else {
      return Positioned(
        top: 60,
        right: 20,
        bottom: 20,
        child: PointerInterceptor(
          child: MouseRegion(
            cursor: SystemMouseCursors.basic,
            child: _buildEditorSidebar(),
          ),
        ),
      );
    }
  }

  Widget _buildEditorSidebar() {
    final double pathLen = _calculatePathLength(_newPipelinePoints);
    final String formattedLen = _formatLength(pathLen);
    
    return _buildGlassContainer(
      width: 380,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Sidebar Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.edit_road_rounded, color: AppTheme.accent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PIPELINE GIS DESIGNER',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.accent,
                        letterSpacing: 0.8,
                      ),
                    ),
                    Text(
                      'Plot, stitch & verify routes',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () {
                  setState(() {
                    _isDrawingMode = false;
                    _newPipelinePoints.clear();
                  });
                },
                color: AppTheme.textMuted,
              ),
            ],
          ),
          const Divider(height: 24),
          
          // Stats Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.bgSurface.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.stroke.withValues(alpha: 0.6)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('POINTS', '${_newPipelinePoints.length}', Icons.place_rounded, Colors.cyan),
                _buildStatItem('DISTANCE', formattedLen, Icons.linear_scale_rounded, AppTheme.accent),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Stitch Start & End Section
          Text(
            'STITCH & CONNECT ANCHORS',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: AppTheme.textMuted,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          _buildStitchAnchorRow(
            label: 'Start Anchor:',
            isStart: true,
            currentPoint: _newPipelinePoints.isNotEmpty ? _newPipelinePoints.first : null,
          ),
          const SizedBox(height: 8),
          _buildStitchAnchorRow(
            label: 'End Anchor:',
            isStart: false,
            currentPoint: _newPipelinePoints.length >= 2 ? _newPipelinePoints.last : null,
          ),
          const SizedBox(height: 12),
          
          // Auto Snap Button
          OutlinedButton.icon(
            onPressed: _newPipelinePoints.isEmpty ? null : _autoSnapNearbyPoints,
            icon: const Icon(Icons.bolt, size: 14),
            label: const Text('Auto-Snap Nearby Points', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const Divider(height: 24),
          
          // Route Points Editor Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ROUTE COORDINATES',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textMuted,
                  letterSpacing: 0.5,
                ),
              ),
              if (_newPipelinePoints.isNotEmpty)
                Text(
                  'Tap point to locate',
                  style: TextStyle(
                    fontSize: 9,
                    color: AppTheme.textMuted,
                    fontStyle: FontStyle.italic,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          
          // Points List
          Expanded(
            child: _newPipelinePoints.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.map_rounded, color: AppTheme.textMuted.withValues(alpha: 0.4), size: 40),
                        const SizedBox(height: 8),
                        Text(
                          'No points placed yet.',
                          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tap on map to plot coordinates',
                          style: TextStyle(fontSize: 10, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _newPipelinePoints.length,
                    itemBuilder: (context, index) {
                      return _buildRoutePointItem(index);
                    },
                  ),
          ),
          const SizedBox(height: 16),
          
          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _isDrawingMode = false;
                      _newPipelinePoints.clear();
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _newPipelinePoints.length < 2
                      ? null
                      : () {
                          _autoSnapPointsBeforeSave();
                          _showPipelineSaveDialog(context);
                        },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Save Route'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRoutePointItem(int index) {
    final pt = _newPipelinePoints[index];
    
    // Find if it matches any stitched asset location exactly
    Map<String, dynamic>? matchedAsset;
    for (final asset in _allStitchableAssets) {
      if (asset['latitude'] == pt.latitude && asset['longitude'] == pt.longitude) {
        matchedAsset = asset;
        break;
      }
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: matchedAsset != null 
            ? (matchedAsset['color'] as Color).withValues(alpha: 0.08)
            : AppTheme.bgSurface.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: matchedAsset != null 
              ? (matchedAsset['color'] as Color).withValues(alpha: 0.3)
              : AppTheme.stroke.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          // Index indicator
          GestureDetector(
            onTap: () => _zoomToPoint(pt),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: matchedAsset != null ? matchedAsset['color'] as Color : AppTheme.accent,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          
          // Coordinate / Stitched Asset name
          Expanded(
            child: GestureDetector(
              onTap: () => _zoomToPoint(pt),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (matchedAsset != null) ...[
                      Text(
                        matchedAsset['name'] as String,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: matchedAsset['color'] as Color,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Stitched ${matchedAsset['type']}',
                        style: TextStyle(fontSize: 8, color: AppTheme.textMuted),
                      ),
                    ] else ...[
                      Text(
                        '${pt.latitude.toStringAsFixed(5)}, ${pt.longitude.toStringAsFixed(5)}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        'Manual Route Point',
                        style: TextStyle(fontSize: 8, color: AppTheme.textMuted),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          
          // Reorder / Delete / Snap controls
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Individual Snap Button
              if (matchedAsset == null)
                IconButton(
                  icon: const Icon(Icons.bolt, size: 14),
                  tooltip: 'Snap to nearest asset',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => _snapIndividualPoint(index),
                  color: AppTheme.textSecondary,
                ),
              const SizedBox(width: 4),
              // Move Up
              IconButton(
                icon: const Icon(Icons.arrow_upward_rounded, size: 14),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: index == 0
                    ? null
                    : () {
                        setState(() {
                          final temp = _newPipelinePoints[index];
                          _newPipelinePoints[index] = _newPipelinePoints[index - 1];
                          _newPipelinePoints[index - 1] = temp;
                        });
                      },
                color: AppTheme.textSecondary,
              ),
              const SizedBox(width: 4),
              // Move Down
              IconButton(
                icon: const Icon(Icons.arrow_downward_rounded, size: 14),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: index == _newPipelinePoints.length - 1
                    ? null
                    : () {
                        setState(() {
                          final temp = _newPipelinePoints[index];
                          _newPipelinePoints[index] = _newPipelinePoints[index + 1];
                          _newPipelinePoints[index + 1] = temp;
                        });
                      },
                color: AppTheme.textSecondary,
              ),
              const SizedBox(width: 4),
              // Delete
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 14),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () {
                  setState(() {
                    _newPipelinePoints.removeAt(index);
                  });
                },
                color: AppTheme.error,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStitchAnchorRow({
    required String label,
    required bool isStart,
    required gmap.LatLng? currentPoint,
  }) {
    Map<String, dynamic>? matchedAsset;
    if (currentPoint != null) {
      for (final asset in _allStitchableAssets) {
        if (asset['latitude'] == currentPoint.latitude && asset['longitude'] == currentPoint.longitude) {
          matchedAsset = asset;
          break;
        }
      }
    }
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
        ),
        PopupMenuButton<Map<String, dynamic>>(
          tooltip: 'Select infrastructure node to stitch',
          onSelected: isStart ? _stitchStartAsset : _stitchEndAsset,
          itemBuilder: (context) {
            return _allStitchableAssets.map((asset) {
              return PopupMenuItem<Map<String, dynamic>>(
                value: asset,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: (asset['color'] as Color).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(asset['icon'] as IconData, size: 12, color: asset['color'] as Color),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        asset['name'] as String,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      asset['type'] as String,
                      style: TextStyle(fontSize: 9, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              );
            }).toList();
          },
          child: Container(
            constraints: const BoxConstraints(maxWidth: 240),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: matchedAsset != null 
                  ? (matchedAsset['color'] as Color).withValues(alpha: 0.1)
                  : AppTheme.bgSurface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: matchedAsset != null 
                    ? (matchedAsset['color'] as Color).withValues(alpha: 0.3)
                    : AppTheme.stroke,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (matchedAsset != null) ...[
                  Icon(matchedAsset['icon'] as IconData, size: 12, color: matchedAsset['color'] as Color),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      matchedAsset['name'] as String,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: matchedAsset['color'] as Color),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        if (isStart && _newPipelinePoints.isNotEmpty) {
                          _newPipelinePoints.removeAt(0);
                        } else if (!isStart && _newPipelinePoints.length >= 2) {
                          _newPipelinePoints.removeLast();
                        }
                      });
                    },
                    child: Icon(Icons.cancel_rounded, size: 12, color: AppTheme.textMuted),
                  ),
                ] else ...[
                  Icon(Icons.link_off_rounded, size: 12, color: AppTheme.textMuted),
                  const SizedBox(width: 6),
                  Text(
                    'Not Stitched (Tap to connect)',
                    style: TextStyle(fontSize: 10, color: AppTheme.textMuted),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: AppTheme.textMuted,
            letterSpacing: 0.5,
          ),
        ),
      ],
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
          Text(label, style: TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w500)),
          SizedBox(
            height: 24,
            child: Switch(
              value: value,
              onChanged: onChanged,
              activeTrackColor: AppTheme.primary.withValues(alpha: 0.3),
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
      builder: (dialogCtx) => AlertDialog(
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
                        Navigator.pop(dialogCtx);
                        ScaffoldMessenger.of(this.context).showSnackBar(
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

  void _showPipelineSaveDialog(BuildContext context) {
    final nameController = TextEditingController();
    final diameterController = TextEditingController(text: '110');
    String selectedMaterial = 'PVC';

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (builderCtx, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.add_road_rounded, color: AppTheme.primary),
              const SizedBox(width: 8),
              const Text('Save New Pipeline'),
            ],
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Pipeline Name',
                    hintText: 'e.g. Annur Sector 4 Main Line',
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: selectedMaterial,
                  decoration: const InputDecoration(
                    labelText: 'Pipe Material',
                  ),
                  items: const [
                    DropdownMenuItem(value: 'PVC', child: Text('PVC (Polyvinyl Chloride)')),
                    DropdownMenuItem(value: 'HDPE', child: Text('HDPE (High Density Polyethylene)')),
                    DropdownMenuItem(value: 'Cast Iron', child: Text('Cast Iron (Metallic)')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => selectedMaterial = val);
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: diameterController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Pipe Diameter (mm)',
                    suffixText: 'mm',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final diameter = double.tryParse(diameterController.text.trim()) ?? 110.0;
                if (name.isEmpty) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(content: Text('Please enter a pipeline name.')),
                  );
                  return;
                }

                final pathGeojson = {
                  'type': 'LineString',
                  'coordinates': _newPipelinePoints.map((p) => [p.longitude, p.latitude]).toList(),
                };

                Navigator.pop(dialogCtx);
                
                setState(() => _isLoading = true);
                try {
                  await _repository.createPipeline({
                    'name': name,
                    'panchayat_id': _panchayatId,
                    'path_geojson': pathGeojson,
                    'diameter_mm': diameter,
                    'material': selectedMaterial,
                    'status': 'active',
                  });

                  setState(() {
                    _isDrawingMode = false;
                    _newPipelinePoints.clear();
                  });

                  _loadData();
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(
                      content: Text('Pipeline added successfully.'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  setState(() => _isLoading = false);
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to save pipeline: $e'),
                      backgroundColor: AppTheme.error,
                    ),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
