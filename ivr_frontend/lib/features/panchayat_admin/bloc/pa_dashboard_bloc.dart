import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../core/api/api_exceptions.dart';
import '../../../models/stats_model.dart';
import '../../../models/user_model.dart';
import '../../../models/pole_model.dart';
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
  final String? warningMessage;
  PADashLoaded({
    required this.stats,
    required this.profile,
    required this.poles,
    this.warningMessage,
  });
  @override
  List<Object?> get props => [stats, profile, poles, warningMessage];
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

  PADashBloc({PanchayatAdminRepository? repo})
    : _repo = repo ?? PanchayatAdminRepository(),
      super(PADashInitial()) {
    on<LoadPADashboard>(_onLoad);
  }

  Future<void> _onLoad(LoadPADashboard event, Emitter<PADashState> emit) async {
    emit(PADashLoading());
    final errors = <String>[];
    StatsModel? stats;
    UserModel? profile;
    List<PoleModel>? poles;

    try {
      stats = await _repo.getStats();
    } on ApiException catch (e) {
      errors.add('Stats unavailable: ${e.message}');
    }

    try {
      profile = await _repo.getMe();
    } on ApiException catch (e) {
      errors.add('Profile unavailable: ${e.message}');
    }

    try {
      poles = await _repo.listPoles();
    } on ApiException catch (e) {
      errors.add('Poles unavailable: ${e.message}');
    }

    if (stats == null && profile == null && poles == null) {
      emit(PADashError(errors.join('\n')));
      return;
    }

    emit(
      PADashLoaded(
        stats: stats ??
            const StatsModel(
              totalComplaints: 0,
              pendingComplaints: 0,
              resolvedComplaints: 0,
              manualReviewComplaints: 0,
              totalPoles: 0,
              totalPanchayats: 0,
              totalAdmins: 0,
            ),
        profile:
            profile ??
            const UserModel(id: 0, email: '', role: 'panchayat_admin'),
        poles: poles ?? const [],
        warningMessage:
            errors.isEmpty ? null : 'Some data could not be loaded. Pull to refresh.',
      ),
    );
  }
}
