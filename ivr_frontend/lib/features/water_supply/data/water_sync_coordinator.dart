import 'package:flutter/foundation.dart';
import 'water_repository.dart';


class CapturedAsset {
  final int id;
  final String type; // 'household_tap', 'public_tap', 'main_pipeline'
  final String material; // 'PVC', 'HDPE', 'Cast Iron'
  final double diameter; // in mm
  final double latitude;
  final double longitude;
  final String? photoPath; // simulated file proof or network URL
  final String status; // 'pending_sync', 'pending_approval', 'approved', 'rejected'
  final String? comment;
  final String agentName;
  final DateTime submittedAt;
  final String? deviceModel;
  final double? altitude;
  final double? precision;

  CapturedAsset({
    required this.id,
    required this.type,
    required this.material,
    required this.diameter,
    required this.latitude,
    required this.longitude,
    this.photoPath,
    required this.status,
    this.comment,
    required this.agentName,
    required this.submittedAt,
    this.deviceModel,
    this.altitude,
    this.precision,
  });

  CapturedAsset copyWith({
    String? status,
    String? comment,
  }) {
    return CapturedAsset(
      id: id,
      type: type,
      material: material,
      diameter: diameter,
      latitude: latitude,
      longitude: longitude,
      photoPath: photoPath,
      status: status ?? this.status,
      comment: comment ?? this.comment,
      agentName: agentName,
      submittedAt: submittedAt,
      deviceModel: deviceModel,
      altitude: altitude,
      precision: precision,
    );
  }
}

class WaterSyncCoordinator extends ChangeNotifier {
  static final WaterSyncCoordinator _instance = WaterSyncCoordinator._internal();

  factory WaterSyncCoordinator() => _instance;

  WaterSyncCoordinator._internal() {
    _initSeedData();
    loadFromBackend();
  }

  final _repository = WaterRepository();


  final List<CapturedAsset> _assets = [];

  List<CapturedAsset> get assets => List.unmodifiable(_assets);

  List<CapturedAsset> get pendingSync =>
      _assets.where((a) => a.status == 'pending_sync').toList();

  List<CapturedAsset> get pendingApproval =>
      _assets.where((a) => a.status == 'pending_approval').toList();

  List<CapturedAsset> get approved =>
      _assets.where((a) => a.status == 'approved').toList();

  List<CapturedAsset> get rejected =>
      _assets.where((a) => a.status == 'rejected').toList();

  int get pendingApprovalCount => pendingApproval.length;
  int get approvedCount => approved.length;
  int get rejectedCount => rejected.length;
  int get pendingSyncCount => pendingSync.length;

  void _initSeedData() {
    final now = DateTime.now();
    _assets.addAll([
      CapturedAsset(
        id: 101,
        type: 'public_tap',
        material: 'PVC',
        diameter: 50.0,
        latitude: 11.2356,
        longitude: 77.1042,
        photoPath: 'https://images.unsplash.com/photo-1585338107529-13afc5f02586?w=600&auto=format&fit=crop&q=60',
        status: 'pending_approval',
        agentName: 'Ramanathan K.',
        submittedAt: now.subtract(const Duration(hours: 4)),
        deviceModel: 'Samsung Galaxy Tab Active 3',
        altitude: 12.4,
        precision: 0.4,
      ),
      CapturedAsset(
        id: 102,
        type: 'main_pipeline',
        material: 'HDPE',
        diameter: 110.0,
        latitude: 11.2389,
        longitude: 77.1085,
        photoPath: 'https://images.unsplash.com/photo-1542060748-10c28b629f6f?w=600&auto=format&fit=crop&q=60',
        status: 'pending_approval',
        agentName: 'Muthu Swamy',
        submittedAt: now.subtract(const Duration(hours: 8)),
        deviceModel: 'Nokia XR20 Rugged',
        altitude: 14.1,
        precision: 0.6,
      ),
      CapturedAsset(
        id: 103,
        type: 'household_tap',
        material: 'Cast Iron',
        diameter: 25.0,
        latitude: 11.2312,
        longitude: 77.0984,
        photoPath: 'https://images.unsplash.com/photo-1605647540924-852290f6b0d5?w=600&auto=format&fit=crop&q=60',
        status: 'approved',
        comment: 'Verified GPS location and installation specs. Clean install.',
        agentName: 'Ramanathan K.',
        submittedAt: now.subtract(const Duration(days: 1)),
        deviceModel: 'Samsung Galaxy Tab Active 3',
        altitude: 11.8,
        precision: 0.3,
      ),
      CapturedAsset(
        id: 104,
        type: 'public_tap',
        material: 'PVC',
        diameter: 32.0,
        latitude: 11.2401,
        longitude: 77.1120,
        photoPath: 'https://images.unsplash.com/photo-1504307651254-35680f356dfd?w=600&auto=format&fit=crop&q=60',
        status: 'rejected',
        comment: 'Photo does not show completed tap connection, only empty trench.',
        agentName: 'Muthu Swamy',
        submittedAt: now.subtract(const Duration(days: 2)),
        deviceModel: 'Nokia XR20 Rugged',
        altitude: 13.5,
        precision: 0.5,
      ),
    ]);
  }

