import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ivr_frontend/config/app_theme.dart';

/// What the operator filled in. The caller does the creating.
class NewRoleDraft {
  const NewRoleDraft({
    required this.name,
    required this.displayName,
    this.displayNameTa,
    this.department,
    this.hierarchyLevel,
    this.canApprove = false,
  });

  final String name;
  final String displayName;
  final String? displayNameTa;
  final String? department;
  final int? hierarchyLevel;
  final bool canApprove;
}

/// Define a designation this council needs and the shipped roster does not
/// have.
///
/// Until this existed the only way to get a role was to clone one: a council
/// could copy a shipped designation but never define its own, so every job
/// title outside the six seeded body types had to come back to the platform
/// operator.
///
/// The rules live on the server — a name that collides with a shipped role,
/// level 0, an empty display name — and are surfaced here as the messages it
/// returns. Restating them in the dialog would give two answers that drift.
class CreateRoleDialog extends StatefulWidget {
  const CreateRoleDialog({super.key, this.onSubmit});

  /// Creates the role and returns null, or an error message to show in place.
  /// Injected by tests; the console passes its repository call.
  final Future<String?> Function(NewRoleDraft draft)? onSubmit;

  @override
  State<CreateRoleDialog> createState() => _CreateRoleDialogState();
}

class _CreateRoleDialogState extends State<CreateRoleDialog> {
  final _form = GlobalKey<FormState>();
  final _display = TextEditingController();
  final _name = TextEditingController();
  final _displayTa = TextEditingController();
  final _department = TextEditingController();

  int _level = 5;
  bool _canApprove = false;
  bool _saving = false;
  String? _error;

  /// True once the operator edits the identifier by hand, after which it stops
  /// following the display name — retyping over someone's deliberate choice is
  /// worse than leaving it slightly out of step.
  bool _nameEditedByHand = false;

  @override
  void initState() {
    super.initState();
    _display.addListener(_suggestName);
  }

  @override
  void dispose() {
    _display.removeListener(_suggestName);
    _display.dispose();
    _name.dispose();
    _displayTa.dispose();
    _department.dispose();
    super.dispose();
  }

  /// `Ward Committee Secretary` → `ward_committee_secretary`.
  void _suggestName() {
    if (_nameEditedByHand) return;
    final slug = _display.text
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    if (slug != _name.text) _name.text = slug;
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    final draft = NewRoleDraft(
      name: _name.text,
      displayName: _display.text,
      displayNameTa: _displayTa.text,
      department: _department.text,
      hierarchyLevel: _level,
      canApprove: _canApprove,
    );

    final error = await widget.onSubmit?.call(draft);
    if (!mounted) return;

    if (error != null) {
      setState(() {
        _saving = false;
        _error = error;
      });
      return;
    }
    Navigator.of(context).pop(draft);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New role'),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _display,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Designation',
                    hintText: 'Ward Committee Secretary',
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Give the role a name people will recognise'
                      : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _displayTa,
                  decoration: const InputDecoration(
                    labelText: 'Designation in Tamil',
                    hintText: 'வார்டு குழு செயலாளர்',
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _name,
                  onChanged: (_) => _nameEditedByHand = true,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[a-z0-9_]')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Identifier',
                    helperText: 'Used in the API. Lowercase, no spaces.',
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'An identifier is required'
                      : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _department,
                  decoration: const InputDecoration(
                    labelText: 'Department',
                    hintText: 'General Administration',
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'SENIORITY',
                  style: TextStyle(
                    fontSize: 10.5,
                    letterSpacing: 0.6,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Level $_level — 1 is the head of the body, 10 is the field.',
                  style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                ),
                Slider(
                  value: _level.toDouble(),
                  // Level 0 is the platform operator's rung and is not offered:
                  // a council granting it to itself would leave its own tenant.
                  min: 1,
                  max: 10,
                  divisions: 9,
                  label: '$_level',
                  onChanged: (v) => setState(() => _level = v.round()),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _canApprove,
                  onChanged: (v) => setState(() => _canApprove = v),
                  title: const Text('Can approve'),
                  subtitle: const Text(
                    'May sign off applications other people submit',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded,
                          size: 16, color: AppTheme.primary),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          'The role starts with no access at all. Tick the '
                          'screens and permissions it needs once it exists.',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.35,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: AppTheme.error.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                        color: AppTheme.error.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            size: 16, color: AppTheme.error),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            _error!,
                            style: const TextStyle(
                                fontSize: 12, height: 1.35, color: AppTheme.error),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create role'),
        ),
      ],
    );
  }
}
