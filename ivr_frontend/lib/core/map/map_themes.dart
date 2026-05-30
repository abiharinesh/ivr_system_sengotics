import 'dart:convert';
import 'package:flutter/material.dart';

/// A single map theme preset with metadata and a Google Maps JSON style.
class MapThemePreset {
  final String id;
  final String name;
  final String description;
  final Color previewPrimaryColor;
  final Color previewSecondaryColor;
  final IconData icon;
  final List<Map<String, dynamic>> styleJson;

  const MapThemePreset({
    required this.id,
    required this.name,
    required this.description,
    required this.previewPrimaryColor,
    required this.previewSecondaryColor,
    required this.icon,
    required this.styleJson,
  });

  /// Encoded JSON string suitable for [GoogleMap.style] / [GoogleMapController.setMapStyle].
  String get encodedStyle => jsonEncode(styleJson);

  /// Returns `null` for the "standard" theme so the default map style is used.
  String? get encodedStyleOrNull =>
      id == 'standard' ? null : encodedStyle;
}

/// Collection of all built-in map theme presets.
abstract final class MapThemes {
  static const List<MapThemePreset> all = [
    standard,
    dark,
    night,
    retro,
    silver,
    aubergine,
  ];

  // ── Standard (Google default) ──────────────────────────────────────────
  static const MapThemePreset standard = MapThemePreset(
    id: 'standard',
    name: 'Standard',
    description: 'Default Google Maps style',
    previewPrimaryColor: Color(0xFFE8EAF0),
    previewSecondaryColor: Color(0xFF98B4D4),
    icon: Icons.map_rounded,
    styleJson: [], // empty = Google default
  );

  // ── Dark Mode ──────────────────────────────────────────────────────────
  static const MapThemePreset dark = MapThemePreset(
    id: 'dark',
    name: 'Dark Mode',
    description: 'Sleek dark theme for low-light use',
    previewPrimaryColor: Color(0xFF1A1A2E),
    previewSecondaryColor: Color(0xFF16213E),
    icon: Icons.dark_mode_rounded,
    styleJson: [
      {'elementType': 'geometry', 'stylers': [{'color': '#212121'}]},
      {'elementType': 'labels.icon', 'stylers': [{'visibility': 'off'}]},
      {'elementType': 'labels.text.fill', 'stylers': [{'color': '#757575'}]},
      {'elementType': 'labels.text.stroke', 'stylers': [{'color': '#212121'}]},
      {'featureType': 'administrative', 'elementType': 'geometry', 'stylers': [{'color': '#757575'}]},
      {'featureType': 'administrative.country', 'elementType': 'labels.text.fill', 'stylers': [{'color': '#9e9e9e'}]},
      {'featureType': 'administrative.land_parcel', 'stylers': [{'visibility': 'off'}]},
      {'featureType': 'administrative.locality', 'elementType': 'labels.text.fill', 'stylers': [{'color': '#bdbdbd'}]},
      {'featureType': 'poi', 'elementType': 'labels.text.fill', 'stylers': [{'color': '#757575'}]},
      {'featureType': 'poi.park', 'elementType': 'geometry', 'stylers': [{'color': '#181818'}]},
      {'featureType': 'poi.park', 'elementType': 'labels.text.fill', 'stylers': [{'color': '#616161'}]},
      {'featureType': 'poi.park', 'elementType': 'labels.text.stroke', 'stylers': [{'color': '#1b1b1b'}]},
      {'featureType': 'road', 'elementType': 'geometry.fill', 'stylers': [{'color': '#2c2c2c'}]},
      {'featureType': 'road', 'elementType': 'labels.text.fill', 'stylers': [{'color': '#8a8a8a'}]},
      {'featureType': 'road.arterial', 'elementType': 'geometry', 'stylers': [{'color': '#373737'}]},
      {'featureType': 'road.highway', 'elementType': 'geometry', 'stylers': [{'color': '#3c3c3c'}]},
      {'featureType': 'road.highway.controlled_access', 'elementType': 'geometry', 'stylers': [{'color': '#4e4e4e'}]},
      {'featureType': 'road.local', 'elementType': 'labels.text.fill', 'stylers': [{'color': '#616161'}]},
      {'featureType': 'transit', 'elementType': 'labels.text.fill', 'stylers': [{'color': '#757575'}]},
      {'featureType': 'water', 'elementType': 'geometry', 'stylers': [{'color': '#000000'}]},
      {'featureType': 'water', 'elementType': 'labels.text.fill', 'stylers': [{'color': '#3d3d3d'}]},
    ],
  );

