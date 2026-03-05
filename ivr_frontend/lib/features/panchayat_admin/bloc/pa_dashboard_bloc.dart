import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../core/api/api_exceptions.dart';
import '../../../models/stats_model.dart';
import '../../../models/user_model.dart';
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
  PADashLoaded({required this.stats, required this.profile});
  @override
  List<Object?> get props => [stats, profile];
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
    try {
      final results = await Future.wait([
        _repo.getStats(),
        _repo.getMe(),
      ]);
      emit(PADashLoaded(
        stats: results[0] as StatsModel,
        profile: results[1] as UserModel,
      ));
    } on ApiException catch (e) {
      emit(PADashError(e.message));
    }
  }
}
