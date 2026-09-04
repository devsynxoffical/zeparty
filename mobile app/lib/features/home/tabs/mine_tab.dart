import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/repositories/backend_repository.dart';
import '../../../core/constants/dummy_data.dart';
import '../../../providers/auth_provider.dart';
import '../../live/create_live_room_screen.dart';
import '../../live/live_room_screen.dart';
import '../../party_room/create_party_screen.dart';
import '../../party_room/live_party_room_screen.dart';

class MineTab extends StatefulWidget {
  final bool isDark;
  
  const MineTab({super.key, required this.isDark});

  @override
  State<MineTab> createState() => _MineTabState();
}

class _MineTabState extends State<MineTab> {
  int _selectedMineFilter = 0; // 0: Recently, 1: Following, 2: Friends

  @override
  Widget build(BuildContext context) {
    final backend = Provider.of<BackendRepository>(context);
    final currentUser = Provider.of<AuthProvider>(context).currentUser;
    final liveRooms = backend.liveRooms;
    final myRooms = backend.getMyRooms(currentUser.id);
    final primary = AppColors.getPrimary(widget.isDark);
    final recentRooms = [...myRooms, ...liveRooms.where((r) => r.host.id != currentUser.id)].take(6).toList();
    final followingRooms = liveRooms.skip(1).take(4).toList();
    final friendUsers = DummyData.popularUsers.take(4).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 90),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateLiveRoomScreen())),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFFFF416C), Color(0xFFFF4B2B)]),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: const Color(0xFFFF416C).withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.live_tv_rounded, color: Colors.white, size: 26),
                        SizedBox(height: 6),
                        Text('Go Live', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreatePartyScreen())),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [primary, AppColors.accent]),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: primary.withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.celebration_rounded, color: Colors.white, size: 26),
                        SizedBox(height: 6),
                        Text('Create Party', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── FILTER PILLS ────────────────────────────────────────────────────────────
          Row(
            children: ['Recently', 'Following', 'Friends'].asMap().entries.map((entry) {
              final idx = entry.key;
              final label = entry.value;
              final isSelected = _selectedMineFilter == idx;
              return GestureDetector(
                onTap: () => setState(() => _selectedMineFilter = idx),
                child: Container(
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? primary.withValues(alpha: 0.15) : AppColors.getCard(widget.isDark),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isSelected ? primary : AppColors.getBorder(widget.isDark), width: 1.2),
                  ),
                  child: Text(label, style: TextStyle(
                    color: isSelected ? primary : AppColors.getTextSecondary(widget.isDark),
                    fontWeight: FontWeight.bold, fontSize: 12,
                  )),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // ── FEED BY FILTER ────────────────────────────────────────────────────────
          if (_selectedMineFilter == 0) ...[
            // RECENTLY
            Text('Rooms You Visited', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.getTextPrimary(widget.isDark))),
            const SizedBox(height: 12),
            SizedBox(
              height: 160,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: recentRooms.length,
                itemBuilder: (context, index) {
                  final room = recentRooms[index];
                  return GestureDetector(
                    onTap: () {
                      if (room.id.startsWith('party_') || room.category == 'Party') {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => LivePartyRoomScreen(room: room)));
                      } else {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => LiveRoomScreen(room: room)));
                      }
                    },
                    child: Container(
                      width: 130,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        image: DecorationImage(image: NetworkImage(room.coverUrl), fit: BoxFit.cover),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 8)],
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter, end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black.withValues(alpha: 0.8)],
                          ),
                        ),
                        padding: const EdgeInsets.all(10),
                        alignment: Alignment.bottomLeft,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(6)),
                              child: const Text('● LIVE', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(height: 4),
                            Text(room.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            Text('Active Live Rooms', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.getTextPrimary(widget.isDark))),
            const SizedBox(height: 12),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: liveRooms.length,
              itemBuilder: (context, index) {
                final room = liveRooms[index];
                return GestureDetector(
                  onTap: () {
                    if (room.id.startsWith('party_') || room.category == 'Party') {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => LivePartyRoomScreen(room: room)));
                    } else {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => LiveRoomScreen(room: room)));
                    }
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.getCard(widget.isDark),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.getBorder(widget.isDark)),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(room.host.avatarUrl, width: 52, height: 52, fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(width: 52, height: 52, color: primary.withValues(alpha: 0.2))),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(room.title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.getTextPrimary(widget.isDark))),
                              const SizedBox(height: 3),
                              Text('Host: ${room.host.name}', style: TextStyle(fontSize: 11, color: AppColors.getTextSecondary(widget.isDark))),
                              const SizedBox(height: 5),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                                      Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
                                      const SizedBox(width: 4),
                                      const Text('LIVE', style: TextStyle(color: Colors.red, fontSize: 9, fontWeight: FontWeight.bold)),
                                    ]),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(Icons.remove_red_eye_rounded, size: 12, color: AppColors.getTextSecondary(widget.isDark)),
                                  const SizedBox(width: 3),
                                  Text('${room.viewerCount}', style: TextStyle(fontSize: 11, color: AppColors.getTextSecondary(widget.isDark))),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.getTextSecondary(widget.isDark)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ] else if (_selectedMineFilter == 1) ...[
            // FOLLOWING
            Text('Creators You Follow', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.getTextPrimary(widget.isDark))),
            const SizedBox(height: 12),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: followingRooms.length,
              itemBuilder: (context, index) {
                final room = followingRooms[index];
                return GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LivePartyRoomScreen(room: room))),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.getCard(widget.isDark),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.getBorder(widget.isDark)),
                    ),
                    child: Row(
                      children: [
                        Stack(
                          children: [
                            CircleAvatar(radius: 26, backgroundImage: NetworkImage(room.host.avatarUrl)),
                            Positioned(
                              bottom: 0, right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                child: const Text('●', style: TextStyle(color: Colors.white, fontSize: 6)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(room.host.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.getTextPrimary(widget.isDark))),
                              const SizedBox(height: 2),
                              Text(room.title, style: TextStyle(fontSize: 11, color: AppColors.getTextSecondary(widget.isDark))),
                              const SizedBox(height: 4),
                              Row(children: [
                                Icon(Icons.people_rounded, size: 12, color: AppColors.getTextSecondary(widget.isDark)),
                                const SizedBox(width: 4),
                                Text('${room.viewerCount} watching', style: TextStyle(fontSize: 11, color: AppColors.getTextSecondary(widget.isDark))),
                              ]),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LivePartyRoomScreen(room: room))),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primary, foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                          child: const Text('Join'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ] else ...[
            // FRIENDS
            Text('Friends Online', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.getTextPrimary(widget.isDark))),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 1.sw > 600 ? 4 : 2, 
                childAspectRatio: 1.5, 
                crossAxisSpacing: 12, 
                mainAxisSpacing: 12
              ),
              itemCount: friendUsers.length,
              itemBuilder: (context, index) {
                final friend = friendUsers[index];
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.getCard(widget.isDark),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.getBorder(widget.isDark)),
                  ),
                  child: Row(
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(radius: 22, backgroundImage: NetworkImage(friend.avatarUrl)),
                          Positioned(
                            bottom: 0, right: 0,
                            child: Container(
                              width: 10, height: 10,
                              decoration: BoxDecoration(
                                color: friend.isLive ? Colors.red : Colors.green,
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.getCard(widget.isDark), width: 1.5),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(friend.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.getTextPrimary(widget.isDark)), maxLines: 1, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 2),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: friend.isLive ? Colors.red : Colors.green,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  friend.isLive ? 'LIVE' : 'Online',
                                  style: TextStyle(fontSize: 10, color: friend.isLive ? Colors.red : Colors.green, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
