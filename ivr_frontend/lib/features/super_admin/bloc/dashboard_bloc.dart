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
  SADashLoaded({required this.stats, required this.poles});
  @override
  List<Object?> get props => [stats, poles];
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
    try {
      final results = await Future.wait([
        _repo.getStats(),
        _repo.listPoles(),
      ]);
      emit(SADashLoaded(
        stats: results[0] as StatsModel,
        poles: (results[1] as List).map((p) => PoleModel.fromJson(p)).toList(),
      ));
    } on ApiException catch (e) {
      emit(SADashError(e.message));
    }
  }
}
