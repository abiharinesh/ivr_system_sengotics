import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../config/app_theme.dart';
import '../../../core/widgets/empty_state.dart';
import '../bloc/user_bloc.dart';
import '../bloc/panchayat_bloc.dart';

class UserManagement extends StatelessWidget {
  const UserManagement({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<UserMgmtBloc, UserMgmtState>(
      listener: (context, state) {
        if (state is UserMgmtActionSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: AppTheme.accent),
          );
        }
        if (state is UserMgmtError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: AppTheme.error),
          );
        }
      },
      builder: (context, state) {
        if (state is UserMgmtLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state is UserMgmtLoaded) {
          if (state.users.isEmpty) {
            return EmptyState(
              icon: Icons.people_rounded,
              title: 'No Users',
              subtitle: 'Create admin users to manage panchayats',
              action: ElevatedButton.icon(
                onPressed: () => _showCreateDialog(context),
                icon: const Icon(Icons.add),
                label: const Text('Add Admin'),
              ),
            );
          }
          return _buildList(context, state);
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildList(BuildContext context, UserMgmtLoaded state) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
          child: Row(
            children: [
              Text(
                '${state.users.length} user(s)',
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _showCreateDialog(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Admin'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: state.users.length,
            itemBuilder: (context, index) {
              final user = state.users[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: CircleAvatar(
                    backgroundColor: user.isSuperAdmin
                        ? AppTheme.warning.withValues(alpha: 0.2)
                        : AppTheme.primary.withValues(alpha: 0.2),
                    child: Icon(
                      user.isSuperAdmin
                          ? Icons.admin_panel_settings_rounded
                          : Icons.person_rounded,
                      color: user.isSuperAdmin
                          ? AppTheme.warning
                          : AppTheme.primaryLight,
                    ),
                  ),
                  title: Text(user.email,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: user.isSuperAdmin
                              ? AppTheme.warning.withValues(alpha: 0.15)
                              : AppTheme.accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          user.isSuperAdmin ? 'Super Admin' : 'Panchayat Admin',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: user.isSuperAdmin
                                ? AppTheme.warning
                                : AppTheme.accent,
                          ),
                        ),
                      ),
                      if (user.panchayatName != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          user.panchayatName!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                  trailing: user.isSuperAdmin
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: AppTheme.error),
                          onPressed: () =>
                              _showDeleteDialog(context, user.id, user.email),
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
    final emailC = TextEditingController();
    final passC = TextEditingController();
    int? selectedPanchayatId;
    final formKey = GlobalKey<FormState>();

    // Get panchayats list from the panchayat bloc
    final panchayatState = context.read<PanchayatBloc>().state;
    final panchayats =
        panchayatState is PanchayatLoaded ? panchayatState.panchayats : [];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Create Panchayat Admin'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: emailC,
                    decoration: const InputDecoration(labelText: 'Email *'),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      if (!v.contains('@')) return 'Invalid email';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: passC,
                    decoration: const InputDecoration(labelText: 'Password *'),
                    obscureText: true,
                    validator: (v) {
                      if (v == null || v.length < 8) {
                        return 'Min 8 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    value: selectedPanchayatId,
                    decoration: const InputDecoration(labelText: 'Panchayat *'),
                    items: panchayats
                        .map((p) => DropdownMenuItem<int>(
                              value: p.id as int,
                              child: Text(p.name as String),
                            ))
                        .toList()
                        .cast<DropdownMenuItem<int>>(),
                    onChanged: (v) {
                      setDialogState(() => selectedPanchayatId = v);
                    },
                    validator: (v) => v == null ? 'Required' : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate() &&
                    selectedPanchayatId != null) {
                  context.read<UserMgmtBloc>().add(CreateUser({
                        'email': emailC.text.trim(),
                        'password': passC.text,
                        'panchayat_id': selectedPanchayatId,
                      }));
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, int id, String email) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete User'),
        content: Text('Delete admin "$email"? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () {
              context.read<UserMgmtBloc>().add(DeleteUser(id));
              Navigator.pop(ctx);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
