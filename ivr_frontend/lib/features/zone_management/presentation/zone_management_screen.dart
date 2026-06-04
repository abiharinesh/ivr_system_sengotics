import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmap;
import '../../../config/app_theme.dart';
import '../../../core/env_maps_loader.dart';
import '../data/models/zone_model.dart';
import '../../../app.dart';
import '../bloc/zone_bloc.dart';
import 'widgets/zone_sidebar.dart';

/// Full-screen zone management screen with interactive Google Map
/// and a sidebar for zone creation, editing, and place search.
class ZoneManagementScreen extends StatefulWidget {
  const ZoneManagementScreen({super.key});

  @override
  State<ZoneManagementScreen> createState() => _ZoneManagementScreenState();
}

class _ZoneManagementScreenState extends State<ZoneManagementScreen> {
  gmap.GoogleMapController? _mapController;
  ZoneModel? _selectedZone;
  bool _isDrawing = false;
  final List<gmap.LatLng> _drawingPoints = [];

  // Preview boundary from place search
  Map<String, dynamic>? _previewBoundary;
  String? _previewPlaceName;

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 800;
    final mapTheme = context.mapThemeProvider;

    return BlocConsumer<ZoneBloc, ZoneState>(
      listener: (context, state) {
        if (state is ZoneError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppTheme.error,
            ),
          );
        }
      },
      builder: (context, state) {
        if (state is ZoneLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final zones = state is ZonesLoaded ? state.zones : <ZoneModel>[];

        if (isMobile) {
          return Scaffold(
            body: _buildMap(zones, mapTheme.currentStyleJson),
            floatingActionButton: FloatingActionButton(
              onPressed: () => _showMobileSidebar(context),
              child: const Icon(Icons.layers_rounded),
            ),
          );
        }

        return Row(
          children: [
            ZoneSidebar(
              selectedZone: _selectedZone,
              onZoneSelected: _onZoneSelected,
              onStartDraw: _toggleDrawing,
              isDrawing: _isDrawing,
              onPlaceBoundarySelected: _onPlaceBoundarySelected,
            ),
            Expanded(
              child: Stack(
                children: [
                  _buildMap(zones, mapTheme.currentStyleJson),
                  // Drawing toolbar
                  if (_isDrawing)
                    Positioned(
                      top: 16,
                      left: 16,
                      child: _DrawingToolbar(
                        pointCount: _drawingPoints.length,
                        onUndo: _undoLastPoint,
                        onClear: _clearDrawing,
                        onComplete: _completeDrawing,
                      ),
                    ),
                  // Preview info bar
                  if (_previewPlaceName != null)
                    Positioned(
                      bottom: 16,
                      left: 16,
                      right: 16,
                      child: _PreviewInfoBar(
                        placeName: _previewPlaceName!,
                        onAddToZone: _addPreviewAsZone,
                        onDismiss: () {
                          setState(() {
                            _previewBoundary = null;
                            _previewPlaceName = null;
                          });
                        },
                      ),
                    ),
                  // Zone legend
                  if (zones.isNotEmpty)
                    Positioned(
                      top: 16,
                      right: 16,
                      child: _ZoneLegend(zones: zones),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMap(List<ZoneModel> zones, String? mapStyle) {
    final mapUnavailableOnWeb = kIsWeb && !isMapsJsReady;

    if (mapUnavailableOnWeb) {
      return Container(
        color: Colors.white70,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(20),
        child: Text(
          mapsWebUnavailableMessage,
          style:       TextStyle(color: AppTheme.textSecondary, fontSize: 14),
          textAlign: TextAlign.center,
        ),
      );
    }

    // Build zone polygons
    final polygons = <gmap.Polygon>{};
    for (final zone in zones.where((z) => z.isActive)) {
      final zonePolygons = _buildPolygonsFromGeojson(zone);
      polygons.addAll(zonePolygons);
    }

    // Add preview boundary polygon
    if (_previewBoundary != null) {
      final previewPolygons = _buildPolygonsFromRawGeojson(
        _previewBoundary!,
        'preview',
        const Color(0xFF2563EB),
        0.15,
        isDashed: true,
      );
      polygons.addAll(previewPolygons);
    }

    // Drawing polygon
    if (_drawingPoints.length >= 2) {
      polygons.add(gmap.Polygon(
        polygonId: const gmap.PolygonId('drawing'),
        points: _drawingPoints,
        fillColor: AppTheme.primary.withValues(alpha: 0.12),
        strokeColor: AppTheme.primary,
        strokeWidth: 2,
      ));
    }

    // Drawing markers
    final markers = <gmap.Marker>{};
    for (int i = 0; i < _drawingPoints.length; i++) {
      markers.add(gmap.Marker(
        markerId: gmap.MarkerId('draw_$i'),
        position: _drawingPoints[i],
        icon: gmap.BitmapDescriptor.defaultMarkerWithHue(
          gmap.BitmapDescriptor.hueAzure,
        ),
      ));
    }

    return gmap.GoogleMap(
      initialCameraPosition: const gmap.CameraPosition(
        target: gmap.LatLng(10.8505, 76.2711), // Tamil Nadu center
        zoom: 8,
      ),
      style: mapStyle,
      onMapCreated: (controller) {
        _mapController = controller;
        _fitToZones(zones);
      },
      onTap: _isDrawing ? _onMapTap : null,
      polygons: polygons,
      markers: markers,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: true,
      mapToolbarEnabled: false,
    );
  }

  Set<gmap.Polygon> _buildPolygonsFromGeojson(ZoneModel zone) {
    final color = _hexToColor(zone.color ?? '#2563EB');
    return _buildPolygonsFromRawGeojson(
      zone.boundaryGeojson,
      'zone_${zone.id}',
      color,
      zone.opacity,
    );
  }

  Set<gmap.Polygon> _buildPolygonsFromRawGeojson(
    Map<String, dynamic> geojson,
    String idPrefix,
    Color color,
    double opacity, {
    bool isDashed = false,
  }) {
    final polygons = <gmap.Polygon>{};
    final type = geojson['type'] as String?;

    if (type == 'Polygon') {
      final coords = geojson['coordinates'] as List<dynamic>?;
      if (coords != null && coords.isNotEmpty) {
        final points = _coordsToLatLng(coords[0] as List<dynamic>);
        polygons.add(gmap.Polygon(
          polygonId: gmap.PolygonId(idPrefix),
          points: points,
          fillColor: color.withValues(alpha: opacity),
          strokeColor: isDashed ? color.withValues(alpha: 0.7) : color,
          strokeWidth: isDashed ? 3 : 2,
        ));
      }
    } else if (type == 'MultiPolygon') {
      final coords = geojson['coordinates'] as List<dynamic>?;
      if (coords != null) {
        for (int i = 0; i < coords.length; i++) {
          final poly = coords[i] as List<dynamic>;
          if (poly.isNotEmpty) {
            final points = _coordsToLatLng(poly[0] as List<dynamic>);
            polygons.add(gmap.Polygon(
              polygonId: gmap.PolygonId('${idPrefix}_$i'),
              points: points,
              fillColor: color.withValues(alpha: opacity),
              strokeColor: isDashed ? color.withValues(alpha: 0.7) : color,
              strokeWidth: isDashed ? 3 : 2,
            ));
          }
        }
      }
    } else if (type == 'Feature') {
      final geometry = geojson['geometry'] as Map<String, dynamic>?;
      if (geometry != null) {
        return _buildPolygonsFromRawGeojson(geometry, idPrefix, color, opacity,
            isDashed: isDashed);
      }
    }

    return polygons;
  }

  List<gmap.LatLng> _coordsToLatLng(List<dynamic> coords) {
    return coords.map((c) {
      final pair = c as List<dynamic>;
      // GeoJSON is [lng, lat]
      return gmap.LatLng(
        (pair[1] as num).toDouble(),
        (pair[0] as num).toDouble(),
      );
    }).toList();
  }

  void _onMapTap(gmap.LatLng position) {
    if (!_isDrawing) return;
    setState(() {
      // If clicking near the first point and we have at least 3, close the polygon
      if (_drawingPoints.length >= 3) {
        final first = _drawingPoints.first;
        final dist = _roughDistance(first, position);
        if (dist < 0.001) {
          // Close it
          _completeDrawing();
          return;
        }
      }
      _drawingPoints.add(position);
    });
  }

  double _roughDistance(gmap.LatLng a, gmap.LatLng b) {
    final dlat = a.latitude - b.latitude;
    final dlng = a.longitude - b.longitude;
    return (dlat * dlat + dlng * dlng);
  }

  void _toggleDrawing() {
    setState(() {
      if (_isDrawing) {
        _completeDrawing();
      } else {
        _isDrawing = true;
        _drawingPoints.clear();
      }
    });
  }

  void _undoLastPoint() {
    if (_drawingPoints.isNotEmpty) {
      setState(() => _drawingPoints.removeLast());
    }
  }

  void _clearDrawing() {
    setState(() {
      _drawingPoints.clear();
      _isDrawing = false;
    });
  }

  void _completeDrawing() {
    if (_drawingPoints.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A polygon needs at least 3 points'),
        ),
      );
      return;
    }

    setState(() => _isDrawing = false);

    // Show save dialog
    _showSaveZoneDialog(_pointsToGeojson(_drawingPoints));
  }

  Map<String, dynamic> _pointsToGeojson(List<gmap.LatLng> points) {
    final coords = points
        .map((p) => [p.longitude, p.latitude])
        .toList();
    // Close the ring
    if (coords.isNotEmpty) {
      coords.add(coords.first);
    }
    return {
      'type': 'Polygon',
      'coordinates': [coords],
    };
  }

  void _onPlaceBoundarySelected(PlaceBoundaryResult result) {
    if (result.geojson == null) return;
    setState(() {
      _previewBoundary = result.geojson;
      _previewPlaceName = result.displayName.split(',').first;
    });
    _fitToBoundary(result.geojson!);
  }

  void _addPreviewAsZone() {
    if (_previewBoundary == null) return;
    _showSaveZoneDialog(_previewBoundary!, suggestedName: _previewPlaceName);
  }

  void _showSaveZoneDialog(
    Map<String, dynamic> boundary, {
    String? suggestedName,
  }) {
    final nameController = TextEditingController(text: suggestedName ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save Zone'),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Zone Name *',
                  hintText: 'e.g., Ward 1, South Zone',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              context.read<ZoneBloc>().add(CreateZone(
                    name: name,
                    boundaryGeojson: boundary,
                    color: '#2563EB',
                    opacity: 0.3,
                    places: suggestedName != null ? [suggestedName] : [],
                  ));
              Navigator.pop(ctx);
              setState(() {
                _previewBoundary = null;
                _previewPlaceName = null;
                _drawingPoints.clear();
              });
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _onZoneSelected(ZoneModel? zone) {
    setState(() => _selectedZone = zone);
    if (zone != null) {
      _fitToBoundary(zone.boundaryGeojson);
    }
  }

  void _fitToZones(List<ZoneModel> zones) {
    if (zones.isEmpty || _mapController == null) return;
    // Compute bounds from all zone centroids
    double minLat = 90, maxLat = -90, minLng = 180, maxLng = -180;
    bool hasPoints = false;

    for (final zone in zones) {
      final coords = _extractFirstCoords(zone.boundaryGeojson);
      for (final c in coords) {
        hasPoints = true;
        if (c.latitude < minLat) minLat = c.latitude;
        if (c.latitude > maxLat) maxLat = c.latitude;
        if (c.longitude < minLng) minLng = c.longitude;
        if (c.longitude > maxLng) maxLng = c.longitude;
      }
    }

    if (!hasPoints) return;
    _mapController!.animateCamera(
      gmap.CameraUpdate.newLatLngBounds(
        gmap.LatLngBounds(
          southwest: gmap.LatLng(minLat, minLng),
          northeast: gmap.LatLng(maxLat, maxLng),
        ),
        60,
      ),
    );
  }

  void _fitToBoundary(Map<String, dynamic> geojson) {
    final coords = _extractFirstCoords(geojson);
    if (coords.isEmpty || _mapController == null) return;

    double minLat = 90, maxLat = -90, minLng = 180, maxLng = -180;
    for (final c in coords) {
      if (c.latitude < minLat) minLat = c.latitude;
      if (c.latitude > maxLat) maxLat = c.latitude;
      if (c.longitude < minLng) minLng = c.longitude;
      if (c.longitude > maxLng) maxLng = c.longitude;
    }

    _mapController!.animateCamera(
      gmap.CameraUpdate.newLatLngBounds(
        gmap.LatLngBounds(
          southwest: gmap.LatLng(minLat, minLng),
          northeast: gmap.LatLng(maxLat, maxLng),
        ),
        60,
      ),
    );
  }

  List<gmap.LatLng> _extractFirstCoords(Map<String, dynamic> geojson) {
    final type = geojson['type'] as String?;
    if (type == 'Polygon') {
      final coords = geojson['coordinates'] as List<dynamic>?;
      if (coords != null && coords.isNotEmpty) {
        return _coordsToLatLng(coords[0] as List<dynamic>);
      }
    } else if (type == 'MultiPolygon') {
      final coords = geojson['coordinates'] as List<dynamic>?;
      if (coords != null && coords.isNotEmpty) {
        final first = coords[0] as List<dynamic>;
        if (first.isNotEmpty) {
          return _coordsToLatLng(first[0] as List<dynamic>);
        }
      }
    } else if (type == 'Feature') {
      final geometry = geojson['geometry'] as Map<String, dynamic>?;
      if (geometry != null) return _extractFirstCoords(geometry);
    }
    return [];
  }

  void _showMobileSidebar(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.8,
        child: BlocProvider.value(
          value: context.read<ZoneBloc>(),
          child: ZoneSidebar(
            selectedZone: _selectedZone,
            onZoneSelected: (zone) {
              _onZoneSelected(zone);
              Navigator.pop(context);
            },
            onStartDraw: () {
              _toggleDrawing();
              Navigator.pop(context);
            },
            isDrawing: _isDrawing,
            onPlaceBoundarySelected: (result) {
              _onPlaceBoundarySelected(result);
              Navigator.pop(context);
            },
          ),
        ),
      ),
    );
  }

  Color _hexToColor(String hex) {
    final sanitized = hex.replaceFirst('#', '');
    return Color(int.parse('FF$sanitized', radix: 16));
  }
}

/// Toolbar shown during polygon drawing mode.
class _DrawingToolbar extends StatelessWidget {
  final int pointCount;
  final VoidCallback onUndo;
  final VoidCallback onClear;
  final VoidCallback onComplete;

  const _DrawingToolbar({
    required this.pointCount,
    required this.onUndo,
    required this.onClear,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppTheme.softShadow,
        border: Border.all(color: AppTheme.stroke),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
                Icon(Icons.draw_rounded, size: 16, color: AppTheme.primary),
          const SizedBox(width: 8),
          Text(
            'Drawing: $pointCount pts',
            style:       TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(width: 12),
          _ToolButton(
            icon: Icons.undo_rounded,
            tooltip: 'Undo',
            onTap: pointCount > 0 ? onUndo : null,
          ),
          const SizedBox(width: 4),
          _ToolButton(
            icon: Icons.close_rounded,
            tooltip: 'Clear',
            onTap: onClear,
          ),
          const SizedBox(width: 4),
          _ToolButton(
            icon: Icons.check_rounded,
            tooltip: 'Complete',
            onTap: pointCount >= 3 ? onComplete : null,
            isPrimary: true,
          ),
        ],
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool isPrimary;

  const _ToolButton({
    required this.icon,
    required this.tooltip,
    this.onTap,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: isPrimary
                ? AppTheme.primary.withValues(alpha: 0.1)
                : null,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 16,
            color: onTap != null
                ? (isPrimary ? AppTheme.primary : AppTheme.textSecondary)
                : AppTheme.textMuted.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }
}

/// Info bar shown when a place boundary is being previewed.
class _PreviewInfoBar extends StatelessWidget {
  final String placeName;
  final VoidCallback onAddToZone;
  final VoidCallback onDismiss;

  const _PreviewInfoBar({
    required this.placeName,
    required this.onAddToZone,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppTheme.softShadow,
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
                Icon(Icons.map_rounded, size: 18, color: AppTheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                      Text(
                  'Boundary Preview',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary,
                  ),
                ),
                Text(
                  placeName,
                  style:       TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onDismiss,
            child: const Text('Dismiss'),
          ),
          const SizedBox(width: 4),
          ElevatedButton.icon(
            onPressed: onAddToZone,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add as Zone'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }
}

/// Zone legend overlay showing zone names and their colors.
class _ZoneLegend extends StatelessWidget {
  final List<ZoneModel> zones;

  const _ZoneLegend({required this.zones});

  @override
  Widget build(BuildContext context) {
    final activeZones = zones.where((z) => z.isActive).toList();
    if (activeZones.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(10),
      constraints: const BoxConstraints(maxWidth: 180),
      decoration: BoxDecoration(
        color: AppTheme.bgCard.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.stroke),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
                Text(
            'ZONES',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 6),
          ...activeZones.map((z) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _hexToColor(z.color ?? '#2563EB'),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        z.name,
                        style:       TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Color _hexToColor(String hex) {
    final sanitized = hex.replaceFirst('#', '');
    return Color(int.parse('FF$sanitized', radix: 16));
  }
}