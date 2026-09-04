import 'package:flutter/material.dart';
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
import '../../../widgets/profile_status_strip.dart';
import '../../profile/user_profile_details_screen.dart';

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

    final user = widget.participant.user;
    final isMe = user.id == currentUser.id;

    // Resolve room role string
    String roomRole = 'Member';
    if (widget.participant.role == ParticipantRole.host) {
      roomRole = 'Owner / Host 👑';
    } else if (widget.participant.role == ParticipantRole.moderator) {
      roomRole = 'Room Admin 🛡️';
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.45,
      maxChildSize: 0.90,
      builder: (ctx, scrollController) => Container(
        decoration: BoxDecoration(
          color: widget.isDark ? const Color(0xFF161226) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: const [
            BoxShadow(color: Colors.black54, blurRadius: 25, spreadRadius: 5),
          ],
        ),
        child: Column(
          children: [
            // Top Grabber Bar
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(3),
              ),
            ),

            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                children: [
                  // 1. Identity Header Block (Tapping opens Full UserProfileDetailsScreen)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => UserProfileDetailsScreen(userId: user.id)),
                          );
                        },
                        child: Stack(
                          children: [
                            UserAvatar(
                              imageUrl: user.avatarUrl,
                              radius: 36,
                              showVipFrame: user.isVip,
                            ),
                            if (user.avatarFrame.isNotEmpty)
                              Positioned(
                                top: -4,
                                right: -4,
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: const BoxDecoration(
                                    color: Colors.amber,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.star_rounded, size: 12, color: Colors.black),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => UserProfileDetailsScreen(userId: user.id)),
                            );
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      user.name,
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
                                  const SizedBox(width: 4),
                                  NobleBadgeChip(user: user, fontSize: 9),
                                  const SizedBox(width: 6),
                                  if (user.isVip)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(colors: [Colors.amber, Colors.orangeAccent]),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        user.vipLevel,
                                        style: const TextStyle(color: Colors.black, fontSize: 9, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'ID: ${user.id} • 🌐 ${user.region}',
                                style: TextStyle(fontSize: 11, color: AppColors.getTextSecondary(widget.isDark)),
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  _badgeChip(roomRole, Colors.purpleAccent),
                                  if (user.agencyName != null && user.agencyName!.isNotEmpty)
                                    _badgeChip('Agency: ${user.agencyName}', Colors.blueAccent),
                                  if (user.isHost) _badgeChip('Official Host', Colors.amber),
                                  if (user.isSeller) _badgeChip('Coin Seller', Colors.green),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Explicit Full Profile Navigation Button
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => UserProfileDetailsScreen(userId: user.id)),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.getPrimary(widget.isDark).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.getPrimary(widget.isDark).withValues(alpha: 0.5)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Profile', style: TextStyle(color: AppColors.getPrimary(widget.isDark), fontSize: 10, fontWeight: FontWeight.bold)),
                              const SizedBox(width: 2),
                              Icon(Icons.chevron_right_rounded, size: 14, color: AppColors.getPrimary(widget.isDark)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  ProfileStatusStrip(user: user),
                  const SizedBox(height: 12),
                  const Divider(color: Colors.white12),

                  // 2. Separate Levels Display (Account, Sending/Wealth, Receiving/Charm, Game)
                  Text(
                    'Level Center & Tier Progression',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.getTextPrimary(widget.isDark),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _levelCard(
                          context,
                          title: 'Account',
                          level: 'Lv. ${user.accountLevel}',
                          icon: Icons.person_rounded,
                          color: Colors.blueAccent,
                          user: user,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _levelCard(
                          context,
                          title: 'Wealth',
                          level: 'Lv. ${user.wealthLevel}',
                          icon: Icons.diamond_rounded,
                          color: Colors.amberAccent,
                          user: user,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _levelCard(
                          context,
                          title: 'Charm',
                          level: 'Lv. ${user.charmLevel}',
                          icon: Icons.favorite_rounded,
                          color: Colors.pinkAccent,
                          user: user,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _levelCard(
                          context,
                          title: 'Game',
                          level: 'Lv. ${user.gameLevel}',
                          icon: Icons.sports_esports_rounded,
                          color: Colors.cyanAccent,
                          user: user,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // 3. Gift Wall & Achievements
                  GestureDetector(
                    onTap: () => _showGiftWallModal(context, user),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: widget.isDark ? const Color(0xFF201B36) : const Color(0xFFF3F0FC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.purple.withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    const Icon(Icons.card_giftcard_rounded, color: Colors.amberAccent, size: 18),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'Gift Wall & Medal Collection',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.getTextPrimary(widget.isDark),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Row(
                                children: [
                                  Text('18 Gifts • 5 Medals', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                  SizedBox(width: 2),
                                  Icon(Icons.chevron_right_rounded, size: 14, color: Colors.grey),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _giftIconChip('🌹', 'Rose x120'),
                              _giftIconChip('👑', 'Crown x14'),
                              _giftIconChip('🚀', 'Rocket x5'),
                              _giftIconChip('🏎️', 'Supercar x2'),
                              _giftIconChip('🏰', 'Castle x1'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 4. CP Relationship Section (Only if active approved relationship)
                  if (user.cpPartnerId != null || user.cpPoints > 0) ...[
                    GestureDetector(
                      onTap: () => _showCpDetailsModal(context, user),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.pinkAccent.withValues(alpha: 0.15),
                              Colors.purpleAccent.withValues(alpha: 0.15),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.pinkAccent.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const CircleAvatar(
                              radius: 16,
                              backgroundColor: Colors.pinkAccent,
                              child: Icon(Icons.favorite, color: Colors.white, size: 16),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Active CP Relationship (Sweet Lovers ❤️)',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.pinkAccent),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Partner: @${user.cpPartnerId ?? "Danial_Official"} • CP Level 5 (${user.cpPoints} Intimacy)',
                                    style: TextStyle(fontSize: 10, color: AppColors.getTextSecondary(widget.isDark)),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded, color: Colors.pinkAccent, size: 18),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 5. Quick Gift Bar
                  if (!isMe) ...[
                    Text(
                      'Quick Gift Selection',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(widget.isDark)),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _quickGiftChip(context, '🌹 Rose', 10, user),
                        const SizedBox(width: 8),
                        _quickGiftChip(context, '💎 Crown', 500, user),
                        const SizedBox(width: 8),
                        _quickGiftChip(context, '🚀 Rocket', 2000, user),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.getPrimary(widget.isDark),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                            onPressed: () {
                              showDialog(context: context, builder: (_) => GiftDialog(targetReceiver: user, streamerName: user.name));
                            },
                            child: const Text('All Gifts 🎁', style: TextStyle(fontSize: 11, color: Colors.white)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 6. Action Buttons Bar (Follow, Message, Send Gift, Mention)
                  if (!isMe)
                    Row(
                      children: [
                         Expanded(
                          child: Consumer<AuthProvider>(
                            builder: (context, auth, _) {
                              final isFollowing = auth.isFollowing(user.id);
                              return ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isFollowing ? Colors.grey : Colors.purpleAccent,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                icon: Icon(isFollowing ? Icons.check : Icons.person_add_alt_1_rounded, size: 16, color: Colors.white),
                                label: Text(isFollowing ? 'Following' : 'Follow', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                onPressed: () {
                                  auth.toggleFollow(user.id);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(!isFollowing ? 'Followed ${user.name} ❤️' : 'Unfollowed ${user.name}')),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          style: IconButton.styleFrom(backgroundColor: widget.isDark ? const Color(0xFF2A2444) : Colors.grey.shade200),
                          icon: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.blueAccent, size: 20),
                          tooltip: 'Direct Message',
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(user: user)));
                          },
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          style: IconButton.styleFrom(backgroundColor: widget.isDark ? const Color(0xFF2A2444) : Colors.grey.shade200),
                          icon: const Icon(Icons.alternate_email_rounded, color: Colors.amber, size: 20),
                          tooltip: '@ Mention In-Chat',
                          onPressed: () {
                            Navigator.pop(context);
                            liveProvider.sendMessage(currentUser, '@${user.name} ');
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Mentioned @${user.name} in room chat feed')));
                          },
                        ),
                      ],
                    ),

                  // 7. Role-Protected Moderation Section (Host / Owner / Admin)
                  if (widget.canManage && !isMe) ...[
                    const SizedBox(height: 16),
                    const Divider(color: Colors.white12),
                    Text(
                      'Role-Protected Room Moderation',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.redAccent.shade100),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.orangeAccent)),
                            icon: const Icon(Icons.mic_off_rounded, size: 14, color: Colors.orangeAccent),
                            label: const Text('Mute Mic', style: TextStyle(color: Colors.orangeAccent, fontSize: 11)),
                            onPressed: () {
                              liveProvider.muteParticipant(user.id);
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${user.name} mic muted')));
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.redAccent)),
                            icon: const Icon(Icons.output_rounded, size: 14, color: Colors.redAccent),
                            label: const Text('Kick Seat', style: TextStyle(color: Colors.redAccent, fontSize: 11)),
                            onPressed: () {
                              liveProvider.removeParticipant(user.id);
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Kicked ${user.name} from mic seat')));
                            },
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _badgeChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _levelCard(
    BuildContext context, {
    required String title,
    required String level,
    required IconData icon,
    required Color color,
    required UserModel user,
  }) {
    return GestureDetector(
      onTap: () => _showLevelDetailsModal(context, title, level, color, user),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: widget.isDark ? const Color(0xFF201B36) : const Color(0xFFF3F0FC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 4),
            Text(title, style: const TextStyle(fontSize: 9, color: Colors.grey)),
            Text(level, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  void _showLevelDetailsModal(BuildContext context, String title, String level, Color color, UserModel user) {
    showDialog(
      context: context,
      builder: (d) => AlertDialog(
        backgroundColor: const Color(0xFF1E1B2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(iconForTitle(title), color: color),
            const SizedBox(width: 8),
            Text('$title Level Details', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Current Tier: $level', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            const Text('XP Progress: 8,450 / 10,000 XP', style: TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: 0.845, minHeight: 6, backgroundColor: Colors.white12, valueColor: AlwaysStoppedAnimation<Color>(color)),
            ),
            const SizedBox(height: 14),
            const Text('Level Perks & Privileges:', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 6),
            const Text('• Custom Room Entry Banner\n• VIP Badge Frame in Stage Grid\n• Multiplier Bonus on Games & Wheels', style: TextStyle(color: Colors.white60, fontSize: 11)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('Close', style: TextStyle(color: Colors.white60))),
        ],
      ),
    );
  }

  IconData iconForTitle(String title) {
    switch (title) {
      case 'Wealth':
        return Icons.diamond_rounded;
      case 'Charm':
        return Icons.favorite_rounded;
      case 'Game':
        return Icons.sports_esports_rounded;
      default:
        return Icons.person_rounded;
    }
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
            Text('${user.name}\'s Gift Gallery', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Total Gifts Received: 18 Types (1,420 Items)', style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _giftDetailTile('🌹 Rose', '120 Received', '1,200 Coins'),
                  _giftDetailTile('👑 Crown', '14 Received', '7,000 Coins'),
                  _giftDetailTile('🚀 Rocket', '5 Received', '10,000 Coins'),
                  _giftDetailTile('🏎️ Supercar', '2 Received', '20,000 Coins'),
                  _giftDetailTile('🏰 Castle', '1 Received', '50,000 Coins'),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('Close', style: TextStyle(color: Colors.white60))),
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

  void _showCpDetailsModal(BuildContext context, UserModel user) {
    showDialog(
      context: context,
      builder: (d) => AlertDialog(
        backgroundColor: const Color(0xFF1E1B2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.favorite_rounded, color: Colors.pinkAccent),
            SizedBox(width: 8),
            Text('CP Relationship Details', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Relationship: Sweet Lovers ❤️', style: const TextStyle(color: Colors.pinkAccent, fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 6),
            Text('Partner: @${user.cpPartnerId ?? "Danial_Official"}', style: const TextStyle(color: Colors.white, fontSize: 13)),
            const SizedBox(height: 6),
            Text('CP Level: 5 Tier • Intimacy: ${user.cpPoints} Points', style: const TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 10),
            const Text('Anniversary: 120 Days Together 💕', style: TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('Close', style: TextStyle(color: Colors.white60))),
        ],
      ),
    );
  }

  Widget _giftIconChip(String emoji, String count) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 22)),
        const SizedBox(height: 2),
        Text(count, style: const TextStyle(fontSize: 9, color: Colors.grey)),
      ],
    );
  }

  Widget _quickGiftChip(BuildContext context, String title, int costCoins, UserModel targetUser) {
    return GestureDetector(
      onTap: () {
        final liveProvider = context.read<LivePartyProvider>();
        final authUser = context.read<AuthProvider>().currentUser;
        liveProvider.sendGiftActivityMessage(
          sender: authUser,
          receiver: targetUser,
          giftId: 'gift_${title.toLowerCase()}',
          giftName: title,
          giftIcon: '🎁',
          quantity: 1,
          transactionId: 'tx_${DateTime.now().millisecondsSinceEpoch}',
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sent $title ($costCoins Coins) to ${targetUser.name} 🎁')),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
        ),
        child: Text(
          title,
          style: const TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
