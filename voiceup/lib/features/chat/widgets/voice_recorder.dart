import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

/// Widget for recording voice messages.
/// 
/// Features:
/// - Hold to record interaction
/// - Recording duration display
/// - Cancel by sliding left
/// - Visual feedback during recording
class VoiceRecorder extends StatefulWidget {
  final Function(File audioFile, int durationSeconds) onRecordingComplete;
  final VoidCallback onCancel;

  const VoiceRecorder({
    super.key,
    required this.onRecordingComplete,
    required this.onCancel,
  });

  @override
  State<VoiceRecorder> createState() => _VoiceRecorderState();
}

class _VoiceRecorderState extends State<VoiceRecorder> {
  final _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  int _recordDuration = 0;
  String? _audioPath;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    try {
      // Request microphone permission
      if (await Permission.microphone.request().isGranted) {
        // Get temporary directory
        final tempDir = await getTemporaryDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        _audioPath = '${tempDir.path}/voice_$timestamp.m4a';

        // Start recording
        await _audioRecorder.start(
          const RecordConfig(
            encoder: AudioEncoder.aacLc,
            bitRate: 128000,
            sampleRate: 44100,
          ),
          path: _audioPath!,
        );

        setState(() {
          _isRecording = true;
          _recordDuration = 0;
        });

        // Update duration
        _startTimer();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Microphone permission is required'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start recording: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _stopRecording() async {
    try {
      _timer?.cancel();
      final path = await _audioRecorder.stop();
      
      setState(() {
        _isRecording = false;
      });

      if (path != null && _recordDuration > 0) {
        final file = File(path);
        if (await file.exists()) {
          widget.onRecordingComplete(file, _recordDuration);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to stop recording: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _cancelRecording() async {
    try {
      _timer?.cancel();
      await _audioRecorder.stop();
      
      setState(() {
        _isRecording = false;
        _recordDuration = 0;
      });

      // Delete the recording file if it exists
      if (_audioPath != null) {
        final file = File(_audioPath!);
        if (await file.exists()) {
          await file.delete();
        }
      }

      widget.onCancel();
    } catch (e) {
      // Silently handle cancellation errors
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _isRecording) {
        setState(() {
          _recordDuration++;
        });
      } else {
        timer.cancel();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: (_) => _startRecording(),
      onLongPressEnd: (_) => _stopRecording(),
      onLongPressMoveUpdate: (details) {
        // Cancel if user slides left
        if (details.offsetFromOrigin.dx < -100) {
          _cancelRecording();
        }
      },
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: _isRecording ? Colors.red : Colors.deepPurple,
          shape: BoxShape.circle,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (_isRecording) ...[
              // Pulsing animation
              AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
              ),
              // Recording duration
              Positioned(
                top: -30,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    _formatDuration(_recordDuration),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
            Icon(
              _isRecording ? Icons.mic : Icons.mic_none,
              color: Colors.white,
              size: 28,
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(1, '0')}:${secs.toString().padLeft(2, '0')}';
  }
}
