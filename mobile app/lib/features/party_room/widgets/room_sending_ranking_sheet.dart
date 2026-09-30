import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/repositories/room_repository.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../models/party_participant_model.dart';
import '../../../../models/user_model.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/live_party_provider.dart';
import 'in_room_profile_card_sheet.dart';

class RoomSendingRankingSheet extends StatefulWidget {
  final String roomId;
  final String roomTitle;
  final bool isDark;

  const RoomSendingRankingSheet({
    super.key,
    required this.roomId,
    required this.roomTitle,
    required this.isDark,
  });

  static void show(BuildContext context, {required String roomId, required String roomTitle, bool isDark = true}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RoomSendingRankingSheet(
        roomId: roomId,
        roomTitle: roomTitle,
        isDark: isDark,
      ),
    );
  }

  @override
  State<RoomSendingRankingSheet> createState() => _RoomSendingRankingSheetState();
}

class _RoomSendingRankingSheetState extends State<RoomSendingRankingSheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedTabIndex = 0; // 0: Daily, 1: Weekly, 2: Monthly
  bool _isLoading = false;

  List<Map<String, dynamic>> _rankings = [];
  Map<String, dynamic>? _viewerRank;
  num _periodTotalCoins = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          _selectedTabIndex = _tabController.index;
        });
        _fetchRankings();
      }
    });
    _fetchRankings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String get _currentPeriodKey {
    switch (_selectedTabIndex) {
      case 0:
        return 'daily';
      case 1:
        return 'weekly';
      case 2:
      default:
        return 'monthly';
    }
  }

  String get _periodLabel {
    switch (_selectedTabIndex) {
      case 0:
        return 'Today (UTC 00:00 - 23:59)';
      case 1:
        return 'This Week (Mon - Sun)';
      case 2:
      default:
        return 'This Month';
    }
  }

  Future<void> _fetchRankings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final res = await RoomRepository.instance.getRoomSendingRankings(
        widget.roomId,
        period: _currentPeriodKey,
      );
      if (mounted) {
        setState(() {
          final list = res['rankings'] as List? ?? [];
          _rankings = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          _viewerRank = res['viewerRank'] != null ? Map<String, dynamic>.from(res['viewerRank'] as Map) : null;
          _periodTotalCoins = (res['periodTotalCoins'] as num?) ?? 0;
          _isLoading = false;
        });
      }
    } catch (e) {
      // Fallback to in-room gift message aggregation if backend fails or room is mock
      if (mounted) {
        final partyProv = Provider.of<LivePartyProvider>(context, listen: false);
        final giftMsgs = partyProv.messages.where((m) => m.isGiftMessage).toList();

        final Map<String, Map<String, dynamic>> userTotals = {};
        num grandTotal = 0;

        for (final msg in giftMsgs) {
          final senderId = msg.sender.id;
          final coins = ((msg.quantity ?? 1) * 100);
          grandTotal += coins;

          if (userTotals.containsKey(senderId)) {
            userTotals[senderId]!['totalCoins'] = (userTotals[senderId]!['totalCoins'] as num) + coins;
          } else {
            userTotals[senderId] = {
              'userId': senderId,
              'name': msg.sender.name,
              'username': msg.sender.username,
              'avatarUrl': msg.sender.avatarUrl,
              'totalCoins': coins,
            };
          }
        }

        final sorted = userTotals.values.toList()
          ..sort((a, b) => (b['totalCoins'] as num).compareTo(a['totalCoins'] as num));

        final rankedList = sorted.asMap().entries.map((entry) {
          final idx = entry.key;
          final item = entry.value;
          return {
            'rank': idx + 1, ...item,
          };
        }).toList();

        final currentUser = Provider.of<AuthProvider>(context, listen: false).currentUser;
        final myIdx = rankedList.indexWhere((r) => r['userId'] == currentUser.id);

        Map<String, dynamic>? myRankObj;
        if (myIdx != -1) {
          myRankObj = rankedList[myIdx];
        } else {
          myRankObj = {
            'rank': 0,
            'userId': currentUser.id,
            'name': currentUser.name.isNotEmpty ? currentUser.name : currentUser.username,
            'avatarUrl': currentUser.avatarUrl,
            'totalCoins': 0,
          };
        }

        setState(() {
          _rankings = rankedList;
          _viewerRank = myRankObj;
          _periodTotalCoins = grandTotal;
          _isLoading = false;
        });
      }
    }
  }

  void _openUserProfile(String userId, String name, String avatarUrl) {
    final partyProv = Provider.of<LivePartyProvider>(context, listen: false);
    final participant = partyProv.participants.where((p) => p.user.id == userId).firstOrNull ??
        PartyParticipantModel(
          user: UserModel(id: userId, username: name.toLowerCase(), name: name, avatarUrl: avatarUrl),
          joinedAt: DateTime.now(),
        );

    InRoomProfileCardSheet.show(
      context,
      participant: participant,
      canManage: false,
      isDark: widget.isDark,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Color(0xFF141125),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        children: [
          // Drag handle
          const SizedBox(height: 10),
          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.emoji_events_rounded, color: Colors.amber, size: 24),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Room Sending Ranking',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Total Coins Sent: ${AppFormatters.formatNumber(_periodTotalCoins.toInt())} 🪙',
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Colors.white10,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, color: Colors.white70, size: 18),
                  ),
                ),
              ],
            ),
          ),

          // Time Period Tabs (Daily, Weekly, Monthly)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFF221C38),
              borderRadius: BorderRadius.circular(20),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFB524E4), Color(0xFFFF4081)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white54,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              tabs: const [
                Tab(text: 'Daily'),
                Tab(text: 'Weekly'),
                Tab(text: 'Monthly'),
              ],
            ),
          ),

          // Period dates label
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              _periodLabel,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11),
            ),
          ),

          // Main Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.amber))
                : _rankings.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.emoji_events_outlined, color: Colors.white.withValues(alpha: 0.3), size: 56),
                            const SizedBox(height: 12),
                            const Text(
                              'No gift senders in this period yet.',
                              style: TextStyle(color: Colors.white60, fontSize: 14),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Be the first to send a gift and claim 1st place! 🎁',
                              style: TextStyle(color: Colors.amber.withValues(alpha: 0.8), fontSize: 12),
                            ),
                          ],
                        ),
                      )
                    : CustomScrollView(
                        slivers: [
                          // Top 3 Podium
                          SliverToBoxAdapter(
                            child: _buildTop3Podium(),
                          ),

                          // Senders List (Rank 4+)
                          if (_rankings.length > 3)
                            SliverPadding(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                              sliver: SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (ctx, index) {
                                    final rankItem = _rankings[index + 3];
                                    return _buildRankRow(rankItem);
                                  },
                                  childCount: _rankings.length - 3,
                                ),
                              ),
                            )
                          else
                            const SliverToBoxAdapter(child: SizedBox(height: 80)),
                        ],
                      ),
          ),

          // Viewer's Rank Bar at Bottom
          if (_viewerRank != null) _buildViewerRankBar(),
        ],
      ),
    );
  }

  Widget _buildTop3Podium() {
    final top1 = _rankings.isNotEmpty ? _rankings[0] : null;
    final top2 = _rankings.length > 1 ? _rankings[1] : null;
    final top3 = _rankings.length > 2 ? _rankings[2] : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 2nd Place
          if (top2 != null)
            _buildPodiumItem(top2, rank: 2, height: 110, crownColor: Colors.grey.shade300, avatarSize: 52)
          else
            const SizedBox(width: 80),

          // 1st Place (Center, tallest)
          if (top1 != null)
            _buildPodiumItem(top1, rank: 1, height: 135, crownColor: Colors.amber, avatarSize: 64)
          else
            const SizedBox(width: 90),

          // 3rd Place
          if (top3 != null)
            _buildPodiumItem(top3, rank: 3, height: 95, crownColor: const Color(0xFFCD7F32), avatarSize: 48)
          else
            const SizedBox(width: 80),
        ],
      ),
    );
  }

  Widget _buildPodiumItem(
    Map<String, dynamic> item, {
    required int rank,
    required double height,
    required Color crownColor,
    required double avatarSize,
  }) {
    final name = item['name']?.toString() ?? item['username']?.toString() ?? 'Sender';
    final avatarUrl = item['avatarUrl']?.toString() ?? '';
    final totalCoins = (item['totalCoins'] as num?) ?? 0;

    String crownEmoji = '🥇';
    if (rank == 2) crownEmoji = '🥈';
    if (rank == 3) crownEmoji = '🥉';

    return GestureDetector(
      onTap: () => _openUserProfile(item['userId']?.toString() ?? '', name, avatarUrl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Crown / Rank Badge
          Text(crownEmoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 2),

          // Avatar
          Container(
            width: avatarSize,
            height: avatarSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: crownColor, width: 2.5),
              boxShadow: [
                BoxShadow(color: crownColor.withValues(alpha: 0.4), blurRadius: 10, spreadRadius: 1),
              ],
            ),
            child: ClipOval(
              child: avatarUrl.isNotEmpty
                  ? Image.network(avatarUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _avatarFallback(name))
                  : _avatarFallback(name),
            ),
          ),
          const SizedBox(height: 6),

          // Name
          SizedBox(
            width: 85,
            child: Text(
              name,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 2),

          // Coins total
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${AppFormatters.formatNumber(totalCoins.toInt())} 🪙',
              style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRankRow(Map<String, dynamic> item) {
    final rank = item['rank'] ?? 4;
    final name = item['name']?.toString() ?? item['username']?.toString() ?? 'Sender';
    final avatarUrl = item['avatarUrl']?.toString() ?? '';
    final totalCoins = (item['totalCoins'] as num?) ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1832),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          // Rank Number
          SizedBox(
            width: 28,
            child: Text(
              '#$rank',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Avatar
          GestureDetector(
            onTap: () => _openUserProfile(item['userId']?.toString() ?? '', name, avatarUrl),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFFB524E4).withValues(alpha: 0.3),
              backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
              child: avatarUrl.isEmpty ? _avatarFallback(name) : null,
            ),
          ),
          const SizedBox(width: 12),

          // Name & ID
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Sender',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 10),
                ),
              ],
            ),
          ),

          // Coin Total
          Row(
            children: [
              const Icon(Icons.monetization_on, color: Colors.amber, size: 14),
              const SizedBox(width: 4),
              Text(
                AppFormatters.formatNumber(totalCoins.toInt()),
                style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildViewerRankBar() {
    final rankVal = _viewerRank!['rank'] ?? 0;
    final coinsVal = (_viewerRank!['totalCoins'] as num?) ?? 0;
    final rankText = rankVal > 0 ? '#$rankVal' : 'Unranked';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2E1B4E), Color(0xFF1A0E31)],
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 10, offset: const Offset(0, -3)),
        ],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFB524E4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    rankText,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'My Room Ranking',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ],
            ),
            Row(
              children: [
                const Icon(Icons.monetization_on, color: Colors.amber, size: 16),
                const SizedBox(width: 4),
                Text(
                  '${AppFormatters.formatNumber(coinsVal.toInt())} Coins',
                  style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatarFallback(String name) {
    return Container(
      color: const Color(0xFF6C5CE7),
      alignment: Alignment.center,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : 'U',
        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }
}
