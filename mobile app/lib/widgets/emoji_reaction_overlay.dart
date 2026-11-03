import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/emoji_reaction_provider.dart';
import '../providers/live_party_provider.dart';
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

    return IgnorePointer(
      child: Consumer<EmojiReactionProvider>(
        builder: (context, provider, child) {
          final activeReactions = provider.activeReactions;
          if (activeReactions.isEmpty) return const SizedBox.shrink();

          return Stack(
            clipBehavior: Clip.none,
            children: activeReactions.map((reaction) {
              Offset? startPos;

              if (isLiveRoom) {
                // In live rooms, center reaction by its visual center on the central live room stage
                startPos = liveStageCenter;
              } else {
                // Audio Party Room: Strictly seat-anchored rendering above mic seat
                int? effectiveSeatId = reaction.seatId;

                // Fallback: If seatId is not in the reaction payload, resolve via LivePartyProvider
                if (effectiveSeatId == null) {
                  try {
                    final partyProv = Provider.of<LivePartyProvider>(context, listen: false);
                    final occupant = partyProv.participants
                        .where((p) =>
                            (p.user.id == reaction.senderId ||
                             (p.user.username.isNotEmpty && p.user.username == reaction.senderId) ||
                             (p.user.publicUserId.isNotEmpty && p.user.publicUserId == reaction.senderId)) &&
                            p.seatNumber != null)
                        .firstOrNull;
                    effectiveSeatId = occupant?.seatNumber;

                    if (effectiveSeatId == null) {
                      final isHost = partyProv.isHost ||
                          partyProv.activeRoom?.host.id == reaction.senderId ||
                          partyProv.activeRoom?.creatorUserId == reaction.senderId ||
                          (partyProv.activeRoom?.host.username.isNotEmpty == true &&
                           partyProv.activeRoom?.host.username.toLowerCase() == reaction.senderId.toLowerCase()) ||
                          (partyProv.activeRoom?.host.publicUserId.isNotEmpty == true &&
                           partyProv.activeRoom?.host.publicUserId == reaction.senderId);
                      if (isHost) {
                        effectiveSeatId = 0;
                      }
                    }
                  } catch (_) {}
                }

                // 1. Try position by seatId anchor (party_seat_{seatId})
                if (effectiveSeatId != null) {
                  startPos = provider.getAnchorPosition('party_seat_$effectiveSeatId');
                }

                // 2. Try position by senderId anchor
                startPos ??= provider.getAnchorPosition('user_${reaction.senderId}');

                // In Audio Party Rooms, do not enable unwanted center screen reactions.
                // Only render if a valid seat anchor was resolved.
                if (startPos == null) {
                  return const SizedBox.shrink();
                }
              }

              final double reactionSize = isLiveRoom
                  ? (size.width * 0.35).clamp(120.0, 140.0)
                  : 84.0;

              // In Audio Party Room, render floating smoothly above the microphone seat
              final double topPos = isLiveRoom
                  ? (startPos.dy - (reactionSize / 2))
                  : (startPos.dy - reactionSize * 0.85);

              return Positioned(
                left: startPos.dx - (reactionSize / 2),
                top: topPos,
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
