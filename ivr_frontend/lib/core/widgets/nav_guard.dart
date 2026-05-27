import 'package:flutter/material.dart';

/// Lightweight, app-wide "unsaved changes" registry.
///
/// Screens that have in-progress edits register a callback returning `true`
/// when there is unsaved work. When the user attempts to navigate away from
/// the screen via the sidebar, [confirmLeave] shows a confirmation prompt and
/// only returns `true` if all registered checks resolve.
///
/// Usage:
/// ```dart
/// late final _guardToken = NavGuard.instance.register(() => _hasUnsavedChanges);
/// @override
/// void dispose() {
///   NavGuard.instance.unregister(_guardToken);
///   super.dispose();
/// }
/// ```
class NavGuard {
  NavGuard._();
  static final NavGuard instance = NavGuard._();

  final List<bool Function()> _checks = [];

  /// Register a function that returns `true` while the screen has unsaved work.
  /// Returns the same function so it can be passed to [unregister].
  bool Function() register(bool Function() isDirty) {
    _checks.add(isDirty);
    return isDirty;
  }

  void unregister(bool Function() token) {
    _checks.remove(token);
  }

  bool get hasUnsaved => _checks.any((f) {
        try {
          return f();
        } catch (_) {
          return false;
        }
      });

  /// Prompt the user to confirm leaving when there is unsaved work.
  /// Returns `true` when it is safe to navigate.
  Future<bool> confirmLeave(BuildContext context) async {
    if (!hasUnsaved) return true;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave this screen?'),
        content: const Text(
          'You have unsaved changes. If you leave now, your edits will be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Stay'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Leave anyway'),
          ),
        ],
      ),
    );
    return result == true;
  }
}

/// Mixin that wires a `State` into [NavGuard] automatically.
/// The screen overrides [hasUnsavedChanges] to indicate whether there is
/// unsaved work pending.
mixin NavGuardMixin<T extends StatefulWidget> on State<T> {
  bool Function()? _guardToken;

  bool get hasUnsavedChanges;

  @override
  void initState() {
    super.initState();
    _guardToken = NavGuard.instance.register(() => mounted && hasUnsavedChanges);
  }

  @override
  void dispose() {
    if (_guardToken != null) {
      NavGuard.instance.unregister(_guardToken!);
      _guardToken = null;
    }
    super.dispose();
  }
}
