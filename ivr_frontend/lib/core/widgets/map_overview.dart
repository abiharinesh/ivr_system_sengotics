import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmap;
import '../../config/app_theme.dart';
import '../env_maps_loader.dart';
import '../map/map_theme_provider.dart';
import '../models/pole_model.dart';
import '../../app.dart';

enum PoleMarkerStatus { active, inactive, fault }

class MapOverview extends StatefulWidget {
  final List<PoleModel> poles;
  final double height;
  final gmap.LatLng? defaultCenter;
  final bool showLegend;
  final bool showCardDecoration;
  final double borderRadius;
  final ValueChanged<PoleModel>? onPoleTap;
  final bool showInfoWindow;
  final bool focusFaultPolesFirst;
  final gmap.BitmapDescriptor Function(PoleModel pole, PoleMarkerStatus status)?
  markerIconBuilder;
  final bool usePngMarkers;
  /// Optional Google Maps JSON style string. When provided, overrides the map
  /// appearance. Pass `null` to use the default Google Maps style.
  /// Use [MapThemeProvider.currentStyleJson] for theme-based styling.
  final String? mapStyle;
  final String faultMarkerAsset;
  final String activeMarkerAsset;
  final String inactiveMarkerAsset;

  const MapOverview({
    super.key,
    required this.poles,
    this.height = 350,
    this.defaultCenter,
    this.showLegend = true,
    this.showCardDecoration = true,
    this.borderRadius = 18,
    this.onPoleTap,
    this.showInfoWindow = true,
    this.focusFaultPolesFirst = false,
    this.markerIconBuilder,
    this.usePngMarkers = kIsWeb,
    this.mapStyle,
    this.faultMarkerAsset = 'assets/map_markers/fault_red.png',
    this.activeMarkerAsset = 'assets/map_markers/active_green.png',
    this.inactiveMarkerAsset = 'assets/map_markers/inactive_yellow.png',
  });

  @override
  State<MapOverview> createState() => _MapOverviewState();
}

class _MapOverviewState extends State<MapOverview> {
  gmap.GoogleMapController? _mapController;
  gmap.BitmapDescriptor? _faultPngMarker;
  gmap.BitmapDescriptor? _activePngMarker;
  gmap.BitmapDescriptor? _inactivePngMarker;


  List<PoleModel> get _validPoles =>
      widget.poles.where((p) => p.latitude != null && p.longitude != null).toList();

  PoleMarkerStatus _statusForPole(PoleModel pole) {
    if (pole.hasCriticalIssues) return PoleMarkerStatus.fault;
    if (pole.hasManualReviewIssues) return PoleMarkerStatus.inactive;
    if (pole.keypadId == null) return PoleMarkerStatus.inactive;
    return PoleMarkerStatus.active;
  }

  gmap.BitmapDescriptor _defaultMarkerForStatus(PoleMarkerStatus status) {
    if (widget.usePngMarkers) {
      final pngMarker = _pngMarkerForStatus(status);
      if (pngMarker != null) return pngMarker;
    }

    switch (status) {
      case PoleMarkerStatus.fault:
        return gmap.BitmapDescriptor.defaultMarkerWithHue(
          gmap.BitmapDescriptor.hueRed,
        );
      case PoleMarkerStatus.inactive:
        return gmap.BitmapDescriptor.defaultMarkerWithHue(
          gmap.BitmapDescriptor.hueAzure,
        );
      case PoleMarkerStatus.active:
        return gmap.BitmapDescriptor.defaultMarkerWithHue(
          gmap.BitmapDescriptor.hueGreen,
        );
    }
  }

  gmap.BitmapDescriptor? _pngMarkerForStatus(PoleMarkerStatus status) {
    switch (status) {
      case PoleMarkerStatus.fault:
        return _faultPngMarker;
      case PoleMarkerStatus.inactive:
        return _inactivePngMarker;
      case PoleMarkerStatus.active:
        return _activePngMarker;
    }
  }

