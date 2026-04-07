import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../config/app_theme.dart';
import '../data/electrician_repository.dart';

class ElectricianJobsScreen extends StatefulWidget {
  const ElectricianJobsScreen({super.key});

  @override
  State<ElectricianJobsScreen> createState() => _ElectricianJobsScreenState();
}

class _ElectricianJobsScreenState extends State<ElectricianJobsScreen> {
  final _repo = ElectricianRepository();
  List<dynamic> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _repo.listComplaints();
      setState(() {
        _items = list;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text(
                'My complaints',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
              ),
              const Spacer(),
              IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
            ],
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(_error!, style: TextStyle(color: Colors.red.shade800)),
            ),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(
              child: ListView.separated(
                itemCount: _items.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final c = Map<String, dynamic>.from(_items[i] as Map);
                  final id = c['id'] as int;
                  final st = c['status']?.toString() ?? '';
                  final pole = c['pole'] as Map<String, dynamic>?;
                  final poleLabel = pole == null ? '—' : '#${pole['id']}';
                  return ListTile(
                    title: Text('Complaint #$id · Pole $poleLabel'),
                    subtitle: Text(st),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/electrician/jobs/$id'),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
