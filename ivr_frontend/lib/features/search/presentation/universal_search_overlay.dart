import 'package:flutter/material.dart';
import '../../../config/app_theme.dart';

class UniversalSearchOverlay extends StatefulWidget {
  const UniversalSearchOverlay({super.key});

  @override
  State<UniversalSearchOverlay> createState() => _UniversalSearchOverlayState();
}

class _UniversalSearchOverlayState extends State<UniversalSearchOverlay> {
  final _searchController = TextEditingController();

  final List<Map<String, String>> _results = [
    {'title': 'CMP-2026-000042 — Electrical Fault', 'type': 'Complaint', 'loc': 'Ward 14'},
    {'title': 'SL-MDU-Z3-042 — Smart LED Pole', 'type': 'Asset', 'loc': 'Madurai Corp'},
    {'title': 'WO-2026-000012 — Road Resurfacing Work Order', 'type': 'Work Order', 'loc': 'Usilampatti'},
  ];

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 650,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Type to search across assets, complaints, work orders, documents... (Ctrl+K)',
                prefixIcon: Icon(Icons.search_rounded, color: AppTheme.primary),
                suffixIcon: IconButton(icon: const Icon(Icons.clear_rounded), onPressed: () => Navigator.pop(context)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 16),
            Text('PostgreSQL Full-Text Search Instant Results', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textSecondary)),
            const SizedBox(height: 12),
            ListView.separated(
              shrinkWrap: true,
              itemCount: _results.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (context, index) {
                final item = _results[index];
                return ListTile(
                  title: Text(item['title']!, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${item['type']} • ${item['loc']}'),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                  onTap: () => Navigator.pop(context),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
