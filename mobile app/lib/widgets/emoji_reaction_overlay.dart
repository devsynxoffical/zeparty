import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/emoji_reaction_provider.dart';
import 'animated_emoji_reaction.dart';

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
    final defaultFallback = fallbackPosition ?? Offset(size.width * 0.5, size.height * 0.72);

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
              if (reaction.seatId != null) {
                startPos = provider.getAnchorPosition('party_seat_${reaction.seatId}');
              }

              // 2. Try position by senderId anchor
              startPos ??= provider.getAnchorPosition('user_${reaction.senderId}');

              // 3. Try host anchor fallback
              startPos ??= provider.getAnchorPosition('live_host_avatar');

              // 4. Default screen position fallback
              startPos ??= defaultFallback;

              return AnimatedEmojiReaction(
                key: ValueKey('anim_${reaction.reactionId}'),
                emoji: reaction.emoji,
                startPosition: startPos,
                onComplete: () {
                  provider.removeReaction(reaction.reactionId);
                },
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
