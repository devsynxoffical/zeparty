import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../core/theme/app_colors.dart';
import '../models/message_model.dart';
import '../core/utils/formatters.dart';

class ChatBubble extends StatefulWidget {
  final MessageModel message;
  final bool isMe;

  const ChatBubble({super.key, required this.message, required this.isMe});

  @override
  State<ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<ChatBubble> {
  bool _isPlayingVoice = false;
  double _playbackProgress = 0.0;
  Timer? _playbackTimer;
  VideoPlayerController? _audioController;

  @override
  void dispose() {
    _playbackTimer?.cancel();
    _audioController?.dispose();
    super.dispose();
  }

  Future<void> _toggleVoicePlayback() async {
    if (_isPlayingVoice) {
      _playbackTimer?.cancel();
      await _audioController?.pause();
      if (mounted) {
        setState(() {
          _isPlayingVoice = false;
        });
      }
    } else {
      setState(() {
        _isPlayingVoice = true;
        _playbackProgress = 0.0;
      });

      try {
        final mediaUrl = widget.message.mediaUrl;
        if (mediaUrl != null && mediaUrl.isNotEmpty) {
          _audioController?.dispose();
          if (mediaUrl.startsWith('http')) {
            _audioController = VideoPlayerController.networkUrl(Uri.parse(mediaUrl));
          } else {
            _audioController = VideoPlayerController.file(File(mediaUrl));
          }
          await _audioController?.initialize();
          await _audioController?.play();
        }
      } catch (e) {
        debugPrint('Voice note playback error: $e');
      }

      _playbackTimer = Timer.periodic(const Duration(milliseconds: 150), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        if (_audioController != null && _audioController!.value.isInitialized) {
          final pos = _audioController!.value.position;
          final dur = _audioController!.value.duration;
          if (dur.inMilliseconds > 0) {
            final prog = pos.inMilliseconds / dur.inMilliseconds;
            setState(() {
              _playbackProgress = prog.clamp(0.0, 1.0);
            });
            if (pos >= dur) {
              _playbackTimer?.cancel();
              setState(() {
                _isPlayingVoice = false;
                _playbackProgress = 1.0;
              });
            }
            return;
          }
        }

        setState(() {
          _playbackProgress += 0.04;
          if (_playbackProgress >= 1.0) {
            _playbackProgress = 1.0;
            _isPlayingVoice = false;
            timer.cancel();
          }
        });
      });
    }
  }

  void _showFullscreenImage(BuildContext context, String imagePath) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: File(imagePath).existsSync()
                    ? Image.file(File(imagePath), fit: BoxFit.contain)
                    : Image.network(imagePath, fit: BoxFit.contain),
              ),
            ),
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = AppColors.getPrimary(isDark);
    final onPrimary = AppColors.onPrimary(isDark: isDark);

    final mediaPath = widget.message.mediaUrl;
    final isVoice = widget.message.type == 'voice' ||
        widget.message.text.contains('🎤') ||
        (mediaPath != null && (mediaPath.endsWith('.m4a') || mediaPath.endsWith('.mp3')));

    final isImage = widget.message.type == 'image' ||
        (mediaPath != null &&
            !isVoice &&
            (mediaPath.endsWith('.jpg') ||
                mediaPath.endsWith('.jpeg') ||
                mediaPath.endsWith('.png') ||
                mediaPath.startsWith('/') ||
                mediaPath.contains('image')));

    final isGift = widget.message.type == 'gift' || widget.message.text.contains('🎁');

    final bubbleColor = widget.isMe
        ? primaryColor
        : Theme.of(context).colorScheme.surfaceContainerHighest;

    final textColor = widget.isMe
        ? onPrimary
        : Theme.of(context).textTheme.bodyLarge?.color;

    return Align(
      alignment: widget.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        padding: isImage ? const EdgeInsets.all(4) : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.76),
        decoration: BoxDecoration(
          color: isGift
              ? (isDark ? const Color(0xFF2A153E) : const Color(0xFFF3E5F5))
              : bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(widget.isMe ? 16 : 4),
            bottomRight: Radius.circular(widget.isMe ? 4 : 16),
          ),
          border: isGift ? Border.all(color: Colors.purpleAccent, width: 1.5) : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: widget.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (isImage && mediaPath != null) ...[
              // ─── Sent Image Thumbnail ───
              GestureDetector(
                onTap: () => _showFullscreenImage(context, mediaPath),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: File(mediaPath).existsSync()
                      ? Image.file(
                          File(mediaPath),
                          width: 220,
                          height: 180,
                          fit: BoxFit.cover,
                        )
                      : Image.network(
                          mediaPath,
                          width: 220,
                          height: 180,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            width: 220,
                            height: 120,
                            color: Colors.grey.shade800,
                            alignment: Alignment.center,
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.image_rounded, color: Colors.white54, size: 36),
                                SizedBox(height: 4),
                                Text('Image preview unavailable', style: TextStyle(color: Colors.white54, fontSize: 11)),
                              ],
                            ),
                          ),
                        ),
                ),
              ),
              if (widget.message.text.isNotEmpty && widget.message.text != '📷 Photo') ...[
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(widget.message.text, style: TextStyle(color: textColor, fontSize: 13)),
                ),
              ],
            ] else if (isGift) ...[
              // ─── Gift Bubble ───
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.purple.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      widget.message.mediaUrl ?? '🎁',
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.message.text,
                        style: TextStyle(
                          color: isDark ? Colors.amberAccent : Colors.deepPurple,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.purpleAccent.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.diamond_rounded, size: 10, color: Colors.cyanAccent),
                            SizedBox(width: 3),
                            Text('Special Gift Sent', style: TextStyle(color: Colors.purpleAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ] else if (isVoice) ...[
              // ─── Playable Voice Note Bubble ───
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: _toggleVoicePlayback,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: widget.isMe ? Colors.white.withValues(alpha: 0.25) : primaryColor.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isPlayingVoice ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        color: textColor,
                        size: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: List.generate(14, (index) {
                          final barHeight = (index % 3 == 0 ? 16 : (index % 2 == 0 ? 10 : 22)).toDouble();
                          final isActive = (index / 14) <= _playbackProgress;
                          return Container(
                            width: 3,
                            height: barHeight,
                            margin: const EdgeInsets.symmetric(horizontal: 1.5),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? (widget.isMe ? Colors.white : primaryColor)
                                  : (widget.isMe ? Colors.white38 : Colors.grey.shade400),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isPlayingVoice
                            ? 'Playing voice note (${(_playbackProgress * 100).toInt()}%)'
                            : widget.message.text.contains('Voice Note')
                                ? widget.message.text
                                : 'Voice Note • Play',
                        style: TextStyle(color: textColor?.withValues(alpha: 0.8), fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ] else ...[
              Text(
                widget.message.text,
                style: TextStyle(color: textColor, fontSize: 14),
              ),
            ],
            const SizedBox(height: 4),
            Padding(
              padding: isImage ? const EdgeInsets.only(right: 6, bottom: 4) : EdgeInsets.zero,
              child: Text(
                AppFormatters.formatTimeAgo(widget.message.timestamp),
                style: TextStyle(
                  color: widget.isMe ? onPrimary.withValues(alpha: 0.7) : Theme.of(context).textTheme.bodySmall?.color,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
