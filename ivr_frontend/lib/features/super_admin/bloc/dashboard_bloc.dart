import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../core/api/api_exceptions.dart';
import '../../../models/stats_model.dart';
import '../../../models/pole_model.dart';
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
  final String? warningMessage;
  SADashLoaded({required this.stats, required this.poles, this.warningMessage});
  @override
  List<Object?> get props => [stats, poles, warningMessage];
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

  SADashBloc({SuperAdminRepository? repo})
    : _repo = repo ?? SuperAdminRepository(),
      super(SADashInitial()) {
    on<LoadSADashboard>(_onLoad);
  }

  Future<void> _onLoad(LoadSADashboard event, Emitter<SADashState> emit) async {
    emit(SADashLoading());
    final errors = <String>[];
    StatsModel? stats;
    List<PoleModel>? poles;

    try {
      stats = await _repo.getStats();
    } on ApiException catch (e) {
      errors.add('Stats unavailable: ${e.message}');
    }

    try {
      final rawPoles = await _repo.listPoles();
      poles = rawPoles.map((p) => PoleModel.fromJson(p)).toList();
    } on ApiException catch (e) {
      errors.add('Poles unavailable: ${e.message}');
    }

    if (stats == null && poles == null) {
      emit(SADashError(errors.join('\n')));
      return;
    }

    emit(
      SADashLoaded(
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
        poles: poles ?? const [],
        warningMessage:
            errors.isEmpty ? null : 'Some data could not be loaded. Pull to refresh.',
      ),
    );
  }
}
