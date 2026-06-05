import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmap;
import '../../../../config/app_theme.dart';
import '../../../../core/widgets/app_loading_state.dart';
import '../../../../core/env_maps_loader.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/list_screen_shell.dart';
import '../../bloc/pole_bloc.dart';

class PoleManagement extends StatelessWidget {
  const PoleManagement({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PoleBloc, PoleState>(
      listener: (context, state) {
        if (state is PoleActionSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppTheme.accent,
            ),
          );
        }
        if (state is PoleError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppTheme.error,
            ),
          );
        }
      },
      builder: (context, state) {
        if (state is PoleLoading) {
          return const AppLoadingState(
            message: 'Loading poles...',
            style: AppLoadingStyle.list,
          );
        }
        if (state is PoleLoaded) {
          if (state.poles.isEmpty) {
            return EmptyState(
              icon: Icons.electrical_services_rounded,
              title: 'No Poles',
              subtitle: 'Add electric poles to track complaints',
              action: ElevatedButton.icon(
                onPressed: () => _showCreateDialog(context),
                icon: const Icon(Icons.add),
                label: const Text('Add Pole'),
              ),
            );
          }
          return _buildList(context, state);
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildList(BuildContext context, PoleLoaded state) {
    return ListScreenShell(
      title: 'Pole Management',
      subtitle: 'Track electric pole inventory and issue counts',
      countLabel: '${state.poles.length} pole(s)',
      action: ElevatedButton.icon(
        onPressed: () => _showCreateDialog(context),
        icon: const Icon(Icons.add, size: 18),
        label: const Text('Add Pole'),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final hPad = constraints.maxWidth < 400 ? 12.0 : 24.0;
          return ListView.builder(
            padding: EdgeInsets.symmetric(horizontal: hPad),
        itemCount: state.poles.length,
        itemBuilder: (context, index) {
          final pole = state.poles[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: AppTheme.bgCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.stroke, width: 1.2),
              boxShadow: AppTheme.softShadow,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header row: icon + title + menu ──────────────────
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF8B5CF6), Color(0xFFA855F7)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              )
                            ],
                          ),
                          child: const Icon(
                            Icons.electrical_services_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Pole number (main title)
                              Text(
                                pole.poleNumber ?? '(No pole number)',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              // DB ID + Keypad side by side
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  // Database ID badge
                                  Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () {
                                        Clipboard.setData(ClipboardData(text: '${pole.id}'));
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Pole ID ${pole.id} copied to clipboard'),
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      },
                                      borderRadius: BorderRadius.circular(6),
                                      child: Tooltip(
                                        message: 'Database ID — copy to clipboard',
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF8B5CF6).withValues(alpha: 0.08),
                                            border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.3), width: 0.8),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.tag, size: 11, color: Color(0xFF8B5CF6)),
                                              const SizedBox(width: 4),
                                              Text(
                                                'ID: ${pole.id}',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFF8B5CF6),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (pole.keypadId != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppTheme.bgSurface,
                                        border: Border.all(color: AppTheme.stroke, width: 0.8),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.dialpad, size: 11, color: AppTheme.textMuted),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Keypad: ${pole.keypadId}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: AppTheme.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        PopupMenuButton<String>(
                          icon: Icon(Icons.more_vert, color: AppTheme.textMuted, size: 20),
                          onSelected: (action) {
                            if (action == 'edit') {
                              _showEditDialog(context, pole);
                            } else if (action == 'delete') {
                              _showDeleteDialog(context, pole.id);
                            }
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit_outlined, size: 16),
                                  SizedBox(width: 8),
                                  Text('Edit Details'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete_outline, size: 16, color: AppTheme.error),
                                  SizedBox(width: 8),
                                  Text(
                                    'Delete Pole',
                                    style: TextStyle(color: AppTheme.error),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const Divider(height: 24),

                    // ── Location Details ──────────────────────────────────
                    Row(
                      children: [
                        Icon(Icons.location_on_rounded, size: 14, color: AppTheme.primaryLight),
                        const SizedBox(width: 6),
                        Text(
                          pole.latitude != null && pole.longitude != null
                              ? '${pole.latitude!.toStringAsFixed(6)}, ${pole.longitude!.toStringAsFixed(6)}'
                              : 'No location coordinates',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),

                    // ── Landmarks Tags ────────────────────────────────────
                    if (pole.landmarks.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: pole.landmarks.map(
                          (l) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTheme.primary.withValues(alpha: 0.15), width: 0.8),
                            ),
                            child: Text(
                              l,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primary,
                              ),
                            ),
                          ),
                        ).toList(),
                      ),
                    ],

                    const Divider(height: 24),

                    // ── Card Footer: complaints count ─────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.report_problem_rounded,
                              size: 14,
                              color: pole.complaintsCount > 0 ? AppTheme.warning : AppTheme.textMuted,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${pole.complaintsCount} active complaints',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: pole.complaintsCount > 0 ? AppTheme.warning : AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'Last updated: Just now',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
          );
        },
      ),
    );
  }

  void _showCreateDialog(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (ctx) => BlocProvider.value(
            value: context.read<PoleBloc>(),
            child: const PoleFormDialog(),
          ),
    );
  }

  void _showEditDialog(BuildContext context, dynamic pole) {
    showDialog(
      context: context,
      builder:
          (ctx) => BlocProvider.value(
            value: context.read<PoleBloc>(),
            child: PoleFormDialog(pole: pole),
          ),
    );
  }

  void _showDeleteDialog(BuildContext context, int id) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Delete Pole'),
            content: const Text('Are you sure? This cannot be undone.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.error,
                ),
                onPressed: () {
                  context.read<PoleBloc>().add(DeletePole(id));
                  Navigator.pop(ctx);
                },
                child: const Text('Delete'),
              ),
            ],
          ),
    );
  }
}

