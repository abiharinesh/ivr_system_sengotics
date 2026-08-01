import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ivr_frontend/config/app_theme.dart';
import 'package:ivr_frontend/core/widgets/app_loading_state.dart';
import 'package:ivr_frontend/core/widgets/dashboard_panels.dart';
import 'package:ivr_frontend/features/roles/super_admin/bloc/settings_bloc.dart';

class AiSettingsScreen extends StatelessWidget {
  const AiSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SettingsBloc, SettingsState>(
      listener: (context, state) {
        if (state is SettingsActionSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppTheme.accent,
            ),
          );
        }
        if (state is SettingsError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppTheme.error,
            ),
          );
        }
      },
      builder: (context, state) {
        if (state is SettingsLoading) {
          return const AppLoadingState(
            message: 'Loading settings...',
            style: AppLoadingStyle.detail,
          );
        }
        if (state is SettingsLoaded) {
          return _buildSettings(context, state);
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildSettings(BuildContext context, SettingsLoaded state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DashboardPanel(
            title: 'AI Provider Control',
            subtitle: 'Configure speech and language intelligence providers',
            child: SizedBox.shrink(),
          ),
          const SizedBox(height: 16),
          const Text(
            'STT Provider',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
                Text(
            'Choose the AI provider for speech-to-text processing',
            style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 16),

          // STT Provider Cards
          ...state.availableSttProviders.map(
            (provider) => _buildProviderCard(
              context: context,
              provider: provider,
              isActive: provider == state.sttProvider,
              isStt: true,
            ),
          ),

          const SizedBox(height: 24),

                Text(
            'LLM Provider',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
                Text(
            'Choose the AI provider for language model processing and data extraction',
            style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 24),

          // LLM Provider Cards
          ...state.availableLlmProviders.map(
            (provider) => _buildProviderCard(
              context: context,
              provider: provider,
              isActive: provider == state.llmProvider,
              isStt: false,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProviderCard({
    required BuildContext context,
    required String provider,
    required bool isActive,
    required bool isStt,
  }) {
    // Provider-specific theming
    String label;
    String subtitle;
    String iconText;
    List<Color> gradientColors;

    switch (provider) {
      case 'gemini':
        label = 'Google Gemini';
        subtitle = isStt ? 'Gemini STT' : 'Gemini LLM Extraction';
        iconText = 'G';
        gradientColors = [const Color(0xFF4285F4), const Color(0xFF34A853)];
        break;
      case 'google-speech':
        label = 'Google Cloud STT';
        subtitle = 'Speech-to-Text V1';
        iconText = 'GC';
        gradientColors = [const Color(0xFFEA4335), const Color(0xFFFBBC05)];
        break;
      case 'groq':
        label = 'GROQ';
        subtitle = isStt ? 'Whisper STT' : 'LLaMA 3.3 Extraction';
        iconText = 'GQ';
        gradientColors = [const Color(0xFFF97316), const Color(0xFFEF4444)];
        break;
      case 'rapidapi':
        label = 'RapidAPI';
        subtitle = 'Speech-to-Text AI';
        iconText = 'R';
        gradientColors = [const Color(0xFF0055D4), const Color(0xFF00C4B4)];
        break;
      default:
        label = provider.toUpperCase();
        subtitle = isStt ? 'STT Provider' : 'LLM Provider';
        iconText = provider[0].toUpperCase();
        gradientColors = [const Color(0xFF6B7280), const Color(0xFF9CA3AF)];
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          if (!isActive) {
            context.read<SettingsBloc>().add(
              isStt ? SetSttProvider(provider) : SetLlmProvider(provider),
            );
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isActive ? AppTheme.accent : AppTheme.dividerColor,
              width: isActive ? 2 : 1,
            ),
            boxShadow:
                isActive
                    ? [
                      BoxShadow(
                        color: AppTheme.accent.withValues(alpha: 0.15),
                        blurRadius: 20,
                        spreadRadius: 0,
                      ),
                      ...AppTheme.softShadow,
                    ]
                    : AppTheme.softShadow,
          ),
          child: LayoutBuilder(
            builder: (context, cardConstraints) {
              final isNarrow = cardConstraints.maxWidth < 450;
              final content = [
                // Provider Icon
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: gradientColors),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      iconText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                if (!isNarrow) const SizedBox(width: 16) else const SizedBox(height: 12),

                // Provider Info
                if (isNarrow)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  )
                else
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (!isNarrow) const SizedBox(width: 16) else const SizedBox(height: 16),

                // Active Indicator / Button
                if (isActive)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppTheme.accent.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: AppTheme.accent,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Active',
                          style: TextStyle(
                            color: AppTheme.accent,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  OutlinedButton(
                    onPressed: () {
                      context.read<SettingsBloc>().add(
                        isStt
                            ? SetSttProvider(provider)
                            : SetLlmProvider(provider),
                      );
                    },
                    child: const Text('Activate'),
                  ),
              ];

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: content,
                );
              }

              return Row(
                children: content,
              );
            },
          ),
        ),
      ),
    );
  }
}