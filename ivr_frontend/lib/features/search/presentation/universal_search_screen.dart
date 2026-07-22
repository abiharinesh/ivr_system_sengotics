import 'package:flutter/material.dart';
import '../../../../config/app_theme.dart';
import '../../../../core/api/api_client.dart';

/// Phase 9: Universal Search screen — searches across all entities
class UniversalSearchScreen extends StatefulWidget {
  final String initialQuery;
  const UniversalSearchScreen({super.key, this.initialQuery = ''});

  @override
  State<UniversalSearchScreen> createState() => _UniversalSearchScreenState();
}

class _UniversalSearchScreenState extends State<UniversalSearchScreen> {
  final _ctrl = TextEditingController();
  Map<String, List<dynamic>>? _results;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery.isNotEmpty) {
      _ctrl.text = widget.initialQuery;
      _search(widget.initialQuery);
    }
  }

  Future<void> _search(String q) async {
    if (q.trim().isEmpty) {
      setState(() { _results = null; });
      return;
    }
    setState(() { _isLoading = true; _error = null; });
    try {
      final res = await ApiClient.instance.get('/api/search/universal', queryParams: {'q': q.trim()});
      final map = res is Map ? res : {};
      setState(() {
        _results = {
          'Complaints': List<dynamic>.from(map['complaints'] ?? []),
          'Assets': List<dynamic>.from(map['assets'] ?? []),
          'Tenders': List<dynamic>.from(map['tenders'] ?? []),
          'Work Orders': List<dynamic>.from(map['workOrders'] ?? []),
          'Contractors': List<dynamic>.from(map['contractors'] ?? []),
        };
      });
    } catch (e) {
      setState(() { _error = e.toString(); });
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  int get _totalCount => _results?.values.fold<int>(0, (sum, list) => sum + list.length) ?? 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        backgroundColor: AppTheme.bgCard,
        title: TextField(
          controller: _ctrl,
          autofocus: true,
          style: TextStyle(color: AppTheme.textPrimary, fontSize: 15),
          decoration: InputDecoration(
            hintText: 'Search complaints, assets, tenders...',
            hintStyle: TextStyle(color: AppTheme.textMuted),
            border: InputBorder.none,
          ),
          onSubmitted: _search,
          onChanged: (v) {
            if (v.isEmpty) setState(() { _results = null; });
          },
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.search, color: AppTheme.primary),
            onPressed: () => _search(_ctrl.text),
          ),
          if (_ctrl.text.isNotEmpty)
            IconButton(
              icon: Icon(Icons.clear, color: AppTheme.textMuted),
              onPressed: () {
                _ctrl.clear();
                setState(() { _results = null; });
              },
            ),
        ],
        iconTheme: IconThemeData(color: AppTheme.textPrimary),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: TextStyle(color: Colors.red)))
              : _results == null
                  ? _buildHint()
                  : _totalCount == 0
                      ? _buildEmpty()
                      : _buildResults(),
    );
  }

  Widget _buildHint() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.manage_search_rounded, size: 64, color: AppTheme.textMuted),
        const SizedBox(height: 16),
        Text('Type to search across all modules.', style: TextStyle(color: AppTheme.textMuted, fontSize: 14)),
      ],
    ),
  );

  Widget _buildEmpty() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.search_off_rounded, size: 64, color: AppTheme.textMuted),
        const SizedBox(height: 16),
        Text('No results found for "${_ctrl.text}".', style: TextStyle(color: AppTheme.textMuted, fontSize: 14)),
      ],
    ),
  );

  Widget _buildResults() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('$_totalCount result(s) for "${_ctrl.text}"',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
        const SizedBox(height: 16),
        for (final entry in _results!.entries)
          if (entry.value.isNotEmpty)
            _SearchSection(title: entry.key, items: entry.value),
      ],
    );
  }
}

class _SearchSection extends StatelessWidget {
  final String title;
  final List<dynamic> items;
  const _SearchSection({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    final icons = {
      'Complaints': Icons.report_problem_outlined,
      'Assets': Icons.inventory_2_outlined,
      'Tenders': Icons.gavel_outlined,
      'Work Orders': Icons.receipt_long_outlined,
      'Contractors': Icons.engineering_outlined,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icons[title] ?? Icons.folder_outlined, size: 16, color: AppTheme.primary),
            const SizedBox(width: 6),
            Text(title,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.primary,
                    letterSpacing: 0.5)),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('${items.length}', style: TextStyle(fontSize: 10, color: AppTheme.primary, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...items.map((item) => _SearchResultTile(item: item as Map<String, dynamic>)),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  final Map<String, dynamic> item;
  const _SearchResultTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final id = item['id'];
    final name = item['name'] ?? item['title_en'] ?? item['description'] ?? item['work_order_number'] ?? item['complaint_type'] ?? '—';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: AppTheme.stroke),
      ),
      child: ListTile(
        leading: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppTheme.bgSurface,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text('#$id', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textMuted)),
        ),
        title: Text(name.toString(), style: TextStyle(fontSize: 13, color: AppTheme.textPrimary, fontWeight: FontWeight.w500)),
        subtitle: item['status'] != null
            ? Text(item['status'].toString(), style: TextStyle(fontSize: 11, color: AppTheme.textMuted))
            : null,
        trailing: Icon(Icons.chevron_right, size: 18, color: AppTheme.textMuted),
      ),
    );
  }
}
