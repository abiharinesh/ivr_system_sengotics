import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

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
  StreamSubscription<BoxEvent>? _boxSub;
  int _pendingCount = 0;
  bool _isOnline = true;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Check initial state
    _updateState();

    // Listen to network changes
    _connSub = Connectivity().onConnectivityChanged.listen((results) {
      setState(() {
        _isOnline = !results.contains(ConnectivityResult.none);
      });
      if (_isOnline) {
        _syncIfOnline();
      }
    });

    // Listen to outbox changes reactive stream
    try {
      _boxSub = Hive.box(FieldOutbox.boxName).watch().listen((_) {
        _updateState();
      });
    } catch (_) {}

    WidgetsBinding.instance.addPostFrameCallback((_) => _syncIfOnline());
  }

  void _updateState() {
    if (mounted) {
      setState(() {
        _pendingCount = FieldOutbox.pendingCount;
      });
    }
  }

  @override
  void dispose() {
    _connSub?.cancel();
    _boxSub?.cancel();
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
    final online = !r.contains(ConnectivityResult.none);
    if (mounted) {
      setState(() {
        _isOnline = online;
      });
    }
    if (!online) return;
    if (_isSyncing) return;

    if (FieldOutbox.pendingCount > 0) {
      if (mounted) {
        setState(() {
          _isSyncing = true;
        });
      }
      try {
        await FieldOutbox.syncAll(agentRepo: _agent, electricianRepo: _electrician);
      } catch (_) {
      } finally {
        if (mounted) {
          setState(() {
            _isSyncing = false;
          });
          _updateState();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mainChild = widget.child ?? const SizedBox.shrink();
    
    // Only show sync status overlay if offline OR if we have pending items to sync
    final showIndicator = !_isOnline || _pendingCount > 0 || _isSyncing;

    if (!showIndicator) {
      return mainChild;
    }

    return Stack(
      children: [
        mainChild,
        Positioned(
          bottom: 16,
          right: 16,
          child: SafeArea(
            child: Material(
              color: Colors.transparent,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B).withValues(alpha: 0.95), // dark slate
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: !_isOnline 
                        ? Colors.red.withValues(alpha: 0.4) 
                        : (_isSyncing ? Colors.blue.withValues(alpha: 0.4) : Colors.green.withValues(alpha: 0.4)),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!_isOnline) ...[
                      const Icon(Icons.cloud_off_rounded, color: Colors.redAccent, size: 16),
                      const SizedBox(width: 8),
                      const Text(
                        'Offline Mode',
                        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ] else if (_isSyncing) ...[
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.blueAccent,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Syncing data...',
                        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ] else ...[
                      const Icon(Icons.cloud_done_rounded, color: Colors.greenAccent, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Online • Connected',
                        style: TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                    if (_pendingCount > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$_pendingCount queued',
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
