import 'dart:js_interop';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ivr_frontend/config/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:web/web.dart' as web;

/// Interactive Audio Player for Voicebot Call Recordings.
///
/// Supports in-browser streaming, play/pause, seek scrubber,
/// elapsed & total duration display, and download/open in new tab.
class IvrAudioPlayer extends StatefulWidget {
  const IvrAudioPlayer({
    super.key,
    required this.audioUrl,
    this.title = 'Call Recording',
  });

  final String audioUrl;
  final String title;

  @override
  State<IvrAudioPlayer> createState() => _IvrAudioPlayerState();
}

class _IvrAudioPlayerState extends State<IvrAudioPlayer> {
  web.HTMLAudioElement? _webAudio;
  bool _isPlaying = false;
  bool _isLoading = false;
  double _positionSeconds = 0.0;
  double _durationSeconds = 0.0;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _initWebAudio();
    }
  }

  void _initWebAudio() {
    try {
      final audio = web.HTMLAudioElement();
      audio.src = widget.audioUrl;
      audio.preload = 'metadata';

      audio.addEventListener(
        'loadedmetadata',
        ((web.Event _) {
          if (mounted) {
            setState(() {
              _durationSeconds =
                  audio.duration.isFinite ? audio.duration : 0.0;
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
            });
          }
        }).toJS,
      );

      _webAudio = audio;
    } catch (_) {
      // Fallback gracefully
    }
  }

  @override
  void dispose() {
    if (kIsWeb && _webAudio != null) {
      _webAudio?.pause();
      _webAudio?.src = '';
    }
    super.dispose();
  }

  void _togglePlay() {
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
    final uri = Uri.tryParse(widget.audioUrl);
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
        border: Border.all(color: AppTheme.stroke),
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
                color: AppTheme.primary,
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
                            _formatDuration(_durationSeconds),
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
