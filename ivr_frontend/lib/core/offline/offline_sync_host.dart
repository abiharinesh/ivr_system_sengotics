import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';

import '../../features/agent/data/agent_repository.dart';
import '../../features/electrician/data/electrician_repository.dart';
import 'field_outbox.dart';

/// Replays queued field jobs when the app resumes or network is restored.
class OfflineSyncHost extends StatefulWidget {
  const OfflineSyncHost({super.key, required this.child});

  final Widget? child;

  @override
  State<OfflineSyncHost> createState() => _OfflineSyncHostState();
}

class _OfflineSyncHostState extends State<OfflineSyncHost>
    with WidgetsBindingObserver {
  final _agent = AgentRepository();
  final _electrician = ElectricianRepository();
  StreamSubscription<List<ConnectivityResult>>? _connSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _connSub = Connectivity().onConnectivityChanged.listen((_) => _syncIfOnline());
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncIfOnline());
  }

  @override
  void dispose() {
    _connSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncIfOnline();
    }
  }

  Future<void> _syncIfOnline() async {
    final r = await Connectivity().checkConnectivity();
    if (r.contains(ConnectivityResult.none)) return;
    await FieldOutbox.syncAll(agentRepo: _agent, electricianRepo: _electrician);
  }

  @override
  Widget build(BuildContext context) => widget.child ?? const SizedBox.shrink();
}