  // ── Night Navigation ───────────────────────────────────────────────────
  static const MapThemePreset night = MapThemePreset(
    id: 'night',
    name: 'Night Navigation',
    description: 'Optimized for night-time driving',
    previewPrimaryColor: Color(0xFF0D1B2A),
    previewSecondaryColor: Color(0xFF1B4965),
    icon: Icons.nightlight_round,
    styleJson: [
      {'elementType': 'geometry', 'stylers': [{'color': '#242f3e'}]},
      {'elementType': 'labels.text.fill', 'stylers': [{'color': '#746855'}]},
      {'elementType': 'labels.text.stroke', 'stylers': [{'color': '#242f3e'}]},
      {'featureType': 'administrative.locality', 'elementType': 'labels.text.fill', 'stylers': [{'color': '#d59563'}]},
      {'featureType': 'poi', 'elementType': 'labels.text.fill', 'stylers': [{'color': '#d59563'}]},
      {'featureType': 'poi.park', 'elementType': 'geometry', 'stylers': [{'color': '#263c3f'}]},
      {'featureType': 'poi.park', 'elementType': 'labels.text.fill', 'stylers': [{'color': '#6b9a76'}]},
      {'featureType': 'road', 'elementType': 'geometry', 'stylers': [{'color': '#38414e'}]},
      {'featureType': 'road', 'elementType': 'geometry.stroke', 'stylers': [{'color': '#212a37'}]},
      {'featureType': 'road', 'elementType': 'labels.text.fill', 'stylers': [{'color': '#9ca5b3'}]},
      {'featureType': 'road.highway', 'elementType': 'geometry', 'stylers': [{'color': '#746855'}]},
      {'featureType': 'road.highway', 'elementType': 'geometry.stroke', 'stylers': [{'color': '#1f2835'}]},
      {'featureType': 'road.highway', 'elementType': 'labels.text.fill', 'stylers': [{'color': '#f3d19c'}]},
      {'featureType': 'transit', 'elementType': 'geometry', 'stylers': [{'color': '#2f3948'}]},
      {'featureType': 'transit.station', 'elementType': 'labels.text.fill', 'stylers': [{'color': '#d59563'}]},
      {'featureType': 'water', 'elementType': 'geometry', 'stylers': [{'color': '#17263c'}]},
      {'featureType': 'water', 'elementType': 'labels.text.fill', 'stylers': [{'color': '#515c6d'}]},
      {'featureType': 'water', 'elementType': 'labels.text.stroke', 'stylers': [{'color': '#17263c'}]},
    ],
  );