  Future<void> _loadPngMarkers() async {
    if (!widget.usePngMarkers || widget.markerIconBuilder != null) return;

    try {
      const imageConfig = ImageConfiguration(size: Size(36, 36));
      final fault = await gmap.BitmapDescriptor.asset(
        imageConfig,
        widget.faultMarkerAsset,
      );
      final active = await gmap.BitmapDescriptor.asset(
        imageConfig,
        widget.activeMarkerAsset,
      );
      final inactive = await gmap.BitmapDescriptor.asset(
        imageConfig,
        widget.inactiveMarkerAsset,
      );
      if (!mounted) return;
      setState(() {
        _faultPngMarker = fault;
        _activePngMarker = active;
        _inactivePngMarker = inactive;
      });
    } catch (_) {
      // If marker assets are unavailable on a platform/build,
      // the map falls back to default hue markers.
    }
  }

  gmap.LatLng _centroidOf(List<PoleModel> poles) {
    double sumLat = 0;
    double sumLng = 0;
    for (final pole in poles) {
      sumLat += pole.latitude!;
      sumLng += pole.longitude!;
    }
    return gmap.LatLng(sumLat / poles.length, sumLng / poles.length);
  }

  List<PoleModel> _preferredCameraPoles(List<PoleModel> validPoles) {
    if (!widget.focusFaultPolesFirst) return validPoles;
    final faultPoles =
        validPoles.where((pole) => pole.hasOpenIssues).toList();
    return faultPoles.isNotEmpty ? faultPoles : validPoles;
  }

  gmap.LatLng _initialCenter(List<PoleModel> validPoles) {
    if (validPoles.isEmpty) {
      return widget.defaultCenter ?? const gmap.LatLng(20.5937, 78.9629);
    }

    final preferred = _preferredCameraPoles(validPoles);
    return _centroidOf(preferred);
  }

