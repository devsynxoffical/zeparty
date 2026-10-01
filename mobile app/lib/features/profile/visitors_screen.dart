import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/repositories/social_repository.dart';
import '../../models/user_model.dart';
import '../messages/chat_screen.dart';
import 'user_profile_details_screen.dart';

class VisitRecord {
  final String id;
  final UserModel user;
  final DateTime visitedAt;
  final bool isMystery;

  const VisitRecord({
    required this.id,
    required this.user,
    required this.visitedAt,
    this.isMystery = false,
  });

  factory VisitRecord.fromJson(Map<String, dynamic> json) {
    final rawUser = json['user'];
    UserModel u;
    if (rawUser is Map<String, dynamic>) {
      u = UserModel.fromJson(rawUser);
    } else {
      u = UserModel(
        id: json['visitorId']?.toString() ?? json['id']?.toString() ?? '',
        username: json['username']?.toString() ?? 'user',
        name: json['name']?.toString() ?? json['displayName']?.toString() ?? 'ZeParty User',
        avatarUrl: json['avatarUrl']?.toString() ?? '',
      );
    }

    return VisitRecord(
      id: json['id']?.toString() ?? '',
      user: u,
      visitedAt: json['visitedAt'] != null
          ? DateTime.tryParse(json['visitedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      isMystery: json['isMystery'] == true,
    );
  }
}

class VisitorsScreen extends StatefulWidget {
  const VisitorsScreen({super.key});

  @override
  State<VisitorsScreen> createState() => _VisitorsScreenState();
}

class _VisitorsScreenState extends State<VisitorsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<VisitRecord> _whosSeenMe = [];
  List<VisitRecord> _whoIveSeen = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadVisitors();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadVisitors() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        SocialRepository.instance.fetchVisitors(),
        SocialRepository.instance.fetchVisited(),
      ]);

      final rawVisitors = results[0];
      final rawVisited = results[1];

      final List<VisitRecord> visitors = rawVisitors.map(VisitRecord.fromJson).toList();
      final List<VisitRecord> visited = rawVisited.map(VisitRecord.fromJson).toList();

      if (mounted) {
        setState(() {
          _whosSeenMe = visitors;
          _whoIveSeen = visited;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppColors.getPrimary(isDark);

    return Scaffold(
      backgroundColor: AppColors.getBackground(isDark),
      appBar: AppBar(
        title: const Text('Profile Visitors', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.getBackground(isDark),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadVisitors,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: primary,
          labelColor: primary,
          unselectedLabelColor: AppColors.getTextSecondary(isDark),
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          tabs: [
            Tab(text: "Who's seen me (${_whosSeenMe.length})"),
            Tab(text: "Who I've seen (${_whoIveSeen.length})"),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildVisitList(context, _whosSeenMe, isIncoming: true, isDark: isDark, primary: primary),
                _buildVisitList(context, _whoIveSeen, isIncoming: false, isDark: isDark, primary: primary),
              ],
            ),
    );
  }

  Widget _buildVisitList(
    BuildContext context,
    List<VisitRecord> records, {
    required bool isIncoming,
    required bool isDark,
    required Color primary,
  }) {
    if (records.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadVisitors,
        color: AppColors.primary,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.25),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.directions_walk_rounded, size: 56, color: AppColors.getTextSecondary(isDark)),
                  const SizedBox(height: 12),
                  Text(
                    isIncoming ? 'No profile visitors yet' : 'You haven\'t visited any profiles yet',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.getTextPrimary(isDark)),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isIncoming
                        ? 'Users who view your profile will appear here'
                        : 'Profiles you check out will show up here',
                    style: TextStyle(fontSize: 13, color: AppColors.getTextSecondary(isDark)),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadVisitors,
      color: AppColors.primary,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: records.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, idx) {
          final rec = records[idx];

          if (rec.isMystery) {
            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.getCard(isDark),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.getBorder(isDark)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.amber.shade200,
                    child: const Icon(Icons.privacy_tip_rounded, color: Colors.black),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Mystery Visitor',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: AppColors.getTextPrimary(isDark),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Used stealth profile visit • ${_formatTimeAgo(rec.visitedAt)}',
                          style: TextStyle(fontSize: 11, color: AppColors.getTextSecondary(isDark)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          final u = rec.user;

          return InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => UserProfileDetailsScreen(userId: u.id)),
              );
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.getCard(isDark),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.getBorder(isDark)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundImage: u.avatarUrl.isNotEmpty ? NetworkImage(u.avatarUrl) : null,
                    child: u.avatarUrl.isEmpty ? const Icon(Icons.person, color: Colors.white) : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                u.displayName.isNotEmpty ? u.displayName : (u.name.isNotEmpty ? u.name : u.username),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: AppColors.getTextPrimary(isDark),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (u.isVip) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.workspace_premium_rounded, size: 14, color: AppColors.gold),
                            ],
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.purple.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Lv.${u.accountLevel}',
                                style: const TextStyle(color: Colors.purpleAccent, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '@${u.username} • ${_formatTimeAgo(rec.visitedAt)}',
                          style: TextStyle(fontSize: 11, color: AppColors.getTextSecondary(isDark)),
                        ),
                      ],
                    ),
                  ),
                  if (isIncoming) ...[
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                        foregroundColor: AppColors.primary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        minimumSize: const Size(0, 32),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(user: u),
                          ),
                        );
                      },
                      child: const Text('Chat', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
