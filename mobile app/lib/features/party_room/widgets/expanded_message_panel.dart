import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/live_party_provider.dart';
import '../../../providers/emoji_reaction_provider.dart';
import '../../../widgets/emoji_picker_sheet.dart';

class ExpandedMessagePanel extends StatefulWidget {
  final VoidCallback onOpenStickers;

  const ExpandedMessagePanel({
    super.key,
    required this.onOpenStickers,
  });

  static void show(BuildContext context, {required VoidCallback onOpenStickers}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: ExpandedMessagePanel(onOpenStickers: onOpenStickers),
      ),
    );
  }

  @override
  State<ExpandedMessagePanel> createState() => _ExpandedMessagePanelState();
}

class _ExpandedMessagePanelState extends State<ExpandedMessagePanel> {
  final TextEditingController _textController = TextEditingController();

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pickGalleryImage() async {
    try {
      final picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (pickedFile != null && mounted) {
        final currentUser = context.read<AuthProvider>().currentUser;
        final provider = context.read<LivePartyProvider>();

        provider.sendMessage(currentUser, '🖼️ [Photo]: ${pickedFile.name}');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Photo attached & sent: ${pickedFile.name} 📷'),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gallery option error: $e'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final provider = context.read<LivePartyProvider>();
    final currentUser = context.read<AuthProvider>().currentUser;

    provider.sendMessage(currentUser, text);
    final participant = provider.participants.where((p) => p.user.id == currentUser.id && p.seatNumber != null).firstOrNull;
    final seatId = participant?.seatNumber;
    context.read<EmojiReactionProvider>().sendReaction(
      roomId: provider.activeRoom?.id ?? 'room_101',
      senderId: currentUser.id,
      emoji: text,
      seatId: seatId,
      senderName: currentUser.name,
    );

    _textController.clear();
    Navigator.pop(context);
  }

  void _openEmojiPicker() {
    Navigator.pop(context);
    EmojiPickerSheet.show(context, onEmojiSelected: (emoji) {
      final provider = context.read<LivePartyProvider>();
      final currentUser = context.read<AuthProvider>().currentUser;
      provider.sendMessage(currentUser, emoji);

      final participant = provider.participants.where((p) => p.user.id == currentUser.id && p.seatNumber != null).firstOrNull;
      final seatId = participant?.seatNumber;

      context.read<EmojiReactionProvider>().sendReaction(
        roomId: provider.activeRoom?.id ?? 'room_101',
        senderId: currentUser.id,
        emoji: emoji,
        seatId: seatId,
        senderName: currentUser.name,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF231D33) : const Color(0xFF332946),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 16,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                // Gallery Picker Icon
                IconButton(
                  icon: const Icon(Icons.image_outlined, color: Colors.white70, size: 20),
                  onPressed: _pickGalleryImage,
                  tooltip: 'Gallery',
                ),

                // Text Input Field
                Expanded(
                  child: TextField(
                    controller: _textController,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    cursorColor: Colors.amber,
                    decoration: InputDecoration(
                      hintText: 'Say something...',
                      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 13),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),

                // Emoji Picker Icon
                IconButton(
                  icon: const Icon(Icons.sentiment_satisfied_alt_rounded, color: Colors.amber, size: 22),
                  onPressed: _openEmojiPicker,
                  tooltip: 'Emoji Reaction',
                ),

                // Send Message Button
                IconButton(
                  icon: const Icon(Icons.send_rounded, color: Colors.amber, size: 20),
                  onPressed: _sendMessage,
                  tooltip: 'Send',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
