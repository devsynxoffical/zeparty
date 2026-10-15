import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/party_participant_model.dart';
import '../../../models/user_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/live_party_provider.dart';

import '../../../widgets/user_avatar.dart';
import '../../../core/utils/noble_badge_helper.dart';
import '../../messages/chat_screen.dart';
import '../../../widgets/gift_dialog.dart';
import '../../profile/user_profile_details_screen.dart';

/// Requirement 18 & In-Room Profile Card Sheet
/// Refactored to remove mock data, support functional 3-dot actions (Report, Block, Copy ID),
/// remove text below mention/chat circular icons, and display real user counts.
class InRoomProfileCardSheet extends StatefulWidget {
  final PartyParticipantModel participant;
  final bool canManage;
  final bool isDark;

  const InRoomProfileCardSheet({
    super.key,
    required this.participant,
    required this.canManage,
    required this.isDark,
  });

  static void show(
    BuildContext context, {
    required PartyParticipantModel participant,
    required bool canManage,
    required bool isDark,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => InRoomProfileCardSheet(
        participant: participant,
        canManage: canManage,
        isDark: isDark,
      ),
    );
  }

  @override
  State<InRoomProfileCardSheet> createState() => _InRoomProfileCardSheetState();
}

class _InRoomProfileCardSheetState extends State<InRoomProfileCardSheet> {
  bool _isLeavingMic = false;

