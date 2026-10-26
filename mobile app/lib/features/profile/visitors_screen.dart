import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/repositories/social_repository.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/user_avatar.dart';
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
    } else if (rawUser is UserModel) {
      u = rawUser;
    } else {
      final pid = (json['publicUserId'] ?? json['publicId'] ?? json['visitorId'] ?? json['id'] ?? '').toString();
      u = UserModel(
        id: json['visitorId']?.toString() ?? json['id']?.toString() ?? '',
        publicUserId: pid,
        username: json['username']?.toString() ?? 'user',
        name: json['name']?.toString() ?? json['displayName']?.toString() ?? 'ZeParty User',
        avatarUrl: json['avatarUrl']?.toString() ?? '',
      );
    }

    return VisitRecord(
      id: json['id']?.toString() ?? '',
      user: u,
      visitedAt: json['visitedAt'] != null
          ? (DateTime.tryParse(json['visitedAt'].toString()) ?? DateTime.now())
          : DateTime.now(),
      isMystery: json['isMystery'] == true,
    );
  }
}

class VisitorsScreen extends StatefulWidget {
  final String? targetUserId;
  const VisitorsScreen({super.key, this.targetUserId});

  @override
  State<VisitorsScreen> createState() => _VisitorsScreenState();
}

class _VisitorsScreenState extends State<VisitorsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<VisitRecord> _whosSeenMe = [];
  List<VisitRecord> _whoIveSeen = [];
  int _totalVisitors = 0;
  int _totalVisited = 0;
  bool _isLoading = false;
  String? _errorMessage;
  int _requestId = 0;

  bool _isAuthorized(AuthProvider auth) {
    if (!auth.isAuthenticated || auth.currentUser.id.isEmpty) return false;
    final currentId = auth.currentUser.id;
    final currentPublicId = auth.currentUser.publicUserId;
    final currentUsername = auth.currentUser.username.toLowerCase();
    if (widget.targetUserId == null ||
        widget.targetUserId!.isEmpty ||
        widget.targetUserId == 'me') {
      return true;
    }
    final target = widget.targetUserId!.toLowerCase();
    return target == currentId.toLowerCase() ||
        (currentPublicId.isNotEmpty && target == currentPublicId.toLowerCase()) ||
        target == currentUsername;
  }

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
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!_isAuthorized(auth)) {
      if (mounted) {
        setState(() {
          _whosSeenMe = [];
          _whoIveSeen = [];
          _totalVisitors = 0;
          _totalVisited = 0;
          _isLoading = false;
          _errorMessage = null;
        });
      }
      return;
    }

    final currentRequestId = ++_requestId;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final myId = auth.currentUser.id;
      final myPublicId = auth.currentUser.publicUserId;

      final results = await Future.wait([
        SocialRepository.instance.fetchVisitorsEnvelope(userId: widget.targetUserId),
        SocialRepository.instance.fetchVisitedEnvelope(userId: widget.targetUserId),
      ]);

      if (_requestId != currentRequestId || !mounted) return;

      final visitorsRes = results[0];
      final visitedRes = results[1];

      final rawVisitors = visitorsRes['data'] ?? visitorsRes['visitors'] ?? [];
      final rawVisited = visitedRes['data'] ?? visitedRes['visited'] ?? [];

      final List<VisitRecord> visitors = [];
      final Set<String> seenVisitorUserIds = {};

      if (rawVisitors is List) {
        for (final item in rawVisitors) {
          if (item is Map<String, dynamic>) {
            final rec = VisitRecord.fromJson(item);
            // Self-visit filter: never display a user's visit to their own profile
            final uId = rec.user.id;
            final uPid = rec.user.publicUserId;
            if (uId == myId || (myPublicId.isNotEmpty && uPid == myPublicId)) {
              continue;
            }
            final dedupeKey = uPid.isNotEmpty ? uPid : uId;
            if (!seenVisitorUserIds.contains(dedupeKey)) {
              seenVisitorUserIds.add(dedupeKey);
              visitors.add(rec);
            }
          }
        }
      }

      final List<VisitRecord> visited = [];
      final Set<String> seenVisitedUserIds = {};

      if (rawVisited is List) {
        for (final item in rawVisited) {
          if (item is Map<String, dynamic>) {
            final rec = VisitRecord.fromJson(item);
            final uId = rec.user.id;
            final uPid = rec.user.publicUserId;
            if (uId == myId || (myPublicId.isNotEmpty && uPid == myPublicId)) {
              continue;
            }
            final dedupeKey = uPid.isNotEmpty ? uPid : uId;
            if (!seenVisitedUserIds.contains(dedupeKey)) {
              seenVisitedUserIds.add(dedupeKey);
              visited.add(rec);
            }
          }
        }
      }

      final visitorsTotal = visitorsRes['pagination']?['total'] ?? visitors.length;
      final visitedTotal = visitedRes['pagination']?['total'] ?? visited.length;

      setState(() {
        _whosSeenMe = visitors;
        _whoIveSeen = visited;
        _totalVisitors = visitorsTotal is int ? visitorsTotal : (int.tryParse(visitorsTotal.toString()) ?? visitors.length);
        _totalVisited = visitedTotal is int ? visitedTotal : (int.tryParse(visitedTotal.toString()) ?? visited.length);
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      if (_requestId != currentRequestId || !mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load visitor history. Please try again.';
      });
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
    final auth = context.watch<AuthProvider>();

    // Route / Deep Link Security: Deny access if unauthorized or viewing another user's visitors
    if (!_isAuthorized(auth)) {
      return Scaffold(
        backgroundColor: AppColors.getBackground(isDark),
        appBar: AppBar(
          title: const Text('Profile Visitors', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: AppColors.getBackground(isDark),
          elevation: 0,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.lock_rounded, size: 48, color: Colors.amber),
                ),
                const SizedBox(height: 16),
                Text(
                  'Private Visitor History',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.getTextPrimary(isDark),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Visitor history is strictly private and can only be accessed by the account owner.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.getTextSecondary(isDark),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  child: const Text('Go Back', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final displayVisitorsCount = _totalVisitors > 0 ? _totalVisitors : _whosSeenMe.length;
    final displayVisitedCount = _totalVisited > 0 ? _totalVisited : _whoIveSeen.length;

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
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          tabs: [
            Tab(text: "Who's seen me ($displayVisitorsCount)"),
            Tab(text: "Who I've seen ($displayVisitedCount)"),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
            )
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.wifi_off_rounded, size: 52, color: AppColors.getTextSecondary(isDark)),
                        const SizedBox(height: 12),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.getTextSecondary(isDark), fontSize: 14),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _loadVisitors,
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('Retry'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildVisitList(
                      context,
                      _whosSeenMe,
                      isIncoming: true,
                      isDark: isDark,
                      primary: primary,
                    ),
                    _buildVisitList(
                      context,
                      _whoIveSeen,
                      isIncoming: false,
                      isDark: isDark,
                      primary: primary,
                    ),
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
                  Icon(
                    Icons.directions_walk_rounded,
                    size: 56,
                    color: AppColors.getTextSecondary(isDark),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isIncoming ? 'No profile visitors yet' : 'You haven\'t visited any profiles yet',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.getTextPrimary(isDark),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isIncoming
                        ? 'Users who view your profile will appear here'
                        : 'Profiles you check out will show up here',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.getTextSecondary(isDark),
                    ),
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
        separatorBuilder: (context, index) => const SizedBox(height: 10),
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
                        Text(
                          'Mystery Visitor',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppColors.getTextPrimary(isDark),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Used stealth profile visit • ${_formatTimeAgo(rec.visitedAt)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.getTextSecondary(isDark),
                          ),
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
                MaterialPageRoute(
                  builder: (_) => UserProfileDetailsScreen(userId: u.effectivePublicId),
                ),
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
                  UserAvatar(imageUrl: u.avatarUrl, radius: 22, isLive: u.isLive),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                u.displayName.isNotEmpty
                                    ? u.displayName
                                    : (u.name.isNotEmpty
                                        ? u.name
                                        : (u.id.isNotEmpty ? 'User ${u.id}' : 'User')),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: AppColors.getTextPrimary(isDark),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (u.svipLevel > 0) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.amber, width: 0.8),
                                ),
                                child: Text(
                                  'SVIP ${u.svipLevel}',
                                  style: const TextStyle(
                                    color: Colors.amber,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'ID: ${u.effectivePublicId} • ${_formatTimeAgo(rec.visitedAt)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.getTextSecondary(isDark),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: AppColors.getTextSecondary(isDark), size: 20),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
