import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/emoji_reaction_provider.dart';
import 'animated_room_reaction.dart';

class EmojiReactionOverlay extends StatelessWidget {
  final String roomId;
  final Offset? fallbackPosition;

  const EmojiReactionOverlay({
    super.key,
    required this.roomId,
    this.fallbackPosition,
  });

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final size = mediaQuery.size;
    final defaultFallback = fallbackPosition ?? Offset(size.width * 0.5, size.height * 0.48);

    return IgnorePointer(
      child: Consumer<EmojiReactionProvider>(
        builder: (context, provider, child) {
          final activeReactions = provider.activeReactions;
          if (activeReactions.isEmpty) return const SizedBox.shrink();

          return Stack(
            clipBehavior: Clip.none,
            children: activeReactions.map((reaction) {
              // 1. Try position by seatId anchor (Party Room)
              Offset? startPos;
              bool isSeated = false;
              if (reaction.seatId != null) {
                startPos = provider.getAnchorPosition('party_seat_${reaction.seatId}');
                if (startPos != null) isSeated = true;
              }

              // 2. Try position by senderId anchor
              if (startPos == null) {
                startPos = provider.getAnchorPosition('user_${reaction.senderId}');
                if (startPos != null) isSeated = true;
              }

              // 3. Try host anchor fallback
              startPos ??= provider.getAnchorPosition('live_host_avatar');

              // 4. Default screen position fallback (audience reaction above chat)
              startPos ??= defaultFallback;

              final double reactionSize = isSeated ? 100.0 : 120.0;

              return Positioned(
                left: startPos.dx - (reactionSize / 2),
                top: startPos.dy - (reactionSize / 2),
                child: AnimatedRoomReaction(
                  key: ValueKey('room_react_${reaction.reactionId}'),
                  emojiKey: reaction.emoji,
                  gameResult: reaction.gameResult,
                  size: reactionSize,
                  onComplete: () {
                    provider.removeReaction(reaction.reactionId);
                  },
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
