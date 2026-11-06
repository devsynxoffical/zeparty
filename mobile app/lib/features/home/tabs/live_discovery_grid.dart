import '../../../providers/live_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_colors.dart';
import '../../../widgets/live_room_card.dart';
import '../../../widgets/party_room_card.dart';
import '../../../core/animations/app_animations.dart';
import '../../live/live_room_screen.dart';
import '../../party_room/live_party_room_screen.dart';
import '../../../models/live_room_model.dart';
import '../../../core/repositories/backend_repository.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../core/services/room_lock_manager.dart';

class LiveDiscoveryGrid extends StatefulWidget {
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
  State<LiveDiscoveryGrid> createState() => _LiveDiscoveryGridState();
}

class _LiveDiscoveryGridState extends State<LiveDiscoveryGrid> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 250) {
      if (BackendRepository.instance.hasMoreRooms && !BackendRepository.instance.isLoadingRooms) {
        BackendRepository.instance.fetchLiveRooms(loadMore: true);
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Deduplicate rooms safely by ID
    final seen = <String>{};
    final roomsToDisplay = <LiveRoomModel>[];
    for (final r in widget.liveRooms) {
      if (r.id.isNotEmpty && !seen.contains(r.id)) {
        seen.add(r.id);
        roomsToDisplay.add(r);
      }
    }

    if (roomsToDisplay.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => BackendRepository.instance.fetchLiveRooms(page: 1, loadMore: false),
        color: AppColors.primaryGold,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
          children: [
            Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: widget.isDark ? const Color(0xFF1E1B2E) : const Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  widget.isPartyTab ? Icons.mic_external_off_rounded : Icons.live_tv_rounded,
                  size: 48,
                  color: widget.isDark ? AppColors.warmGold.withValues(alpha: 0.6) : AppColors.royalBlue.withValues(alpha: 0.6),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.isPartyTab ? 'No Party Rooms Active' : 'No Live Streams Active',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: widget.isDark ? Colors.white : Colors.black87,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.isPartyTab ? 'Start an audio party room and invite friends!' : 'Go live and connect with your audience!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: widget.isDark ? Colors.white60 : Colors.black54,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => BackendRepository.instance.fetchLiveRooms(page: 1, loadMore: false),
      color: AppColors.primaryGold,
      child: GridView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(left: 14, right: 14, top: 4, bottom: 115),
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
                  final liveProv = context.read<LiveProvider>();
                  final currentUser = context.read<AuthProvider>().currentUser;
                  final isLiveHost = liveProv.activeRoom != null && (liveProv.activeRoom!.host.id == currentUser.id || liveProv.activeRoom!.creatorUserId == currentUser.id);
                  if (isLiveHost) {
                    showDialog(
                      context: context,
                      builder: (dlgCtx) => AlertDialog(
                        backgroundColor: const Color(0xFF1E1938),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        title: const Text('Confirm', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        content: const Text(
                          'End your Live broadcast and join this Party room?',
                          style: TextStyle(color: Colors.white70),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(dlgCtx),
                            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE91E63)),
                            onPressed: () async {
                              Navigator.pop(dlgCtx);
                              await liveProv.closeRoom();
                              if (context.mounted) {
                                final currentUser = context.read<AuthProvider>().currentUser;
                                RoomLockManager.instance.checkAndEnterRoom(
                                  context,
                                  room: room,
                                  currentUser: currentUser,
                                  onAdmitted: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => LivePartyRoomScreen(room: room),
                                      ),
                                    );
                                  },
                                );
                              }
                            },
                            child: const Text('End Live and Join', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    );
                    return;
                  }

                  RoomLockManager.instance.checkAndEnterRoom(
                    context,
                    room: room,
                    currentUser: currentUser,
                    onAdmitted: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => LivePartyRoomScreen(room: room),
                        ),
                      );
                    },
                  );
                }
              },
              child: widget.isPartyTab ? PartyRoomCard(room: room) : LiveRoomCard(room: room),
            ),
          );
        },
      ),
    );
  }
}
