import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_exceptions.dart';
import '../../../core/models/stats_model.dart';
import '../../../core/models/user_model.dart';
import '../../../core/models/pole_model.dart';
import '../../../core/models/dashboard_insights_model.dart';
import '../../super_admin/data/models/complaint_model.dart';
import '../data/panchayat_admin_repository.dart';

// Events
abstract class PADashEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoadPADashboard extends PADashEvent {}

// States
abstract class PADashState extends Equatable {
  @override
  List<Object?> get props => [];
}

class PADashInitial extends PADashState {}

class PADashLoading extends PADashState {}

class PADashLoaded extends PADashState {
  final StatsModel stats;
  final UserModel profile;
  final List<PoleModel> poles;
  final DashboardInsights insights;
  final List<ComplaintModel> complaints;
  final List<dynamic> electricians;
  final String? warningMessage;
  PADashLoaded({
    required this.stats,
    required this.profile,
    required this.poles,
    required this.insights,
    required this.complaints,
    required this.electricians,
    this.warningMessage,
  });
  @override
  List<Object?> get props => [stats, profile, poles, insights, complaints, electricians, warningMessage];
}

class PADashError extends PADashState {
  final String message;
  PADashError(this.message);
  @override
  List<Object?> get props => [message];
}

// BLoC
class PADashBloc extends Bloc<PADashEvent, PADashState> {
  final PanchayatAdminRepository _repo;
  Timer? _pollingTimer;

  PADashBloc({PanchayatAdminRepository? repo})
    : _repo = repo ?? PanchayatAdminRepository(),
      super(PADashInitial()) {
    on<LoadPADashboard>(_onLoad);
    _startPolling();
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      add(LoadPADashboard());
    });
  }

  @override
  Future<void> close() {
    _pollingTimer?.cancel();
    return super.close();
  }

  Future<void> _onLoad(LoadPADashboard event, Emitter<PADashState> emit) async {
    final bool isAlreadyLoaded = state is PADashLoaded;
    
    StatsModel? cachedStats;
    UserModel? cachedProfile;
    List<PoleModel>? cachedPoles;
    DashboardInsights? cachedInsights;
    List<ComplaintModel>? cachedComplaints;
    List<dynamic>? cachedElectricians;
    bool hasCache = false;

    if (!isAlreadyLoaded) {
      cachedStats = _repo.getCachedStats();
      cachedPoles = _repo.getCachedPoles();
      cachedInsights = _repo.getCachedDashboardInsights();
      cachedComplaints = _repo.getCachedComplaints(status: 'pending');
      
      final cachedProfileData = ApiClient.instance.getCached('/api/admin/me');
      cachedProfile = cachedProfileData != null ? UserModel.fromJson(cachedProfileData) : null;
      cachedElectricians = ApiClient.instance.getCached('/api/admin/electricians') as List?;

      hasCache = cachedStats != null && 
                 cachedPoles != null && 
                 cachedInsights != null && 
                 cachedComplaints != null && 
                 cachedProfile != null;

      if (hasCache) {
        emit(
          PADashLoaded(
            stats: cachedStats,
            profile: cachedProfile,
            poles: cachedPoles,
            insights: cachedInsights,
            complaints: cachedComplaints,
            electricians: cachedElectricians ?? const [],
          ),
        );
      } else {
        emit(PADashLoading());
      }
    }

    final errors = <String>[];
    StatsModel? stats;
    UserModel? profile;
    List<PoleModel>? poles;
    DashboardInsights? insights;
    List<ComplaintModel>? complaints;
    List<dynamic>? electricians;

    try {
      stats = await _repo.getStats(forceRefresh: isAlreadyLoaded || !hasCache);
    } on ApiException catch (e) {
      errors.add('Stats unavailable: ${e.message}');
    }

    try {
      profile = await _repo.getMe();
    } on ApiException catch (e) {
      errors.add('Profile unavailable: ${e.message}');
    }

    try {
      poles = await _repo.listPoles(forceRefresh: isAlreadyLoaded || !hasCache);
    } on ApiException catch (e) {
      errors.add('Poles unavailable: ${e.message}');
    }

    try {
      insights = await _repo.getDashboardInsights(forceRefresh: isAlreadyLoaded || !hasCache);
    } on ApiException catch (e) {
      errors.add('Dashboard insights unavailable: ${e.message}');
    }

    try {
      complaints = await _repo.listComplaints(status: 'pending', forceRefresh: isAlreadyLoaded || !hasCache);
    } on ApiException catch (e) {
      errors.add('Complaints unavailable: ${e.message}');
    }

    try {
      electricians = await _repo.listElectricians();
    } on ApiException catch (e) {
      errors.add('Electricians unavailable: ${e.message}');
    }

    if (stats == null && profile == null && poles == null && insights == null && complaints == null && electricians == null) {
      if (!isAlreadyLoaded && !hasCache) {
        emit(PADashError(errors.join('\n')));
      }
      return;
    }

    final currentLoaded = state is PADashLoaded ? state as PADashLoaded : null;
    emit(
      PADashLoaded(
        stats: stats ?? currentLoaded?.stats ?? cachedStats ?? const StatsModel(
          totalComplaints: 0,
          pendingComplaints: 0,
          resolvedComplaints: 0,
          manualReviewComplaints: 0,
          totalPoles: 0,
          totalPanchayats: 0,
          totalAdmins: 0,
        ),
        profile: profile ?? currentLoaded?.profile ?? cachedProfile ?? const UserModel(id: 0, email: '', role: 'panchayat_admin'),
        poles: poles ?? currentLoaded?.poles ?? cachedPoles ?? const [],
        insights: insights ?? currentLoaded?.insights ?? cachedInsights ?? const DashboardInsights(
          resolutionTrend: ResolutionTrend(
            currentWeek: [0, 0, 0, 0, 0, 0, 0],
            lastWeek: [0, 0, 0, 0, 0, 0, 0],
          ),
          byCategory: [],
          recentActivity: [],
        ),
        complaints: complaints ?? currentLoaded?.complaints ?? cachedComplaints ?? const [],
        electricians: electricians ?? currentLoaded?.electricians ?? cachedElectricians ?? const [],
        warningMessage: errors.isEmpty ? null : 'Some data could not be loaded. Pull to refresh.',
      ),
    );
  }
}
