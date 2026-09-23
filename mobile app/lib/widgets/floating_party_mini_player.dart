import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/live_party_provider.dart';
import '../features/party_room/live_party_room_screen.dart';

class FloatingPartyMiniPlayer extends StatefulWidget {
  const FloatingPartyMiniPlayer({super.key});

  @override
  State<FloatingPartyMiniPlayer> createState() => _FloatingPartyMiniPlayerState();
}

class _FloatingPartyMiniPlayerState extends State<FloatingPartyMiniPlayer> with SingleTickerProviderStateMixin {
  Offset? _position;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LivePartyProvider>();

    if (!provider.isMinimized || provider.activeRoom == null) {
      return const SizedBox.shrink();
    }

    final room = provider.activeRoom!;
    final screenSize = MediaQuery.of(context).size;

    // Default position at bottom-right above standard bottom navigation bar
    final defaultOffset = Offset(
      screenSize.width - 230,
      screenSize.height - 180,
    );

    final currentOffset = _position ?? defaultOffset;

    // Constrain position within visible screen bounds
    final clampedX = currentOffset.dx.clamp(10.0, screenSize.width - 230);
    final clampedY = currentOffset.dy.clamp(50.0, screenSize.height - 120);

    return Positioned(
      left: clampedX,
      top: clampedY,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _position = Offset(
              clampedX + details.delta.dx,
              clampedY + details.delta.dy,
            );
          });
        },
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 220,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF23143B), Color(0xFF130924)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: const Color(0xFFB524E4).withValues(alpha: 0.8),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFB524E4).withValues(alpha: 0.45),
                  blurRadius: 16,
                  spreadRadius: 1,
                  offset: const Offset(0, 4),
                ),
                const BoxShadow(
                  color: Colors.black87,
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Animated Live Equalizer / Cover Avatar
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.amber, width: 1.5),
                      ),
                      child: ClipOval(
                        child: room.coverUrl.isNotEmpty
                            ? Image.network(
                                room.coverUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _buildPlaceholderAvatar(room.title),
                              )
                            : _buildPlaceholderAvatar(room.title),
                      ),
                    ),
                    Positioned(
                      bottom: -2,
                      right: -2,
                      child: AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          return Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Color.lerp(const Color(0xFF00E676), const Color(0xFF00B0FF), _pulseController.value),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.graphic_eq_rounded, color: Colors.white, size: 9),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),

                // Room Title & Host Info
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        room.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.mic, color: Color(0xFF00E676), size: 10),
                          const SizedBox(width: 2),
                          Flexible(
                            child: Text(
                              room.host.name.isNotEmpty ? room.host.name : 'Party Room',
                              style: const TextStyle(
                                color: Color(0xFF00E676),
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Expand Full Screen Button
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                  icon: const Icon(Icons.fullscreen_rounded, color: Colors.cyanAccent, size: 22),
                  onPressed: () {
                    provider.setMinimized(false);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => LivePartyRoomScreen(room: room),
                      ),
                    );
                  },
                ),

                // Close / Leave Room Button
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                  icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 18),
                  onPressed: () {
                    provider.setMinimized(false);
                    provider.leaveParty();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderAvatar(String title) {
    return Container(
      color: const Color(0xFF7B1FA2),
      alignment: Alignment.center,
      child: Text(
        title.isNotEmpty ? title[0].toUpperCase() : 'P',
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
      ),
    );
  }
}
