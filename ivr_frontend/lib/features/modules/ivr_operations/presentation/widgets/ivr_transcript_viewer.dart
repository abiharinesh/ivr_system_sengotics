import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ivr_frontend/config/app_theme.dart';

/// Rich Dialogue Bubble & Metadata Transcript Viewer.
///
/// Formats multi-turn conversations between the AI Voicebot and Citizen
/// into conversational speech bubbles with speaker avatars and dual Tamil/English view.
/// Also elegantly handles structured session metadata and completion statuses.
class IvrTranscriptViewer extends StatefulWidget {
  const IvrTranscriptViewer({
    super.key,
    required this.transcriptTamil,
    this.transcriptEnglish,
  });

  final String transcriptTamil;
  final String? transcriptEnglish;

  @override
  State<IvrTranscriptViewer> createState() => _IvrTranscriptViewerState();
}

class _IvrTranscriptViewerState extends State<IvrTranscriptViewer> {
  bool _showEnglish = false;

  bool get _hasEnglish =>
      widget.transcriptEnglish != null &&
      widget.transcriptEnglish!.trim().isNotEmpty &&
      widget.transcriptEnglish != widget.transcriptTamil;

  List<_DialogueTurn> _parseDialogue(String text) {
    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    final turns = <_DialogueTurn>[];

    for (final line in lines) {
      final lower = line.toLowerCase();
      if (lower.startsWith('user:') ||
          lower.startsWith('citizen:') ||
          lower.startsWith('caller:')) {
        final content = line.substring(line.indexOf(':') + 1).trim();
        turns.add(
            _DialogueTurn(isAi: false, speaker: 'Citizen', text: content));
      } else if (lower.startsWith('bot:') ||
          lower.startsWith('ai:') ||
          lower.startsWith('assistant:') ||
          lower.startsWith('voicebot:')) {
        final content = line.substring(line.indexOf(':') + 1).trim();
        turns.add(_DialogueTurn(
            isAi: true, speaker: 'Voicebot AI', text: content));
      } else if (line.contains(':') &&
          !line.startsWith('http://') &&
          !line.startsWith('https://')) {
        // Structured field e.g. "service_type: street_light"
        final colonIdx = line.indexOf(':');
        final key = line.substring(0, colonIdx).trim();
        final val = line.substring(colonIdx + 1).trim();
        turns.add(_DialogueTurn(
          isAi: true,
          speaker: key.replaceAll('_', ' ').toUpperCase(),
          text: val,
          isMetadata: true,
        ));
      } else {
        turns.add(_DialogueTurn(
          isAi: false,
          speaker: 'Citizen (Audio Transcript)',
          text: line,
        ));
      }
    }

    return turns;
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Transcript copied to clipboard'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentText = (_showEnglish && _hasEnglish)
        ? widget.transcriptEnglish!
        : widget.transcriptTamil;

    final trimmed = currentText.trim();
    final isJustCompleted =
        trimmed.toLowerCase() == 'voicebot call completed';
    final turns = _parseDialogue(currentText);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.stroke),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header with language toggle and copy action
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.bgCard,
              border: Border(bottom: BorderSide(color: AppTheme.stroke)),
            ),
            child: Row(
              children: [
                Icon(Icons.chat_bubble_outline_rounded,
                    size: 15, color: AppTheme.primary),
                const SizedBox(width: 8),
                Text(
                  'CONVERSATION TRANSCRIPT',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: AppTheme.textMuted,
                  ),
                ),
                const Spacer(),
                if (_hasEnglish) ...[
                  InkWell(
                    onTap: () => setState(() => _showEnglish = false),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: !_showEnglish
                            ? AppTheme.primary.withValues(alpha: 0.12)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'தமிழ்',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: !_showEnglish
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: !_showEnglish
                              ? AppTheme.primary
                              : AppTheme.textMuted,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: () => setState(() => _showEnglish = true),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _showEnglish
                            ? AppTheme.primary.withValues(alpha: 0.12)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'English',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: _showEnglish
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: _showEnglish
                              ? AppTheme.primary
                              : AppTheme.textMuted,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                IconButton(
                  tooltip: 'Copy Transcript',
                  icon: const Icon(Icons.copy_rounded, size: 15),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  color: AppTheme.textMuted,
                  onPressed: () => _copyToClipboard(currentText),
                ),
              ],
            ),
          ),

          // Dialogue Bubbles or Status Card
          Padding(
            padding: const EdgeInsets.all(12),
            child: isJustCompleted
                ? Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: AppTheme.primary.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle_outline_rounded,
                            size: 18, color: AppTheme.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Voicebot Session Completed',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Call recording is available above for audio review.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      for (final turn in turns) _buildBubble(turn),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBubble(_DialogueTurn turn) {
    if (turn.isMetadata) {
      // Structured Metadata Row
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.bgCard,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.stroke),
          ),
          child: Row(
            children: [
              Text(
                turn.speaker,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textMuted,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  turn.text,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (turn.isAi) {
      // AI Voicebot Bubble (Left-aligned)
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.smart_toy_rounded,
                  size: 14, color: AppTheme.primary),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.08),
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                  border: Border.all(
                      color: AppTheme.primary.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Assistant',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      turn.text,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.4,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      // Citizen Bubble (Right-aligned)
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.bgCard,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                  border: Border.all(color: AppTheme.stroke),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      turn.speaker,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      turn.text,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.4,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: AppTheme.textSecondary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.person_rounded,
                  size: 14, color: AppTheme.textSecondary),
            ),
          ],
        ),
      );
    }
  }
}

class _DialogueTurn {
  const _DialogueTurn({
    required this.isAi,
    required this.speaker,
    required this.text,
    this.isMetadata = false,
  });

  final bool isAi;
  final String speaker;
  final String text;
  final bool isMetadata;
}

