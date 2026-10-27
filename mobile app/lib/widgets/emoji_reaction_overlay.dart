import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/emoji_reaction_provider.dart';
import 'animated_room_reaction.dart';

class EmojiReactionOverlay extends StatelessWidget {
  final String roomId;
  final Offset? fallbackPosition;
  final bool isLiveRoom;

  const EmojiReactionOverlay({
    super.key,
    required this.roomId,
    this.fallbackPosition,
    this.isLiveRoom = false,
  });

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final size = mediaQuery.size;
    final keyboardHeight = mediaQuery.viewInsets.bottom;
    final topPadding = mediaQuery.padding.top;

    // Calculate central stage bounds accounting for safe insets, header, and keyboard
    final headerBottom = topPadding + 64.0;
    final bottomControlsHeight = keyboardHeight > 0 ? 0.0 : (64.0 + mediaQuery.padding.bottom);
    final visibleStageTop = headerBottom;
    final visibleStageBottom = size.height - keyboardHeight - bottomControlsHeight;
    final liveCenterY = visibleStageTop + ((visibleStageBottom - visibleStageTop) / 2);
    final liveCenterX = size.width / 2;
    final liveStageCenter = Offset(liveCenterX, liveCenterY);

    final defaultFallback = fallbackPosition ?? (isLiveRoom ? liveStageCenter : Offset(size.width * 0.5, size.height * 0.48));

    return IgnorePointer(
      child: Consumer<EmojiReactionProvider>(
        builder: (context, provider, child) {
          // If not in a Live Video room (e.g. in Party Room), do not render overlay in the center.
          // Reactions in Party Rooms appear exclusively on the user's seat!
          if (!isLiveRoom) return const SizedBox.shrink();

          final activeReactions = provider.activeReactions;
          if (activeReactions.isEmpty) return const SizedBox.shrink();

          return Stack(
            clipBehavior: Clip.none,
            children: activeReactions.map((reaction) {
              Offset startPos;
              bool isSeated = false;

              if (isLiveRoom) {
                // In live rooms, center reaction by its visual center on the central live room stage
                startPos = liveStageCenter;
              } else {
                // 1. Try position by seatId anchor (Party Room)
                Offset? seatPos;
                if (reaction.seatId != null) {
                  seatPos = provider.getAnchorPosition('party_seat_${reaction.seatId}');
                  if (seatPos != null) isSeated = true;
                }

                // 2. Try position by senderId anchor
                if (seatPos == null) {
                  seatPos = provider.getAnchorPosition('user_${reaction.senderId}');
                  if (seatPos != null) isSeated = true;
                }

                // 3. Fallback position for audience / non-seated
                startPos = seatPos ?? defaultFallback;
              }

              final double reactionSize = isLiveRoom
                  ? (size.width * 0.35).clamp(120.0, 140.0)
                  : (isSeated ? 76.0 : 120.0);

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
