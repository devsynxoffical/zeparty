import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/party_participant_model.dart';
import '../models/user_model.dart';
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
    final hostRad = 28.0 * scale;
    final seatRad = 24.0 * scale;

    if (totalSeats <= 10) {
      return [
        // Row 1: Host & Co-Host
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildSeat(context, 0, 'Host', hostRad, true),
              _buildSeat(context, 1, 'Co-Host', hostRad, true),
            ],
          ),
        ),
        // Row 2: 4 Seats (1 to 4)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(4, (i) => _buildSeat(context, i + 2, '${i + 1}', seatRad, false)),
          ),
        ),
        // Row 3: 4 Seats (5 to 8)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(4, (i) => _buildSeat(context, i + 6, '${i + 5}', seatRad, false)),
          ),
        ),
      ];
    } else if (totalSeats <= 15) {
      return [
        // Row 1: 3 Top Stage Seats
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 5),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildSeat(context, 0, 'Host', 26 * scale, true),
              _buildSeat(context, 1, 'Co-Host', 26 * scale, true),
              _buildSeat(context, 2, 'VIP', 26 * scale, false),
            ],
          ),
        ),
        // Row 2..4: 4 seats each (12 seats)
        ...List.generate(3, (rowIdx) {
          int startIdx = 3 + (rowIdx * 4);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(
                4,
                (colIdx) => _buildSeat(
                  context,
                  startIdx + colIdx,
                  '${startIdx + colIdx - 2}',
                  21 * scale,
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
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 5),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildSeat(context, 0, 'Host', 25 * scale, true),
              _buildSeat(context, 1, 'Co-Host', 25 * scale, true),
            ],
          ),
        ),
        // Row 2..4: 6 seats each (18 seats)
        ...List.generate(3, (rowIdx) {
          int startIdx = 2 + (rowIdx * 6);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(
                6,
                (colIdx) {
                  int idx = startIdx + colIdx;
                  if (idx >= 20) return const SizedBox();
                  return _buildSeat(context, idx, '${idx - 1}', 18.5 * scale, false);
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
          padding: const EdgeInsets.symmetric(horizontal: 35, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildSeat(context, 0, 'Host', 23 * scale, true),
              _buildSeat(context, 1, 'Co-Host', 23 * scale, true),
            ],
          ),
        ),
        // Rows 2..5: 7 seats per row (28 seats)
        ...List.generate(4, (rowIdx) {
          int startIdx = 2 + (rowIdx * 7);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(
                7,
                (colIdx) {
                  int idx = startIdx + colIdx;
                  if (idx >= 30) return const SizedBox();
                  return _buildSeat(context, idx, '${idx - 1}', 17 * scale, false);
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
                        glowColor: isHostUser ? Colors.amber : const Color(0xFF00E676),
                        frameAsset: NobleBadgeHelper.getFrameAsset(
                          participant.user.nobleTitle ?? (participant.user.svipLevel > 0 ? 'SVIP ${participant.user.svipLevel}' : (participant.user.role != UserRole.user ? participant.user.role.name : null)),
                        ),
                      )
                    : Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isHostUser
                                ? const Color(0xFFFFD700)
                                : (isMod ? const Color(0xFF40C4FF) : const Color(0xFFAB47BC).withValues(alpha: 0.8)),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (isHostUser ? Colors.amber : const Color(0xFFAB47BC)).withValues(alpha: 0.3),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: UserAvatar(
                          imageUrl: participant.user.avatarUrl,
                          name: participant.user.name,
                          radius: radius,
                          frameAsset: NobleBadgeHelper.getFrameAsset(
                            participant.user.nobleTitle ?? (participant.user.svipLevel > 0 ? 'SVIP ${participant.user.svipLevel}' : (participant.user.role != UserRole.user ? participant.user.role.name : null)),
                          ),
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
                    top: -6,
                    child: Text('👑', style: TextStyle(fontSize: 13)),
                  ),
                if (isMod && !isHostUser)
                  const Positioned(
                    top: -6,
                    child: Text('🛡️', style: TextStyle(fontSize: 11)),
                  ),
                if (label == 'VIP' && !isHostUser && !isMod)
                  const Positioned(
                    top: -6,
                    child: Text('💎', style: TextStyle(fontSize: 11)),
                  ),
                Positioned(
                  bottom: -2,
                  right: -2,
                  child: Container(
                    padding: const EdgeInsets.all(2.5),
                    decoration: BoxDecoration(
                      color: isMuted ? const Color(0xFFFF1744) : const Color(0xFF00E676),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF1E1338), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: (isMuted ? Colors.red : Colors.green).withValues(alpha: 0.5),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Icon(
                      isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                      size: radius * 0.38,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            SizedBox(
              width: radius * 3.4,
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
                        fontSize: isHostRow ? 10.5 : 9,
                      ),
                    ),
                  ),
                  NobleBadgeChip(user: participant.user, fontSize: 7),
                  NobleTagChip(user: participant.user, height: 11),
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
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF3E1A2E).withValues(alpha: 0.7),
                    const Color(0xFF200F1A).withValues(alpha: 0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: Colors.redAccent.withValues(alpha: 0.5),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.redAccent.withValues(alpha: 0.15),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  Icons.lock_rounded,
                  color: Colors.redAccent.withValues(alpha: 0.9),
                  size: radius * 0.75,
                ),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              'Locked',
              style: TextStyle(
                color: Colors.redAccent.withValues(alpha: 0.85),
                fontSize: isHostRow ? 10 : 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    // Empty Seat with Sleek Cushioned Chair Graphic (Ahlan Reference Match)
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
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF4A3468).withValues(alpha: 0.45),
                  const Color(0xFF281C40).withValues(alpha: 0.65),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.22),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Icon(
                Icons.weekend_rounded,
                color: Colors.white.withValues(alpha: 0.55),
                size: radius * 0.9,
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.65),
              fontSize: isHostRow ? 10 : 9.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