  // ── Retro ──────────────────────────────────────────────────────────────
  static const MapThemePreset retro = MapThemePreset(
    id: 'retro',
    name: 'Retro',
    description: 'Warm vintage tones and muted colors',
    previewPrimaryColor: Color(0xFFEDE0C8),
    previewSecondaryColor: Color(0xFFC4A882),
    icon: Icons.auto_awesome_rounded,
    styleJson: [
      {'elementType': 'geometry', 'stylers': [{'color': '#ebe3cd'}]},
      {'elementType': 'labels.text.fill', 'stylers': [{'color': '#523735'}]},
      {'elementType': 'labels.text.stroke', 'stylers': [{'color': '#f5f1e6'}]},
      {'featureType': 'administrative', 'elementType': 'geometry.stroke', 'stylers': [{'color': '#c9b2a6'}]},
      {'featureType': 'administrative.land_parcel', 'elementType': 'geometry.stroke', 'stylers': [{'color': '#dcd2be'}]},
      {'featureType': 'administrative.land_parcel', 'elementType': 'labels.text.fill', 'stylers': [{'color': '#ae9e90'}]},
      {'featureType': 'landscape.natural', 'elementType': 'geometry', 'stylers': [{'color': '#dfd2ae'}]},
      {'featureType': 'poi', 'elementType': 'geometry', 'stylers': [{'color': '#dfd2ae'}]},
      {'featureType': 'poi', 'elementType': 'labels.text.fill', 'stylers': [{'color': '#93817c'}]},
      {'featureType': 'poi.park', 'elementType': 'geometry.fill', 'stylers': [{'color': '#a5b076'}]},
      {'featureType': 'poi.park', 'elementType': 'labels.text.fill', 'stylers': [{'color': '#447530'}]},
      {'featureType': 'road', 'elementType': 'geometry', 'stylers': [{'color': '#f5f1e6'}]},
      {'featureType': 'road.arterial', 'elementType': 'geometry', 'stylers': [{'color': '#fdfcf8'}]},
      {'featureType': 'road.highway', 'elementType': 'geometry', 'stylers': [{'color': '#f8c967'}]},
      {'featureType': 'road.highway', 'elementType': 'geometry.stroke', 'stylers': [{'color': '#e9bc62'}]},
      {'featureType': 'road.highway.controlled_access', 'elementType': 'geometry', 'stylers': [{'color': '#e98d58'}]},
      {'featureType': 'road.highway.controlled_access', 'elementType': 'geometry.stroke', 'stylers': [{'color': '#db8555'}]},
      {'featureType': 'road.local', 'elementType': 'labels.text.fill', 'stylers': [{'color': '#806b63'}]},
      {'featureType': 'transit.line', 'elementType': 'geometry', 'stylers': [{'color': '#dfd2ae'}]},
      {'featureType': 'transit.line', 'elementType': 'labels.text.fill', 'stylers': [{'color': '#8f7d77'}]},
      {'featureType': 'transit.line', 'elementType': 'labels.text.stroke', 'stylers': [{'color': '#ebe3cd'}]},
      {'featureType': 'transit.station', 'elementType': 'geometry', 'stylers': [{'color': '#dfd2ae'}]},
      {'featureType': 'water', 'elementType': 'geometry.fill', 'stylers': [{'color': '#b9d3c2'}]},
      {'featureType': 'water', 'elementType': 'labels.text.fill', 'stylers': [{'color': '#92998d'}]},
    ],
  );

  // ── Silver ─────────────────────────────────────────────────────────────
  static const MapThemePreset silver = MapThemePreset(
    id: 'silver',
    name: 'Silver',
    description: 'Minimal grayscale for clean dashboards',
    previewPrimaryColor: Color(0xFFE0E0E0),
    previewSecondaryColor: Color(0xFFBDBDBD),
    icon: Icons.brightness_5_rounded,
    styleJson: [
      {'elementType': 'geometry', 'stylers': [{'color': '#f5f5f5'}]},
      {'elementType': 'labels.icon', 'stylers': [{'visibility': 'off'}]},
      {'elementType': 'labels.text.fill', 'stylers': [{'color': '#616161'}]},
      {'elementType': 'labels.text.stroke', 'stylers': [{'color': '#f5f5f5'}]},
      {'featureType': 'administrative.land_parcel', 'elementType': 'labels.text.fill', 'stylers': [{'color': '#bdbdbd'}]},
      {'featureType': 'poi', 'elementType': 'geometry', 'stylers': [{'color': '#eeeeee'}]},
      {'featureType': 'poi', 'elementType': 'labels.text.fill', 'stylers': [{'color': '#757575'}]},
      {'featureType': 'poi.park', 'elementType': 'geometry', 'stylers': [{'color': '#e5e5e5'}]},
      {'featureType': 'poi.park', 'elementType': 'labels.text.fill', 'stylers': [{'color': '#9e9e9e'}]},
      {'featureType': 'road', 'elementType': 'geometry', 'stylers': [{'color': '#ffffff'}]},
      {'featureType': 'road.arterial', 'elementType': 'labels.text.fill', 'stylers': [{'color': '#757575'}]},
      {'featureType': 'road.highway', 'elementType': 'geometry', 'stylers': [{'color': '#dadada'}]},
      {'featureType': 'road.highway', 'elementType': 'labels.text.fill', 'stylers': [{'color': '#616161'}]},
      {'featureType': 'road.local', 'elementType': 'labels.text.fill', 'stylers': [{'color': '#9e9e9e'}]},
      {'featureType': 'transit.line', 'elementType': 'geometry', 'stylers': [{'color': '#e5e5e5'}]},
      {'featureType': 'transit.station', 'elementType': 'geometry', 'stylers': [{'color': '#eeeeee'}]},
      {'featureType': 'water', 'elementType': 'geometry', 'stylers': [{'color': '#c9c9c9'}]},
      {'featureType': 'water', 'elementType': 'labels.text.fill', 'stylers': [{'color': '#9e9e9e'}]},
    ],
  );

