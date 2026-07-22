import 'package:flutter/material.dart';
import '../../../../config/app_theme.dart';

class BranchHierarchyTreeScreen extends StatefulWidget {
  const BranchHierarchyTreeScreen({super.key});

  @override
  State<BranchHierarchyTreeScreen> createState() => _BranchHierarchyTreeScreenState();
}

class _BranchHierarchyTreeScreenState extends State<BranchHierarchyTreeScreen> {
  String _selectedFilter = 'ALL';

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Administrative Branch Hierarchy Tree',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Visual multi-level hierarchy (State → District → Block/Corp → Village/Ward)',
                    style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                  ),
                ],
              ),
              Row(
                children: [
                  DropdownButton<String>(
                    value: _selectedFilter,
                    items: const [
                      DropdownMenuItem(value: 'ALL', child: Text('All Levels')),
                      DropdownMenuItem(value: 'DISTRICT', child: Text('District Panchayats')),
                      DropdownMenuItem(value: 'UNION', child: Text('Panchayat Unions')),
                      DropdownMenuItem(value: 'VILLAGE', child: Text('Village Panchayats')),
                    ],
                    onChanged: (v) => setState(() => _selectedFilter = v!),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add Branch Node'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  _buildTreeNode(
                    title: 'Level 1: State Administration — Tamil Nadu Government',
                    subtitle: 'State Capital HQ • Code: TN-STATE-01',
                    type: 'STATE',
                    isRoot: true,
                    children: [
                      _buildTreeNode(
                        title: 'Level 2: Madurai District Panchayat',
                        subtitle: 'District HQ • 13 Blocks • Code: MDU-DIST-05',
                        type: 'DISTRICT_PANCHAYAT',
                        children: [
                          _buildTreeNode(
                            title: 'Level 3: Usilampatti Panchayat Union',
                            subtitle: 'Block Union • 54 Villages • Code: USL-BLK-12',
                            type: 'PANCHAYAT_UNION',
                            children: [
                              _buildTreeNode(
                                title: 'Level 4: Thirumangalam Village Panchayat',
                                subtitle: 'Village Body • Population 4,200 • Code: THM-VLG-01',
                                type: 'VILLAGE_PANCHAYAT',
                              ),
                              _buildTreeNode(
                                title: 'Level 4: Doddappanaickanur Village Panchayat',
                                subtitle: 'Village Body • Population 2,890 • Code: DDP-VLG-02',
                                type: 'VILLAGE_PANCHAYAT',
                              ),
                            ],
                          ),
                          _buildTreeNode(
                            title: 'Level 3: Vadipatti Block Union',
                            subtitle: 'Block Union • 38 Villages • Code: VDP-BLK-14',
                            type: 'PANCHAYAT_UNION',
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTreeNode({
    required String title,
    required String subtitle,
    required String type,
    bool isRoot = false,
    List<Widget> children = const [],
  }) {
    return Container(
      margin: const EdgeInsets.only(left: 16, top: 12),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: AppTheme.primary.withValues(alpha: 0.3), width: 2)),
      ),
      padding: const EdgeInsets.only(left: 16),
      child: ExpansionTile(
        initiallyExpanded: true,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isRoot ? AppTheme.primary : AppTheme.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isRoot ? Icons.account_balance_rounded : Icons.location_city_rounded,
            color: isRoot ? Colors.white : AppTheme.primary,
            size: 20,
          ),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        trailing: Chip(
          label: Text(type),
          backgroundColor: Colors.blue.shade50,
          labelStyle: TextStyle(color: Colors.blue.shade800, fontSize: 11, fontWeight: FontWeight.bold),
        ),
        children: children,
      ),
    );
  }
}
