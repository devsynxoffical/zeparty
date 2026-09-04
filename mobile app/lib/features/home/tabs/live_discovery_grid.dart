import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/repositories/backend_repository.dart';
import '../../../widgets/live_room_card.dart';
import '../../../widgets/party_room_card.dart';
import '../../../core/animations/app_animations.dart';
import '../../live/live_vertical_feed_screen.dart';
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
    final roomsToDisplay = liveRooms.isEmpty ? BackendRepository.instance.liveRooms : liveRooms;

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
        return FadeScaleTransitionWidget(
          child: GestureDetector(
            onTap: () {
              if (isPartyTab) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LivePartyRoomScreen(room: room),
                  ),
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LiveVerticalFeedScreen(initialIndex: index),
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
