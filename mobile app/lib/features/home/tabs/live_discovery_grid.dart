import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_colors.dart';
import '../../../widgets/live_room_card.dart';
import '../../../widgets/party_room_card.dart';
import '../../../core/animations/app_animations.dart';
import '../../live/live_room_screen.dart';
import '../../party_room/live_party_room_screen.dart';
import '../../../models/live_room_model.dart';

class LiveDiscoveryGrid extends StatelessWidget {
  final List<LiveRoomModel> liveRooms;
  final bool isDark;
  final bool isPartyTab;

  const LiveDiscoveryGrid({
    super.key,
    required this.liveRooms,
    required this.isDark,
    this.isPartyTab = false,
  });

  @override
  Widget build(BuildContext context) {
    final roomsToDisplay = liveRooms;

    if (roomsToDisplay.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1B2E) : const Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isPartyTab ? Icons.mic_external_off_rounded : Icons.live_tv_rounded,
                  size: 48,
                  color: isDark ? AppColors.warmGold.withValues(alpha: 0.6) : AppColors.royalBlue.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isPartyTab ? 'No Party Rooms Active' : 'No Live Streams Active',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                isPartyTab ? 'Start an audio party room and invite friends!' : 'Go live and connect with your audience!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark ? Colors.white60 : Colors.black54,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.only(left: 14, right: 14, top: 4, bottom: 90),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 1.sw > 900 ? 4 : (1.sw > 600 ? 3 : 2),
        childAspectRatio: 0.82,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: roomsToDisplay.length,
      itemBuilder: (context, index) {
        final room = roomsToDisplay[index];
        final isLiveVideo = room.roomType == 'LIVE_VIDEO' || room.roomType == 'Video Room';

        return FadeScaleTransitionWidget(
          child: GestureDetector(
            onTap: () {
              if (isLiveVideo) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LiveRoomScreen(room: room),
                  ),
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LivePartyRoomScreen(room: room),
                  ),
                );
              }
            },
            child: isPartyTab ? PartyRoomCard(room: room) : LiveRoomCard(room: room),
          ),
        );
      },
    );
  }
}