  Future<void> loadFromBackend() async {
    try {
      final backendAssets = await _repository.getCapturedAssets();
      if (backendAssets.isNotEmpty) {
        _assets.clear();
        for (var item in backendAssets) {
          _assets.add(CapturedAsset(
            id: item['id'] as int,
            type: item['type'] as String,
            material: item['material'] as String,
            diameter: (item['diameter_mm'] as num).toDouble(),
            latitude: (item['latitude'] as num).toDouble(),
            longitude: (item['longitude'] as num).toDouble(),
            photoPath: item['photo_url'] as String?,
            status: item['status'] as String,
            comment: item['comment'] as String?,
            agentName: item['agent_name'] as String,
            submittedAt: DateTime.parse(item['submitted_at'] as String),
            deviceModel: item['device_model'] as String?,
            altitude: item['altitude'] != null ? (item['altitude'] as num).toDouble() : null,
            precision: item['precision'] != null ? (item['precision'] as num).toDouble() : null,
          ));
        }
        notifyListeners();
      }
    } catch (e) {
      // Keep seed data as fallback
    }
  }

  void captureAsset({
    required String type,
    required String material,
    required double diameter,
    required double latitude,
    required double longitude,
    String? photoPath,
    required String agentName,
    String? deviceModel,
    double? altitude,
    double? precision,
  }) {
    final newAsset = CapturedAsset(
      id: DateTime.now().millisecondsSinceEpoch,
      type: type,
      material: material,
      diameter: diameter,
      latitude: latitude,
      longitude: longitude,
      photoPath: photoPath ?? 'https://images.unsplash.com/photo-1585338107529-13afc5f02586?w=600&auto=format&fit=crop&q=60',
      status: 'pending_sync',
      agentName: agentName,
      submittedAt: DateTime.now(),
      deviceModel: deviceModel ?? 'Generic Mobile Device',
      altitude: altitude ?? 15.0,
      precision: precision ?? 0.8,
    );
    _assets.add(newAsset);
    notifyListeners();
  }

  Future<void> syncAssets() async {
    for (int i = 0; i < _assets.length; i++) {
      if (_assets[i].status == 'pending_sync') {
        try {
          final result = await _repository.submitCapturedAsset({
            'type': _assets[i].type,
            'material': _assets[i].material,
            'diameter_mm': _assets[i].diameter,
            'latitude': _assets[i].latitude,
            'longitude': _assets[i].longitude,
            'photo_url': _assets[i].photoPath,
            'agent_name': _assets[i].agentName,
            'device_model': _assets[i].deviceModel,
            'altitude': _assets[i].altitude,
            'precision': _assets[i].precision,
          });
          _assets[i] = CapturedAsset(
            id: result['id'] as int,
            type: _assets[i].type,
            material: _assets[i].material,
            diameter: _assets[i].diameter,
            latitude: _assets[i].latitude,
            longitude: _assets[i].longitude,
            photoPath: _assets[i].photoPath,
            status: 'pending_approval',
            agentName: _assets[i].agentName,
            submittedAt: DateTime.parse(result['submitted_at'] as String),
            deviceModel: _assets[i].deviceModel,
            altitude: _assets[i].altitude,
            precision: _assets[i].precision,
          );
        } catch (e) {
          // Keep local if API fails
        }
      }
    }
    notifyListeners();
  }

  Future<void> approveAsset(int id, String comment) async {
    final idx = _assets.indexWhere((a) => a.id == id);
    if (idx != -1) {
      try {
        await _repository.approveCapturedAsset(id, comment);
        _assets[idx] = _assets[idx].copyWith(
          status: 'approved',
          comment: comment,
        );
        notifyListeners();
      } catch (e) {
        // Handle error
      }
    }
  }

  Future<void> rejectAsset(int id, String comment) async {
    final idx = _assets.indexWhere((a) => a.id == id);
    if (idx != -1) {
      try {
        await _repository.rejectCapturedAsset(id, comment);
        _assets[idx] = _assets[idx].copyWith(
          status: 'rejected',
          comment: comment,
        );
        notifyListeners();
      } catch (e) {
        // Handle error
      }
    }
  }
}
