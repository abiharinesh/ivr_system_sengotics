import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../config/app_theme.dart';
import '../../../../models/zone_model.dart';
import '../../bloc/zone_bloc.dart';
import 'place_search_widget.dart';

/// Left sidebar for zone management: lists saved zones, provides
/// zone creation controls, and place search for boundary auto-fetch.
class ZoneSidebar extends StatefulWidget {
  final ZoneModel? selectedZone;
  final ValueChanged<ZoneModel?> onZoneSelected;
  final VoidCallback onStartDraw;
  final bool isDrawing;
  final ValueChanged<PlaceBoundaryResult> onPlaceBoundarySelected;

  const ZoneSidebar({
    super.key,
    this.selectedZone,
    required this.onZoneSelected,
    required this.onStartDraw,
    required this.isDrawing,
    required this.onPlaceBoundarySelected,
  });

  @override
  State<ZoneSidebar> createState() => _ZoneSidebarState();
}

class _ZoneSidebarState extends State<ZoneSidebar> {
  final _nameController = TextEditingController();
  String _selectedColor = '#2563EB';
  double _opacity = 0.3;

  static const List<String> _colorPalette = [
    '#2563EB', '#10B981', '#F59E0B', '#EF4444', '#8B5CF6',
    '#06B6D4', '#F97316', '#EC4899', '#6366F1', '#14B8A6',
    '#84CC16', '#A855F7',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 310,
      decoration:       BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: AppTheme.stroke)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration:       BoxDecoration(
              border: Border(bottom: BorderSide(color: AppTheme.stroke)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.layers_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                      Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Zone Manager',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        'Draw or search to define boundaries',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(14),
              children: [
                // ── Place Search ──
                      Text(
                  'SEARCH PLACE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: AppTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 8),
                PlaceSearchWidget(
                  onSearch: (query) async {
                    final repo = context.read<ZoneBloc>();
                    repo.add(LookupPlaceBoundary(placeName: query));
                    // Wait for results via BLoC state
                    await Future.delayed(const Duration(milliseconds: 1500));
                    final state = repo.state;
                    if (state is ZonesLoaded) {
                      return state.placeResults;
                    }
                    return [];
                  },
                  onPlaceSelected: widget.onPlaceBoundarySelected,
                ),
                const SizedBox(height: 18),

                // ── Drawing Mode ──
                      Text(
                  'DRAW ZONE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: AppTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: widget.onStartDraw,
                    icon: Icon(
                      widget.isDrawing
                          ? Icons.check_rounded
                          : Icons.draw_rounded,
                      size: 16,
                    ),
                    label: Text(
                      widget.isDrawing
                          ? 'Finish Drawing'
                          : 'Draw on Map',
                    ),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: widget.isDrawing
                          ? AppTheme.accent.withValues(alpha: 0.08)
                          : null,
                      side: BorderSide(
                        color: widget.isDrawing
                            ? AppTheme.accent
                            : AppTheme.strokeStrong,
                      ),
                    ),
                  ),
                ),
                if (widget.isDrawing)
                        Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(
                      'Click on the map to place vertices. Close the polygon by clicking the first point.',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textMuted,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                const SizedBox(height: 18),

                // ── Zone Name & Color ──
                      Text(
                  'ZONE DETAILS',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: AppTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _nameController,
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(
                    hintText: 'Zone name (e.g., Ward 1)',
                    hintStyle: TextStyle(fontSize: 13),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Color picker
                      Text(
                  'Zone Color',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _colorPalette.map((hex) {
                    final isSelected = hex == _selectedColor;
                    final color = _hexToColor(hex);
                    return GestureDetector(
                      onTap: () => setState(() => _selectedColor = hex),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? AppTheme.textPrimary
                                : Colors.transparent,
                            width: 2.5,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(
                                Icons.check,
                                size: 14,
                                color: Colors.white,
                              )
                            : null,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                // Opacity slider
                Row(
                  children: [
                          Text(
                      'Opacity',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${(_opacity * 100).round()}%',
                      style:       TextStyle(
                        fontSize: 11,
                        color: AppTheme.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: _opacity,
                  min: 0.1,
                  max: 0.8,
                  divisions: 7,
                  onChanged: (v) => setState(() => _opacity = v),
                ),
                const SizedBox(height: 18),

                // ── Saved Zones ──
                BlocBuilder<ZoneBloc, ZoneState>(
                  builder: (context, state) {
                    if (state is! ZonesLoaded || state.zones.isEmpty) {
                      return Column(
                        children: [
                                Text(
                            'SAVED ZONES',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                              color: AppTheme.textMuted,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AppTheme.bgSurface,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child:       Column(
                              children: [
                                Icon(
                                  Icons.layers_clear_rounded,
                                  size: 32,
                                  color: AppTheme.textMuted,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'No zones defined yet',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textMuted,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Search for a place or draw a zone',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SAVED ZONES (${state.zones.length})',
                          style:       TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: AppTheme.textMuted,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...state.zones.map((zone) => _ZoneCard(
                              zone: zone,
                              isSelected:
                                  widget.selectedZone?.id == zone.id,
                              onTap: () => widget.onZoneSelected(zone),
                              onToggle: () {
                                context.read<ZoneBloc>().add(UpdateZone(
                                      zoneId: zone.id,
                                      isActive: !zone.isActive,
                                    ));
                              },
                              onDelete: () {
                                context.read<ZoneBloc>().add(
                                      DeleteZone(zoneId: zone.id),
                                    );
                                if (widget.selectedZone?.id == zone.id) {
                                  widget.onZoneSelected(null);
                                }
                              },
                            )),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          // Save button
          Container(
            padding: const EdgeInsets.all(14),
            decoration:       BoxDecoration(
              border: Border(top: BorderSide(color: AppTheme.stroke)),
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _nameController.text.trim().isEmpty ? null : _handleSave,
                icon: const Icon(Icons.save_rounded, size: 16),
                label: const Text('Save Zone'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleSave() {
    if (_nameController.text.trim().isEmpty) return;
    // The zone creation will be handled by the parent screen
    // which will pass the boundary coordinates from the map
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Draw a boundary or select a place first, then save.'),
      ),
    );
  }

  /// Exposes the current form values for the parent screen to use.
  String get zoneName => _nameController.text.trim();
  String get zoneColor => _selectedColor;
  double get zoneOpacity => _opacity;

  Color _hexToColor(String hex) {
    final sanitized = hex.replaceFirst('#', '');
    return Color(int.parse('FF$sanitized', radix: 16));
  }
}

class _ZoneCard extends StatelessWidget {
  final ZoneModel zone;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _ZoneCard({
    required this.zone,
    required this.isSelected,
    required this.onTap,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final color = _hexToColor(zone.color ?? '#2563EB');
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppTheme.durationFast,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.06)
              : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? color : AppTheme.stroke,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: zone.isActive ? color : AppTheme.textMuted,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    zone.name,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: zone.isActive
                          ? AppTheme.textPrimary
                          : AppTheme.textMuted,
                    ),
                  ),
                  if (zone.places.isNotEmpty)
                    Text(
                      '${zone.places.length} place(s)',
                      style:       TextStyle(
                        fontSize: 10,
                        color: AppTheme.textMuted,
                      ),
                    ),
                ],
              ),
            ),
            GestureDetector(
              onTap: onToggle,
              child: Icon(
                zone.isActive
                    ? Icons.visibility_rounded
                    : Icons.visibility_off_rounded,
                size: 16,
                color: AppTheme.textMuted,
              ),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: onDelete,
              child:       Icon(
                Icons.delete_outline_rounded,
                size: 16,
                color: AppTheme.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _hexToColor(String hex) {
    final sanitized = hex.replaceFirst('#', '');
    return Color(int.parse('FF$sanitized', radix: 16));
  }
}