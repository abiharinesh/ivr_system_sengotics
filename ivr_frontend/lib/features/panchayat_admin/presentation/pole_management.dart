import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../config/app_theme.dart';
import '../../../core/widgets/empty_state.dart';
import '../bloc/pole_bloc.dart';

class PoleManagement extends StatelessWidget {
  const PoleManagement({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PoleBloc, PoleState>(
      listener: (context, state) {
        if (state is PoleActionSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: AppTheme.accent),
          );
        }
        if (state is PoleError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: AppTheme.error),
          );
        }
      },
      builder: (context, state) {
        if (state is PoleLoading) {
          return const Center(child: CircularProgressIndicator());
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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
          child: Row(
            children: [
              Text(
                '${state.poles.length} pole(s)',
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _showCreateDialog(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Pole'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: state.poles.length,
            itemBuilder: (context, index) {
              final pole = state.poles[index];
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
                              gradient: const LinearGradient(
                                colors: [Color(0xFF8B5CF6), Color(0xFFA855F7)],
                              ),
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
                                if (pole.keypadId != null)
                                  Text(
                                    'Keypad: ${pole.keypadId}',
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
                                _showEditDialog(context, pole);
                              } else if (action == 'delete') {
                                _showDeleteDialog(context, pole.id);
                              }
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(value: 'edit', child: Text('Edit')),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete',
                                    style: TextStyle(color: AppTheme.error)),
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (pole.landmarks.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: pole.landmarks
                              .map((l) => Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color:
                                          AppTheme.primary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      l,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.primaryLight,
                                      ),
                                    ),
                                  ))
                              .toList(),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (pole.latitude != null && pole.longitude != null)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.location_on,
                                    size: 14, color: AppTheme.textMuted),
                                const SizedBox(width: 4),
                                Text(
                                  '${pole.latitude!.toStringAsFixed(4)}, ${pole.longitude!.toStringAsFixed(4)}',
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
                              const Icon(Icons.report_problem_rounded,
                                  size: 14, color: AppTheme.textMuted),
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
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showCreateDialog(BuildContext context) {
    final poleNumC = TextEditingController();
    final keypadC = TextEditingController();
    final latC = TextEditingController();
    final lngC = TextEditingController();
    final landmarksC = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Electric Pole'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: poleNumC,
                  decoration: const InputDecoration(labelText: 'Pole Number'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: keypadC,
                  decoration: const InputDecoration(labelText: 'Keypad ID'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: latC,
                        decoration: const InputDecoration(labelText: 'Latitude'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: lngC,
                        decoration: const InputDecoration(labelText: 'Longitude'),
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
                    hintText: 'e.g. Near temple, Bus stop',
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final data = <String, dynamic>{};
              if (poleNumC.text.isNotEmpty) data['pole_number'] = poleNumC.text.trim();
              if (keypadC.text.isNotEmpty) data['keypad_id'] = keypadC.text.trim();
              if (latC.text.isNotEmpty) data['latitude'] = double.tryParse(latC.text);
              if (lngC.text.isNotEmpty) data['longitude'] = double.tryParse(lngC.text);
              if (landmarksC.text.isNotEmpty) {
                data['landmarks'] = landmarksC.text
                    .split(',')
                    .map((e) => e.trim())
                    .where((e) => e.isNotEmpty)
                    .toList();
              }
              context.read<PoleBloc>().add(CreatePole(data));
              Navigator.pop(ctx);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, dynamic pole) {
    final poleNumC = TextEditingController(text: pole.poleNumber ?? '');
    final keypadC = TextEditingController(text: pole.keypadId ?? '');
    final latC = TextEditingController(
        text: pole.latitude?.toString() ?? '');
    final lngC = TextEditingController(
        text: pole.longitude?.toString() ?? '');
    final landmarksC = TextEditingController(
        text: pole.landmarks.join(', '));
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Pole'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: poleNumC,
                  decoration: const InputDecoration(labelText: 'Pole Number'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: keypadC,
                  decoration: const InputDecoration(labelText: 'Keypad ID'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: latC,
                        decoration: const InputDecoration(labelText: 'Latitude'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: lngC,
                        decoration: const InputDecoration(labelText: 'Longitude'),
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
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final data = <String, dynamic>{};
              if (poleNumC.text.isNotEmpty) data['pole_number'] = poleNumC.text.trim();
              if (keypadC.text.isNotEmpty) data['keypad_id'] = keypadC.text.trim();
              if (latC.text.isNotEmpty) data['latitude'] = double.tryParse(latC.text);
              if (lngC.text.isNotEmpty) data['longitude'] = double.tryParse(lngC.text);
              if (landmarksC.text.isNotEmpty) {
                data['landmarks'] = landmarksC.text
                    .split(',')
                    .map((e) => e.trim())
                    .where((e) => e.isNotEmpty)
                    .toList();
              }
              context.read<PoleBloc>().add(UpdatePole(pole.id, data));
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, int id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Pole'),
        content: const Text('Are you sure? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
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
