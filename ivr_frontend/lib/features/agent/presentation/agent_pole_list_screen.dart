import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/agent_repository.dart';

class AgentPoleListScreen extends StatefulWidget {
  const AgentPoleListScreen({super.key});

  @override
  State<AgentPoleListScreen> createState() => _AgentPoleListScreenState();
}

class _AgentPoleListScreenState extends State<AgentPoleListScreen> {
  final _repo = AgentRepository();
  final _search = TextEditingController();
  List<dynamic> _poles = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _repo.listPoles(
        search: _search.text.trim().isEmpty ? null : _search.text.trim(),
      );
      setState(() {
        _poles = list;
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
              Expanded(
                child: TextField(
                  controller: _search,
                  decoration: const InputDecoration(
                    hintText: 'Search pole / keypad',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _load(),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Search'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_error != null)
            Material(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_error!, style: TextStyle(color: Colors.red.shade900)),
              ),
            ),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(
              child: ListView.separated(
                itemCount: _poles.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final p = Map<String, dynamic>.from(_poles[i] as Map);
                  final id = p['id'] as int;
                  final num = p['pole_number']?.toString() ?? '—';
                  final key = p['keypad_id']?.toString() ?? '—';
                  final hasImg = (p['image_url'] as String?)?.isNotEmpty ?? false;
                  return ListTile(
                    title: Text('Pole #$id'),
                    subtitle: Text('No. $num · Keypad $key${hasImg ? ' · Photo ✓' : ''}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/agent/poles/$id'),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
