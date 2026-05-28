import 'package:flutter/material.dart';

import '../../../core/api/api_exceptions.dart';
import '../../../config/app_theme.dart';
import '../../../core/widgets/app_loading_state.dart';
import '../../../core/widgets/list_screen_shell.dart';
import '../../../models/pole_model.dart';
import '../data/super_admin_repository.dart';

class SuperAdminPoleManagement extends StatefulWidget {
  const SuperAdminPoleManagement({super.key});

  @override
  State<SuperAdminPoleManagement> createState() =>
      _SuperAdminPoleManagementState();
}

class _SuperAdminPoleManagementState extends State<SuperAdminPoleManagement> {
  final SuperAdminRepository _repo = SuperAdminRepository();
  String _search = '';
  int? _panchayatFilter;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  List<PoleModel> _allPoles = const [];

  @override
  void initState() {
    super.initState();
    _loadPoles();
  }

  Future<void> _loadPoles() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _repo.listPoles();
      setState(() {
        _allPoles = data.map((p) => PoleModel.fromJson(p)).toList();
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Failed to load poles.');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const AppLoadingState(
        message: 'Loading poles...',
        style: AppLoadingStyle.list,
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40, color: AppTheme.error),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _loadPoles,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final allPoles = _allPoles;
    final searchLower = _search.trim().toLowerCase();
    final poles =
        allPoles.where((p) {
          final matchesSearch =
              searchLower.isEmpty
                  ? true
                  : ((p.poleNumber ?? '').toLowerCase().contains(searchLower) ||
                      (p.keypadId ?? '').toLowerCase().contains(searchLower));
          final matchesPanchayat =
              _panchayatFilter == null || p.panchayatId == _panchayatFilter;
          return matchesSearch && matchesPanchayat;
        }).toList();

    final totalPoles = allPoles.length;
    final withLocation =
        allPoles.where((p) => p.latitude != null && p.longitude != null).length;
    final totalComplaints = allPoles.fold<int>(
      0,
      (sum, p) => sum + p.complaintsCount,
    );
    final panchayatIds = <int>{};
    for (final p in allPoles) {
      if (p.panchayatId != null) panchayatIds.add(p.panchayatId!);
    }

    final visibleCount = poles.length;

    return ListScreenShell(
      title: 'Pole Management (All Panchayats)',
      subtitle: 'Search and audit electric poles across every panchayat',
      countLabel:
          '$visibleCount of $totalPoles pole(s) shown • '
          '$withLocation with coordinates • '
          '${panchayatIds.length} panchayat(s) • '
          '$totalComplaints complaint(s)',
      action: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          OutlinedButton.icon(
            onPressed: _saving ? null : _loadPoles,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Refresh'),
          ),
          ElevatedButton.icon(
            onPressed: _saving ? null : () => _showPoleDialog(),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Pole'),
          ),
        ],
      ),
      filters: _buildFilters(panchayatIds),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final hPad = constraints.maxWidth < 400 ? 12.0 : 24.0;
          return ListView.builder(
            padding: EdgeInsets.fromLTRB(hPad, 0, hPad, hPad),
            itemCount: poles.length,
            itemBuilder: (context, index) {
              final pole = poles[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              gradient: AppTheme.primaryGradient,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.electrical_services_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  pole.poleNumber ?? 'Pole #${pole.id}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    if (pole.keypadId != null) ...[
                                      const Icon(
                                        Icons.dialpad_rounded,
                                        size: 14,
                                        color: AppTheme.textMuted,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Keypad: ${pole.keypadId}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.textSecondary,
                                        ),
                                      ),
                                    ],
                                    const Spacer(),
                                    if (pole.panchayatId != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppTheme.bgSurface,
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                        ),
                                        child: Text(
                                          'Panchayat #${pole.panchayatId}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: AppTheme.textSecondary,
                                          ),
                                        ),
                                      ),
                                    const SizedBox(width: 8),
                                    PopupMenuButton<String>(
                                      onSelected: (value) {
                                        if (value == 'edit') {
                                          _showPoleDialog(pole: pole);
                                        } else if (value == 'delete') {
                                          _showDeleteConfirm(pole);
                                        }
                                      },
                                      itemBuilder:
                                          (_) => const [
                                            PopupMenuItem(
                                              value: 'edit',
                                              child: Text('Edit'),
                                            ),
                                            PopupMenuItem(
                                              value: 'delete',
                                              child: Text(
                                                'Delete',
                                                style: TextStyle(
                                                  color: AppTheme.error,
                                                ),
                                              ),
                                            ),
                                          ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          if (pole.latitude != null && pole.longitude != null)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.location_on_outlined,
                                  size: 14,
                                  color: AppTheme.textMuted,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${pole.latitude!.toStringAsFixed(4)}, '
                                  '${pole.longitude!.toStringAsFixed(4)}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          const Spacer(),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.report_problem_rounded,
                                size: 14,
                                color: AppTheme.textMuted,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${pole.complaintsCount} complaint(s)',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (pole.landmarks.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children:
                              pole.landmarks
                                  .map(
                                    (l) => Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primary.withValues(
                                          alpha: 0.08,
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        l,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppTheme.primary,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildFilters(Set<int> panchayatIds) {
    final items = [
      const DropdownMenuItem<int?>(value: null, child: Text('All panchayats')),
      ...panchayatIds.map(
        (id) =>
            DropdownMenuItem<int?>(value: id, child: Text('Panchayat #$id')),
      ),
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 10,
      children: [
        SizedBox(
          width: 360,
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Search by pole number or keypad id',
              prefixIcon: Icon(Icons.search, size: 18),
            ),
            onChanged: (value) {
              setState(() => _search = value);
            },
          ),
        ),
        SizedBox(
          width: 190,
          child: DropdownButtonFormField<int?>(
            initialValue: _panchayatFilter,
            items: items,
            onChanged: (value) {
              setState(() => _panchayatFilter = value);
            },
            decoration: const InputDecoration(
              labelText: 'Panchayat',
              contentPadding: EdgeInsets.symmetric(horizontal: 12),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showPoleDialog({PoleModel? pole}) async {
    final isEdit = pole != null;
    final formKey = GlobalKey<FormState>();

    final poleNumberC = TextEditingController(text: pole?.poleNumber ?? '');
    final keypadC = TextEditingController(text: pole?.keypadId ?? '');
    final latC = TextEditingController(
      text: pole?.latitude != null ? pole!.latitude.toString() : '',
    );
    final lngC = TextEditingController(
      text: pole?.longitude != null ? pole!.longitude.toString() : '',
    );
    final landmarksC = TextEditingController(
      text: pole?.landmarks.join(', ') ?? '',
    );

    final availablePanchayats =
        _allPoles
            .where((p) => p.panchayatId != null)
            .map((p) => p.panchayatId!)
            .toSet()
            .toList()
          ..sort();

    int? selectedPanchayat =
        pole?.panchayatId ??
        _panchayatFilter ??
        (availablePanchayats.isNotEmpty ? availablePanchayats.first : null);

    final saved = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            builder: (ctx, setLocalState) {
              return AlertDialog(
                title: Text(isEdit ? 'Edit Pole' : 'Create Pole'),
                content: SizedBox(
                  width: 580,
                  child: Form(
                    key: formKey,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          DropdownButtonFormField<int>(
                            initialValue: selectedPanchayat,
                            items:
                                availablePanchayats
                                    .map(
                                      (id) => DropdownMenuItem<int>(
                                        value: id,
                                        child: Text('Panchayat #$id'),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (value) {
                              setLocalState(() => selectedPanchayat = value);
                            },
                            decoration: const InputDecoration(
                              labelText: 'Panchayat',
                            ),
                            validator: (value) {
                              if (value == null) {
                                return 'Please select a panchayat';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: poleNumberC,
                                  decoration: const InputDecoration(
                                    labelText: 'Pole Number',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: keypadC,
                                  decoration: const InputDecoration(
                                    labelText: 'Keypad ID',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: latC,
                                  decoration: const InputDecoration(
                                    labelText: 'Latitude',
                                  ),
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: lngC,
                                  decoration: const InputDecoration(
                                    labelText: 'Longitude',
                                  ),
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: landmarksC,
                            decoration: const InputDecoration(
                              labelText: 'Landmarks (comma-separated)',
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
                    onPressed: _saving ? null : () => Navigator.pop(ctx, false),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed:
                        _saving
                            ? null
                            : () async {
                              if (!formKey.currentState!.validate()) return;

                              final lat =
                                  latC.text.trim().isEmpty
                                      ? null
                                      : double.tryParse(latC.text.trim());
                              final lng =
                                  lngC.text.trim().isEmpty
                                      ? null
                                      : double.tryParse(lngC.text.trim());

                              if ((latC.text.trim().isNotEmpty &&
                                      lat == null) ||
                                  (lngC.text.trim().isNotEmpty &&
                                      lng == null)) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Latitude/Longitude must be valid numbers',
                                    ),
                                    backgroundColor: AppTheme.error,
                                  ),
                                );
                                return;
                              }

                              setState(() => _saving = true);
                              try {
                                final payload = <String, dynamic>{
                                  'panchayat_id': selectedPanchayat,
                                  'pole_number':
                                      poleNumberC.text.trim().isEmpty
                                          ? null
                                          : poleNumberC.text.trim(),
                                  'keypad_id':
                                      keypadC.text.trim().isEmpty
                                          ? null
                                          : keypadC.text.trim(),
                                  'latitude': lat,
                                  'longitude': lng,
                                  'landmarks':
                                      landmarksC.text.trim().isEmpty
                                          ? <String>[]
                                          : landmarksC.text
                                              .split(',')
                                              .map((e) => e.trim())
                                              .where((e) => e.isNotEmpty)
                                              .toList(),
                                };

                                if (isEdit) {
                                  await _repo.updatePole(pole.id, payload);
                                } else {
                                  await _repo.createPole(payload);
                                }

                                if (!ctx.mounted) return;
                                Navigator.of(ctx).pop(true);
                              } on ApiException catch (e) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(e.message),
                                    backgroundColor: AppTheme.error,
                                  ),
                                );
                              } finally {
                                if (mounted) {
                                  setState(() => _saving = false);
                                }
                              }
                            },
                    child: Text(isEdit ? 'Save' : 'Create'),
                  ),
                ],
              );
            },
          ),
    );

    if (saved == true) {
      await _loadPoles();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isEdit
                  ? 'Pole updated successfully'
                  : 'Pole created successfully',
            ),
            backgroundColor: AppTheme.accent,
          ),
        );
      }
    }
  }

  Future<void> _showDeleteConfirm(PoleModel pole) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Delete Pole'),
            content: Text(
              'Delete ${pole.poleNumber ?? 'Pole #${pole.id}'}? This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.error,
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delete'),
              ),
            ],
          ),
    );

    if (confirm != true) return;

    setState(() => _saving = true);
    try {
      await _repo.deletePole(pole.id);
      await _loadPoles();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pole deleted successfully'),
            backgroundColor: AppTheme.accent,
          ),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }
}
