import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../models/live_room_model.dart';
import '../../models/user_model.dart';
import '../../core/repositories/backend_repository.dart';
import '../party_room/live_party_room_screen.dart';

class ProfileRoomsScreen extends StatefulWidget {
  final UserModel user;
  const ProfileRoomsScreen({super.key, required this.user});

  @override
  State<ProfileRoomsScreen> createState() => _ProfileRoomsScreenState();
}

class _ProfileRoomsScreenState extends State<ProfileRoomsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppColors.getPrimary(isDark);
    final allRooms = BackendRepository.instance.liveRooms;

    final ownedRooms = allRooms.where((r) =>
        r.host.id == widget.user.id || r.host.name.toLowerCase() == widget.user.name.toLowerCase()
    ).toList();

    final sampleOwnedRoom = LiveRoomModel(
      id: 'room_owned_1',
      title: '${widget.user.name}\'s Official Audio Lounge 🎵',
      host: widget.user,
      coverUrl: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?auto=format&fit=crop&w=400&q=80',
      viewerCount: 42,
      category: 'Chat',
      startTime: DateTime.now(),
    );

    final displayOwnedRooms = ownedRooms.isNotEmpty ? ownedRooms : [sampleOwnedRoom];

    final joinedRooms = allRooms.take(3).toList();
    final followedRooms = allRooms.skip(3).take(3).toList();

    return Scaffold(
      backgroundColor: AppColors.getBackground(isDark),
      appBar: AppBar(
        title: const Text('My Rooms', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.getBackground(isDark),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Owned / Created Room Top Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Room (${displayOwnedRooms.length})',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.getTextPrimary(isDark),
                ),
              ),
            ),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: displayOwnedRooms.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, idx) {
                return _buildRoomCard(context, displayOwnedRooms[idx], isDark, primary);
              },
            ),
            const SizedBox(height: 20),

            // Tab Bar for Joined & Followed Rooms
            TabBar(
              controller: _tabController,
              indicatorColor: primary,
              labelColor: primary,
              unselectedLabelColor: AppColors.getTextSecondary(isDark),
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              tabs: const [
                Tab(text: 'Join'),
                Tab(text: 'Follow'),
              ],
            ),

            SizedBox(
              height: 350,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildRoomList(context, joinedRooms, 'No joined rooms yet', isDark, primary),
                  _buildRoomList(context, followedRooms, 'No followed rooms yet', isDark, primary),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoomList(BuildContext context, List<LiveRoomModel> rooms, String emptyText, bool isDark, Color primary) {
    if (rooms.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.meeting_room_rounded, size: 48, color: AppColors.getTextSecondary(isDark)),
              const SizedBox(height: 12),
              Text(
                emptyText,
                style: TextStyle(color: AppColors.getTextSecondary(isDark), fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: rooms.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, idx) {
        return _buildRoomCard(context, rooms[idx], isDark, primary);
      },
    );
  }

  Widget _buildRoomCard(BuildContext context, LiveRoomModel room, bool isDark, Color primary) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => LivePartyRoomScreen(room: room)),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.getCard(isDark),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: primary.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                room.coverUrl,
                width: 60,
                height: 60,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 60,
                  height: 60,
                  color: Colors.purple.shade900,
                  child: const Icon(Icons.music_note_rounded, color: Colors.amberAccent),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('🇺🇸', style: TextStyle(fontSize: 14)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          room.title,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppColors.getTextPrimary(isDark),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.mic_rounded, size: 12, color: AppColors.getTextSecondary(isDark)),
                      const SizedBox(width: 4),
                      Text(
                        'Host: ${room.host.name}',
                        style: TextStyle(fontSize: 11, color: AppColors.getTextSecondary(isDark)),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Lv.${room.host.accountLevel > 0 ? room.host.accountLevel : 10}',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: primary),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.graphic_eq_rounded, size: 12, color: Colors.greenAccent),
                  const SizedBox(width: 4),
                  Text(
                    '${room.viewerCount}',
                    style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