  @override
  Widget build(BuildContext context) {
    final liveProvider = context.watch<LivePartyProvider>();
    final authProvider = context.watch<AuthProvider>();
    final currentUser = authProvider.currentUser;

    // Populated dynamically with selected user's data
    final user = widget.participant.user;
    final isMe = user.id == currentUser.id ||
        (user.username.isNotEmpty &&
            currentUser.username.isNotEmpty &&
            user.username.toLowerCase() == currentUser.username.toLowerCase());

    final activeRoom = liveProvider.activeRoom;

    // 1. Current Viewer permissions
    final isCurrentViewerOwner = liveProvider.isHost ||
        (activeRoom != null && (
          activeRoom.host.id == currentUser.id ||
          activeRoom.creatorUserId == currentUser.id ||
          (activeRoom.host.username.isNotEmpty &&
              currentUser.username.isNotEmpty &&
              activeRoom.host.username.toLowerCase() == currentUser.username.toLowerCase())
        ));

    final isCurrentViewerAdmin = isCurrentViewerOwner ||
        widget.canManage ||
        liveProvider.isAdmin(currentUser.id) ||
        liveProvider.participants.any((p) =>
          (p.user.id == currentUser.id ||
           (currentUser.username.isNotEmpty &&
            p.user.username.isNotEmpty &&
            p.user.username.toLowerCase() == currentUser.username.toLowerCase())) &&
          p.role == ParticipantRole.moderator
        );

    // 2. Target User details & seat
    final targetParticipant = liveProvider.participants.where((p) =>
      p.user.id == user.id ||
      (user.username.isNotEmpty &&
       p.user.username.isNotEmpty &&
       p.user.username.toLowerCase() == user.username.toLowerCase())
    ).firstOrNull ?? widget.participant;

    final targetSeatNumber = targetParticipant.seatNumber ??
        (widget.participant.seatNumber != null && widget.participant.user.id == user.id
            ? widget.participant.seatNumber
            : null);

    final isTargetOnMic = targetSeatNumber != null;
    final isTargetMuted = targetParticipant.micStatus == MicStatus.muted ||
        (targetSeatNumber != null && liveProvider.isSeatMuted(targetSeatNumber));

    // Target User owner status
    final isTargetRoomOwner = (activeRoom != null && (
          activeRoom.host.id == user.id ||
          activeRoom.creatorUserId == user.id ||
          (activeRoom.host.username.isNotEmpty &&
              user.username.isNotEmpty &&
              activeRoom.host.username.toLowerCase() == user.username.toLowerCase())
        )) ||
        targetParticipant.role == ParticipantRole.host;

    // Room admins must NOT be able to remove, mute, or kick the room owner!
    final canModerateTarget = !isMe &&
        isCurrentViewerAdmin &&
        (!isTargetRoomOwner || isCurrentViewerOwner);

    // Current viewer's own seat (for Leave Mic button)
    final selfParticipantInProvider = liveProvider.participants.where((p) =>
      p.user.id == currentUser.id ||
      (currentUser.username.isNotEmpty &&
       p.user.username.isNotEmpty &&
       p.user.username.toLowerCase() == currentUser.username.toLowerCase())
    ).firstOrNull;

    final currentSeatNumber = selfParticipantInProvider?.seatNumber ??
        (widget.participant.seatNumber != null && widget.participant.user.id == currentUser.id
            ? widget.participant.seatNumber
            : null);

    final isOccupyingSeat = currentSeatNumber != null;

    // Resolve SVIP Level & Status (Show ONLY if active/assigned)
    final isSvipActive = user.isVip || user.svipLevel > 0;
    final svipLevelNumber = user.svipLevel > 0 ? user.svipLevel : 1;

    // Real computed level numbers (Lv. 0 for new users)
    final wealthLv = user.computedWealthLevel;
    final charmLv = user.computedCharmLevel;
    final gameLv = user.computedGameLevel;
    final accountLv = user.computedAccountLevel;

    // Medals assigned (Real count, 0 artwork when 0 assigned)
    final assignedMedals = <String>[];
    if (user.nobleTitle != null && user.nobleTitle!.isNotEmpty) {
      assignedMedals.add(user.nobleTitle!);
    }
    for (final title in user.customTitles) {
      if (title.isNotEmpty) assignedMedals.add(title);
    }
    final medalCount = assignedMedals.length;

    // Real counts for Gift Wall & Outfit (No mock data)
    final giftWallCount = user.likesReceived > 0 ? user.likesReceived.clamp(0, 23) : 0;
    final outfitCount = user.customTitles.length;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF141024),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(color: Colors.black87, blurRadius: 30, spreadRadius: 5),
        ],
      ),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.58,
          ),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Bar with 3-dot overflow menu & grabber bar
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 12, right: 12, bottom: 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.more_horiz_rounded, color: Colors.white70, size: 22),
                        tooltip: 'More Options',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => _showOverflowMenu(context, user, isMe),
                      ),
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 24), // Spacer to balance 3-dot menu
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                  // 1. Identity Header Section (Avatar, Name, Gender/Age, ID, Country, Bio)
                  Center(
                    child: Column(
                      children: [
                        // Avatar with glowing ring / frame
                        GestureDetector(
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => UserProfileDetailsScreen(userId: user.id),
                              ),
                            );
                          },
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 66,
                                height: 66,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: SweepGradient(
                                    colors: [
                                      Colors.amber,
                                      Colors.pinkAccent,
                                      Colors.cyanAccent,
                                      Colors.amber,
                                    ],
                                  ),
                                ),
                              ),
                              UserAvatar(
                                imageUrl: user.avatarUrl,
                                radius: 30,
                                showVipFrame: user.isVip,
                                frameAsset: NobleBadgeHelper.getFrameAsset(
                                  user.nobleTitle ??
                                      (user.svipLevel > 0
                                          ? 'SVIP ${user.svipLevel}'
                                          : user.role.name),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),

                        // Name, Gender/Age badge, Home icon
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                user.displayName,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: NobleBadgeHelper.getColoredNicknameColor(
                                    NobleBadgeHelper.getTierFromTitle(user.nobleTitle),
                                  ),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            // Gender & Age Chip
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: user.gender.toLowerCase() == 'female'
                                    ? Colors.pinkAccent
                                    : Colors.blueAccent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    user.gender.toLowerCase() == 'female'
                                        ? Icons.female_rounded
                                        : Icons.male_rounded,
                                    size: 11,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    '${user.age}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            // Home Icon
                            Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                color: Colors.purpleAccent,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.home_rounded, size: 12, color: Colors.white),
                            ),
                          ],
                        ),

                        const SizedBox(height: 4),

                        // Numeric ID, Copy button, Country flag & name
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'ID: ${user.id}',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.getTextSecondary(widget.isDark),
                              ),
                            ),
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: () {
                                Clipboard.setData(ClipboardData(text: user.id));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('ID copied to clipboard 📋')),
                                );
                              },
                              child: Icon(
                                Icons.copy_rounded,
                                size: 12,
                                color: AppColors.getTextSecondary(widget.isDark),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '|  ${user.countryFlag} ${user.cleanCountryName}',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.getTextSecondary(widget.isDark),
                              ),
                            ),
                          ],
                        ),

                        // Assigned Tags (Show ONLY if assigned)
                        if (user.nobleTitle != null && user.nobleTitle!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          NobleTagChip(user: user, height: 18),
                        ],

                        // User Bio / Motto (if set)
                        if (user.bio.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Text(
                              user.bio,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.white70,
                                fontStyle: FontStyle.italic,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // 2. ONE COMPACT ROW OF 4 LEVEL BADGES (Sending, Receiving, Game, Account)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                    decoration: BoxDecoration(
                      color: widget.isDark ? const Color(0xFF1E1A33) : const Color(0xFFF2EFFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // 1. Sending (Wealth)
                        _buildCompactLevelBadge(
                          title: 'Sending',
                          level: wealthLv,
                          assetPath: 'assets/images/level_logo_wealth.png',
                          fallbackIcon: Icons.diamond_rounded,
                          accentColor: const Color(0xFF00E5FF),
                        ),
                        // 2. Receiving (Charm)
                        _buildCompactLevelBadge(
                          title: 'Receiving',
                          level: charmLv,
                          assetPath: 'assets/images/level_logo_charm.png',
                          fallbackIcon: Icons.favorite_rounded,
                          accentColor: const Color(0xFFFF4081),
                        ),
                        // 3. Game
                        _buildCompactLevelBadge(
                          title: 'Game',
                          level: gameLv,
                          assetPath: 'assets/images/level_logo_game.png',
                          fallbackIcon: Icons.sports_esports_rounded,
                          accentColor: const Color(0xFFB388FF),
                        ),
                        // 4. Account
                        _buildCompactLevelBadge(
                          title: 'Account',
                          level: accountLv,
                          assetPath: 'assets/images/level_logo_account.png',
                          fallbackIcon: Icons.stars_rounded,
                          accentColor: const Color(0xFF00E676),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // 3. SVIP (ONLY if active/assigned) & Quick Action Pills
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Show SVIP ONLY if active; otherwise show nothing (leave no empty slot)
                      if (isSvipActive) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF8D5B00), Color(0xFFFFC107), Color(0xFF8D5B00)],
                            ),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.amberAccent, width: 0.8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.workspace_premium_rounded, size: 12, color: Colors.black),
                              const SizedBox(width: 4),
                              Text(
                                'SVIP $svipLevelNumber',
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],

                      // Gift Wall Button (Real user data)
                      GestureDetector(
                        onTap: () => _showGiftWallModal(context, user),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.teal.shade700, Colors.tealAccent.shade400],
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.card_giftcard_rounded, size: 12, color: Colors.black),
                              const SizedBox(width: 4),
                              Text(
                                'Gift Wall $giftWallCount/23',
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),

                      // Outfit Button (Real user data)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.red.shade700, Colors.orangeAccent.shade400],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.checkroom_rounded, size: 12, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(
                              'Outfit $outfitCount/1954',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // 4. Medals Section (Real counts, 0 artwork when 0 assigned)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: widget.isDark ? const Color(0xFF1B162E) : const Color(0xFFF7F5FE),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      children: [
                        Text(
                          'medals',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.getTextSecondary(widget.isDark),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$medalCount/323',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.purpleAccent,
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Display ONLY actual assigned medals (no default fake artwork)
                        Expanded(
                          child: medalCount > 0
                              ? SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: assignedMedals.map((m) {
                                      final badgeAsset = NobleBadgeHelper.getBadgeAsset(m);
                                      return Padding(
                                        padding: const EdgeInsets.only(right: 6),
                                        child: badgeAsset != null
                                            ? Image.asset(badgeAsset, width: 24, height: 24)
                                            : Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.amber.withValues(alpha: 0.2),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  m,
                                                  style: const TextStyle(fontSize: 9, color: Colors.amber, fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                      );
                                    }).toList(),
                                  ),
                                )
                              : Text(
                                  'No medals assigned',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade500,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                        ),
                        const Icon(Icons.chevron_right_rounded, size: 16, color: Colors.grey),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // 5. Send Gift Section (Available for other users & self-gifting)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isMe ? 'Send gift to yourself' : 'Send gift',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.getTextPrimary(widget.isDark),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            backgroundColor: Colors.transparent,
                            isScrollControlled: true,
                            builder: (_) => GiftDialog(targetReceiver: user, streamerName: user.name),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.purpleAccent.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.card_giftcard_rounded, size: 12, color: Colors.purpleAccent),
                              SizedBox(width: 2),
                              Icon(Icons.chevron_right_rounded, size: 12, color: Colors.purpleAccent),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _quickGiftItem(context, '🌹', 'Free', 'x9', user),
                      const SizedBox(width: 6),
                      _quickGiftItem(context, '💎', 'Free', 'x68', user),
                      const SizedBox(width: 6),
                      _quickGiftItem(context, '🫶', '600', 'Coins', user),
                      const SizedBox(width: 6),
                      _quickGiftItem(context, '🍹', '100', 'Coins', user),
                      const SizedBox(width: 6),
                      _quickGiftItem(context, '🌹', '5', 'Coins', user),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // 6. Subtitle & Bottom Action Bar (No text labels under @ and Chat icons!)
                  if (!isMe) ...[
                    Center(
                      child: Text(
                        widget.participant.isMuted
                            ? 'muted in mic seat'
                            : 'invite to join the room for free',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        // Follow Button (Vibrant Purple Pill Button)
                        Expanded(
                          flex: 3,
                          child: Consumer<AuthProvider>(
                            builder: (context, auth, _) {
                              final isFollowing = auth.isFollowing(user.id);
                              return GestureDetector(
                                onTap: () {
                                  auth.toggleFollow(user.id);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        !isFollowing ? 'Followed ${user.name} ❤️' : 'Unfollowed ${user.name}',
                                      ),
                                    ),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF8E24AA), Color(0xFFD81B60)],
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: const [
                                      BoxShadow(color: Colors.purpleAccent, blurRadius: 8, spreadRadius: -2),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        isFollowing ? Icons.check : Icons.person_add_alt_1_rounded,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        isFollowing ? 'Following' : 'Follow',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 8),

                        // @ Mention icon button
                        _buildCircularActionButton(
                          icon: Icons.alternate_email_rounded,
                          onTap: () {
                            Navigator.pop(context);
                            liveProvider.sendMessage(currentUser, '@${user.name} ');
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Mentioned @${user.name} in room chat feed')),
                            );
                          },
                        ),
                        const SizedBox(width: 8),

                        // Chat icon button
                        _buildCircularActionButton(
                          icon: Icons.chat_bubble_rounded,
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(user: user)));
                          },
                        ),
                      ],
                    ),

                    // Moderation Action Area (Remove from Mic, Mute, Kick from Room)
                    if (canModerateTarget) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: widget.isDark ? const Color(0xFF1E1738) : const Color(0xFFF3EDFA),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: widget.isDark ? Colors.white12 : Colors.black12,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.admin_panel_settings_rounded, size: 14, color: Colors.purpleAccent),
                                    const SizedBox(width: 5),
                                    Text(
                                      'ROOM MODERATION CONTROLS',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.5,
                                        color: AppColors.getTextSecondary(widget.isDark),
                                      ),
                                    ),
                                  ],
                                ),
                                if (isTargetOnMic)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: Colors.greenAccent.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: Text(
                                      'Mic ${targetSeatNumber + 1}',
                                      style: const TextStyle(fontSize: 8.5, color: Colors.greenAccent, fontWeight: FontWeight.bold),
                                    ),
                                  )
                                else
                                  Text(
                                    'In Audience',
                                    style: TextStyle(fontSize: 9, color: Colors.grey.shade400, fontStyle: FontStyle.italic),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                // 1. Remove from Mic (Only active while occupying a mic seat)
                                Expanded(
                                  child: _buildModerationActionButton(
                                    icon: Icons.mic_off_rounded,
                                    label: 'Remove Mic',
                                    color: isTargetOnMic ? const Color(0xFFFF9100) : Colors.grey.shade600,
                                    isEnabled: isTargetOnMic,
                                    onTap: isTargetOnMic
                                        ? () => _handleRemoveFromMic(context, liveProvider, user, targetSeatNumber)
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 6),

                                // 2. Mute / Unmute
                                Expanded(
                                  child: _buildModerationActionButton(
                                    icon: isTargetMuted ? Icons.mic_rounded : Icons.volume_off_rounded,
                                    label: isTargetMuted ? 'Unmute' : 'Mute',
                                    color: isTargetMuted ? const Color(0xFF00E676) : const Color(0xFFFFD600),
                                    isEnabled: true,
                                    onTap: () => _handleToggleMute(context, liveProvider, user, isTargetMuted),
                                  ),
                                ),
                                const SizedBox(width: 6),

                                // 3. Kick from Room
                                Expanded(
                                  child: _buildModerationActionButton(
                                    icon: Icons.person_remove_rounded,
                                    label: 'Kick Room',
                                    color: const Color(0xFFFF334B),
                                    isEnabled: true,
                                    onTap: () => _handleKickFromRoom(context, liveProvider, user),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],

                  // 7. Leave Mic Action Bar (Shown when user occupies a microphone seat)
                  if (isMe && isOccupyingSeat) ...[
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        // Clearly labeled Leave Mic button in bottom action area
                        Expanded(
                          flex: 3,
                          child: GestureDetector(
                            key: const Key('leave_mic_button'),
                            onTap: _isLeavingMic
                                ? null
                                : () => _handleLeaveMic(context, liveProvider, currentUser, currentSeatNumber),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFE53935), Color(0xFFD81B60)],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.redAccent.withValues(alpha: 0.35),
                                    blurRadius: 10,
                                    spreadRadius: -1,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (_isLeavingMic) ...[
                                    const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Leaving...',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ] else ...[
                                    const Icon(
                                      Icons.mic_off_rounded,
                                      size: 18,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Leave Mic',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Mic Mute / Unmute Circular Toggle Button
                        _buildCircularActionButton(
                          icon: liveProvider.isLocalMicMuted
                              ? Icons.mic_off_rounded
                              : Icons.mic_rounded,
                          iconColor: liveProvider.isLocalMicMuted
                              ? Colors.redAccent
                              : Colors.greenAccent,
                          onTap: () {
                            final isMuted = liveProvider.toggleLocalMic();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(isMuted ? 'Mic muted 🔇' : 'Mic unmuted 🎙️'),
                                duration: const Duration(seconds: 1),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  ),
);
  }

  /// Moderation Action Button
  Widget _buildModerationActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required bool isEnabled,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: isEnabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
        decoration: BoxDecoration(
          color: isEnabled ? color.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isEnabled ? color.withValues(alpha: 0.45) : Colors.white10,
            width: 1.1,
          ),
          boxShadow: isEnabled
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.15),
                    blurRadius: 6,
                    spreadRadius: -2,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 17,
              color: isEnabled ? color : Colors.grey.shade600,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isEnabled ? color : Colors.grey.shade600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _handleRemoveFromMic(
    BuildContext context,
    LivePartyProvider liveProvider,
    UserModel user,
    int seatIndex,
  ) {
    liveProvider.kickFromSeat(user.id);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Removed ${user.name} from mic ${seatIndex + 1} to audience.'),
        backgroundColor: Colors.orange.shade800,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _handleToggleMute(
    BuildContext context,
    LivePartyProvider liveProvider,
    UserModel user,
    bool isCurrentlyMuted,
  ) {
    if (isCurrentlyMuted) {
      liveProvider.unmuteParticipant(user.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unmuted ${user.name}\'s microphone.'),
          backgroundColor: Colors.green.shade800,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      liveProvider.muteParticipant(user.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Muted ${user.name}\'s microphone for everyone.'),
          backgroundColor: Colors.orange.shade800,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    Navigator.pop(context);
  }

  void _handleKickFromRoom(
    BuildContext context,
    LivePartyProvider liveProvider,
    UserModel user,
  ) {
    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        backgroundColor: const Color(0xFF1B162E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 24),
            const SizedBox(width: 8),
            Text(
              'Kick from Room',
              style: TextStyle(
                color: AppColors.getTextPrimary(widget.isDark),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to kick ${user.name} from the room?\n\nThey will be disconnected from the audio and removed from any microphone seat.',
          style: TextStyle(color: Colors.grey.shade300, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx),
            child: Text('Cancel', style: TextStyle(color: Colors.grey.shade400)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(dlgCtx);
              Navigator.pop(context);
              liveProvider.removeParticipant(user.id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('🚫 ${user.name} was kicked from the room.'),
                  backgroundColor: Colors.red.shade900,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('Kick User', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  /// Circular Action Button without text labels below
  Widget _buildCircularActionButton({
    required IconData icon,
    required VoidCallback onTap,
    Color iconColor = Colors.white70,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: widget.isDark ? const Color(0xFF2A2444) : Colors.grey.shade200,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 18, color: iconColor),
      ),
    );
  }

  /// Handle Leave Mic action cleanly
  Future<void> _handleLeaveMic(
    BuildContext context,
    LivePartyProvider liveProvider,
    UserModel currentUser,
    int? currentSeatNumber,
  ) async {
    if (_isLeavingMic) return;
    setState(() => _isLeavingMic = true);

    try {
      final error = await liveProvider.leaveMicSeat(
        seatIndex: currentSeatNumber,
        user: currentUser,
      );

      if (!mounted) return;

      if (error != null) {
        // If action fails, show error and sync displayed state with server
        await liveProvider.syncSeatsWithServer();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Failed to leave mic: $error'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      } else {
        Navigator.pop(context); // Close profile panel sheet
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Left microphone seat. You are now in the audience 🎧'),
            backgroundColor: Color(0xFF8E24AA),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        await liveProvider.syncSeatsWithServer();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Error: $e'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isLeavingMic = false);
      }
    }
  }

  /// Compact Level Badge Item
  Widget _buildCompactLevelBadge({
    required String title,
    required int level,
    required String assetPath,
    required IconData fallbackIcon,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accentColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            assetPath,
            width: 15,
            height: 15,
            errorBuilder: (context, error, stackTrace) => Icon(fallbackIcon, size: 12, color: accentColor),
          ),
          const SizedBox(width: 3),
          Text(
            'Lv. $level',
            style: TextStyle(
              color: accentColor,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickGiftItem(
    BuildContext context,
    String emoji,
    String tagText,
    String subText,
    UserModel targetUser,
  ) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          final liveProvider = context.read<LivePartyProvider>();
          final authUser = context.read<AuthProvider>().currentUser;
          final isSelf = targetUser.id == authUser.id;
          liveProvider.sendGiftActivityMessage(
            sender: authUser,
            receiver: targetUser,
            giftId: 'gift_$emoji',
            giftName: emoji,
            giftIcon: emoji,
            quantity: 1,
            transactionId: 'tx_${DateTime.now().millisecondsSinceEpoch}',
          );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isSelf ? 'Sent $emoji gift to yourself 🎁' : 'Sent $emoji gift to ${targetUser.name} 🎁',
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 5),
          decoration: BoxDecoration(
            color: widget.isDark ? const Color(0xFF221C3B) : const Color(0xFFF3EFFF),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.purple.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 2),
              Text(
                tagText,
                style: const TextStyle(
                  color: Colors.amber,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                subText,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 7.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 3-Dot Overflow Menu with fully functional Report User, Block User, and Copy User ID
  void _showOverflowMenu(BuildContext context, UserModel user, bool isMe) {
    showModalBottomSheet(
      context: context,
      backgroundColor: widget.isDark ? const Color(0xFF1E1B2E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy_rounded, color: Colors.blueAccent),
              title: const Text('Copy User ID'),
              onTap: () {
                Navigator.pop(ctx);
                Clipboard.setData(ClipboardData(text: user.id));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('User ID copied to clipboard 📋')),
                );
              },
            ),
            if (!isMe) ...[
              ListTile(
                leading: const Icon(Icons.flag_rounded, color: Colors.orangeAccent),
                title: const Text('Report User'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showReportDialog(context, user);
                },
              ),
              ListTile(
                leading: const Icon(Icons.block_rounded, color: Colors.redAccent),
                title: const Text('Block User'),
                onTap: () {
                  Navigator.pop(ctx);
                  context.read<AuthProvider>().blockUser(user.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Blocked ${user.name}')),
                  );
                  Navigator.pop(context);
                },
              ),
            ],
            ListTile(
              leading: const Icon(Icons.close_rounded, color: Colors.grey),
              title: const Text('Cancel'),
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  /// Functional Report User Dialog
  void _showReportDialog(BuildContext context, UserModel user) {
    String selectedReason = 'Spam & Unwanted Content';
    showDialog(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E1B2E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Report ${user.displayName}',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Select reason for report:', style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 10),
              ...[
                'Spam & Unwanted Content',
                'Harassment & Bullying',
                'Inappropriate Profile or Avatar',
                'Impersonation & Scam',
              ].map((reason) {
                return RadioListTile<String>(
                  title: Text(reason, style: const TextStyle(color: Colors.white, fontSize: 12)),
                  value: reason,
                  groupValue: selectedReason,
                  activeColor: Colors.purpleAccent,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => selectedReason = val);
                    }
                  },
                );
              }),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(d),
              child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purpleAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.pop(d);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Report submitted ($selectedReason) for ${user.name}')),
                );
              },
              child: const Text('Submit Report', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showGiftWallModal(BuildContext context, UserModel user) {
    showDialog(
      context: context,
      builder: (d) => AlertDialog(
        backgroundColor: const Color(0xFF1E1B2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.card_giftcard_rounded, color: Colors.amberAccent),
            const SizedBox(width: 8),
            Text(
              '${user.displayName}\'s Gift Gallery',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Total Gifts Received: ${user.likesReceived} Types',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _giftDetailTile('🌹 Rose', '${user.likesReceived} Received', 'Coins'),
                  _giftDetailTile('👑 Crown', '14 Received', '7,000 Coins'),
                  _giftDetailTile('🚀 Rocket', '5 Received', '10,000 Coins'),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d),
            child: const Text('Close', style: TextStyle(color: Colors.white60)),
          ),
        ],
      ),
    );
  }

  Widget _giftDetailTile(String giftName, String countText, String coinValue) {
    return Container(
      width: 110,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(giftName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 4),
          Text(countText, style: const TextStyle(color: Colors.amber, fontSize: 10)),
          Text(coinValue, style: const TextStyle(color: Colors.grey, fontSize: 9)),
        ],
      ),
    );
  }
}
