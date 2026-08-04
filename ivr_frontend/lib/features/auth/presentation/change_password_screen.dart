import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:ivr_frontend/config/app_theme.dart';
import 'package:ivr_frontend/features/auth/bloc/auth_bloc.dart';
import 'package:ivr_frontend/features/auth/bloc/auth_event.dart';
import 'package:ivr_frontend/features/auth/bloc/auth_state.dart';
import 'package:ivr_frontend/features/auth/data/auth_repository.dart';
import 'package:ivr_frontend/features/auth/presentation/widgets/auth_shell.dart';

/// Set a new password.
///
/// Reached two ways: forced, when the account is still on the password it was
/// issued, and voluntarily from the profile menu. Accounts are provisioned
/// with a random temporary password and `must_change_password = true`; until
/// this screen existed there was no way to satisfy that flag, so every
/// provisioned account stayed on a password somebody else had seen.
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key, this.forced = false});

  /// Forced entry hides the escape routes: the router will send the user
  /// straight back here, so offering "cancel" would be a lie.
  final bool forced;

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  final _repo = AuthRepository();

  bool _obscureCurrent = true;
  bool _obscureNext = true;

  PasswordVerdict _verdict = PasswordVerdict.empty;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _next.addListener(_onNextChanged);
    // Fetch the rules up front so they are on screen before the first
    // keystroke rather than appearing as the user is refused.
    _grade('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _next.removeListener(_onNextChanged);
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _onNextChanged() {
    // The meter reads the server's own policy rather than reimplementing it,
    // so the form can never accept something the API would refuse. Debounced
    // because it is a request per keystroke otherwise.
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _grade(_next.text);
    });
  }

  Future<void> _grade(String candidate) async {
    try {
      final v = await _repo.gradePassword(candidate);
      if (!mounted) return;
      setState(() => _verdict = v);
    } catch (_) {
      // A failed grade must not block typing; submit is still validated
      // server-side.
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    context.read<AuthBloc>().add(
          PasswordChangeRequested(
            currentPassword: _current.text,
            newPassword: _next.text,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is PasswordChanged) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppTheme.accent,
              content: const Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 10),
                  Expanded(child: Text('Password updated.')),
                ],
              ),
            ),
          );
          context.go('/dashboard');
        } else if (state is AuthError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppTheme.error,
              content: Row(
                children: [
                  const Icon(Icons.error_outline_rounded,
                      color: Colors.white, size: 18),
                  const SizedBox(width: 10),
                  Expanded(child: Text(state.message)),
                ],
              ),
            ),
          );
        }
      },
      child: AuthShell(
        asideTitle: widget.forced ? 'One step first' : 'Account security',
        asideBody: widget.forced
            ? 'This account is still using the password it was issued. Set one '
                'only you know before going any further.'
            : 'Choose a new password for your account.',
        asideIcon: Icons.lock_reset_rounded,
        child: _form(),
      ),
    );
  }

  Widget _form() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.forced ? 'Set your password' : 'Change your password',
            style: TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            widget.forced
                ? 'The password you were given is known to whoever issued it. '
                    'Replace it to continue.'
                : 'You will stay signed in on this device.',
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          _field(
            controller: _current,
            label: widget.forced ? 'Password you were issued' : 'Current password',
            icon: Icons.lock_outline_rounded,
            obscure: _obscureCurrent,
            onToggle: () => setState(() => _obscureCurrent = !_obscureCurrent),
            validator: (v) =>
                (v == null || v.isEmpty) ? 'Enter your current password' : null,
          ),
          const SizedBox(height: 16),
          _field(
            controller: _next,
            label: 'New password',
            icon: Icons.lock_reset_rounded,
            obscure: _obscureNext,
            onToggle: () => setState(() => _obscureNext = !_obscureNext),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Choose a new password';
              if (v.length < _verdict.minLength) {
                return 'Use at least ${_verdict.minLength} characters';
              }
              if (_verdict.problems.isNotEmpty) return _verdict.problems.first;
              return null;
            },
          ),
          const SizedBox(height: 12),
          _strength(),
          const SizedBox(height: 16),
          _field(
            controller: _confirm,
            label: 'Confirm new password',
            icon: Icons.check_circle_outline_rounded,
            obscure: _obscureNext,
            onToggle: () => setState(() => _obscureNext = !_obscureNext),
            validator: (v) =>
                v != _next.text ? 'The two passwords do not match' : null,
          ),
          const SizedBox(height: 24),
          BlocBuilder<AuthBloc, AuthState>(
            builder: (context, state) {
              final busy = state is AuthLoading;
              return SizedBox(
                height: 50,
                child: FilledButton(
                  onPressed: busy ? null : _submit,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          widget.forced ? 'Set password and continue' : 'Update password',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              );
            },
          ),
          if (!widget.forced) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => context.go('/dashboard'),
              child: const Text('Cancel'),
            ),
          ] else ...[
            const SizedBox(height: 14),
            Center(
              child: TextButton.icon(
                onPressed: () =>
                    context.read<AuthBloc>().add(LogoutRequested()),
                icon: const Icon(Icons.logout_rounded, size: 16),
                label: const Text('Sign out instead'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool obscure,
    required VoidCallback onToggle,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      autofillHints: const [AutofillHints.password],
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppTheme.textMuted, size: 20),
        suffixIcon: IconButton(
          tooltip: obscure ? 'Show' : 'Hide',
          icon: Icon(
            obscure
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            color: AppTheme.textMuted,
            size: 20,
          ),
          onPressed: onToggle,
        ),
      ),
      validator: validator,
    );
  }

  /// Strength bar plus the outstanding rules.
  ///
  /// Every failing rule is listed at once rather than one at a time, so the
  /// user can fix them in a single pass instead of being refused repeatedly.
  Widget _strength() {
    final typed = _next.text.isNotEmpty;
    final score = typed ? _verdict.score : 0;
    final color = switch (score) {
      0 => AppTheme.error,
      1 => AppTheme.error,
      2 => AppTheme.warning,
      3 => AppTheme.accent,
      _ => AppTheme.accent,
    };

    final outstanding =
        typed ? _verdict.problems : _verdict.requirements;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (var i = 0; i < 4; i++) ...[
              Expanded(
                child: AnimatedContainer(
                  duration: AppTheme.durationFast,
                  height: 4,
                  decoration: BoxDecoration(
                    color: typed && i < score ? color : AppTheme.bgElevated,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              if (i < 3) const SizedBox(width: 4),
            ],
            const SizedBox(width: 10),
            SizedBox(
              width: 76,
              child: Text(
                typed ? _verdict.label : '',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
          ],
        ),
        if (outstanding.isNotEmpty) ...[
          const SizedBox(height: 10),
          for (final line in outstanding)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    typed
                        ? Icons.close_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 13,
                    color: typed ? AppTheme.error : AppTheme.textMuted,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      line,
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.35,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ] else if (typed) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.check_circle_rounded, size: 14, color: AppTheme.accent),
              const SizedBox(width: 7),
              Text(
                'This password meets every requirement.',
                style: TextStyle(fontSize: 11.5, color: AppTheme.accent),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
