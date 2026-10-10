import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../models/message_model.dart';
import '../core/utils/formatters.dart';
import '../features/social/short_videos_screen.dart';
import '../providers/backpack_provider.dart';

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
    if (widget.message.isExpired) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⏳ Media not available. Voice note expired after 1 month to conserve storage.'),
          backgroundColor: Colors.orangeAccent,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    if (_isPlayingVoice) {
      _playbackTimer?.cancel();
      await _audioController?.pause();
      if (mounted) {
        setState(() {
          _isPlayingVoice = false;
        });
      }
    } else {
      final mediaUrl = widget.message.mediaUrl;
      if (mediaUrl == null || mediaUrl.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Media not available or has expired.'),
            backgroundColor: Colors.orangeAccent,
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }

      setState(() {
        _isPlayingVoice = true;
        _playbackProgress = 0.0;
      });

      try {
        _audioController?.dispose();
        if (mediaUrl.startsWith('http') || mediaUrl.startsWith('https')) {
          _audioController = VideoPlayerController.networkUrl(Uri.parse(mediaUrl));
        } else {
          _audioController = VideoPlayerController.file(File(mediaUrl));
        }
        await _audioController?.initialize();
        await _audioController?.setVolume(1.0);
        await _audioController?.play();
      } catch (e) {
        debugPrint('Voice note playback error: $e');
        _playbackTimer?.cancel();
        if (mounted) {
          setState(() {
            _isPlayingVoice = false;
            _playbackProgress = 0.0;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ Media not available'),
              backgroundColor: Colors.redAccent,
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }
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
    if (widget.message.isExpired) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⏳ Media not available. Image expired after 1 month to conserve storage.'),
          backgroundColor: Colors.orangeAccent,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }
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
    final isExpired = widget.message.isExpired;
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
    final backpack = context.watch<BackpackProvider>();
    final equippedBubble = widget.isMe ? backpack.equippedBubbleUrl : null;
    final hasCustomBubble = equippedBubble != null && equippedBubble.isNotEmpty;

    final bubbleColor = widget.isMe
        ? primaryColor
        : Theme.of(context).colorScheme.surfaceContainerHighest;

    final textColor = widget.isMe
        ? (hasCustomBubble ? Colors.white : onPrimary)
        : Theme.of(context).textTheme.bodyLarge?.color;

    return Align(
      alignment: widget.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        padding: isImage
            ? const EdgeInsets.all(4)
            : (hasCustomBubble
                ? const EdgeInsets.fromLTRB(20, 12, 20, 12)
                : const EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.76),
        decoration: BoxDecoration(
          color: isGift
              ? (isDark ? const Color(0xFF2A153E) : const Color(0xFFF3E5F5))
              : (hasCustomBubble ? Colors.transparent : bubbleColor),
          image: hasCustomBubble
              ? DecorationImage(
                  image: (equippedBubble.startsWith('http://') || equippedBubble.startsWith('https://'))
                      ? NetworkImage(equippedBubble) as ImageProvider
                      : AssetImage(equippedBubble),
                  fit: BoxFit.fill,
                )
              : null,
          borderRadius: hasCustomBubble
              ? BorderRadius.circular(16)
              : BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(widget.isMe ? 16 : 4),
                  bottomRight: Radius.circular(widget.isMe ? 4 : 16),
                ),
          border: isGift ? Border.all(color: Colors.purpleAccent, width: 1.5) : null,
          boxShadow: hasCustomBubble
              ? null
              : [
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
            if (isImage && isExpired) ...[
              // ─── Expired Image Placeholder ───
              Container(
                width: 220,
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.image_not_supported_outlined, color: Colors.white60, size: 36),
                    SizedBox(height: 6),
                    Text(
                      'Media not available',
                      style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Expired after 1 month to manage storage',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white54, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ] else if (isImage && mediaPath != null) ...[
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
                        color: isExpired
                            ? Colors.grey.withValues(alpha: 0.3)
                            : (widget.isMe ? Colors.white.withValues(alpha: 0.25) : primaryColor.withValues(alpha: 0.2)),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isExpired
                            ? Icons.timer_off_outlined
                            : (_isPlayingVoice ? Icons.pause_rounded : Icons.play_arrow_rounded),
                        color: isExpired ? Colors.white60 : textColor,
                        size: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!isExpired) ...[
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
                      ] else ...[
                        Text(
                          'Media not available',
                          style: TextStyle(color: textColor ?? Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Expired after 1 month to reduce storage',
                          style: TextStyle(color: textColor?.withValues(alpha: 0.65) ?? Colors.white60, fontSize: 10),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ] else if (widget.message.text.contains('zeparty.app/short/')) ...[
              // ─── Clickable Short Video Link Preview Card ───
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ShortVideosScreen()),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.play_circle_fill_rounded, color: AppColors.primary, size: 26),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.message.text,
                              style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.open_in_new_rounded, size: 12, color: AppColors.primary),
                            SizedBox(width: 4),
                            Text('Tap to Watch Short 🎬', style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              Text(
                widget.message.text,
                style: TextStyle(
                  color: textColor,
                  fontSize: 14,
                  fontWeight: hasCustomBubble ? FontWeight.w600 : FontWeight.normal,
                  shadows: hasCustomBubble
                      ? [const Shadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 1))]
                      : null,
                ),
              ),
            ],
            const SizedBox(height: 4),
            Padding(
              padding: isImage ? const EdgeInsets.only(right: 6, bottom: 4) : EdgeInsets.zero,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    AppFormatters.formatTimeAgo(widget.message.timestamp),
                    style: TextStyle(
                      color: widget.isMe
                          ? (hasCustomBubble ? Colors.white.withValues(alpha: 0.9) : onPrimary.withValues(alpha: 0.75))
                          : Theme.of(context).textTheme.bodySmall?.color,
                      fontSize: 10,
                      fontWeight: hasCustomBubble ? FontWeight.bold : FontWeight.normal,
                      shadows: hasCustomBubble
                          ? [const Shadow(color: Colors.black45, blurRadius: 3, offset: Offset(0, 1))]
                          : null,
                    ),
                  ),
                  if (widget.isMe) ...[
                    const SizedBox(width: 4),
                    _buildReadReceiptIcon(widget.message.status, onPrimary),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReadReceiptIcon(MessageStatus status, Color onPrimaryColor) {
    switch (status) {
      case MessageStatus.sent:
        // Single Tick (Grey / Translucent) -> Sent / Recipient Offline
        return Icon(
          Icons.check_rounded,
          size: 14,
          color: onPrimaryColor.withValues(alpha: 0.65),
        );
      case MessageStatus.delivered:
        // Double Tick (Grey / Translucent) -> Delivered / Recipient Online
        return Icon(
          Icons.done_all_rounded,
          size: 15,
          color: onPrimaryColor.withValues(alpha: 0.75),
        );
      case MessageStatus.read:
        // Double Tick (Colorful / Vibrant Cyan/Gold) -> Read by Recipient
        return const Icon(
          Icons.done_all_rounded,
          size: 15,
          color: Color(0xFF00E5FF),
        );
    }
  }
}
