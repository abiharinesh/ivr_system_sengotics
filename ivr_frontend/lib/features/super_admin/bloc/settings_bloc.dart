import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../core/api/api_exceptions.dart';
import '../data/super_admin_repository.dart';

// ── Events ────────────────────────────────────────────────────────────────
abstract class SettingsEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoadAiProvider extends SettingsEvent {}

class SetAiProvider extends SettingsEvent {
  final String provider;
  SetAiProvider(this.provider);
  @override
  List<Object?> get props => [provider];
}

// ── States ────────────────────────────────────────────────────────────────
abstract class SettingsState extends Equatable {
  @override
  List<Object?> get props => [];
}

class SettingsInitial extends SettingsState {}
class SettingsLoading extends SettingsState {}

class SettingsLoaded extends SettingsState {
  final String provider;
  final List<String> availableProviders;
  final String? updatedAt;
  SettingsLoaded({
    required this.provider,
    required this.availableProviders,
    this.updatedAt,
  });
  @override
  List<Object?> get props => [provider, availableProviders];
}

class SettingsActionSuccess extends SettingsState {
  final String message;
  SettingsActionSuccess(this.message);
  @override
  List<Object?> get props => [message];
}

class SettingsError extends SettingsState {
  final String message;
  SettingsError(this.message);
  @override
  List<Object?> get props => [message];
}

// ── BLoC ──────────────────────────────────────────────────────────────────
class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  final SuperAdminRepository _repo;

  SettingsBloc({SuperAdminRepository? repo})
      : _repo = repo ?? SuperAdminRepository(),
        super(SettingsInitial()) {
    on<LoadAiProvider>(_onLoad);
    on<SetAiProvider>(_onSet);
  }

  Future<void> _onLoad(LoadAiProvider event, Emitter<SettingsState> emit) async {
    emit(SettingsLoading());
    try {
      final data = await _repo.getAiProvider();
      emit(SettingsLoaded(
        provider: data['provider'] as String? ?? 'gemini',
        availableProviders: (data['available_providers'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            ['groq', 'gemini'],
        updatedAt: data['updated_at']?.toString(),
      ));
    } on ApiException catch (e) {
      emit(SettingsError(e.message));
    }
  }

  Future<void> _onSet(SetAiProvider event, Emitter<SettingsState> emit) async {
    try {
      await _repo.setAiProvider(event.provider);
      emit(SettingsActionSuccess('AI provider set to ${event.provider}'));
      add(LoadAiProvider());
    } on ApiException catch (e) {
      emit(SettingsError(e.message));
    }
  }
}
