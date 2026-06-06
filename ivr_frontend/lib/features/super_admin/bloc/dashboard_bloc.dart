import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../core/api/api_exceptions.dart';
import '../../../core/models/stats_model.dart';
import '../../../core/models/pole_model.dart';
import '../../../core/models/dashboard_insights_model.dart';
import '../data/super_admin_repository.dart';

// Events
abstract class SADashEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoadSADashboard extends SADashEvent {}

// States
abstract class SADashState extends Equatable {
  @override
  List<Object?> get props => [];
}

class SADashInitial extends SADashState {}

class SADashLoading extends SADashState {}

class SADashLoaded extends SADashState {
  final StatsModel stats;
  final List<PoleModel> poles;
  final DashboardInsights insights;
  final String? warningMessage;
  SADashLoaded({
    required this.stats,
    required this.poles,
    required this.insights,
    this.warningMessage,
  });
  @override
  List<Object?> get props => [stats, poles, insights, warningMessage];
}

class SADashError extends SADashState {
  final String message;
  SADashError(this.message);
  @override
  List<Object?> get props => [message];
}

// BLoC
class SADashBloc extends Bloc<SADashEvent, SADashState> {
  final SuperAdminRepository _repo;
  Timer? _pollingTimer;

  SADashBloc({SuperAdminRepository? repo})
    : _repo = repo ?? SuperAdminRepository(),
      super(SADashInitial()) {
    on<LoadSADashboard>(_onLoad);
    _startPolling();
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      add(LoadSADashboard());
    });
  }

  @override
  Future<void> close() {
    _pollingTimer?.cancel();
    return super.close();
  }

  Future<void> _onLoad(LoadSADashboard event, Emitter<SADashState> emit) async {
    final bool isAlreadyLoaded = state is SADashLoaded;
    
    StatsModel? cachedStats;
    List<PoleModel>? cachedPoles;
    DashboardInsights? cachedInsights;
    bool hasCache = false;

    if (!isAlreadyLoaded) {
      cachedStats = _repo.getCachedStats();
      final rawCachedPoles = _repo.getCachedPoles();
      cachedPoles = rawCachedPoles?.map((p) => PoleModel.fromJson(p)).toList();
      cachedInsights = _repo.getCachedDashboardInsights();

      hasCache = cachedStats != null && cachedPoles != null && cachedInsights != null;

      if (hasCache) {
        emit(
          SADashLoaded(
            stats: cachedStats,
            poles: cachedPoles,
            insights: cachedInsights,
          ),
        );
      } else {
        emit(SADashLoading());
      }
    }

    final errors = <String>[];
    StatsModel? stats;
    List<PoleModel>? poles;
    DashboardInsights? insights;

    try {
      stats = await _repo.getStats(forceRefresh: isAlreadyLoaded || !hasCache);
    } on ApiException catch (e) {
      errors.add('Stats unavailable: ${e.message}');
    }

    try {
      final rawPoles = await _repo.listPoles(forceRefresh: isAlreadyLoaded || !hasCache);
      poles = rawPoles.map((p) => PoleModel.fromJson(p)).toList();
    } on ApiException catch (e) {
      errors.add('Poles unavailable: ${e.message}');
    }

    try {
      insights = await _repo.getDashboardInsights(forceRefresh: isAlreadyLoaded || !hasCache);
    } on ApiException catch (e) {
      errors.add('Dashboard insights unavailable: ${e.message}');
    }

    if (stats == null && poles == null && insights == null) {
      if (!isAlreadyLoaded && !hasCache) {
        emit(SADashError(errors.join('\n')));
      }
      return;
    }

    final currentLoaded = state is SADashLoaded ? state as SADashLoaded : null;
    emit(
      SADashLoaded(
        stats: stats ?? currentLoaded?.stats ?? cachedStats ?? const StatsModel(
          totalComplaints: 0,
          pendingComplaints: 0,
          resolvedComplaints: 0,
          manualReviewComplaints: 0,
          totalPoles: 0,
          totalPanchayats: 0,
          totalAdmins: 0,
        ),
        poles: poles ?? currentLoaded?.poles ?? cachedPoles ?? const [],
        insights: insights ?? currentLoaded?.insights ?? cachedInsights ?? const DashboardInsights(
          resolutionTrend: ResolutionTrend(
            currentWeek: [0, 0, 0, 0, 0, 0, 0],
            lastWeek: [0, 0, 0, 0, 0, 0, 0],
          ),
          byCategory: [],
          recentActivity: [],
        ),
        warningMessage: errors.isEmpty ? null : 'Some data could not be loaded. Pull to refresh.',
      ),
    );
  }
}
