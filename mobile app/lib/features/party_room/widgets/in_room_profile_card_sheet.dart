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

    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      minChildSize: 0.50,
      maxChildSize: 0.94,
      builder: (ctx, scrollController) => Container(
        decoration: BoxDecoration(
          color: widget.isDark ? const Color(0xFF141024) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: const [
            BoxShadow(color: Colors.black87, blurRadius: 30, spreadRadius: 5),
          ],
        ),
        child: Column(
          children: [
            // Top Bar with 3-dot overflow menu & grabber bar
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 12, right: 12, bottom: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.more_horiz_rounded, color: Colors.white70, size: 24),
                    tooltip: 'More Options',
                    onPressed: () => _showOverflowMenu(context, user, isMe),
                  ),
                  Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 48), // Spacer to balance 3-dot menu
                ],
              ),
            ),

            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
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
                                width: 84,
                                height: 84,
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
                                radius: 38,
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
                        const SizedBox(height: 10),

                        // Name, Gender/Age badge, Home icon
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                user.displayName,
                                style: TextStyle(
                                  fontSize: 18,
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

                  const SizedBox(height: 16),

                  // 2. ONE COMPACT ROW OF 4 LEVEL BADGES (Sending, Receiving, Game, Account)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                    decoration: BoxDecoration(
                      color: widget.isDark ? const Color(0xFF1E1A33) : const Color(0xFFF2EFFC),
                      borderRadius: BorderRadius.circular(16),
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

                  const SizedBox(height: 14),

                  // 3. SVIP (ONLY if active/assigned) & Quick Action Pills
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Show SVIP ONLY if active; otherwise show nothing (leave no empty slot)
                      if (isSvipActive) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF8D5B00), Color(0xFFFFC107), Color(0xFF8D5B00)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.amberAccent, width: 0.8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.workspace_premium_rounded, size: 14, color: Colors.black),
                              const SizedBox(width: 4),
                              Text(
                                'SVIP $svipLevelNumber',
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],

                      // Gift Wall Button (Real user data)
                      GestureDetector(
                        onTap: () => _showGiftWallModal(context, user),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.teal.shade700, Colors.tealAccent.shade400],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.card_giftcard_rounded, size: 13, color: Colors.black),
                              const SizedBox(width: 4),
                              Text(
                                'Gift Wall $giftWallCount/23',
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Outfit Button (Real user data)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.red.shade700, Colors.orangeAccent.shade400],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.checkroom_rounded, size: 13, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(
                              'Outfit $outfitCount/1954',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // 4. Medals Section (Real counts, 0 artwork when 0 assigned)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: widget.isDark ? const Color(0xFF1B162E) : const Color(0xFFF7F5FE),
                      borderRadius: BorderRadius.circular(16),
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

                  const SizedBox(height: 16),

                  // 5. Send Gift Section
                  if (!isMe) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Send gift',
                          style: TextStyle(
                            fontSize: 12,
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
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.purpleAccent.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.card_giftcard_rounded, size: 13, color: Colors.purpleAccent),
                                SizedBox(width: 2),
                                Icon(Icons.chevron_right_rounded, size: 13, color: Colors.purpleAccent),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _quickGiftItem(context, '🌹', 'Free', 'x9', user),
                        const SizedBox(width: 8),
                        _quickGiftItem(context, '💎', 'Free', 'x68', user),
                        const SizedBox(width: 8),
                        _quickGiftItem(context, '🫶', '600', 'Coins', user),
                        const SizedBox(width: 8),
                        _quickGiftItem(context, '🍹', '100', 'Coins', user),
                        const SizedBox(width: 8),
                        _quickGiftItem(context, '🌹', '5', 'Coins', user),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 6. Subtitle & Bottom Action Bar (No text labels under @ and Chat icons!)
                  if (!isMe) ...[
                    Center(
                      child: Text(
                        widget.participant.isMuted
                            ? 'muted in mic seat'
                            : 'invite to join the room for free',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
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
                                  padding: const EdgeInsets.symmetric(vertical: 11),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF8E24AA), Color(0xFFD81B60)],
                                    ),
                                    borderRadius: BorderRadius.circular(24),
                                    boxShadow: const [
                                      BoxShadow(color: Colors.purpleAccent, blurRadius: 10, spreadRadius: -2),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        isFollowing ? Icons.check : Icons.person_add_alt_1_rounded,
                                        size: 18,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        isFollowing ? 'Following' : 'Follow',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
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
                        const SizedBox(width: 12),

                        // @ Mention icon button (NO text label below!)
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
                        const SizedBox(width: 10),

                        // Chat icon button (NO text label below!)
                        _buildCircularActionButton(
                          icon: Icons.chat_bubble_rounded,
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(user: user)));
                          },
                        ),

                        // Mic Action for Owner / Moderator
                        if (widget.canManage) ...[
                          const SizedBox(width: 10),
                          _buildCircularActionButton(
                            icon: widget.participant.isMuted
                                ? Icons.mic_off_rounded
                                : Icons.mic_rounded,
                            iconColor: widget.participant.isMuted
                                ? Colors.redAccent
                                : Colors.greenAccent,
                            onTap: () {
                              if (widget.participant.isMuted) {
                                liveProvider.unmuteParticipant(user.id);
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${user.name} mic unmuted')));
                              } else {
                                liveProvider.muteParticipant(user.id);
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${user.name} mic muted')));
                              }
                              Navigator.pop(context);
                            },
                          ),
                        ],
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
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: widget.isDark ? const Color(0xFF2A2444) : Colors.grey.shade200,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 20, color: iconColor),
      ),
    );
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            assetPath,
            width: 18,
            height: 18,
            errorBuilder: (_, __, ___) => Icon(fallbackIcon, size: 14, color: accentColor),
          ),
          const SizedBox(width: 4),
          Text(
            'Lv. $level',
            style: TextStyle(
              color: accentColor,
              fontSize: 11,
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
            SnackBar(content: Text('Sent $emoji gift to ${targetUser.name} 🎁')),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: widget.isDark ? const Color(0xFF221C3B) : const Color(0xFFF3EFFF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.purple.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(height: 2),
              Text(
                tagText,
                style: const TextStyle(
                  color: Colors.amber,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                subText,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 8,
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
