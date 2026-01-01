import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:voiceup/features/chat/widgets/voice_recorder.dart';

/// Bottom input bar for sending messages.
/// 
/// Features:
/// - Text field with send button
/// - Photo attachment button
/// - Voice recording button (hold to record)
class TextInputBar extends StatefulWidget {
  final Function(String text) onSendText;
  final Function(File photo) onSendPhoto;
  final Function(File audio, int durationSeconds) onSendVoice;

  const TextInputBar({
    super.key,
    required this.onSendText,
    required this.onSendPhoto,
    required this.onSendVoice,
  });

  @override
  State<TextInputBar> createState() => _TextInputBarState();
}

class _TextInputBarState extends State<TextInputBar> {
  final TextEditingController _textController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _textController.addListener(() {
      setState(() {
        _hasText = _textController.text.trim().isNotEmpty;
      });
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _handleSendText() {
    final text = _textController.text.trim();
    if (text.isNotEmpty) {
      widget.onSendText(text);
      _textController.clear();
    }
  }

  Future<void> _handlePickPhoto() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image != null) {
        final file = File(image.path);
        widget.onSendPhoto(file);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick photo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Photo attachment button
            IconButton(
              icon: const Icon(Icons.photo, color: Colors.deepPurple),
              onPressed: _handlePickPhoto,
            ),
            // Text input field
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _textController,
                  decoration: const InputDecoration(
                    hintText: 'Type a message...',
                    border: InputBorder.none,
                  ),
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                  onSubmitted: (_) => _handleSendText(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Send button or voice recorder
            if (_hasText)
              IconButton(
                icon: const Icon(Icons.send, color: Colors.deepPurple),
                onPressed: _handleSendText,
              )
            else
              VoiceRecorder(
                onRecordingComplete: widget.onSendVoice,
                onCancel: () {
                  // Handle cancel if needed
                },
              ),
          ],
        ),
      ),
    );
  }
}