class PoleFormDialog extends StatefulWidget {
  final dynamic pole;
  const PoleFormDialog({super.key, this.pole});

  @override
  State<PoleFormDialog> createState() => _PoleFormDialogState();
}

class _PoleFormDialogState extends State<PoleFormDialog> {
  final _poleNumC = TextEditingController();
  final _keypadC = TextEditingController();
  final _latC = TextEditingController();
  final _lngC = TextEditingController();
  final _landmarksC = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  gmap.LatLng? _selectedLocation;
  bool _isFetchingLocation = false;

  @override
  void initState() {
    super.initState();
    if (widget.pole != null) {
      _poleNumC.text = widget.pole.poleNumber ?? '';
      _keypadC.text = widget.pole.keypadId ?? '';
      _latC.text = widget.pole.latitude?.toString() ?? '';
      _lngC.text = widget.pole.longitude?.toString() ?? '';
      _landmarksC.text = widget.pole.landmarks.join(', ');

      if (widget.pole.latitude != null && widget.pole.longitude != null) {
        _selectedLocation = gmap.LatLng(
          widget.pole.latitude!,
          widget.pole.longitude!,
        );
      }
    }
  }

  Future<void> _fetchCurrentLocation() async {
    setState(() => _isFetchingLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled.');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied.');
      }

      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        _selectedLocation = gmap.LatLng(position.latitude, position.longitude);
        _latC.text = position.latitude.toString();
        _lngC.text = position.longitude.toString();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      setState(() => _isFetchingLocation = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mapUnavailableOnWeb = kIsWeb && !isMapsJsReady;
    final Widget mapWidget =
        mapUnavailableOnWeb
            ? Container(
              color: Colors.black12,
              alignment: Alignment.center,
              padding: const EdgeInsets.all(12),
              child: Text(
                mapsWebUnavailableMessage,
                textAlign: TextAlign.center,
                style:       TextStyle(color: AppTheme.textSecondary),
              ),
            )
            : gmap.GoogleMap(
              initialCameraPosition: gmap.CameraPosition(
                target: _selectedLocation ?? const gmap.LatLng(20.5937, 78.9629),
                zoom: _selectedLocation == null ? 4.0 : 15.0,
              ),
              onTap: (point) {
                setState(() {
                  _selectedLocation = point;
                  _latC.text = point.latitude.toString();
                  _lngC.text = point.longitude.toString();
                });
              },
              markers:
                  _selectedLocation == null
                      ? {}
                      : {
                        gmap.Marker(
                          markerId: const gmap.MarkerId('selected_location'),
                          position: _selectedLocation!,
                        ),
                      },
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
            );

    return AlertDialog(
      title: Text(widget.pole == null ? 'Add Electric Pole' : 'Edit Pole'),
      content: Form(
        key: _formKey,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width < 640
                ? MediaQuery.of(context).size.width * 0.9
                : 600,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _poleNumC,
                        decoration: const InputDecoration(
                          labelText: 'Pole Number',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _keypadC,
                        decoration: const InputDecoration(
                          labelText: 'Keypad ID',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Map Picker
                const Text(
                  'Location',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 250,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[700]!),
                    color: Colors.grey[900],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    children: [
                      mapWidget,
                      Positioned(
                        right: 8,
                        bottom: 8,
                        child: FloatingActionButton.small(
                          onPressed:
                              _isFetchingLocation
                                  ? null
                                  : _fetchCurrentLocation,
                          child:
                              _isFetchingLocation
                                  ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                  : const Icon(Icons.my_location),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _latC,
                        decoration: const InputDecoration(
                          labelText: 'Latitude',
                          hintText: 'Tap map or type here',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          signed: true,
                          decimal: true,
                        ),
                        onChanged: (val) {
                          final lat = double.tryParse(val);
                          final lng = double.tryParse(_lngC.text);
                          if (lat != null && lng != null) {
                            setState(() {
                              _selectedLocation = gmap.LatLng(lat, lng);
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _lngC,
                        decoration: const InputDecoration(
                          labelText: 'Longitude',
                          hintText: 'Tap map or type here',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          signed: true,
                          decimal: true,
                        ),
                        onChanged: (val) {
                          final lat = double.tryParse(_latC.text);
                          final lng = double.tryParse(val);
                          if (lat != null && lng != null) {
                            setState(() {
                              _selectedLocation = gmap.LatLng(lat, lng);
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _landmarksC,
                  decoration: const InputDecoration(
                    labelText: 'Landmarks (comma-separated)',
                    hintText: 'e.g. Near temple, Bus stop',
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final data = <String, dynamic>{};
            if (_poleNumC.text.isNotEmpty) {
              data['pole_number'] = _poleNumC.text.trim();
            }
            if (_keypadC.text.isNotEmpty) {
              data['keypad_id'] = _keypadC.text.trim();
            }
            if (_latC.text.isNotEmpty) {
              data['latitude'] = double.tryParse(_latC.text);
            }
            if (_lngC.text.isNotEmpty) {
              data['longitude'] = double.tryParse(_lngC.text);
            }
            if (_landmarksC.text.isNotEmpty) {
              data['landmarks'] =
                  _landmarksC.text
                      .split(',')
                      .map((e) => e.trim())
                      .where((e) => e.isNotEmpty)
                      .toList();
            }
            if (widget.pole == null) {
              context.read<PoleBloc>().add(CreatePole(data));
            } else {
              context.read<PoleBloc>().add(UpdatePole(widget.pole.id, data));
            }
            Navigator.pop(context);
          },
          child: Text(widget.pole == null ? 'Create' : 'Save'),
        ),
      ],
    );
  }
}