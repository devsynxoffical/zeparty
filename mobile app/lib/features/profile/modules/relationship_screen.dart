import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../core/repositories/backend_repository.dart';
import '../../../../core/repositories/social_repository.dart';
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
      isScrollControlled: true,
      backgroundColor: AppColors.getCard(Theme.of(context).brightness == Brightness.dark),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _BuildRelationshipModalSheet(
        auth: auth,
        onSelectCandidate: (candidate) {
          _showRelationshipCardChooser(context, candidate);
        },
      ),
    );
  }

  // ── Module 10: Relationship Card Chooser & Store Purchase Flow ──
  void _showRelationshipCardChooser(BuildContext context, UserModel targetUser) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.getCard(isDark),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => FutureBuilder<List<dynamic>>(
        future: SocialRepository.instance.fetchRelationshipCards(),
        builder: (context, snapshot) {
          final isWaiting = snapshot.connectionState == ConnectionState.waiting;
          List<RelationshipCardModel> cards = [];

          if (snapshot.hasData && snapshot.data!.isNotEmpty) {
            cards = snapshot.data!
                .map((item) => RelationshipCardModel.fromJson(Map<String, dynamic>.from(item as Map)))
                .toList();
          } else if (!isWaiting) {
            // Fallback to configured catalog
            cards = const [
              RelationshipCardModel(
                id: 'card_cp',
                name: 'CP Card (Eternal CP Ring)',
                type: 'CP',
                imageUrl: 'assets/images/cp_ring.png',
                coinPrice: 50000,
                benefits: 'Exclusive CP Ring Badge, Dynamic Entry Banner, Relationship Leveling',
                maxCount: 1,
              ),
              RelationshipCardModel(
                id: 'card_friend',
                name: 'Friend Card',
                type: 'Friend',
                imageUrl: 'assets/images/friend_card.png',
                coinPrice: 5000,
                benefits: 'Friend Badge, Social Profile Wall Showcase',
                maxCount: 20,
              ),
              RelationshipCardModel(
                id: 'card_bozun',
                name: 'Bozun Card',
                type: 'Bozun',
                imageUrl: 'assets/images/bozun_card.png',
                coinPrice: 15000,
                benefits: 'Bozun Oath Badge, Shared Room Perks, Wall Accent',
                maxCount: 10,
              ),
              RelationshipCardModel(
                id: 'card_best_friend',
                name: 'Best Friend Card',
                type: 'Best Friend',
                imageUrl: 'assets/images/best_friend.png',
                coinPrice: 20000,
                benefits: 'Best Friend Badge, Chat Frame, Shared Room Perks',
                maxCount: 5,
              ),
            ];
          }

          return SafeArea(
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
                            Text(
                              'Select Card for ${targetUser.name}',
                              style: TextStyle(color: AppColors.getTextPrimary(isDark), fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            Text(
                              'Target user will receive a relationship invitation',
                              style: TextStyle(color: AppColors.getTextSecondary(isDark), fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Divider(color: isDark ? Colors.white24 : AppColors.lightBorder),
                  if (isWaiting)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: cards.length,
                        itemBuilder: (c, i) {
                          final card = cards[i];
                          return Card(
                            color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFF8FAFC),
                            margin: const EdgeInsets.only(bottom: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            child: ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.purple.withValues(alpha: 0.3),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.favorite_rounded, color: Colors.pinkAccent),
                              ),
                              title: Text(
                                card.name,
                                style: TextStyle(color: AppColors.getTextPrimary(isDark), fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                '${card.benefits}\nMax Limit: ${card.maxCount} ${card.type} • Expiry: ${card.expiryHours}h',
                                style: TextStyle(color: AppColors.getTextSecondary(isDark), fontSize: 11),
                              ),
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
          );
        },
      ),
    );
  }

  void _showRelationshipStoreDialog(BuildContext context, UserModel targetUser, RelationshipCardModel card) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    bool isPurchasing = false;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (d) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          final wallet = dialogCtx.watch<WalletProvider>();
          final hasEnoughCoins = wallet.coins >= card.coinPrice;

          return AlertDialog(
            backgroundColor: AppColors.getCard(isDark),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Icon(Icons.storefront_rounded, color: isDark ? Colors.amberAccent : Colors.amber.shade800),
                const SizedBox(width: 8),
                Text('Purchase ${card.type} Card', style: TextStyle(color: AppColors.getTextPrimary(isDark), fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.purple.withValues(alpha: 0.2) : const Color(0xFFFDF4FF),
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
                              style: TextStyle(color: AppColors.getTextPrimary(isDark), fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Card Name: ${card.name}', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 13)),
                      Text('Price: ${card.coinPrice} Coins 🪙', style: TextStyle(color: AppColors.getTextPrimary(isDark), fontSize: 12)),
                      Text('Your Balance: ${wallet.coins} Coins 🪙', style: TextStyle(color: hasEnoughCoins ? Colors.greenAccent : Colors.redAccent, fontSize: 12, fontWeight: FontWeight.w600)),
                      Text('Refund Policy: ${card.refundPolicy}', style: TextStyle(color: AppColors.getTextSecondary(isDark), fontSize: 10)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '⚠️ Purchase alone does NOT activate relationship. An invitation will be sent to the target user. Upon acceptance, the relationship becomes active.',
                  style: TextStyle(color: isDark ? Colors.amberAccent : Colors.amber.shade900, fontSize: 11, fontStyle: FontStyle.italic),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isPurchasing ? null : () => Navigator.pop(d),
                child: Text('Cancel', style: TextStyle(color: AppColors.getTextSecondary(isDark))),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: hasEnoughCoins ? Colors.pinkAccent : Colors.grey),
                onPressed: isPurchasing
                    ? null
                    : () async {
                        if (!hasEnoughCoins) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Insufficient Coins! You need ${card.coinPrice} coins. Current balance: ${wallet.coins}.'),
                              backgroundColor: Colors.redAccent,
                            ),
                          );
                          return;
                        }

                        setDialogState(() => isPurchasing = true);

                        try {
                          // Call backend purchase and invitation flow with deductCoins: true
                          await SocialRepository.instance.purchaseAndSendRelationshipCard(
                            recipientUserId: targetUser.id,
                            cardType: card.type,
                            deductCoins: true,
                          );

                          // Deduct coins / refresh wallet balance ONLY after backend confirmation
                          await wallet.fetchWallet();

                          if (context.mounted) {
                            final auth = context.read<AuthProvider>();
                            auth.sendCpRequest(targetUser.id);
                            Navigator.pop(d);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('📩 Invitation sent to ${targetUser.name}! Pending their acceptance.'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } catch (e) {
                          setDialogState(() => isPurchasing = false);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to purchase and send card: $e'),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                          }
                        }
                      },
                child: isPurchasing
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Purchase & Send Invitation', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
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
        orElse: () => BackendRepository.instance.getUserById(user.cpPartnerId!),
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

class _BuildRelationshipModalSheet extends StatefulWidget {
  final AuthProvider auth;
  final Function(UserModel) onSelectCandidate;

  const _BuildRelationshipModalSheet({
    required this.auth,
    required this.onSelectCandidate,
  });

  @override
  State<_BuildRelationshipModalSheet> createState() => _BuildRelationshipModalSheetState();
}

class _BuildRelationshipModalSheetState extends State<_BuildRelationshipModalSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<UserModel> _friends = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchEligibleFriends();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchEligibleFriends({String search = ''}) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final List<UserModel> res = await SocialRepository.instance.getEligibleRelationshipFriends(search: search);
      if (mounted) {
        setState(() {
          final currentUserId = widget.auth.currentUser.id;
          _friends = res.where((UserModel u) => u.id != currentUserId).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load eligible friends. Please check your network and retry.';
          _isLoading = false;
        });
      }
    }
  }

  List<UserModel> get _displayFriends {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return _friends;
    return _friends.where((u) {
      final name = u.name.toLowerCase();
      final username = u.username.toLowerCase();
      final id = u.id.toLowerCase();
      final publicId = u.publicUserId.toLowerCase();
      return name.contains(q) || username.contains(q) || id.contains(q) || publicId.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppColors.getPrimary(isDark);
    final displayList = _displayFriends;

    return Container(
      height: MediaQuery.of(context).size.height * 0.70,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      child: Column(
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Text(
            'Build New Relationship',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'Select an eligible mutual friend to send a relationship card invitation.\n(Both users must follow each other mutually)',
            style: TextStyle(fontSize: 12, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          // Search Box (Issue 15 & 17: Search by Nickname or User ID)
          TextField(
            controller: _searchController,
            onChanged: (val) {
              setState(() {});
              _fetchEligibleFriends(search: val);
            },
            style: TextStyle(color: AppColors.getTextPrimary(isDark), fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search mutual friends by nickname or ID...',
              hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                        _fetchEligibleFriends();
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              filled: true,
              fillColor: isDark ? const Color(0xFF1E1A33) : Colors.black.withValues(alpha: 0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 36),
                            const SizedBox(height: 8),
                            Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12), textAlign: TextAlign.center),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: () => _fetchEligibleFriends(search: _searchController.text),
                              icon: const Icon(Icons.refresh_rounded, size: 16),
                              label: const Text('Retry'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ],
                        ),
                      )
                    : displayList.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.purple.withValues(alpha: 0.15),
                                  ),
                                  child: const Icon(Icons.people_outline_rounded, size: 40, color: Colors.purpleAccent),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'No eligible friends found',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Follow creators or friends and have them follow you back to unlock relationships!',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.white60, fontSize: 12),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: displayList.length,
                            itemBuilder: (ctx, idx) {
                              final candidate = displayList[idx];
                              return ListTile(
                                leading: UserAvatar(imageUrl: candidate.avatarUrl, radius: 24),
                                title: Text(candidate.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'ID: ${candidate.effectivePublicId}',
                                      style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.black54),
                                    ),
                                    const SizedBox(height: 2),
                                    const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.sync_alt_rounded, size: 12, color: Colors.greenAccent),
                                        SizedBox(width: 4),
                                        Text('Mutual Follow', style: TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  ],
                                ),
                                isThreeLine: true,
                                trailing: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primary,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  onPressed: () {
                                    Navigator.pop(context);
                                    widget.onSelectCandidate(candidate);
                                  },
                                  child: const Text('Invite', style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}