import 'package:flutter/material.dart';
import '../../core/services/api_client.dart';

class EventRankingRewardsScreen extends StatefulWidget {
  final String? eventId;
  const EventRankingRewardsScreen({super.key, this.eventId});

  @override
  State<EventRankingRewardsScreen> createState() => _EventRankingRewardsScreenState();
}

class _EventRankingRewardsScreenState extends State<EventRankingRewardsScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _eventData;
  List<dynamic> _rankings = [];

  @override
  void initState() {
    super.initState();
    _fetchEventLeaderboard();
  }

  Future<void> _fetchEventLeaderboard() async {
    setState(() => _isLoading = true);
    final targetId = widget.eventId ?? 'active_current';
    try {
      final response = await ApiClient.instance.get('/v1/events/ranking-rewards/$targetId/leaderboard');
      if (response.statusCode == 200 && response.data?['success'] == true) {
        final data = response.data['data'] as Map<String, dynamic>?;
        if (data != null) {
          setState(() {
            _eventData = data['event'] as Map<String, dynamic>? ?? data;
            _rankings = (data['rankings'] as List?) ?? (data['leaderboard'] as List?) ?? [];
            _isLoading = false;
          });
          return;
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _eventData?['title']?.toString() ?? 'Special Event Ranking Rewards';
    final description = _eventData?['description']?.toString() ?? 'Top contestants earn exclusive SVIP badges, custom mounts, and diamond prizes!';

    return Scaffold(
      backgroundColor: const Color(0xFF0F0B1E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Event Ranking Rewards',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.amber))
          : RefreshIndicator(
              onRefresh: _fetchEventLeaderboard,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Banner Header
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF7B1FA2), Color(0xFF512DA8), Color(0xFF303F9F)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF512DA8).withValues(alpha: 0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          )
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.emoji_events_rounded, color: Colors.amber, size: 28),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  title,
                                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            description,
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13, height: 1.4),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Rewards Tier Cards
                    const Text(
                      '🏆 Campaign Rewards & Prizes',
                      style: TextStyle(color: Colors.amber, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildPrizeCard(
                          rankTitle: '🥇 1st Place',
                          rewardText: 'SVIP Badge + 500k Diamonds + Royal Dragon Mount',
                          color: const Color(0xFFFFD700),
                        ),
                        const SizedBox(width: 10),
                        _buildPrizeCard(
                          rankTitle: '🥈 2nd Place',
                          rewardText: 'Noble Frame + 250k Diamonds + Phoenix Wings',
                          color: const Color(0xFFC0C0C0),
                        ),
                        const SizedBox(width: 10),
                        _buildPrizeCard(
                          rankTitle: '🥉 3rd Place',
                          rewardText: 'Gold Badge + 100k Diamonds + Cyber Car Mount',
                          color: const Color(0xFFCD7F32),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Live Contestants Leaderboard
                    const Text(
                      '🔥 Live Contestant Rankings',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),

                    if (_rankings.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(30),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Text(
                          'No event rankings active right now. Check back soon!',
                          style: TextStyle(color: Colors.white54, fontSize: 14),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _rankings.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final item = _rankings[index] as Map<String, dynamic>;
                          final rank = index + 1;
                          final name = item['name'] ?? item['username'] ?? 'Contestant $rank';
                          final avatar = item['avatarUrl'] ?? 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=150&q=80';
                          final score = item['score'] ?? item['diamonds'] ?? '0';

                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: rank <= 3
                                  ? Colors.amber.withValues(alpha: 0.08)
                                  : Colors.white.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: rank == 1
                                    ? Colors.amber
                                    : (rank <= 3 ? Colors.amber.withValues(alpha: 0.4) : Colors.white10),
                              ),
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 28,
                                  child: Text(
                                    '#$rank',
                                    style: TextStyle(
                                      color: rank == 1
                                          ? const Color(0xFFFFD700)
                                          : (rank == 2
                                              ? const Color(0xFFC0C0C0)
                                              : (rank == 3 ? const Color(0xFFCD7F32) : Colors.white54)),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                CircleAvatar(
                                  radius: 20,
                                  backgroundImage: NetworkImage(avatar.toString()),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    name.toString(),
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '💎 $score',
                                    style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildPrizeCard({required String rankTitle, required String rewardText, required Color color}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Column(
          children: [
            Text(
              rankTitle,
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 6),
            Text(
              rewardText,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 10, height: 1.3),
            ),
          ],
        ),
      ),
    );
  }
}
