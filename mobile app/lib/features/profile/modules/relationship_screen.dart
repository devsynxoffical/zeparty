import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../core/repositories/backend_repository.dart';
import '../../../../widgets/user_avatar.dart';
import '../../../../models/user_model.dart';
import '../../../../models/relationship_card_model.dart';
import '../../../../providers/wallet_provider.dart';
import 'cp_ranking_screen.dart';

class RelationshipScreen extends StatefulWidget {
  const RelationshipScreen({super.key});

  @override
  State<RelationshipScreen> createState() => _RelationshipScreenState();
}

class _RelationshipScreenState extends State<RelationshipScreen> {
  void _showBuildOptions(BuildContext context, AuthProvider auth) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.getCard(Theme.of(context).brightness == Brightness.dark),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final candidates = BackendRepository.instance.popularUsers;
        final user = auth.currentUser;
        
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Build New Relationship',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: candidates.length,
                  itemBuilder: (ctx, idx) {
                    final candidate = candidates[idx];
                    if (candidate.id == user.id) return const SizedBox.shrink();

                    return ListTile(
                      leading: UserAvatar(imageUrl: candidate.avatarUrl, radius: 24),
                      title: Text(candidate.name),
                      subtitle: Text('Wealth Lv ${candidate.wealthLevel}'),
                      trailing: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purpleAccent,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          _showRelationshipCardChooser(context, candidate);
                        },
                        child: const Text('Invite'),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Module 10: Relationship Card Chooser & Store Purchase Flow ──
  void _showRelationshipCardChooser(BuildContext context, UserModel targetUser) {
    final cards = [
      const RelationshipCardModel(
        id: 'card_cp',
        name: 'Eternal CP Ring Card',
        type: 'CP',
        imageUrl: 'assets/images/cp_ring.png',
        coinPrice: 1000,
        benefits: 'Exclusive CP Ring Badge, Dynamic Entry Banner, Relationship Leveling',
        maxCount: 1,
      ),
      const RelationshipCardModel(
        id: 'card_best_friend',
        name: 'Best Friend Oath Card',
        type: 'Best Friend',
        imageUrl: 'assets/images/best_friend.png',
        coinPrice: 500,
        benefits: 'Best Friend Badge, Chat Frame, Shared Room Perks',
        maxCount: 5,
      ),
      const RelationshipCardModel(
        id: 'card_bro_sis',
        name: 'Bro & Sis Soul Card',
        type: 'Bro/Sis',
        imageUrl: 'assets/images/bro_sis.png',
        coinPrice: 300,
        benefits: 'Bro/Sis Label, Special Profile Wall Accent',
        maxCount: 10,
      ),
      const RelationshipCardModel(
        id: 'card_game_friend',
        name: 'Game Buddy Card',
        type: 'Game Friend',
        imageUrl: 'assets/images/game_buddy.png',
        coinPrice: 200,
        benefits: 'Game Team-up Badge, Extra Game Bonus Rewards',
        maxCount: 20,
      ),
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1B2E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  UserAvatar(imageUrl: targetUser.avatarUrl, radius: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Select Card for ${targetUser.name}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        const Text('Target user remains attached to invitation flow', style: TextStyle(color: Colors.white60, fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(color: Colors.white24),
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: cards.length,
                  itemBuilder: (c, i) {
                    final card = cards[i];
                    return Card(
                      color: Colors.white.withValues(alpha: 0.08),
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Colors.purple.withValues(alpha: 0.3), shape: BoxShape.circle),
                          child: const Icon(Icons.favorite_rounded, color: Colors.pinkAccent),
                        ),
                        title: Text(card.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        subtitle: Text('${card.benefits}\nMax Limit: ${card.maxCount} ${card.type}', style: const TextStyle(color: Colors.white60, fontSize: 11)),
                        isThreeLine: true,
                        trailing: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _showRelationshipStoreDialog(context, targetUser, card);
                          },
                          child: Text('${card.coinPrice} 🪙', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRelationshipStoreDialog(BuildContext context, UserModel targetUser, RelationshipCardModel card) {
    showDialog(
      context: context,
      builder: (d) => AlertDialog(
        backgroundColor: const Color(0xFF1E1B2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.storefront_rounded, color: Colors.amberAccent),
            const SizedBox(width: 8),
            Text('Purchase ${card.type} Card', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      UserAvatar(imageUrl: targetUser.avatarUrl, radius: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Target: ${targetUser.name}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Card Name: ${card.name}', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 13)),
                  Text('Price: ${card.coinPrice} Coins 🪙', style: const TextStyle(color: Colors.white, fontSize: 12)),
                  Text('Refund Policy: ${card.refundPolicy}', style: const TextStyle(color: Colors.white60, fontSize: 10)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '⚠️ Purchase alone does NOT activate relationship. An invitation will be sent to the target user. Upon acceptance, the relationship becomes active.',
              style: TextStyle(color: Colors.amberAccent, fontSize: 11, fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel', style: TextStyle(color: Colors.white60))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.pinkAccent),
            onPressed: () {
              final wallet = context.read<WalletProvider>();
              final success = wallet.spendCoins(card.coinPrice, 'Relationship Card: ${card.name}');
              if (!success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Insufficient Coins! Please recharge your wallet.'), backgroundColor: Colors.redAccent),
                );
                return;
              }

              final auth = context.read<AuthProvider>();
              auth.sendCpRequest(targetUser.id);
              auth.receiveMockCpRequest(targetUser.id); // For testing acceptance

              Navigator.pop(d);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('📩 Purchased ${card.name}! Invitation sent to ${targetUser.name}. Pending acceptance.'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Purchase & Send Invitation', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showOptions(BuildContext context, AuthProvider auth) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.getCard(Theme.of(context).brightness == Brightness.dark),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.broken_image, color: Colors.redAccent),
                title: const Text('Dissolve Relationship', style: TextStyle(color: Colors.redAccent)),
                onTap: () {
                  Navigator.pop(context);
                  auth.breakUpCp();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Relationship dissolved.')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.close),
                title: const Text('Cancel'),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;

    final bool hasPartner = user.cpPartnerId != null && user.cpPartnerId!.isNotEmpty;
    UserModel? partner;
    if (hasPartner) {
      partner = BackendRepository.instance.popularUsers.firstWhere(
        (u) => u.id == user.cpPartnerId,
        orElse: () => BackendRepository.instance.popularUsers.first,
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1E0A3C), // Deep purple background to match reference
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Colors.white),
            ),
          ),
        ),
        title: const Text(
          'Relationship',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.emoji_events_rounded, color: Colors.amber),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (c) => const CPRankingScreen()));
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: GestureDetector(
              onTap: () {
                if (hasPartner) _showOptions(context, auth);
              },
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.more_horiz_rounded, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Pending requests alert if any
                  if (user.pendingCpRequests.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.pinkAccent.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.pinkAccent),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Colors.pinkAccent),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'You have pending relationship requests!',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.pinkAccent,
                              minimumSize: const Size(60, 30),
                            ),
                            onPressed: () => _showRequests(context, auth),
                            child: const Text('View', style: TextStyle(color: Colors.white)),
                          )
                        ],
                      ),
                    ),

                  // MAIN CP CARD
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 30),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF5A2C99), Color(0xFF381575)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Current User
                        Column(
                          children: [
                            UserAvatar(imageUrl: user.avatarUrl, radius: 32, showVipFrame: true),
                            const SizedBox(height: 8),
                            Text(
                              user.name.split(' ').first,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        // Center icon
                        const Text('🔥', style: TextStyle(fontSize: 40)),
                        // Partner or Build
                        if (hasPartner && partner != null)
                          Column(
                            children: [
                              UserAvatar(imageUrl: partner.avatarUrl, radius: 32, showVipFrame: true),
                              const SizedBox(height: 8),
                              Text(
                                partner.name.split(' ').first,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ],
                          )
                        else
                          GestureDetector(
                            onTap: () => _showBuildOptions(context, auth),
                            child: Column(
                              children: [
                                Container(
                                  width: 64,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1),
                                  ),
                                  child: const Icon(Icons.add, color: Colors.white38, size: 32),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Build',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Divider
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.star_border, color: Colors.white38, size: 14),
                      const SizedBox(width: 8),
                      Text(
                        'All relationship',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.star_border, color: Colors.white38, size: 14),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Other Relationship Slots Grid
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        _buildEmptySlotCard(context, auth),
                        _buildEmptySlotCard(context, auth),
                        // Add more slots as needed
                      ],
                    ),
                  ),

                  const SizedBox(height: 100), // padding for bottom button
                ],
              ),
            ),
            
            // BOTTOM BUILD BUTTON
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text('Build new relationship', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purpleAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                onPressed: () => _showBuildOptions(context, auth),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptySlotCard(BuildContext context, AuthProvider auth) {
    return GestureDetector(
      onTap: () => _showBuildOptions(context, auth),
      child: Container(
        width: 110,
        height: 140,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF4A1C82), Color(0xFF2D1059)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomLeft: Radius.circular(10),
            bottomRight: Radius.circular(10),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 5,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
              ),
              child: const Icon(Icons.add, color: Colors.white38, size: 24),
            ),
            const SizedBox(height: 12),
            const Text(
              'Build',
              style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  void _showRequests(BuildContext context, AuthProvider auth) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.getCard(Theme.of(context).brightness == Brightness.dark),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final candidates = BackendRepository.instance.popularUsers;
        final user = auth.currentUser;
        
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Pending Requests',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              if (user.pendingCpRequests.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('No pending requests.'),
                )
              else
                Expanded(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: user.pendingCpRequests.length,
                    itemBuilder: (ctx, idx) {
                      final reqId = user.pendingCpRequests[idx];
                      final requester = candidates.firstWhere(
                        (u) => u.id == reqId, 
                        orElse: () => candidates.first,
                      );
                      
                      return ListTile(
                        leading: UserAvatar(imageUrl: requester.avatarUrl, radius: 24),
                        title: Text(requester.name),
                        subtitle: const Text('Wants to be your CP!'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.check_circle, color: Colors.green),
                              onPressed: () {
                                auth.acceptCpRequest(reqId);
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Relationship established with ${requester.name}!')),
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.cancel, color: Colors.red),
                              onPressed: () {
                                auth.rejectCpRequest(reqId);
                                Navigator.pop(context);
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
