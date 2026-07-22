import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../config/app_theme.dart';

class ContextSelectorScreen extends StatefulWidget {
  const ContextSelectorScreen({super.key});

  @override
  State<ContextSelectorScreen> createState() => _ContextSelectorScreenState();
}

class _ContextSelectorScreenState extends State<ContextSelectorScreen> {
  int _selectedContextIndex = 0;

  final List<Map<String, String>> _contexts = [
    {
      'role': 'Block Development Officer (BDO)',
      'tenant': 'Tamil Nadu e-Governance Administration',
      'branch': 'Usilampatti Panchayat Union (USL-BLK-12)',
      'scope': 'Level 3 — Panchayat Union Scope',
    },
    {
      'role': 'District Nodal Officer',
      'tenant': 'Madurai City Municipal Corporation',
      'branch': 'Madurai Collectorate HQ (MDU-DIST-05)',
      'scope': 'Level 2 — District Wide Scope',
    },
  ];

  @override
  Widget build(BuildContext context) {
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
                          'Select tenant, branch posting, and active RBAC role context.',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                const Text(
                  'Empanelled Active Roles & Branch Allocations:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 12),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _contexts.length,
                  itemBuilder: (context, index) {
                    final ctx = _contexts[index];
                    final isSel = _selectedContextIndex == index;
                    return InkWell(
                      onTap: () => setState(() => _selectedContextIndex = index),
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
                              value: index,
                              groupValue: _selectedContextIndex,
                              onChanged: (v) => setState(
                                  () => _selectedContextIndex = v ?? 0),
                              activeColor: AppTheme.primary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    ctx['role']!,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: isSel
                                          ? AppTheme.primary
                                          : AppTheme.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    ctx['branch']!,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${ctx['tenant']} • ${ctx['scope']}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.textMuted,
                                    ),
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
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Switched Administrative Context successfully!',
                          ),
                        ),
                      );
                      context.go('/dashboard');
                    },
                    child: const Text('Confirm Active Context & Continue'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
