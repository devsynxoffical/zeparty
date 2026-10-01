import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/services/api_client.dart';
import '../../core/services/socket_service.dart';
import '../../models/user_model.dart';
import '../../models/pk_battle_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/live_provider.dart';
import '../../widgets/user_avatar.dart';
import 'pk_battle_screen.dart';

class PkMatchScreen extends StatefulWidget {
  final String? currentRoomId;
  const PkMatchScreen({super.key, this.currentRoomId});

  @override
  State<PkMatchScreen> createState() => _PkMatchScreenState();
}

class _PkMatchScreenState extends State<PkMatchScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _radarController;
  late AnimationController _vsPulseController;
  late Animation<double> _radarAnimation;
  late Animation<double> _vsScale;

  StreamSubscription? _pkStartedSub;
  StreamSubscription? _pkAcceptedSub;
  StreamSubscription? _pkDeclinedSub;

  bool _isSearching = false;
  bool _isMatched = false;
  String _statusText = 'Finding live opponent...';
  UserModel? _matchedOpponent;

  List<Map<String, dynamic>> _availableHosts = [];
  bool _isLoadingHosts = false;
  String? _invitingHostId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _radarAnimation = Tween<double>(begin: 0.8, end: 1.8).animate(
      CurvedAnimation(parent: _radarController, curve: Curves.easeInOut),
    );

    _vsPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _vsScale = Tween<double>(begin: 0.9, end: 1.15).animate(
      CurvedAnimation(parent: _vsPulseController, curve: Curves.easeInOut),
    );

    _setupSocketListeners();
    _loadAvailableHosts();
    _startQuickMatch();
  }

  void _setupSocketListeners() {
    final socket = SocketService.instance;

    _pkStartedSub = socket.onPkStarted.listen((data) {
      if (!mounted) return;
      try {
        final pk = PKBattleModel.fromJson(data);
        _handleMatchSuccess(pk);
      } catch (e) {
        debugPrint('[PkMatchScreen] pk:started parse error: $e');
      }
    });

    _pkAcceptedSub = socket.onPkInvitationAccepted.listen((data) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 Host accepted your PK invitation! Starting battle...'),
          backgroundColor: AppColors.success,
        ),
      );
    });

    _pkDeclinedSub = socket.onPkInvitationDeclined.listen((data) {
      if (!mounted) return;
      setState(() {
        _invitingHostId = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Host declined your PK invitation.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    });
  }

  Future<void> _startQuickMatch() async {
    final live = context.read<LiveProvider>();
    final currentUser = context.read<AuthProvider>().currentUser;
    final roomId = widget.currentRoomId ?? live.activeRoom?.id;

    if (roomId == null || roomId.isEmpty) {
      setState(() {
        _statusText = 'Start a live stream first to initiate PK battle.';
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _isMatched = false;
      _statusText = 'Scanning for live hosts in region...';
    });

    try {
      final res = await ApiClient.instance.post<Map<String, dynamic>>(
        '/v1/pk/matchmaking/join',
        data: {
          'roomId': roomId,
          'region': currentUser.region.isNotEmpty ? currentUser.region : 'GLOBAL',
          'hostInfo': {
            'id': currentUser.id,
            'name': currentUser.displayName.isNotEmpty ? currentUser.displayName : currentUser.name,
            'username': currentUser.username,
            'avatarUrl': currentUser.avatarUrl,
          },
        },
      );

      final data = res.data?['data'];
      if (data != null && data['matched'] == true) {
        final rawPk = data['pkEvent'];
        if (rawPk != null) {
          final pk = PKBattleModel.fromJson(Map<String, dynamic>.from(rawPk));
          _handleMatchSuccess(pk);
          return;
        }
      }

      if (mounted) {
        setState(() {
          _statusText = 'Waiting for an available live opponent to connect...';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusText = 'Searching live queue...';
        });
      }
    }
  }

  Future<void> _loadAvailableHosts() async {
    setState(() => _isLoadingHosts = true);
    final live = context.read<LiveProvider>();
    final roomId = widget.currentRoomId ?? live.activeRoom?.id;

    try {
      final res = await ApiClient.instance.get<Map<String, dynamic>>(
        '/v1/pk/available-hosts',
        queryParameters: {
          if (roomId != null) 'excludeRoomId': roomId,
        },
      );
      final rawList = res.data?['data'];
      final List<Map<String, dynamic>> hosts = [];
      if (rawList is List) {
        for (final item in rawList) {
          if (item is Map) {
            hosts.add(Map<String, dynamic>.from(item));
          }
        }
      }
      if (mounted) {
        setState(() {
          _availableHosts = hosts;
          _isLoadingHosts = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingHosts = false);
    }
  }

  Future<void> _sendDirectInvite(Map<String, dynamic> hostItem) async {
    final live = context.read<LiveProvider>();
    final currentUser = context.read<AuthProvider>().currentUser;
    final myRoomId = widget.currentRoomId ?? live.activeRoom?.id;
    final targetRoomId = hostItem['roomId']?.toString();
    final targetUserId = hostItem['host']?['id']?.toString();

    if (myRoomId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please start your live stream first.')),
      );
      return;
    }

    setState(() => _invitingHostId = targetUserId);

    try {
      await ApiClient.instance.post<Map<String, dynamic>>(
        '/v1/pk/invite',
        data: {
          'fromRoomId': myRoomId,
          'targetRoomId': targetRoomId,
          'targetUserId': targetUserId,
          'durationSeconds': 300,
          'fromHostInfo': {
            'id': currentUser.id,
            'name': currentUser.displayName.isNotEmpty ? currentUser.displayName : currentUser.name,
            'username': currentUser.username,
            'avatarUrl': currentUser.avatarUrl,
            'roomTitle': live.activeRoom?.title ?? 'Live Stream',
          },
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✉️ PK invitation sent to ${hostItem['host']?['name'] ?? 'Host'}!'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _invitingHostId = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send invitation: $e')),
        );
      }
    }
  }

  void _handleMatchSuccess(PKBattleModel pk) {
    if (!mounted) return;
    _radarController.stop();

    setState(() {
      _isMatched = true;
      _statusText = 'Opponent Found! Starting 1v1 Battle...';
      _matchedOpponent = pk.hostB;
    });

    context.read<LiveProvider>().setPkBattle(pk);

    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) {
        Navigator.pop(context);
      }
    });
  }

  @override
  void dispose() {
    _pkStartedSub?.cancel();
    _pkAcceptedSub?.cancel();
    _pkDeclinedSub?.cancel();
    _radarController.dispose();
    _vsPulseController.dispose();

    // Leave matchmaking queue if still searching
    final live = context.read<LiveProvider>();
    final roomId = widget.currentRoomId ?? live.activeRoom?.id;
    if (roomId != null) {
      ApiClient.instance.post('/v1/pk/matchmaking/leave', data: {'roomId': roomId}).catchError((_) {});
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFF0A071B),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background Glow
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.2,
                colors: [
                  Color(0xFF2E124D),
                  Color(0xFF0A071B),
                ],
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Header Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white, size: 26),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Text(
                        '1v1 PK Battle Arena',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 44),
                    ],
                  ),
                ),

                // Tabs: Quick Match vs Direct Invite
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicatorColor: const Color(0xFF00E5FF),
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white54,
                    labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    tabs: const [
                      Tab(text: '⚡ Quick Match', icon: Icon(Icons.radar_rounded, size: 18)),
                      Tab(text: '👥 Invite Live Hosts', icon: Icon(Icons.people_alt_rounded, size: 18)),
                    ],
                  ),
                ),

                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // Tab 1: Real Matchmaking Radar
                      _buildQuickMatchTab(user),

                      // Tab 2: Available Real Live Hosts
                      _buildInviteHostsTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickMatchTab(UserModel user) {
    return Column(
      children: [
        const Spacer(),

        // Center Arena Scanner
        Center(
          child: Column(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  // Radar Pulse Rings
                  if (!_isMatched)
                    AnimatedBuilder(
                      animation: _radarAnimation,
                      builder: (context, child) {
                        return Container(
                          width: 170 * _radarAnimation.value,
                          height: 170 * _radarAnimation.value,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF00E5FF).withValues(
                                alpha: (2.0 - _radarAnimation.value).clamp(0.0, 1.0),
                              ),
                              width: 2.0,
                            ),
                          ),
                        );
                      },
                    ),

                  // Host Avatars Side-by-Side Arena Preview
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Current Host (Team Blue)
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: Color(0xFF00E5FF),
                          shape: BoxShape.circle,
                        ),
                        child: UserAvatar(
                          imageUrl: user.avatarUrl,
                          radius: 46,
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Central Pulsating VS Badge
                      ScaleTransition(
                        scale: _vsScale,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFFD700), Color(0xFFFFAB00)],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFFD700).withValues(alpha: 0.8),
                                blurRadius: 16,
                              ),
                            ],
                          ),
                          child: const Text(
                            'VS',
                            style: TextStyle(
                              color: Color(0xFF0A071B),
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Opponent Host (Team Red)
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: _isMatched ? const Color(0xFFFF4081) : Colors.white24,
                          shape: BoxShape.circle,
                        ),
                        child: UserAvatar(
                          imageUrl: _matchedOpponent?.avatarUrl ?? '',
                          radius: 46,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 36),

              // Status Indicator Text
              Text(
                _statusText,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _isMatched ? const Color(0xFF00E5FF) : Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  'Matching with active live hosts in your region in real-time.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ),
            ],
          ),
        ),

        const Spacer(),

        // Cancel / Retry Button
        if (!_isMatched)
          Padding(
            padding: const EdgeInsets.only(bottom: 28),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white30, width: 1.2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                  ),
                  child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _startQuickMatch,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Search Again'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00E5FF),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildInviteHostsTab() {
    if (_isLoadingHosts) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF00E5FF), strokeWidth: 2),
      );
    }

    if (_availableHosts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.live_tv_rounded, size: 52, color: Colors.white38),
              const SizedBox(height: 12),
              const Text(
                'No other live hosts online right now',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 6),
              const Text(
                'When other creators start streaming, they will appear here for 1v1 PK invites.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _loadAvailableHosts,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Refresh List'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white12,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAvailableHosts,
      color: const Color(0xFF00E5FF),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _availableHosts.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final item = _availableHosts[i];
          final host = item['host'] ?? {};
          final hostId = host['id']?.toString() ?? '';
          final hostName = host['name']?.toString() ?? host['username']?.toString() ?? 'Host';
          final avatarUrl = host['avatarUrl']?.toString() ?? '';
          final roomTitle = item['roomTitle']?.toString() ?? 'Live Stream';
          final viewerCount = item['viewerCount'] ?? 0;
          final isInvitingThis = _invitingHostId == hostId;

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Row(
              children: [
                UserAvatar(imageUrl: avatarUrl, radius: 24, isLive: true),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hostName,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$roomTitle • 👥 $viewerCount viewers',
                        style: const TextStyle(color: Colors.white60, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: isInvitingThis ? null : () => _sendDirectInvite(item),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isInvitingThis ? Colors.grey : const Color(0xFFFF4081),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  child: Text(
                    isInvitingThis ? 'Inviting...' : 'Invite to PK',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
