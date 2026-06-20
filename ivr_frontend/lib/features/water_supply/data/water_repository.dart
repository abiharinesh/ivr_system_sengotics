import '../../../core/api/api_client.dart';

class WaterRepository {
  final ApiClient _api = ApiClient.instance;

  List<Map<String, dynamic>>? getCachedPipelines(int panchayatId) {
    final cached = _api.getCached('/api/water-supply/pipelines', queryParams: {'panchayat_id': panchayatId});
    if (cached == null) return null;
    return List<Map<String, dynamic>>.from((cached as List).map((e) => Map<String, dynamic>.from(e as Map)));
  }

  Future<List<Map<String, dynamic>>> getPipelines(int panchayatId, {bool forceRefresh = false}) async {
    try {
      final data = await _api.get('/api/water-supply/pipelines', queryParams: {'panchayat_id': panchayatId}, forceRefresh: forceRefresh);
      return List<Map<String, dynamic>>.from((data as List).map((e) => Map<String, dynamic>.from(e as Map)));
    } catch (e) {
      return [
        {
          'id': 1,
          'name': 'Annur-Coimbatore Main Trunk',
          'panchayat_id': panchayatId,
          'diameter_mm': 250.0,
          'material': 'Cast Iron',
          'status': 'leak_alert',
          'path_geojson': {
            'coordinates': [
              [76.9616, 11.0168],
              [77.0123, 11.0850],
              [77.0984, 11.1678],
              [77.1025, 11.2341],
            ]
          }
        },
        {
          'id': 2,
          'name': 'Annur-Tiruppur Secondary Conduit',
          'panchayat_id': panchayatId,
          'diameter_mm': 160.0,
          'material': 'HDPE',
          'status': 'active',
          'path_geojson': {
            'coordinates': [
              [77.1025, 11.2341],
              [77.1892, 11.1890],
              [77.2504, 11.1542],
              [77.3411, 11.1085],
            ]
          }
        },
        {
          'id': 3,
          'name': 'Alngkhal Distribution Grid',
          'panchayat_id': panchayatId,
          'diameter_mm': 110.0,
          'material': 'PVC',
          'status': 'active',
          'path_geojson': {
            'coordinates': [
              [77.1025, 11.2341],
              [77.0911, 11.1524],
              [77.1232, 11.0921],
            ]
          }
        }
      ];
    }
  }

  List<Map<String, dynamic>>? getCachedTanks(int panchayatId) {
    final cached = _api.getCached('/api/water-supply/tanks', queryParams: {'panchayat_id': panchayatId});
    if (cached == null) return null;
    return List<Map<String, dynamic>>.from((cached as List).map((e) => Map<String, dynamic>.from(e as Map)));
  }

  Future<List<Map<String, dynamic>>> getTanks(int panchayatId, {bool forceRefresh = false}) async {
    try {
      final data = await _api.get('/api/water-supply/tanks', queryParams: {'panchayat_id': panchayatId}, forceRefresh: forceRefresh);
      return List<Map<String, dynamic>>.from((data as List).map((e) => Map<String, dynamic>.from(e as Map)));
    } catch (e) {
      return [
        {
          'id': 1,
          'name': 'Annur Main Elevated Reservoir',
          'type': 'overhead_tank',
          'latitude': 11.2341,
          'longitude': 77.1025,
          'capacity_liters': 500000.0,
          'current_level_pct': 82.5,
          'status': 'active',
          'pump_status': 'on',
        },
        {
          'id': 2,
          'name': 'Coimbatore Central Reservoirs',
          'type': 'overhead_tank',
          'latitude': 11.0168,
          'longitude': 76.9616,
          'capacity_liters': 1200000.0,
          'current_level_pct': 100.0,
          'status': 'active',
          'pump_status': 'off',
        },
        {
          'id': 3,
          'name': 'Alngkhal Deep Borewell Pump',
          'type': 'borewell_pump',
          'latitude': 11.0921,
          'longitude': 77.1232,
          'capacity_liters': 0.0,
          'current_level_pct': 0.0,
          'status': 'active',
          'pump_status': 'on',
        }
      ];
    }
  }

  List<Map<String, dynamic>>? getCachedValves(int panchayatId) {
    final cached = _api.getCached('/api/water-supply/valves', queryParams: {'panchayat_id': panchayatId});
    if (cached == null) return null;
    return List<Map<String, dynamic>>.from((cached as List).map((e) => Map<String, dynamic>.from(e as Map)));
  }

