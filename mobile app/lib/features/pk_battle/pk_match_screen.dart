import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/repositories/pk_repository.dart';
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

class _PkMatchScreenState extends State<PkMatchScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _userIdController = TextEditingController();

  List<UserModel> _availableHosts = [];
  bool _isLoadingHosts = false;
  String? _invitingUserId;
  bool _isCreatingSession = false;
  bool _isStartingPk = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _ensurePKSessionAndLoadHosts();
  }

  Future<void> _ensurePKSessionAndLoadHosts() async {
    final liveProv = context.read<LiveProvider>();
    final authProv = context.read<AuthProvider>();
    final currentUser = authProv.currentUser;

    // Verify host authority
    final isHost = liveProv.activeRoom != null &&
        (liveProv.activeRoom!.host.id == currentUser.id ||
            liveProv.activeRoom!.creatorUserId == currentUser.id);

    if (!isHost) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Only active live hosts can initiate a PK Battle.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      Navigator.pop(context);
      return;
    }

    // If no active PK session exists yet for this room, create one (State: CREATED)
    if (liveProv.activePkBattle == null) {
      setState(() => _isCreatingSession = true);
      try {
        await liveProv.createHostPKBattle(durationSeconds: 300);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to initialize PK session: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _isCreatingSession = false);
      }
    }

    _loadAvailableHosts();
  }

  Future<void> _loadAvailableHosts() async {
    setState(() => _isLoadingHosts = true);
    try {
      final hosts = await PKRepository.instance.getAvailableLiveHosts();
      final authUserId = context.read<AuthProvider>().currentUser.id;
      if (mounted) {
        setState(() {
          _availableHosts = hosts.where((h) => h.id != authUserId).toList();
          _isLoadingHosts = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingHosts = false);
    }
  }

  Future<void> _sendDirectInvite(String targetUserId, String targetName) async {
    final liveProv = context.read<LiveProvider>();
    if (liveProv.activePkBattle == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PK session is initializing, please wait...')),
      );
      return;
    }

    setState(() => _invitingUserId = targetUserId);
    try {
      await liveProv.sendPKInvite(targetUserId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✉️ PK invitation sent to $targetName!'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send invitation: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _invitingUserId = null);
    }
  }

  Future<void> _startPKBattle() async {
    final liveProv = context.read<LiveProvider>();
    final pk = liveProv.activePkBattle;

    if (pk == null || pk.totalParticipants < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Need at least 2 participants to start PK Battle.')),
      );
      return;
    }

    setState(() => _isStartingPk = true);
    try {
      final startedPk = await liveProv.startHostPKBattle();
      if (mounted && startedPk != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => PKBattleScreen(pkBattle: startedPk),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start PK: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isStartingPk = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _userIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final liveProv = context.watch<LiveProvider>();
    final pk = liveProv.activePkBattle;
    final participantCount = pk?.totalParticipants ?? 1;
    final canStart = participantCount >= 2;

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
                      const Column(
                        children: [
                          Text(
                            'PK Battle Host Center',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 17,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            '2 to 4 Participants • Server Authoritative',
                            style: TextStyle(
                              color: Color(0xFF00E5FF),
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 44),
                    ],
                  ),
                ),

                // Participant Slots Banner (1 to 4)
                _buildParticipantSlotsBanner(pk),

                // Navigation Tabs (Path A vs Path B)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
                    labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    tabs: const [
                      Tab(text: '⚔️ Path A: Live Hosts', icon: Icon(Icons.tv_rounded, size: 18)),
                      Tab(text: '🔗 Path B: Invite User', icon: Icon(Icons.link_rounded, size: 18)),
                    ],
                  ),
                ),

                // Tabs Body
                Expanded(
                  child: _isCreatingSession
                      ? const Center(
                          child: CircularProgressIndicator(color: Color(0xFF00E5FF)),
                        )
                      : TabBarView(
                          controller: _tabController,
                          children: [
                            _buildHostVsHostTab(),
                            _buildHostInviteUserTab(pk),
                          ],
                        ),
                ),

                // Bottom Action Bar: "Start PK Battle"
                _buildBottomActionBar(canStart, participantCount),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantSlotsBanner(PKBattleModel? pk) {
    final participants = pk?.participantList ?? [];
    final totalSlots = 4;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'PARTICIPANTS (2 - 4)',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: participants.length >= 2
                      ? AppColors.success.withValues(alpha: 0.2)
                      : Colors.orangeAccent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: participants.length >= 2 ? AppColors.success : Colors.orangeAccent,
                    width: 1,
                  ),
                ),
                child: Text(
                  '${participants.length}/4 Active',
                  style: TextStyle(
                    color: participants.length >= 2 ? AppColors.success : Colors.orangeAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(totalSlots, (index) {
              final slotNumber = index + 1;
              final participant = index < participants.length ? participants[index] : null;

              return Column(
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: participant != null
                                ? (participant.isHost ? const Color(0xFF00E5FF) : Colors.purpleAccent)
                                : Colors.white24,
                            width: 2,
                          ),
                        ),
                        child: participant != null
                            ? UserAvatar(
                                imageUrl: participant.avatarUrl,
                                radius: 26,
                              )
                            : const Icon(
                                Icons.person_add_alt_1_rounded,
                                color: Colors.white30,
                                size: 24,
                              ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0A071B),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Text(
                            '$slotNumber',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: 64,
                    child: Text(
                      participant != null
                          ? (participant.isHost ? '${participant.name} (Host)' : participant.name)
                          : 'Empty',
                      style: TextStyle(
                        color: participant != null ? Colors.white : Colors.white38,
                        fontSize: 10,
                        fontWeight: participant != null ? FontWeight.w600 : FontWeight.normal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildHostVsHostTab() {
    if (_isLoadingHosts) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF)));
    }

    if (_availableHosts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.live_tv_rounded, color: Colors.white24, size: 56),
              const SizedBox(height: 12),
              const Text(
                'No other live hosts online right now',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 6),
              const Text(
                'Use Path B to invite any user via direct PK Invite Link or Code!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadAvailableHosts,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Refresh Hosts'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E5FF),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _availableHosts.length,
      itemBuilder: (context, index) {
        final host = _availableHosts[index];
        final isInviting = _invitingUserId == host.id;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            children: [
              UserAvatar(imageUrl: host.avatarUrl, radius: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      host.name.isNotEmpty ? host.name : host.username,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.greenAccent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Live Host',
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: isInviting ? null : () => _sendDirectInvite(host.id, host.name),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E5FF),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: isInviting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                      )
                    : const Text(
                        'Invite to PK',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHostInviteUserTab(PKBattleModel? pk) {
    final inviteCode = pk?.inviteCode ?? 'PK-${pk?.id.substring(0, 6).toUpperCase()}';
    final shareUrl = 'zeparty://pk/invite/$inviteCode';

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PK Invite Link & Code',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Share this invite code or link with any user. When they accept, they will join your PK Battle screen as an authorized participant (max 4).',
            style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 16),

          // Code Box
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF00E5FF).withValues(alpha: 0.15),
                  Colors.purpleAccent.withValues(alpha: 0.15),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'INVITE CODE',
                      style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      inviteCode,
                      style: const TextStyle(
                        color: Color(0xFF00E5FF),
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.0,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, color: Colors.white, size: 24),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: inviteCode));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('📋 PK Invite Code copied to clipboard!'),
                        backgroundColor: AppColors.primary,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          const Text(
            'Direct User Invite',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _userIdController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Enter User ID or Username...',
                    hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.06),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFF00E5FF)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: () {
                  final target = _userIdController.text.trim();
                  if (target.isNotEmpty) {
                    _sendDirectInvite(target, target);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E5FF),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Send', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionBar(bool canStart, int participantCount) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF140D2B),
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!canStart)
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.info_outline_rounded, color: Colors.orangeAccent, size: 16),
                  SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'At least 2 participants required before PK can start',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.orangeAccent, fontSize: 11.5, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: canStart && !_isStartingPk ? _startPKBattle : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E5FF),
                disabledBackgroundColor: Colors.white.withValues(alpha: 0.12),
                foregroundColor: Colors.black,
                disabledForegroundColor: Colors.white38,
                elevation: canStart ? 8 : 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _isStartingPk
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black),
                    )
                  : Text(
                      canStart ? '🔥 START PK BATTLE ($participantCount/4 READY)' : 'WAITING FOR PARTICIPANTS...',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        letterSpacing: 0.5,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