  Future<void> _moveCameraToPreferredPoles({
    required List<PoleModel> validPoles,
    required bool animate,
  }) async {
    try {
      final controller = _mapController;
      if (controller == null || validPoles.isEmpty) return;

      final targetPoles = _preferredCameraPoles(validPoles);
      if (targetPoles.isEmpty) return;

      if (targetPoles.length == 1) {
        final pole = targetPoles.first;
        final update = gmap.CameraUpdate.newLatLngZoom(
          gmap.LatLng(pole.latitude!, pole.longitude!),
          15,
        );
        if (animate) {
          await controller.animateCamera(update);
        } else {
          await controller.moveCamera(update);
        }
        return;
      }

      final latitudes = targetPoles.map((pole) => pole.latitude!).toList();
      final longitudes = targetPoles.map((pole) => pole.longitude!).toList();
      final bounds = gmap.LatLngBounds(
        southwest: gmap.LatLng(
          latitudes.reduce((a, b) => a < b ? a : b),
          longitudes.reduce((a, b) => a < b ? a : b),
        ),
        northeast: gmap.LatLng(
          latitudes.reduce((a, b) => a > b ? a : b),
          longitudes.reduce((a, b) => a > b ? a : b),
        ),
      );
      try {
        final update = gmap.CameraUpdate.newLatLngBounds(bounds, 50);
        if (animate) {
          await controller.animateCamera(update);
        } else {
          await controller.moveCamera(update);
        }
      } catch (_) {
        final fallback = gmap.CameraUpdate.newLatLngZoom(_centroidOf(targetPoles), 13);
        if (animate) {
          await controller.animateCamera(fallback);
        } else {
          await controller.moveCamera(fallback);
        }
      }
    } catch (e) {
      debugPrint('Error moving camera to preferred poles: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _loadPngMarkers();
  }

  @override
  void didUpdateWidget(covariant MapOverview oldWidget) {
    super.didUpdateWidget(oldWidget);
    final shouldReloadPngMarkers =
        widget.usePngMarkers &&
        (oldWidget.usePngMarkers != widget.usePngMarkers ||
            oldWidget.faultMarkerAsset != widget.faultMarkerAsset ||
            oldWidget.activeMarkerAsset != widget.activeMarkerAsset ||
            oldWidget.inactiveMarkerAsset != widget.inactiveMarkerAsset);
    if (shouldReloadPngMarkers) {
      _loadPngMarkers();
    }



    final shouldRefocus =
        oldWidget.poles != widget.poles ||
        oldWidget.focusFaultPolesFirst != widget.focusFaultPolesFirst;
    if (shouldRefocus && _mapController != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _moveCameraToPreferredPoles(validPoles: _validPoles, animate: true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeStyle = context.mapThemeProvider.currentStyleJson;
    final effectiveMapStyle = widget.mapStyle ?? themeStyle;



    // Collect valid locations
    final validPoles = _validPoles;

    // Calculate center
    final center = _initialCenter(validPoles);

    final markers =
        validPoles.map((p) {
          final status = _statusForPole(p);
          final markerIcon =
              widget.markerIconBuilder?.call(p, status) ??
              _defaultMarkerForStatus(status);

          return gmap.Marker(
            markerId: gmap.MarkerId('pole_${p.id}'),
            position: gmap.LatLng(p.latitude!, p.longitude!),
            infoWindow:
                widget.showInfoWindow
                    ? gmap.InfoWindow(
                      title: 'Pole: ${p.poleNumber ?? 'Unknown'}',
                      snippet:
                          'Pending: ${p.pendingComplaints}, '
                          'Processing: ${p.inProgressComplaints}, '
                          'Manual: ${p.manualReviewComplaints}',
                    )
                    : gmap.InfoWindow.noText,
            icon: markerIcon,
            onTap: () => widget.onPoleTap?.call(p),
          );
        }).toSet();



    final mapUnavailableOnWeb = kIsWeb && !isMapsJsReady;

    final mapContent = Stack(
      children: [
        Positioned.fill(
          child: mapUnavailableOnWeb
              ? Container(
                  color: AppTheme.bgCard.withValues(alpha: 0.7),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    mapsWebUnavailableMessage,
                    style:       TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                )
              : gmap.GoogleMap(
                  mapId: googleMapsMapId,
                  markerType: googleMapsMarkerType,
                  initialCameraPosition: gmap.CameraPosition(
                    target: center,
                    zoom: validPoles.isEmpty ? 5.0 : 13.0,
                  ),
                  style: effectiveMapStyle,
                  onMapCreated: (controller) {
                    _mapController = controller;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) return;
                      _moveCameraToPreferredPoles(
                        validPoles: validPoles,
                        animate: false,
                      );
                    });
                  },
                  markers: markers,
                  mapType: gmap.MapType.normal,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                ),
          ),
        if (validPoles.isEmpty)
          Container(
            color: AppTheme.bgCard.withValues(alpha: 0.7),
            child:       Center(
              child: Text(
                'No mapped poles available',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 15),
              ),
            ),
          ),
        if (widget.showLegend)
          Positioned(
            bottom: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.bgCard.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.stroke),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _LegendItem(color: Colors.green, label: 'Active'),
                  SizedBox(width: 12),
                  _LegendItem(color: Colors.red, label: 'Issue'),
                  SizedBox(width: 12),
                  _LegendItem(color: Colors.amber, label: 'Inactive'),
                ],
              ),
            ),
          ),
      ],
    );

    if (!widget.showCardDecoration) {
      return SizedBox(
        height: widget.height,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          child: mapContent,
        ),
      );
    }

    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(widget.borderRadius),
        border: Border.all(color: AppTheme.stroke),
        boxShadow: AppTheme.softShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(child: mapContent),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.location_on, color: color, size: 16),
        const SizedBox(width: 4),
        Text(
          label,
          style:       TextStyle(color: AppTheme.textSecondary, fontSize: 12),
        ),
      ],
    );
  }
}