  // ── Aubergine ──────────────────────────────────────────────────────────
  static const MapThemePreset aubergine = MapThemePreset(
    id: 'aubergine',
    name: 'Aubergine',
    description: 'Deep purple tones with subtle POIs',
    previewPrimaryColor: Color(0xFF2D1B4E),
    previewSecondaryColor: Color(0xFF4A1A6B),
    icon: Icons.palette_rounded,
    styleJson: [
      {'elementType': 'geometry', 'stylers': [{'color': '#1d2c4d'}]},
      {'elementType': 'labels.text.fill', 'stylers': [{'color': '#8ec3b9'}]},
      {'elementType': 'labels.text.stroke', 'stylers': [{'color': '#1a3646'}]},
      {'featureType': 'administrative.country', 'elementType': 'geometry.stroke', 'stylers': [{'color': '#4b6878'}]},
      {'featureType': 'administrative.land_parcel', 'elementType': 'labels.text.fill', 'stylers': [{'color': '#64779e'}]},
      {'featureType': 'administrative.province', 'elementType': 'geometry.stroke', 'stylers': [{'color': '#4b6878'}]},
      {'featureType': 'landscape.man_made', 'elementType': 'geometry.stroke', 'stylers': [{'color': '#334e87'}]},
      {'featureType': 'landscape.natural', 'elementType': 'geometry', 'stylers': [{'color': '#023e58'}]},
      {'featureType': 'poi', 'elementType': 'geometry', 'stylers': [{'color': '#283d6a'}]},
      {'featureType': 'poi', 'elementType': 'labels.text.fill', 'stylers': [{'color': '#6f9ba5'}]},
      {'featureType': 'poi', 'elementType': 'labels.text.stroke', 'stylers': [{'color': '#1d2c4d'}]},
      {'featureType': 'poi.park', 'elementType': 'geometry.fill', 'stylers': [{'color': '#023e58'}]},
      {'featureType': 'poi.park', 'elementType': 'labels.text.fill', 'stylers': [{'color': '#3C7680'}]},
      {'featureType': 'road', 'elementType': 'geometry', 'stylers': [{'color': '#304a7d'}]},
      {'featureType': 'road', 'elementType': 'labels.text.fill', 'stylers': [{'color': '#98a5be'}]},
      {'featureType': 'road', 'elementType': 'labels.text.stroke', 'stylers': [{'color': '#1d2c4d'}]},
      {'featureType': 'road.highway', 'elementType': 'geometry', 'stylers': [{'color': '#2c6675'}]},
      {'featureType': 'road.highway', 'elementType': 'geometry.stroke', 'stylers': [{'color': '#255763'}]},
      {'featureType': 'road.highway', 'elementType': 'labels.text.fill', 'stylers': [{'color': '#b0d5ce'}]},
      {'featureType': 'road.highway', 'elementType': 'labels.text.stroke', 'stylers': [{'color': '#023e58'}]},
      {'featureType': 'transit', 'elementType': 'labels.text.fill', 'stylers': [{'color': '#98a5be'}]},
      {'featureType': 'transit', 'elementType': 'labels.text.stroke', 'stylers': [{'color': '#1d2c4d'}]},
      {'featureType': 'transit.line', 'elementType': 'geometry.fill', 'stylers': [{'color': '#283d6a'}]},
      {'featureType': 'transit.station', 'elementType': 'geometry', 'stylers': [{'color': '#3a4762'}]},
      {'featureType': 'water', 'elementType': 'geometry', 'stylers': [{'color': '#0e1626'}]},
      {'featureType': 'water', 'elementType': 'labels.text.fill', 'stylers': [{'color': '#4e6d70'}]},
    ],
  );

  /// Lookup a preset by [id]. Returns [standard] if not found.
  static MapThemePreset byId(String id) =>
      all.firstWhere((t) => t.id == id, orElse: () => standard);
}
