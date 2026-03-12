import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../config/app_theme.dart';
import '../../models/pole_model.dart';

class MapOverview extends StatelessWidget {
  final List<PoleModel> poles;
  final double height;
  final LatLng? defaultCenter;
  final bool showLegend;
  final bool showCardDecoration;
  final double borderRadius;

  const MapOverview({
    super.key,
    required this.poles,
    this.height = 350,
    this.defaultCenter,
    this.showLegend = true,
    this.showCardDecoration = true,
    this.borderRadius = 18,
  });

  @override
  Widget build(BuildContext context) {
    // Collect valid locations
    final validPoles =
        poles.where((p) => p.latitude != null && p.longitude != null).toList();

    // Calculate center
    LatLng center =
        defaultCenter ??
        const LatLng(20.5937, 78.9629); // Default to India roughly
    if (validPoles.isNotEmpty) {
      double sumLat = 0;
      double sumLng = 0;
      for (var p in validPoles) {
        sumLat += p.latitude!;
        sumLng += p.longitude!;
      }
      center = LatLng(sumLat / validPoles.length, sumLng / validPoles.length);
    }

    final markers =
        validPoles.map((p) {
          final isRed = p.complaintsCount > 0;
          final markerHue =
              isRed
                  ? BitmapDescriptor.hueRed
                  : (p.keypadId == null
                      ? BitmapDescriptor.hueAzure
                      : BitmapDescriptor.hueGreen);

          return Marker(
            markerId: MarkerId('pole_${p.id}'),
            position: LatLng(p.latitude!, p.longitude!),
            infoWindow: InfoWindow(
              title: 'Pole: ${p.poleNumber ?? 'Unknown'}',
              snippet: 'Complaints: ${p.complaintsCount}',
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(markerHue),
          );
        }).toSet();

    final mapContent = Stack(
      children: [
        Positioned.fill(
          child: GoogleMap(
            initialCameraPosition: CameraPosition(
              target: center,
              zoom: validPoles.isEmpty ? 5.0 : 13.0,
            ),
            markers: markers,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),
        ),
        if (validPoles.isEmpty)
          Container(
            color: Colors.white70,
            child: const Center(
              child: Text(
                'No mapped poles available',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 15),
              ),
            ),
          ),
        if (showLegend)
          Positioned(
            bottom: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.95),
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
                  _LegendItem(color: Colors.blue, label: 'Inactive'),
                ],
              ),
            ),
          ),
      ],
    );

    if (!showCardDecoration) {
      return SizedBox(
        height: height,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: mapContent,
        ),
      );
    }

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
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
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
        ),
      ],
    );
  }
}