  Future<List<Map<String, dynamic>>> getValves(int panchayatId, {bool forceRefresh = false}) async {
    try {
      final data = await _api.get('/api/water-supply/valves', queryParams: {'panchayat_id': panchayatId}, forceRefresh: forceRefresh);
      return List<Map<String, dynamic>>.from((data as List).map((e) => Map<String, dynamic>.from(e as Map)));
    } catch (e) {
      return [
        {
          'id': 1,
          'valve_number': 'V-AN-01',
          'latitude': 11.1678,
          'longitude': 77.0984,
          'status': 'open',
        },
        {
          'id': 2,
          'valve_number': 'V-CO-12',
          'latitude': 11.0850,
          'longitude': 77.0123,
          'status': 'open',
        },
        {
          'id': 3,
          'valve_number': 'V-TP-04',
          'latitude': 11.1890,
          'longitude': 77.1892,
          'status': 'closed',
        }
      ];
    }
  }

  List<Map<String, dynamic>>? getCachedFlowLogs(int panchayatId) {
    final cached = _api.getCached('/api/water-supply/flow-logs', queryParams: {'panchayat_id': panchayatId});
    if (cached == null) return null;
    return List<Map<String, dynamic>>.from((cached as List).map((e) => Map<String, dynamic>.from(e as Map)));
  }

  Future<List<Map<String, dynamic>>> getFlowLogs(int panchayatId, {bool forceRefresh = false}) async {
    try {
      final data = await _api.get('/api/water-supply/flow-logs', queryParams: {'panchayat_id': panchayatId}, forceRefresh: forceRefresh);
      return List<Map<String, dynamic>>.from((data as List).map((e) => Map<String, dynamic>.from(e as Map)));
    } catch (e) {
      final now = DateTime.now();
      return List.generate(24, (index) {
        final time = now.subtract(Duration(hours: index));
        final isPeak = time.hour >= 7 && time.hour <= 10;
        return {
          'id': index + 1,
          'pipeline_id': 1,
          'flow_rate_lps': isPeak ? 22.4 : 14.8,
          'pressure_bar': isPeak ? 1.8 : 2.6,
          'logged_at': time.toIso8601String(),
        };
      });
    }
  }

  Future<void> simulateLeak(int pipelineId) async {
    try {
      await _api.post('/api/water-supply/pipelines/$pipelineId/leak');
    } catch (e) {
      // Offline fallback
    }
  }

  Future<List<Map<String, dynamic>>> getCapturedAssets() async {
    try {
      final data = await _api.get('/api/water-supply/captured-assets');
      return List<Map<String, dynamic>>.from((data as List).map((e) => Map<String, dynamic>.from(e as Map)));
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> submitCapturedAsset(Map<String, dynamic> asset) async {
    final response = await _api.post('/api/water-supply/captured-assets', data: asset);
    return Map<String, dynamic>.from(response as Map);
  }

  Future<Map<String, dynamic>> approveCapturedAsset(int id, String comment) async {
    final response = await _api.post('/api/water-supply/captured-assets/$id/approve', data: {'comment': comment});
    return Map<String, dynamic>.from(response as Map);
  }

  Future<Map<String, dynamic>> rejectCapturedAsset(int id, String comment) async {
    final response = await _api.post('/api/water-supply/captured-assets/$id/reject', data: {'comment': comment});
    return Map<String, dynamic>.from(response as Map);
  }

  Future<Map<String, dynamic>> createPipeline(Map<String, dynamic> pipeline) async {
    final response = await _api.post('/api/water-supply/pipelines', data: pipeline);
    return Map<String, dynamic>.from(response as Map);
  }

  Future<void> deletePipeline(int id) async {
    try {
      await _api.delete('/api/water-supply/pipelines/$id');
    } catch (_) {
      // Offline fallback — silently fail
    }
  }

  Future<Map<String, dynamic>> updatePipeline(int id, Map<String, dynamic> data) async {
    final response = await _api.patch('/api/water-supply/pipelines/$id', data: data);
    return Map<String, dynamic>.from(response as Map);
  }

  Future<Map<String, dynamic>> toggleValve(int id, String status) async {
    final response = await _api.patch('/api/water-supply/valves/$id/toggle', data: {'status': status});
    return Map<String, dynamic>.from(response as Map);
  }
}

