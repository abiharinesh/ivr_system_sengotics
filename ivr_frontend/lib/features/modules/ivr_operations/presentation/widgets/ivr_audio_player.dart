import 'dart:js_interop';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ivr_frontend/config/api_config.dart';
import 'package:ivr_frontend/config/app_theme.dart';
import 'package:ivr_frontend/core/storage/secure_storage.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:web/web.dart' as web;

/// Interactive Audio Player for Voicebot Call Recordings.
///
/// Supports authenticated in-browser streaming via backend audio proxy,
/// play/pause, seek scrubber, elapsed & total duration display,
/// and download/open in new tab.
class IvrAudioPlayer extends StatefulWidget {
  const IvrAudioPlayer({
    super.key,
    required this.audioUrl,
    this.voiceCallId,
    this.title = 'Call Recording',
  });

  final String audioUrl;
  final int? voiceCallId;
  final String title;

  @override
  State<IvrAudioPlayer> createState() => _IvrAudioPlayerState();
}

class _IvrAudioPlayerState extends State<IvrAudioPlayer> {
  web.HTMLAudioElement? _webAudio;
  bool _isPlaying = false;
  bool _isLoading = false;
  bool _hasError = false;
  double _positionSeconds = 0.0;
  double _durationSeconds = 0.0;
  String? _effectiveAudioUrl;

  @override
  void initState() {
    super.initState();
    _resolveAndInit();
  }

  @override
  void didUpdateWidget(covariant IvrAudioPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.audioUrl != widget.audioUrl ||
        oldWidget.voiceCallId != widget.voiceCallId) {
      _disposeAudio();
      _resolveAndInit();
    }
  }

  Future<void> _resolveAndInit() async {
    String url = widget.audioUrl;

    if (widget.voiceCallId != null && widget.voiceCallId! > 0) {
      final token = await SecureStorageService.getToken();
      final base = ApiConfig.baseUrl;
      final tokenQuery =
          token != null && token.isNotEmpty ? '?token=$token' : '';
      url = '$base/api/ivr-operations/audio-proxy/${widget.voiceCallId}$tokenQuery';
    }

    if (!mounted) return;

    setState(() {
      _effectiveAudioUrl = url;
      _hasError = false;
    });

    if (kIsWeb) {
      _initWebAudio(url);
    }
  }

  void _initWebAudio(String url) {
    try {
      final audio = web.HTMLAudioElement();
      audio.src = url;
      audio.preload = 'metadata';

      audio.addEventListener(
        'loadedmetadata',
        ((web.Event _) {
          if (mounted) {
            setState(() {
              _durationSeconds =
                  audio.duration.isFinite ? audio.duration : 0.0;
              _hasError = false;
            });
          }
        }).toJS,
      );

      audio.addEventListener(
        'timeupdate',
        ((web.Event _) {
          if (mounted && _isPlaying) {
            setState(() {
              _positionSeconds = audio.currentTime;
            });
          }
        }).toJS,
      );

      audio.addEventListener(
        'ended',
        ((web.Event _) {
          if (mounted) {
            setState(() {
              _isPlaying = false;
              _positionSeconds = 0.0;
            });
          }
        }).toJS,
      );

      audio.addEventListener(
        'error',
        ((web.Event _) {
          if (mounted) {
            setState(() {
              _isLoading = false;
              _isPlaying = false;
              _hasError = true;
            });
          }
        }).toJS,
      );

      _webAudio = audio;
    } catch (_) {
      // Fallback gracefully
    }
  }

  void _disposeAudio() {
    if (kIsWeb && _webAudio != null) {
      _webAudio?.pause();
      _webAudio?.src = '';
      _webAudio = null;
    }
  }

  @override
  void dispose() {
    _disposeAudio();
    super.dispose();
  }

  void _togglePlay() {
    if (_hasError) {
      _resolveAndInit();
      return;
    }

    if (kIsWeb && _webAudio != null) {
      if (_isPlaying) {
        _webAudio!.pause();
        setState(() => _isPlaying = false);
      } else {
        setState(() => _isLoading = true);
        _webAudio!.play();
        setState(() {
          _isPlaying = true;
          _isLoading = false;
          _hasError = false;
        });
      }
    } else {
      _openExternal();
    }
  }

  void _seekTo(double value) {
    if (kIsWeb && _webAudio != null) {
      _webAudio!.currentTime = value;
      setState(() => _positionSeconds = value);
    }
  }

  Future<void> _openExternal() async {
    final targetUrl = _effectiveAudioUrl ?? widget.audioUrl;
    final uri = Uri.tryParse(targetUrl);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String _formatDuration(double seconds) {
    if (seconds <= 0 || seconds.isNaN) return '0:00';
    final mins = (seconds / 60).floor();
    final secs = (seconds % 60).floor();
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.bgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _hasError ? AppTheme.warning.withValues(alpha: 0.5) : AppTheme.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.graphic_eq_rounded, size: 16, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text(
                widget.title,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              if (_hasError)
                TextButton.icon(
                  onPressed: _resolveAndInit,
                  icon: const Icon(Icons.refresh_rounded, size: 14),
                  label: const Text('Retry', style: TextStyle(fontSize: 11)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              IconButton(
                tooltip: 'Open in new tab',
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                color: AppTheme.textMuted,
                onPressed: _openExternal,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Material(
                color: _hasError ? AppTheme.warning : AppTheme.primary,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: _togglePlay,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: _isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Icon(
                            _isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            size: 20,
                            color: Colors.white,
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  children: [
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 4,
                        thumbShape:
                            const RoundSliderThumbShape(enabledThumbRadius: 6),
                        overlayShape:
                            const RoundSliderOverlayShape(overlayRadius: 12),
                        activeTrackColor: AppTheme.primary,
                        inactiveTrackColor: AppTheme.stroke,
                        thumbColor: AppTheme.primary,
                      ),
                      child: Slider(
                        value: _positionSeconds.clamp(
                            0.0, _durationSeconds > 0 ? _durationSeconds : 1.0),
                        max: _durationSeconds > 0 ? _durationSeconds : 1.0,
                        onChanged: _durationSeconds > 0 ? _seekTo : null,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatDuration(_positionSeconds),
                            style: TextStyle(
                              fontSize: 10.5,
                              color: AppTheme.textMuted,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                            ),
                          ),
                          Text(
                            _durationSeconds > 0
                                ? _formatDuration(_durationSeconds)
                                : (_isPlaying ? 'Playing…' : 'Ready to play'),
                            style: TextStyle(
                              fontSize: 10.5,
                              color: AppTheme.textMuted,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

