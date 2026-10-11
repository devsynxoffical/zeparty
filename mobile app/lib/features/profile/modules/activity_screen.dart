import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        backgroundColor: AppColors.getBackground(isDark),
        appBar: AppBar(
          backgroundColor: AppColors.getBackground(isDark),
          title: Text('Activity Center', style: TextStyle(color: AppColors.getTextPrimary(isDark), fontWeight: FontWeight.bold)),
          iconTheme: IconThemeData(color: AppColors.getTextPrimary(isDark)),
          bottom: TabBar(
            isScrollable: true,
            labelColor: AppColors.getPrimary(isDark),
            unselectedLabelColor: AppColors.getTextSecondary(isDark),
            indicatorColor: AppColors.getPrimary(isDark),
            tabAlignment: TabAlignment.start,
            tabs: const [
              Tab(text: 'Game'),
              Tab(text: 'Gift'),
              Tab(text: 'Recharge'),
              Tab(text: 'PK'),
              Tab(text: 'Other'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildEventList(context, isDark, 'Game'),
            _buildEventList(context, isDark, 'Gift'),
            _buildEventList(context, isDark, 'Recharge'),
            _buildEventList(context, isDark, 'PK'),
            _buildEventList(context, isDark, 'Other'),
          ],
        ),
      ),
    );
  }

  Widget _buildEventList(BuildContext context, bool isDark, String category) {
    final events = _getEvents(context, category);

    if (events.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy_rounded, size: 64, color: AppColors.getTextSecondary(isDark).withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text('No events right now', style: TextStyle(color: AppColors.getTextSecondary(isDark))),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[index];
        final isEnded = event['status'] == 'Ended';
        
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: AppColors.getCard(isDark),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.getBorder(isDark)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Banner
              Stack(
                children: [
                  Container(
                    height: 120,
                    decoration: BoxDecoration(
                      color: (event['color'] as Color).withValues(alpha: 0.3),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    child: Center(
                      child: Icon(Icons.celebration_rounded, size: 48, color: event['color'] as Color),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isEnded ? Colors.grey : AppColors.getPrimary(isDark),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        event['status'] as String,
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
              // Content
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event['title'] as String,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(isDark)),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      event['desc'] as String,
                      style: TextStyle(color: AppColors.getTextSecondary(isDark), fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(Icons.timer_outlined, size: 14, color: AppColors.getTextSecondary(isDark)),
                        const SizedBox(width: 4),
                        Text(
                          event['countdown'] as String,
                          style: TextStyle(color: AppColors.getTextSecondary(isDark), fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        // Reward text — Flexible so it never overflows
                        Flexible(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('🎁 ', style: TextStyle(fontSize: 14)),
                              Flexible(
                                child: Text(
                                  'Reward: ${event['reward']}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.getPrimary(isDark),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Action Button — fixed size, never clipped
                        ElevatedButton(
                          onPressed: isEnded ? null : () {},
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isEnded ? AppColors.getMuted(isDark) : AppColors.getPrimary(isDark),
                            foregroundColor: isEnded ? AppColors.getTextSecondary(isDark) : AppColors.onPrimary(isDark: isDark),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            isEnded ? 'Completed' : 'Join Now',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
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
    );
  }

  List<Map<String, dynamic>> _getEvents(BuildContext context, String category) {
    final List<Map<String, dynamic>> realEvents = [];

    if (category == 'Game') {
      realEvents.add({
        'title': '🚀 Rocket & Fruit Match Game Challenges',
        'desc': 'Join any active party room to play Rocket & Fruit games and share the daily jackpot coin pool.',
        'status': 'Active',
        'countdown': 'Live 24/7 in Voice Rooms',
        'reward': 'Jackpot Coins & Trophy Badges',
        'color': Colors.deepOrangeAccent,
      });
    } else if (category == 'PK') {
      realEvents.add({
        'title': '⚔️ Live Host PK Battle Tournament',
        'desc': 'Challenge rival hosts in 1v1 PK Battles. Top streamers receive global entrance banners and badges.',
        'status': 'Active',
        'countdown': 'Ongoing Matches',
        'reward': 'Global Banners & SVIP Points',
        'color': Colors.blueAccent,
      });
    } else if (category == 'Recharge') {
      realEvents.add({
        'title': '💎 Official P2P & Agency Coin Bonus',
        'desc': 'Recharge coins through verified recharge agencies or P2P trading board to unlock extra tier rewards.',
        'status': 'Active',
        'countdown': 'Available Now',
        'reward': 'Extra Coins & SVIP Leveling',
        'color': Colors.greenAccent,
      });
    } else if (category == 'Gift') {
      realEvents.add({
        'title': '🎁 Supercar & Crown Gifting Festival',
        'desc': 'Send luxury Supercar or Crown gifts in live rooms to boost your Wealth level and climb the leaderboard.',
        'status': 'Active',
        'countdown': 'Daily Leaderboard Reset',
        'reward': 'Wealth Level Badges & Custom Frames',
        'color': Colors.purpleAccent,
      });
    }

    return realEvents;
  }
}
