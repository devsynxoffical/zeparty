import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../providers/room_overlay_provider.dart';
import '../providers/live_provider.dart';
import '../providers/live_party_provider.dart';

class FloatingRoomOverlay extends StatefulWidget {
  const FloatingRoomOverlay({super.key});

  @override
  State<FloatingRoomOverlay> createState() => _FloatingRoomOverlayState();
}

class _FloatingRoomOverlayState extends State<FloatingRoomOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RoomOverlayProvider>(
      builder: (context, overlayProvider, child) {
        if (!overlayProvider.isMinimized || overlayProvider.activeRoom == null) {
          return const SizedBox.shrink();
        }

        final room = overlayProvider.activeRoom!;
        final isLive = overlayProvider.roomType == 'LIVE';
        final screenSize = MediaQuery.of(context).size;

        return Positioned(
          left: overlayProvider.position.dx,
          top: overlayProvider.position.dy,
          child: GestureDetector(
            onPanUpdate: (details) {
              overlayProvider.updatePosition(details.delta, screenSize);
            },
            onTap: () {
              overlayProvider.expandRoom(context);
            },
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 145,
                height: 195,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.45),
                      blurRadius: 16,
                      spreadRadius: 2,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.black.withValues(alpha: 0.75),
                            Colors.purple.shade900.withValues(alpha: 0.65),
                            Colors.black.withValues(alpha: 0.85),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isLive
                              ? AppColors.liveRed.withValues(alpha: 0.6)
                              : Colors.amber.withValues(alpha: 0.6),
                          width: 1.5,
                        ),
                      ),
                      child: Stack(
                        children: [
                          // Background Image or Avatar Blur
                          if (room.coverUrl.isNotEmpty)
                            Positioned.fill(
                              child: Opacity(
                                opacity: 0.35,
                                child: Image.network(
                                  room.coverUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                                ),
                              ),
                            ),

                          // Content Column
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Top Header Row: Room Type Pill & Close Button
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    // Room Type Badge
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isLive ? AppColors.liveRed : Colors.amber.shade700,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          ScaleTransition(
                                            scale: _pulseAnimation,
                                            child: Container(
                                              width: 5,
                                              height: 5,
                                              decoration: const BoxDecoration(
                                                color: Colors.white,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 3),
                                          Text(
                                            isLive ? 'LIVE' : 'PARTY',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Close Button (X)
                                    GestureDetector(
                                      onTap: () {
                                        overlayProvider.closeRoom(context);
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(3),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(alpha: 0.4),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.close_rounded,
                                          color: Colors.white,
                                          size: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                // Center Host Avatar & Pulsing Audio Ring
                                Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    ScaleTransition(
                                      scale: _pulseAnimation,
                                      child: Container(
                                        width: 54,
                                        height: 54,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: isLive
                                                ? AppColors.liveRed.withValues(alpha: 0.8)
                                                : Colors.amberAccent.withValues(alpha: 0.8),
                                            width: 2,
                                          ),
                                        ),
                                      ),
                                    ),
                                    CircleAvatar(
                                      radius: 23,
                                      backgroundColor: Colors.grey.shade800,
                                      backgroundImage: room.host.avatarUrl.isNotEmpty
                                          ? NetworkImage(room.host.avatarUrl)
                                          : null,
                                      child: room.host.avatarUrl.isEmpty
                                          ? Text(
                                              room.host.name.isNotEmpty
                                                  ? room.host.name[0].toUpperCase()
                                                  : 'Z',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            )
                                          : null,
                                    ),
                                  ],
                                ),

                                // Room Title & Host Name
                                Column(
                                  children: [
                                    Text(
                                      room.title.isNotEmpty ? room.title : room.host.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 1),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Icons.remove_red_eye_rounded,
                                          color: Colors.white70,
                                          size: 10,
                                        ),
                                        const SizedBox(width: 3),
                                        Text(
                                          '${room.viewerCount}',
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),

                                // Bottom Action Controls: Expand & Mic Toggle
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    // Expand Full Screen Button
                                    GestureDetector(
                                      onTap: () => overlayProvider.expandRoom(context),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: const Row(
                                          children: [
                                            Icon(
                                              Icons.open_in_full_rounded,
                                              color: Colors.white,
                                              size: 12,
                                            ),
                                            SizedBox(width: 3),
                                            Text(
                                              'Expand',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),

                                    // Quick Mic Mute Toggle
                                    Consumer2<LiveProvider, LivePartyProvider>(
                                      builder: (ctx, liveProv, partyProv, _) {
                                        final isMicMuted = isLive
                                            ? liveProv.isMicMuted
                                            : partyProv.isLocalMicMuted;

                                        return GestureDetector(
                                          onTap: () {
                                            if (isLive) {
                                              liveProv.toggleLocalMic();
                                            } else {
                                              partyProv.toggleLocalMic();
                                            }
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: isMicMuted
                                                  ? Colors.red.withValues(alpha: 0.5)
                                                  : Colors.green.withValues(alpha: 0.5),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              isMicMuted
                                                  ? Icons.mic_off_rounded
                                                  : Icons.mic_rounded,
                                              color: Colors.white,
                                              size: 12,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
