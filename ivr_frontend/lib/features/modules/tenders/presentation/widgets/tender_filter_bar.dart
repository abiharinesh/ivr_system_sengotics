import 'package:flutter/material.dart';

class TenderFilterBar extends StatelessWidget {
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;

  final String? statusFilter;
  final ValueChanged<String?> onStatusChanged;

  final int? panchayatFilter;
  final ValueChanged<int?>? onPanchayatChanged;
  final List<dynamic>? panchayats; // list of panchayats if super admin

  final bool isGridView;
  final VoidCallback onViewToggle;

  const TenderFilterBar({
    super.key,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.statusFilter,
    required this.onStatusChanged,
    this.panchayatFilter,
    this.onPanchayatChanged,
    this.panchayats,
    required this.isGridView,
    required this.onViewToggle,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 720;

        final searchField = Expanded(
          flex: isNarrow ? 0 : 2,
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFCBD5E1), width: 1),
            ),
            child: TextField(
              onChanged: onSearchChanged,
              controller: TextEditingController(text: searchQuery)
                ..selection = TextSelection.fromPosition(
                  TextPosition(offset: searchQuery.length),
                ),
              decoration: const InputDecoration(
                hintText: 'Search tenders by title or ID...',
                hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                prefixIcon: Icon(
                  Icons.search,
                  color: Color(0xFF64748B),
                  size: 18,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 9),
              ),
              style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
            ),
          ),
        );

        final filtersRow = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Status filter dropdown
            Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFCBD5E1), width: 1),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  value: statusFilter,
                  icon: const Icon(
                    Icons.filter_list_outlined,
                    size: 16,
                    color: Color(0xFF64748B),
                  ),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF0F172A),
                    fontWeight: FontWeight.w600,
                  ),
                  hint: const Text('All Statuses'),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('All Statuses')),
                    DropdownMenuItem(value: 'draft', child: Text('Draft')),
                    DropdownMenuItem(
                      value: 'published',
                      child: Text('Active / Published'),
                    ),
                    DropdownMenuItem(
                      value: 'quotations_closed',
                      child: Text('Bids Closed'),
                    ),
                    DropdownMenuItem(
                      value: 'vendor_selected',
                      child: Text('L1 Selected'),
                    ),
                    DropdownMenuItem(
                      value: 'field_verification',
                      child: Text('Inspection'),
                    ),
                    DropdownMenuItem(value: 'closed', child: Text('Closed')),
                  ],
                  onChanged: onStatusChanged,
                ),
              ),
            ),
            if (onPanchayatChanged != null && panchayats != null) ...[
              const SizedBox(width: 8),
              // Panchayat filter dropdown
              Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFCBD5E1), width: 1),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int?>(
                    value: panchayatFilter,
                    icon: const Icon(
                      Icons.location_on_outlined,
                      size: 16,
                      color: Color(0xFF64748B),
                    ),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF0F172A),
                      fontWeight: FontWeight.w600,
                    ),
                    hint: const Text('All Panchayats'),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('All Panchayats'),
                      ),
                      ...panchayats!.map(
                        (p) => DropdownMenuItem(
                          value: p.id as int,
                          child: Text(p.name as String),
                        ),
                      ),
                    ],
                    onChanged: onPanchayatChanged,
                  ),
                ),
              ),
            ],
            const SizedBox(width: 8),
            // Grid/List View Toggle Button
            Container(
              height: 40,
              width: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFCBD5E1), width: 1),
              ),
              child: IconButton(
                tooltip:
                    isGridView ? 'Switch to List View' : 'Switch to Grid View',
                icon: Icon(
                  isGridView ? Icons.format_list_bulleted : Icons.grid_view,
                  size: 18,
                  color: const Color(0xFF0F766E),
                ),
                onPressed: onViewToggle,
              ),
            ),
          ],
        );

        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [searchField]),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [filtersRow],
              ),
            ],
          );
        } else {
          return Row(
            children: [searchField, const SizedBox(width: 12), filtersRow],
          );
        }
      },
    );
  }
}
