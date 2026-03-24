import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../config/app_theme.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/list_screen_shell.dart';
import '../bloc/panchayat_bloc.dart';

class PanchayatManagement extends StatefulWidget {
  const PanchayatManagement({super.key});

  @override
  State<PanchayatManagement> createState() => _PanchayatManagementState();
}

class _PanchayatManagementState extends State<PanchayatManagement> {
  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PanchayatBloc, PanchayatState>(
      listener: (context, state) {
        if (state is PanchayatActionSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppTheme.accent,
            ),
          );
        }
        if (state is PanchayatError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppTheme.error,
            ),
          );
        }
      },
      builder: (context, state) {
        if (state is PanchayatLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state is PanchayatLoaded) {
          if (state.panchayats.isEmpty) {
            return EmptyState(
              icon: Icons.location_city_rounded,
              title: 'No Panchayats',
              subtitle: 'Create your first panchayat to get started',
              action: ElevatedButton.icon(
                onPressed: () => _showCreateDialog(context),
                icon: const Icon(Icons.add),
                label: const Text('Add Panchayat'),
              ),
            );
          }
          return _buildList(context, state);
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildList(BuildContext context, PanchayatLoaded state) {
    return ListScreenShell(
      title: 'Panchayat Management',
      subtitle: 'Create and maintain all panchayat entities',
      countLabel: '${state.panchayats.length} panchayat(s)',
      action: ElevatedButton.icon(
        onPressed: () => _showCreateDialog(context),
        icon: const Icon(Icons.add, size: 18),
        label: const Text('Add Panchayat'),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final hPad = constraints.maxWidth < 400 ? 12.0 : 24.0;
          return ListView.builder(
            padding: EdgeInsets.symmetric(horizontal: hPad),
            itemCount: state.panchayats.length,
            itemBuilder: (context, index) {
              final p = state.panchayats[index];
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
                          color: AppTheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.location_city_rounded,
                          color: AppTheme.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (p.ivrNumber != null)
                              Text(
                                'IVR: ${p.ivrNumber}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textMuted,
                                ),
                              ),
                          ],
                        ),
                      ),
                      PopupMenuButton<String>(
                        onSelected: (action) {
                          if (action == 'edit') {
                            _showEditDialog(context, p);
                          } else if (action == 'delete') {
                            _showDeleteDialog(context, p.id, p.name);
                          }
                        },
                        itemBuilder:
                            (_) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: Text('Edit'),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text(
                                  'Delete',
                                  style: TextStyle(color: AppTheme.error),
                                ),
                              ),
                            ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _InfoChip(
                        icon: Icons.electrical_services_rounded,
                        label: '${p.polesCount} poles',
                      ),
                      const SizedBox(width: 12),
                      _InfoChip(
                        icon: Icons.report_problem_rounded,
                        label: '${p.complaintsCount} complaints',
                      ),
                      const SizedBox(width: 12),
                      _InfoChip(
                        icon: Icons.people_rounded,
                        label: '${p.usersCount} admins',
                      ),
                    ],
                  ),
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

  void _showCreateDialog(BuildContext context) {
    final nameC = TextEditingController();
    final ivrC = TextEditingController();
    final latC = TextEditingController();
    final lngC = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Add Panchayat'),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameC,
                      decoration: const InputDecoration(labelText: 'Name *'),
                      validator:
                          (v) => v == null || v.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: ivrC,
                      decoration: const InputDecoration(
                        labelText: 'IVR Number',
                      ),
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
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    final data = <String, dynamic>{'name': nameC.text.trim()};
                    if (ivrC.text.isNotEmpty) {
                      data['ivr_number'] = ivrC.text.trim();
                    }
                    if (latC.text.isNotEmpty) {
                      data['center_lat'] = double.tryParse(latC.text);
                    }
                    if (lngC.text.isNotEmpty) {
                      data['center_lng'] = double.tryParse(lngC.text);
                    }
                    context.read<PanchayatBloc>().add(CreatePanchayat(data));
                    Navigator.pop(ctx);
                  }
                },
                child: const Text('Create'),
              ),
            ],
          ),
    );
  }

  void _showEditDialog(BuildContext context, dynamic panchayat) {
    final nameC = TextEditingController(text: panchayat.name);
    final ivrC = TextEditingController(text: panchayat.ivrNumber ?? '');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Edit Panchayat'),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameC,
                      decoration: const InputDecoration(labelText: 'Name *'),
                      validator:
                          (v) => v == null || v.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: ivrC,
                      decoration: const InputDecoration(
                        labelText: 'IVR Number',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    final data = <String, dynamic>{'name': nameC.text.trim()};
                    if (ivrC.text.isNotEmpty) {
                      data['ivr_number'] = ivrC.text.trim();
                    }
                    context.read<PanchayatBloc>().add(
                      UpdatePanchayat(panchayat.id, data),
                    );
                    Navigator.pop(ctx);
                  }
                },
                child: const Text('Save'),
              ),
            ],
          ),
    );
  }

  void _showDeleteDialog(BuildContext context, int id, String name) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Delete Panchayat'),
            content: Text(
              'Are you sure you want to delete "$name"? This action cannot be undone.',
            ),
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
                  context.read<PanchayatBloc>().add(DeletePanchayat(id));
                  Navigator.pop(ctx);
                },
                child: const Text('Delete'),
              ),
            ],
          ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppTheme.textMuted),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
      ],
    );
  }
}
