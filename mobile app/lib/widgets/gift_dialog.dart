import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_colors.dart';
import '../models/gift_model.dart';
import '../models/user_model.dart';
import '../providers/live_provider.dart';
import '../providers/wallet_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/live_party_provider.dart';
import '../providers/live_gift_provider.dart';
import '../widgets/user_avatar.dart';
import '../features/recharge/recharge_screen.dart';

class GiftDialog extends StatefulWidget {
  final String streamerName;
  final UserModel? targetReceiver;
  final ValueChanged<GiftModel>? onGiftSent;

  const GiftDialog({
    super.key,
    this.streamerName = 'Streamer',
    this.targetReceiver,
    this.onGiftSent,
  });

  @override
  State<GiftDialog> createState() => _GiftDialogState();
}

class _GiftDialogState extends State<GiftDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool recipientIsAllSelected = false;
  String selectedCategory = 'Lucky Gift';
  CatalogTypeFilter selectedCatalogFilter = CatalogTypeFilter.all;

  GiftModel? selectedGift;
  PropItemModel? selectedProp = GiftModel.defaultProps.first;
  int quantity = 1;

  Set<String> _selectedUserIds = {};

  final List<String> categories = [
    'All',
    'Lucky Gift',
    'Classic',
    'Event Gifts',
    'Privileges',
    'Special',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: categories.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          selectedCategory = categories[_tabController.index];
        });
      }
    });

    if (widget.targetReceiver != null) {
      _selectedUserIds.add(widget.targetReceiver!.id);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final liveGiftProv = context.read<LiveGiftProvider>();
      if (liveGiftProv.catalogGifts.isNotEmpty && selectedGift == null) {
        setState(() {
          selectedGift = liveGiftProv.catalogGifts.first;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  int _calculateTotalPrice(int giftPrice, int recipientCount) {
    return giftPrice * quantity * (recipientCount > 0 ? recipientCount : 1);
  }

  void _openRechargeScreen(BuildContext context) {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RechargeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = AppColors.getPrimary(isDark);
    final wallet = context.watch<WalletProvider>();
    final partyProv = context.watch<LivePartyProvider>();
    final liveGiftProv = context.watch<LiveGiftProvider>();

    final auth = context.watch<AuthProvider>();
    final currentUser = auth.currentUser;

    // Available room recipients
    final roomParticipants = partyProv.participants.map((p) => p.user).toList();
    final List<UserModel> availableRecipients = roomParticipants.isNotEmpty
        ? roomParticipants.map((u) {
            if (u.id == currentUser.id && currentUser.avatarUrl.isNotEmpty) {
              return u.copyWith(avatarUrl: currentUser.avatarUrl, name: currentUser.name);
            }
            return u;
          }).toList()
        : (widget.targetReceiver != null
            ? [
                (widget.targetReceiver!.id == currentUser.id && currentUser.avatarUrl.isNotEmpty)
                    ? widget.targetReceiver!.copyWith(avatarUrl: currentUser.avatarUrl, name: currentUser.name)
                    : (widget.targetReceiver!.avatarUrl.isEmpty && currentUser.avatarUrl.isNotEmpty && (widget.targetReceiver!.name == currentUser.name || widget.targetReceiver!.name == widget.streamerName)
                        ? widget.targetReceiver!.copyWith(avatarUrl: currentUser.avatarUrl)
                        : widget.targetReceiver!)
              ]
            : [
                (widget.streamerName == currentUser.name || widget.streamerName == currentUser.displayName || widget.streamerName.contains(currentUser.name))
                    ? currentUser
                    : UserModel(
                        id: 'user_target',
                        username: widget.streamerName,
                        name: widget.streamerName,
                        avatarUrl: currentUser.avatarUrl.isNotEmpty
                            ? currentUser.avatarUrl
                            : 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150',
                      ),
              ]);

    // Active Recipients List
    final effectiveRecipients = recipientIsAllSelected
        ? availableRecipients
        : availableRecipients.where((u) => _selectedUserIds.contains(u.id)).toList();

    final recipientCount = effectiveRecipients.isNotEmpty ? effectiveRecipients.length : 1;
    final currentGiftPrice = selectedGift != null
        ? (selectedGift!.priceCoins > 0 ? selectedGift!.priceCoins : selectedGift!.diamondPrice)
        : 0;
    final totalPrice = _calculateTotalPrice(currentGiftPrice, recipientCount);

    return Material(
      color: Colors.transparent,
      child: SafeArea(
        child: Container(
          height: MediaQuery.of(context).size.height * 0.60,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF141024) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 20, spreadRadius: 4),
            ],
          ),
          child: Column(
            children: [
              // Top Grabber Handle
              Container(
                width: 38,
                height: 4,
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // 1. RECIPIENT BAR
              Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: availableRecipients.map((user) {
                          final isSelected = recipientIsAllSelected || _selectedUserIds.contains(user.id);
                          final resolvedAvatarUrl = (user.id == currentUser.id && currentUser.avatarUrl.isNotEmpty)
                              ? currentUser.avatarUrl
                              : (user.avatarUrl.isNotEmpty ? user.avatarUrl : (currentUser.avatarUrl.isNotEmpty ? currentUser.avatarUrl : null));

                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                recipientIsAllSelected = false;
                                if (_selectedUserIds.contains(user.id)) {
                                  if (_selectedUserIds.length > 1) {
                                    _selectedUserIds.remove(user.id);
                                  }
                                } else {
                                  _selectedUserIds.add(user.id);
                                }
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.only(right: 10),
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isSelected ? const Color(0xFF00E676) : Colors.transparent,
                                        width: 2,
                                      ),
                                      boxShadow: isSelected
                                          ? [const BoxShadow(color: Color(0xFF00E676), blurRadius: 6)]
                                          : null,
                                    ),
                                    child: UserAvatar(
                                      imageUrl: resolvedAvatarUrl,
                                      name: user.name,
                                      radius: 18,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  SizedBox(
                                    width: 44,
                                    child: Text(
                                      user.name,
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: isSelected ? const Color(0xFF00E676) : AppColors.getTextSecondary(isDark),
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // RECIPIENT ALL BUTTON
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        recipientIsAllSelected = !recipientIsAllSelected;
                        if (recipientIsAllSelected) {
                          _selectedUserIds = availableRecipients.map((u) => u.id).toSet();
                        } else if (widget.targetReceiver != null) {
                          _selectedUserIds = {widget.targetReceiver!.id};
                        } else if (availableRecipients.isNotEmpty) {
                          _selectedUserIds = {availableRecipients.first.id};
                        }
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: recipientIsAllSelected
                            ? const LinearGradient(colors: [Color(0xFF00E676), Color(0xFF00B0FF)])
                            : null,
                        color: recipientIsAllSelected ? null : AppColors.getSurface(isDark),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: recipientIsAllSelected ? const Color(0xFF00E676) : AppColors.getBorder(isDark),
                        ),
                        boxShadow: recipientIsAllSelected
                            ? [const BoxShadow(color: Color(0xFF00E676), blurRadius: 8)]
                            : null,
                      ),
                      child: Text(
                        'All',
                        style: TextStyle(
                          color: recipientIsAllSelected ? Colors.black : AppColors.getTextPrimary(isDark),
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Authoritative Coins Balance & Recharge Link
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.monetization_on_rounded, color: AppColors.gold, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '${wallet.coins}',
                        style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.getTextPrimary(isDark), fontSize: 13),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => _openRechargeScreen(context),
                        child: Text('Recharge >', style: TextStyle(color: primaryColor, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  Text(
                    'Selected: $recipientCount recipient${recipientCount > 1 ? 's' : ''}',
                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // 2. GIFT CATEGORY TABS & 3. CATALOG TYPE FILTER DROPDOWN
              Row(
                children: [
                  Expanded(
                    child: TabBar(
                      controller: _tabController,
                      isScrollable: true,
                      indicatorColor: primaryColor,
                      indicatorWeight: 3,
                      labelColor: primaryColor,
                      unselectedLabelColor: AppColors.getTextSecondary(isDark),
                      labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
                      unselectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      dividerColor: Colors.transparent,
                      tabAlignment: TabAlignment.start,
                      tabs: categories.map((c) => Tab(text: c)).toList(),
                    ),
                  ),

                  const SizedBox(width: 6),

                  Container(
                    height: 30,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: AppColors.getSurface(isDark),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: AppColors.getBorder(isDark)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<CatalogTypeFilter>(
                        value: selectedCatalogFilter,
                        dropdownColor: AppColors.getCard(isDark),
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16),
                        style: TextStyle(color: AppColors.getTextPrimary(isDark), fontSize: 11, fontWeight: FontWeight.bold),
                        items: const [
                          DropdownMenuItem(value: CatalogTypeFilter.all, child: Text('All ▾')),
                          DropdownMenuItem(value: CatalogTypeFilter.gift, child: Text('Gift')),
                          DropdownMenuItem(value: CatalogTypeFilter.props, child: Text('Props')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => selectedCatalogFilter = val);
                        },
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // 4. ITEM GRID / 5. PROPS CONTENT
              Expanded(
                child: selectedCatalogFilter == CatalogTypeFilter.props
                    ? _buildPropsGrid(isDark, primaryColor)
                    : _buildGiftGrid(isDark, primaryColor, selectedCategory, liveGiftProv.catalogGifts),
              ),

              const SizedBox(height: 10),

              // 6. SEND CONTROLS & TOTAL PRICE
              Row(
                children: [
                  Text('Qty:', style: TextStyle(color: AppColors.getTextPrimary(isDark), fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(width: 8),

                  Container(
                    height: 34,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: AppColors.getSurface(isDark),
                      borderRadius: BorderRadius.circular(17),
                      border: Border.all(color: AppColors.getBorder(isDark)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: quantity,
                        dropdownColor: AppColors.getCard(isDark),
                        icon: const Icon(Icons.arrow_drop_down, size: 18),
                        items: [1, 10, 50, 99, 520, 1314].map((q) => DropdownMenuItem(
                          value: q,
                          child: Text('$q', style: TextStyle(color: AppColors.getTextPrimary(isDark), fontSize: 12, fontWeight: FontWeight.bold)),
                        )).toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => quantity = v);
                        },
                      ),
                    ),
                  ),

                  const Spacer(),

                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: AppColors.onPrimary(isDark: isDark),
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      elevation: 4,
                    ),
                    onPressed: selectedGift == null || effectiveRecipients.isEmpty || liveGiftProv.isSending
                        ? null
                        : () async {
                            final auth = context.read<AuthProvider>();
                            final liveProv = context.read<LiveProvider>();
                            final partyLiveProv = context.read<LivePartyProvider>();

                            if (wallet.coins < totalPrice) {
                              showDialog(
                                context: context,
                                builder: (dlgCtx) => AlertDialog(
                                  backgroundColor: AppColors.getCard(isDark),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  title: Row(
                                    children: [
                                      const Icon(Icons.monetization_on_rounded, color: AppColors.gold, size: 24),
                                      const SizedBox(width: 8),
                                      Text('Insufficient Coins', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(isDark))),
                                    ],
                                  ),
                                  content: Text(
                                    'You need $totalPrice 🪙 to send this gift. You currently have ${wallet.coins} 🪙. Would you like to recharge now?',
                                    style: TextStyle(color: AppColors.getTextSecondary(isDark), fontSize: 13),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(dlgCtx),
                                      child: Text('Cancel', style: TextStyle(color: AppColors.getTextSecondary(isDark))),
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: primaryColor,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      onPressed: () {
                                        Navigator.pop(dlgCtx);
                                        _openRechargeScreen(context);
                                      },
                                      child: const Text('Recharge Now 🪙', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                              );
                              return;
                            }

                            int totalSuccess = 0;
                            final roomId = liveProv.activeRoom?.id ?? partyLiveProv.activeRoom?.id ?? '';

                            for (final targetUser in effectiveRecipients) {
                              final success = await liveGiftProv.sendGift(
                                walletProvider: wallet,
                                gift: selectedGift!,
                                sender: auth.currentUser,
                                receiver: targetUser,
                                roomId: roomId,
                                quantity: quantity,
                              );

                              if (success) {
                                totalSuccess++;
                                try {
                                  partyLiveProv.sendGiftActivityMessage(
                                    sender: auth.currentUser,
                                    receiver: targetUser,
                                    giftId: selectedGift!.id,
                                    giftName: selectedGift!.name,
                                    giftIcon: selectedGift!.icon,
                                    quantity: quantity,
                                    transactionId: 'tx_${DateTime.now().millisecondsSinceEpoch}',
                                  );
                                } catch (_) {}
                              }
                            }

                            if (totalSuccess > 0) {
                              widget.onGiftSent?.call(selectedGift!);
                              if (mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('🎁 Sent $quantity × ${selectedGift!.name} to $totalSuccess recipient(s)!'),
                                    backgroundColor: Colors.green[800],
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            } else if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(liveGiftProv.lastError ?? 'Failed to send gift. Please check connection.'),
                                  backgroundColor: Colors.red[800],
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          },
                    child: liveGiftProv.isSending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Text(
                            'Send $totalPrice 🪙',
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGiftGrid(bool isDark, Color primaryColor, String category, List<GiftModel> catalog) {
    List<GiftModel> displayGifts;
    if (category == 'Lucky Gift') {
      displayGifts = catalog.where((g) => g.isLuckyGift).toList();
    } else if (category == 'Classic') {
      displayGifts = catalog.where((g) => g.category == 'Classic' || g.giftCategory == 'POPULAR').toList();
    } else if (category == 'Event Gifts') {
      displayGifts = catalog.where((g) => g.category == 'Event Gifts' || g.giftCategory == 'LUXURY').toList();
    } else if (category == 'Privileges') {
      displayGifts = catalog.where((g) => g.category == 'Privileges' || g.giftCategory == 'VIP').toList();
    } else if (category == 'Special') {
      displayGifts = catalog.where((g) => g.category == 'Special' || g.giftCategory == 'AUDIO').toList();
    } else {
      displayGifts = catalog;
    }

    if (displayGifts.isEmpty) {
      displayGifts = catalog.isNotEmpty ? catalog : GiftModel.defaultCatalog;
    }

    return GridView.builder(
      padding: const EdgeInsets.only(top: 4),
      itemCount: displayGifts.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 0.82,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemBuilder: (context, index) {
        final gift = displayGifts[index];
        final isSelected = selectedGift?.id == gift.id;
        final coinPrice = gift.priceCoins > 0 ? gift.priceCoins : gift.diamondPrice;

        return GestureDetector(
          onTap: () {
            setState(() {
              selectedGift = gift;
            });
          },
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isSelected
                      ? primaryColor.withValues(alpha: 0.18)
                      : AppColors.getCard(isDark),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? primaryColor : AppColors.getBorder(isDark),
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: isSelected
                      ? [BoxShadow(color: primaryColor.withValues(alpha: 0.3), blurRadius: 8)]
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(gift.icon, style: const TextStyle(fontSize: 26)),
                    const SizedBox(height: 2),
                    Text(
                      gift.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.getTextPrimary(isDark),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.monetization_on_rounded, color: AppColors.gold, size: 10),
                        const SizedBox(width: 2),
                        Text(
                          '$coinPrice',
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.gold,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              if (gift.luckyBadge != null || gift.label != null)
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      gradient: (gift.luckyBadge?.contains('MAX') ?? false)
                          ? const LinearGradient(colors: [Colors.purple, Colors.pink])
                          : gift.luckyBadge == 'MAGIC'
                              ? const LinearGradient(colors: [Colors.amber, Colors.orange])
                              : const LinearGradient(colors: [Colors.blue, Colors.cyan]),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white, width: 0.8),
                    ),
                    child: Text(
                      gift.luckyBadge ?? gift.label!,
                      style: const TextStyle(color: Colors.white, fontSize: 7.5, fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPropsGrid(bool isDark, Color primaryColor) {
    final props = GiftModel.defaultProps;

    return GridView.builder(
      padding: const EdgeInsets.only(top: 4),
      itemCount: props.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2.1,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemBuilder: (context, index) {
        final prop = props[index];
        final isSelected = selectedProp?.id == prop.id;

        return GestureDetector(
          onTap: () => setState(() => selectedProp = prop),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isSelected ? primaryColor.withValues(alpha: 0.15) : AppColors.getCard(isDark),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isSelected ? primaryColor : AppColors.getBorder(isDark)),
            ),
            child: Row(
              children: [
                Text(prop.icon, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        prop.name,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(isDark)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        prop.expiryText ?? 'Owned',
                        style: const TextStyle(fontSize: 9, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Equipped ${prop.name}! ✨')),
                    );
                  },
                  child: Text(prop.actionLabel, style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
