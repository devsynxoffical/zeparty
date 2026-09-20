import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/party_participant_model.dart';
import '../providers/live_party_provider.dart';
import '../providers/emoji_reaction_provider.dart';
import '../core/utils/noble_badge_helper.dart';
import 'pulse_glow_avatar.dart';
import 'user_avatar.dart';

class MultiRoleSeatGrid extends StatelessWidget {
  final List<PartyParticipantModel> participants;
  final bool isDark;
  final int capacity;
  final Set<int> lockedSeats;
  final String micSizePreset; // 'Small', 'Medium', 'Large' (Default: Large)
  final Function(int) onSeatTap;
  final Function(PartyParticipantModel) onParticipantTap;

  const MultiRoleSeatGrid({
    super.key,
    required this.participants,
    required this.isDark,
    this.capacity = 10,
    this.lockedSeats = const {},
    this.micSizePreset = 'Large',
    required this.onSeatTap,
    required this.onParticipantTap,
  });

  double _getPresetScale() {
    switch (micSizePreset) {
      case 'Small':
        return 0.85;
      case 'Medium':
        return 1.0;
      case 'Large':
      default:
        return 1.25; // Default Large Mic Seats
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveCapacity = [10, 15, 20, 30].contains(capacity) ? capacity : 10;
    final scale = _getPresetScale();

    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.topCenter,
      child: SizedBox(
        width: MediaQuery.of(context).size.width,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: _buildSeatRows(context, effectiveCapacity, scale),
        ),
      ),
    );
  }

  List<Widget> _buildSeatRows(BuildContext context, int totalSeats, double scale) {
    final hostRad = 26.0 * scale;
    final seatRad = 22.0 * scale;

    if (totalSeats <= 10) {
      return [
        // Row 1: Host & Co-Host
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildSeat(context, 0, 'Host', hostRad, true),
              _buildSeat(context, 1, 'Co-Host', hostRad, true),
            ],
          ),
        ),
        // Row 2: 4 Seats
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(4, (i) => _buildSeat(context, i + 2, 'Seat ${i + 3}', seatRad, false)),
          ),
        ),
        // Row 3: 4 Seats
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(4, (i) => _buildSeat(context, i + 6, 'Seat ${i + 7}', seatRad, false)),
          ),
        ),
      ];
    } else if (totalSeats <= 15) {
      return [
        // Row 1: 3 Top Stage Seats
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 3),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildSeat(context, 0, 'Host', 24 * scale, true),
              _buildSeat(context, 1, 'Co-Host', 24 * scale, true),
              _buildSeat(context, 2, 'VIP', 24 * scale, false),
            ],
          ),
        ),
        // Row 2..4: 4 seats each (12 seats)
        ...List.generate(3, (rowIdx) {
          int startIdx = 3 + (rowIdx * 4);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(
                4,
                (colIdx) => _buildSeat(
                  context,
                  startIdx + colIdx,
                  'Seat ${startIdx + colIdx + 1}',
                  19 * scale,
                  false,
                ),
              ),
            ),
          );
        }),
      ];
    } else if (totalSeats <= 20) {
      return [
        // Row 1: 2 Host Seats
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 3),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildSeat(context, 0, 'Host', 22 * scale, true),
              _buildSeat(context, 1, 'Co-Host', 22 * scale, true),
            ],
          ),
        ),
        // Row 2..4: 6 seats each (18 seats)
        ...List.generate(3, (rowIdx) {
          int startIdx = 2 + (rowIdx * 6);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(
                6,
                (colIdx) {
                  int idx = startIdx + colIdx;
                  if (idx >= 20) return const SizedBox();
                  return _buildSeat(context, idx, 'Seat ${idx + 1}', 16.5 * scale, false);
                },
              ),
            ),
          );
        }),
      ];
    } else {
      // 30 Seats Layout
      return [
        // Row 1: 2 Host Seats
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildSeat(context, 0, 'Host', 20 * scale, true),
              _buildSeat(context, 1, 'Co-Host', 20 * scale, true),
            ],
          ),
        ),
        // Rows 2..5: 7 seats per row (28 seats)
        ...List.generate(4, (rowIdx) {
          int startIdx = 2 + (rowIdx * 7);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(
                7,
                (colIdx) {
                  int idx = startIdx + colIdx;
                  if (idx >= 30) return const SizedBox();
                  return _buildSeat(context, idx, '${idx + 1}', 14.5 * scale, false);
                },
              ),
            ),
          );
        }),
      ];
    }
  }

  Widget _buildSeat(BuildContext context, int seatIndex, String label, double radius, bool isHostRow) {
    final participant = participants.where((p) => p.seatNumber == seatIndex).firstOrNull;
    final isLocked = lockedSeats.contains(seatIndex);

    final emojiProv = context.read<EmojiReactionProvider>();
    var seatKey = emojiProv.getAnchorKey('party_seat_$seatIndex');
    if (seatKey == null) {
      seatKey = GlobalKey();
      emojiProv.registerAnchor('party_seat_$seatIndex', seatKey);
    }
    if (participant != null) {
      emojiProv.registerAnchor('user_${participant.user.id}', seatKey);
    }

    if (participant != null) {
      final isMuted = participant.micStatus == MicStatus.muted;
      final isHostUser = participant.role == ParticipantRole.host;
      final isMod = participant.role == ParticipantRole.moderator;

      final livePartyProv = context.watch<LivePartyProvider>();
      final activeReaction = livePartyProv.activeMicReactions[seatIndex];

      return GestureDetector(
        key: seatKey,
        onTap: () => onParticipantTap(participant),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                participant.isSpeaking
                    ? PulseGlowAvatar(
                        imageUrl: participant.user.avatarUrl,
                        name: participant.user.name,
                        radius: radius + 1,
                        glowColor: isHostUser ? Colors.amber : Colors.greenAccent,
                      )
                    : Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isHostUser
                                ? Colors.amber
                                : (isMod ? Colors.blueAccent : Colors.pinkAccent.withValues(alpha: 0.6)),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (isHostUser ? Colors.amber : Colors.purpleAccent).withValues(alpha: 0.2),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: UserAvatar(
                          imageUrl: participant.user.avatarUrl,
                          name: participant.user.name,
                          radius: radius,
                        ),
                      ),
                if (activeReaction != null)
                  Positioned(
                    top: -36,
                    child: TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 300),
                      tween: Tween(begin: 0.5, end: 1.0),
                      curve: Curves.elasticOut,
                      builder: (context, scale, child) {
                        return Transform.scale(
                          scale: scale,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.amberAccent, width: 1.5),
                              boxShadow: [
                                BoxShadow(color: Colors.pinkAccent.withValues(alpha: 0.6), blurRadius: 10, spreadRadius: 1),
                              ],
                            ),
                            child: Text(
                              activeReaction['reactionAsset'] ?? '🎉',
                              style: const TextStyle(fontSize: 20),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                if (isHostUser)
                  const Positioned(
                    top: -5,
                    child: Text('👑', style: TextStyle(fontSize: 12)),
                  ),
                if (isMod && !isHostUser)
                  const Positioned(
                    top: -5,
                    child: Text('🛡️', style: TextStyle(fontSize: 10)),
                  ),
                if (label == 'VIP' && !isHostUser && !isMod)
                  const Positioned(
                    top: -5,
                    child: Text('💎', style: TextStyle(fontSize: 10)),
                  ),
                Positioned(
                  bottom: -2,
                  right: -2,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: isMuted ? Colors.red : const Color(0xFF00C853),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black, width: 1),
                    ),
                    child: Icon(
                      isMuted ? Icons.mic_off : Icons.mic,
                      size: radius * 0.35,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(
              width: radius * 3.2,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      participant.user.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: NobleBadgeHelper.getColoredNicknameColor(
                          NobleBadgeHelper.getTierFromTitle(participant.user.nobleTitle),
                        ),
                        fontWeight: FontWeight.w600,
                        fontSize: isHostRow ? 10 : 8.5,
                      ),
                    ),
                  ),
                  NobleBadgeChip(user: participant.user, fontSize: 7),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Locked Seat State
    if (isLocked) {
      return GestureDetector(
        key: seatKey,
        onTap: () => onSeatTap(seatIndex),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: radius * 2,
              height: radius * 2,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.redAccent.withValues(alpha: 0.15),
                border: Border.all(
                  color: Colors.redAccent.withValues(alpha: 0.4),
                  width: 1.2,
                ),
              ),
              child: Center(
                child: Icon(
                  Icons.lock_rounded,
                  color: Colors.redAccent,
                  size: radius * 0.8,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Locked',
              style: TextStyle(
                color: Colors.redAccent.withValues(alpha: 0.8),
                fontSize: isHostRow ? 10 : 8.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    // Empty Seat
    return GestureDetector(
      key: seatKey,
      onTap: () => onSeatTap(seatIndex),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: radius * 2,
            height: radius * 2,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.05),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.18),
                width: 1.2,
              ),
            ),
            child: Center(
              child: Icon(
                Icons.mic_none_rounded,
                color: Colors.white.withValues(alpha: 0.4),
                size: radius * 0.8,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: isHostRow ? 10 : 8.5,
            ),
          ),
        ],
      ),
    );
  }
}
