import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_exceptions.dart';
import '../data/super_admin_repository.dart';

// ── Events ────────────────────────────────────────────────────────────────
abstract class SettingsEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoadProviders extends SettingsEvent {}

class SetSttProvider extends SettingsEvent {
  final String provider;
  SetSttProvider(this.provider);
  @override
  List<Object?> get props => [provider];
}

class SetLlmProvider extends SettingsEvent {
  final String provider;
  SetLlmProvider(this.provider);
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
  final String sttProvider;
  final List<String> availableSttProviders;
  final String llmProvider;
  final List<String> availableLlmProviders;

  SettingsLoaded({
    required this.sttProvider,
    required this.availableSttProviders,
    required this.llmProvider,
    required this.availableLlmProviders,
  });

  @override
  List<Object?> get props => [
    sttProvider,
    availableSttProviders,
    llmProvider,
    availableLlmProviders,
  ];
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
    on<LoadProviders>(_onLoad);
    on<SetSttProvider>(_onSetStt);
    on<SetLlmProvider>(_onSetLlm);
  }

  Future<void> _onLoad(LoadProviders event, Emitter<SettingsState> emit) async {
    final cachedStt = ApiClient.instance.getCached('/api/superadmin/settings/stt');
    final cachedLlm = ApiClient.instance.getCached('/api/superadmin/settings/llm');
    final hasCache = cachedStt != null && cachedLlm != null;

    if (hasCache) {
      emit(
        SettingsLoaded(
          sttProvider: cachedStt['provider'] as String? ?? 'gemini',
          availableSttProviders:
              (cachedStt['available_providers'] as List?)
                  ?.map((e) => e.toString())
                  .toList() ??
              ['gemini', 'groq', 'rapidapi', 'google-speech'],
          llmProvider: cachedLlm['provider'] as String? ?? 'gemini',
          availableLlmProviders:
              (cachedLlm['available_providers'] as List?)
                  ?.map((e) => e.toString())
                  .toList() ??
              ['gemini', 'groq'],
        ),
      );
    } else {
      emit(SettingsLoading());
    }

    try {
      final sttData = await _repo.getSttProvider();
      final llmData = await _repo.getLlmProvider();

      emit(
        SettingsLoaded(
          sttProvider: sttData['provider'] as String? ?? 'gemini',
          availableSttProviders:
              (sttData['available_providers'] as List?)
                  ?.map((e) => e.toString())
                  .toList() ??
              ['gemini', 'groq', 'rapidapi', 'google-speech'],
          llmProvider: llmData['provider'] as String? ?? 'gemini',
          availableLlmProviders:
              (llmData['available_providers'] as List?)
                  ?.map((e) => e.toString())
                  .toList() ??
              ['gemini', 'groq'],
        ),
      );
    } on ApiException catch (e) {
      if (!hasCache) {
        emit(SettingsError(e.message));
      }
    }
  }

  Future<void> _onSetStt(
    SetSttProvider event,
    Emitter<SettingsState> emit,
  ) async {
    try {
      await _repo.setSttProvider(event.provider);
      emit(SettingsActionSuccess('STT provider set to ${event.provider}'));
      add(LoadProviders());
    } on ApiException catch (e) {
      emit(SettingsError(e.message));
    }
  }

  Future<void> _onSetLlm(
    SetLlmProvider event,
    Emitter<SettingsState> emit,
  ) async {
    try {
      await _repo.setLlmProvider(event.provider);
      emit(SettingsActionSuccess('LLM provider set to ${event.provider}'));
      add(LoadProviders());
    } on ApiException catch (e) {
      emit(SettingsError(e.message));
    }
  }
}
