import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../config/app_theme.dart';
import '../../../core/models/user_model.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';

/// Lets a user holding more than one role/org-unit assignment pick which one
/// is active. Reads real assignments off the logged-in user's JWT
/// (`UserModel.roleAssignments`) and calls `POST /api/auth/switch-context`
/// to re-scope the session — no mock data.
class ContextSelectorScreen extends StatefulWidget {
  const ContextSelectorScreen({super.key});

  @override
  State<ContextSelectorScreen> createState() => _ContextSelectorScreenState();
}

class _ContextSelectorScreenState extends State<ContextSelectorScreen> {
  int? _selectedRoleId;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is Authenticated) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Switched context successfully')),
          );
          context.go('/dashboard');
        } else if (state is AuthError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not switch context: ${state.message}')),
          );
        }
      },
      builder: (context, state) {
        final user = state is Authenticated ? state.user : null;
        final assignments = user?.roleAssignments ?? const <UserRoleAssignment>[];
        _selectedRoleId ??= assignments.isNotEmpty ? assignments.first.id : null;

        return Scaffold(
          backgroundColor: AppTheme.bgDark,
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 580),
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: AppTheme.softShadow,
                  border: Border.all(color: AppTheme.stroke),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.swap_horizontal_circle_rounded,
                            color: AppTheme.primary,
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Switch Administrative Context',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Select which role/org-unit assignment should be active.',
                              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    const Text(
                      'Your Role Assignments:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                    if (assignments.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          'You only hold a single role assignment — there is nothing to switch between yet.',
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: assignments.length,
                        itemBuilder: (context, index) {
                          final assignment = assignments[index];
                          final isSel = _selectedRoleId == assignment.id;
                          return InkWell(
                            onTap: () => setState(() => _selectedRoleId = assignment.id),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isSel
                                    ? AppTheme.primary.withValues(alpha: 0.08)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSel ? AppTheme.primary : AppTheme.stroke,
                                  width: isSel ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Radio<int>(
                                    value: assignment.id,
                                    groupValue: _selectedRoleId,
                                    onChanged: (v) => setState(() => _selectedRoleId = v),
                                    activeColor: AppTheme.primary,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          assignment.roleName,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: isSel ? AppTheme.primary : AppTheme.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          assignment.orgUnitId != null
                                              ? 'Org unit #${assignment.orgUnitId}'
                                              : 'Tenant-wide',
                                          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: (state is AuthLoading || _selectedRoleId == null)
                            ? null
                            : () => context
                                .read<AuthBloc>()
                                .add(SwitchContextRequested(_selectedRoleId!)),
                        child: state is AuthLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Confirm Active Context & Continue'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
