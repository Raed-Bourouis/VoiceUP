import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

/// Widget for playing voice messages. 
/// 
/// Features:
/// - Play/pause button
/// - Progress bar
/// - Duration display
class VoicePlayer extends StatefulWidget {
  final String audioUrl;
  final int duration; // Duration in seconds
  final Color color;

  const VoicePlayer({
    super.key,
    required this.audioUrl,
    required this.duration,
    this.color = Colors.deepPurple,
  });

  @override
  State<VoicePlayer> createState() => _VoicePlayerState();
}

class _VoicePlayerState extends State<VoicePlayer> {
  late AudioPlayer _audioPlayer;
  bool _isPlaying = false;
  bool _isLoading = false;
  bool _hasError = false;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _totalDuration = Duration(seconds: widget.duration);
    _setupAudioPlayer();
  }

  void _setupAudioPlayer() {
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
          _isLoading = state == PlayerState.stopped && _isLoading;
        });
      }
    });

    _audioPlayer.onPositionChanged.listen((position) {
      if (mounted) {
        setState(() {
          _currentPosition = position;
        });
      }
    });

    _audioPlayer.onDurationChanged.listen((duration) {
      if (mounted && duration. inSeconds > 0) {
        setState(() {
          _totalDuration = duration;
        });
      }
    });

    _audioPlayer. onPlayerComplete.listen((event) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _currentPosition = Duration.zero;
        });
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _togglePlayPause() async {
    if (_hasError) {
      // Reset error state and try again
      setState(() {
        _hasError = false;
      });
    }

    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
      } else {
        setState(() {
          _isLoading = true;
        });

        if (_currentPosition == Duration.zero) {
          await _audioPlayer.play(UrlSource(widget.audioUrl));
        } else {
          await _audioPlayer.resume();
        }

        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to play audio: ${e.toString().substring(0, 50)}...'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = _totalDuration. inMilliseconds > 0
        ? _currentPosition.inMilliseconds / _totalDuration.inMilliseconds
        : 0.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Play/Pause/Loading button
        SizedBox(
          width: 40,
          height: 40,
          child: _isLoading
              ?  Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: widget.color,
                  ),
                )
              : IconButton(
                  padding: EdgeInsets.zero,
                  icon: Icon(
                    _hasError
                        ? Icons.error_outline
                        : (_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled),
                    color: _hasError ? Colors.red : widget.color,
                    size: 32,
                  ),
                  onPressed: _togglePlayPause,
                ),
        ),
        const SizedBox(width: 8),
        // Progress and duration
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: progress. clamp(0.0, 1.0),
                  backgroundColor: widget.color.withOpacity(0.3),
                  valueColor: AlwaysStoppedAnimation<Color>(widget.color),
                  minHeight: 4,
                ),
              ),
              const SizedBox(height:  4),
              // Duration text
              Text(
                '${_formatDuration(_currentPosition)} / ${_formatDuration(_totalDuration)}',
                style: TextStyle(
                  fontSize: 11,
                  color: widget. color. withOpacity(0.8),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(1, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}