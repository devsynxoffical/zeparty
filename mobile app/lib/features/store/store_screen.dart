import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../models/store_item_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/backpack_provider.dart';
import '../../providers/store_provider.dart';
import '../../providers/wallet_provider.dart';
import '../profile/modules/outfit_screen.dart';
import '../wallet/wallet_screen.dart';

class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key});

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StoreProvider>().fetchStoreItems();
      final auth = context.read<AuthProvider>();
      context.read<BackpackProvider>().fetchBackpack(currentUser: auth.currentUser);
    });
  }

  void _handleBuy(StoreItemModel item) async {
    final wallet = context.read<WalletProvider>();
    if (wallet.coins < item.priceCoins) {
      _showInsufficientCoinsDialog();
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => Center(child: CircularProgressIndicator(color: AppColors.getPrimary(Theme.of(context).brightness == Brightness.dark))),
    );

    final success = await context.read<StoreProvider>().purchaseItem(item, wallet);
    if (mounted) Navigator.pop(context); // hide loading

    if (success && mounted) {
      final auth = context.read<AuthProvider>();
      final backpack = context.read<BackpackProvider>();
      backpack.addPurchasedAsset(item);
      await backpack.fetchBackpack(refresh: true, currentUser: auth.currentUser);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully purchased ${item.name}! Added to My Outfit.'),
          backgroundColor: AppColors.success,
          action: SnackBarAction(
            label: 'MY OUTFIT',
            textColor: Colors.amberAccent,
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (c) => const OutfitScreen()));
            },
          ),
        ),
      );
    } else if (mounted) {
      final error = context.read<StoreProvider>().errorMessage;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error ?? 'Failed to purchase item'), backgroundColor: AppColors.error),
      );
    }
  }

  void _showInsufficientCoinsDialog() {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: AppColors.getCard(Theme.of(context).brightness == Brightness.dark),
        title: Text('Insufficient Coins', style: TextStyle(color: AppColors.getTextPrimary(Theme.of(context).brightness == Brightness.dark))),
        content: Text('You do not have enough coins to complete this purchase. Please recharge your wallet.', style: TextStyle(color: AppColors.getTextSecondary(Theme.of(context).brightness == Brightness.dark))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (c) => const WalletScreen()));
            },
            child: Text('Recharge', style: TextStyle(color: AppColors.getPrimary(Theme.of(context).brightness == Brightness.dark))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = AppColors.getTextPrimary(isDark);
    final secondaryText = AppColors.getTextSecondary(isDark);
    final storeProvider = context.watch<StoreProvider>();
    final categories = storeProvider.categories;

    return DefaultTabController(
      length: categories.length,
      child: Scaffold(
        backgroundColor: AppColors.getBackground(isDark),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.getCard(isDark).withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: primaryText),
            ),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text('Store', style: TextStyle(color: primaryText, fontWeight: FontWeight.bold, fontSize: 18)),
          centerTitle: true,
          actions: [
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.getCard(isDark).withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.refresh_rounded, size: 18, color: AppColors.getPrimary(isDark)),
              ),
              onPressed: () {
                context.read<StoreProvider>().fetchStoreItems();
                final auth = context.read<AuthProvider>();
                context.read<BackpackProvider>().fetchBackpack(refresh: true, currentUser: auth.currentUser);
              },
            ),
            const SizedBox(width: 8),
          ],
          bottom: TabBar(
            isScrollable: true,
            indicatorColor: primaryText,
            indicatorSize: TabBarIndicatorSize.label,
            indicatorWeight: 3,
            labelColor: primaryText,
            unselectedLabelColor: secondaryText,
            labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            unselectedLabelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            dividerColor: Colors.transparent,
            tabAlignment: TabAlignment.start,
            tabs: categories.map((c) => Tab(text: c)).toList(),
          ),
        ),
        body: storeProvider.isLoading
            ? Center(child: CircularProgressIndicator(color: AppColors.getPrimary(isDark)))
            : TabBarView(
                children: categories.map((category) {
                  final items = storeProvider.getItemsByCategory(category);
                  return _buildCategoryGrid(items, isDark);
                }).toList(),
              ),
      ),
    );
  }

  Widget _buildCategoryGrid(List<StoreItemModel> items, bool isDark) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.storefront_outlined, size: 48, color: AppColors.getTextSecondary(isDark).withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            Text(
              'No items available in this category.',
              style: TextStyle(color: AppColors.getTextSecondary(isDark)),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.75,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        return _buildStoreItemCard(item, isDark);
      },
    );
  }

  Widget _buildStoreItemCard(StoreItemModel item, bool isDark) {
    final cardColor = AppColors.getCard(isDark);
    final border = AppColors.getBorder(isDark);
    final primaryText = AppColors.getTextPrimary(isDark);
    final secondaryText = AppColors.getTextSecondary(isDark);
    final backpack = context.watch<BackpackProvider>();
    final isOwned = backpack.isItemOwned(item);

    return GestureDetector(
      onTap: () => _showItemAnimatedPreview(item, isDark),
      child: Container(
        decoration: BoxDecoration(
          color: cardColor.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.access_time_rounded, size: 14, color: secondaryText),
                    const SizedBox(width: 4),
                    Text('${item.durationDays} Days', style: TextStyle(color: secondaryText, fontSize: 11)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.5), width: 0.8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.play_circle_fill_rounded, size: 10, color: Colors.purpleAccent),
                      const SizedBox(width: 3),
                      Text('Preview', style: TextStyle(color: Colors.purpleAccent.shade100, fontSize: 9, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
            
            const Spacer(),
            
            Text(
              item.name,
              style: TextStyle(color: primaryText, fontWeight: FontWeight.bold, fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            
            // Image / Icon
            Builder(
              builder: (context) {
                final catLower = item.categoryId.toLowerCase();
                final typeLower = item.assetType.toLowerCase();
                final isBg = catLower.contains('background') || typeLower.contains('theme') || typeLower.contains('background');
                final fitMode = isBg ? BoxFit.cover : BoxFit.contain;
                final imgHeight = isBg ? 65.0 : 60.0;
                final imgWidth = isBg ? double.infinity : null;

                Widget imageWidget;
                if (item.imageUrl.startsWith('http')) {
                  imageWidget = Image.network(
                    item.imageUrl,
                    height: imgHeight,
                    width: imgWidth,
                    fit: fitMode,
                    errorBuilder: (c, e, s) => const Icon(Icons.stars_rounded, size: 40, color: Colors.amber),
                  );
                } else if (item.imageUrl.isNotEmpty) {
                  imageWidget = Image.asset(
                    item.imageUrl,
                    height: imgHeight,
                    width: imgWidth,
                    fit: fitMode,
                    errorBuilder: (c, e, s) => const Icon(Icons.stars_rounded, size: 40, color: Colors.amber),
                  );
                } else {
                  imageWidget = const Icon(Icons.shopping_bag_rounded, size: 40, color: Colors.purpleAccent);
                }

                if (isBg) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      height: imgHeight,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: imageWidget,
                    ),
                  );
                }

                return imageWidget;
              },
            ),
            
            const Spacer(),
            
            // Price / Owned State
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.monetization_on_rounded, size: 15, color: Colors.orangeAccent),
                const SizedBox(width: 4),
                Text(
                  (item.priceCoins > 0 ? item.priceCoins : 50000).toString(),
                  style: TextStyle(color: primaryText, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ],
            ),
            
            const SizedBox(height: 10),
            
            // Action Button: Owned vs Buy Now
            isOwned
                ? GestureDetector(
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (c) => const OutfitScreen()));
                    },
                    child: Container(
                      height: 34,
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(17),
                        border: Border.all(color: Colors.green, width: 1.2),
                      ),
                      alignment: Alignment.center,
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_rounded, size: 14, color: Colors.green),
                          SizedBox(width: 4),
                          Text('Owned', style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  )
                : GestureDetector(
                    onTap: () => _handleBuy(item),
                    child: Container(
                      height: 34,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Colors.purple, Colors.deepPurpleAccent]),
                        borderRadius: BorderRadius.circular(17),
                      ),
                      alignment: Alignment.center,
                      child: const Text('Buy Now', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  /// Live animated preview dialog showing the asset in realistic application context
  void _showItemAnimatedPreview(StoreItemModel item, bool isDark) {
    final catLower = item.categoryId.toLowerCase();
    final typeLower = item.assetType.toLowerCase();
    final isFrame = catLower.contains('frame') || typeLower.contains('frame');
    final isBubble = catLower.contains('bubble') || typeLower.contains('bubble');
    final isBg = catLower.contains('background') || typeLower.contains('theme');
    final isCard = catLower.contains('card') || typeLower.contains('card');
    final isCar = catLower.contains('car') || typeLower.contains('mount');

    final backpack = context.read<BackpackProvider>();
    final isOwned = backpack.isItemOwned(item);
    final wallet = context.read<WalletProvider>();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.getCard(isDark),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Pull Handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),

              // Title Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: TextStyle(
                            color: AppColors.getTextPrimary(isDark),
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.purple.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                item.categoryId,
                                style: const TextStyle(color: Colors.purpleAccent, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Validity: ${item.durationDays} Days',
                              style: TextStyle(color: AppColors.getTextSecondary(isDark), fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: AppColors.getTextSecondary(isDark)),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── ANIMATED PREVIEW STAGE ──
              Container(
                height: 180,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF1E1035),
                      Colors.black.withValues(alpha: 0.85),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.purple.withValues(alpha: 0.3)),
                ),
                alignment: Alignment.center,
                child: Builder(
                  builder: (context) {
                    if (isFrame) {
                      // Live Avatar Frame Demonstration
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          const CircleAvatar(
                            radius: 46,
                            backgroundImage: AssetImage('assets/images/user1.png'),
                          ),
                          SizedBox(
                            width: 140,
                            height: 140,
                            child: Image.asset(
                              item.imageUrl,
                              fit: BoxFit.contain,
                              errorBuilder: (c, e, s) => const SizedBox(),
                            ),
                          ),
                        ],
                      );
                    } else if (isBubble) {
                      // Live Chat Bubble Demonstration
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.asset(
                                item.imageUrl,
                                height: 90,
                                width: double.infinity,
                                fit: BoxFit.fill,
                                errorBuilder: (c, e, s) => Container(
                                  height: 80,
                                  color: Colors.purple.withValues(alpha: 0.3),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white70, size: 18),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      'Hello! Welcome to ZeParty Live 🎉',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        shadows: [
                                          Shadow(color: Colors.black.withValues(alpha: 0.8), blurRadius: 4),
                                        ],
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    } else if (isBg) {
                      // Live Room Theme Background Demonstration
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.asset(
                              item.imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (c, e, s) => const Center(child: Icon(Icons.image, size: 50, color: Colors.white30)),
                            ),
                            Container(
                              color: Colors.black.withValues(alpha: 0.25),
                            ),
                            const Center(
                              child: Text(
                                'Live Room Background Preview',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  shadows: [Shadow(color: Colors.black, blurRadius: 6)],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    } else if (isCard) {
                      // Special Card Holographic Demonstration
                      return Container(
                        width: 220,
                        height: 125,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.6)),
                          boxShadow: [
                            BoxShadow(color: Colors.amber.withValues(alpha: 0.2), blurRadius: 12),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.asset(
                                item.imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (c, e, s) => const SizedBox(),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.name,
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                    const Spacer(),
                                    const Text('VIP MEMBER', style: TextStyle(color: Colors.amberAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    } else if (isCar) {
                      // Car / Mount Demonstration
                      return SizedBox(
                        height: 120,
                        child: Image.asset(
                          item.imageUrl,
                          fit: BoxFit.contain,
                          errorBuilder: (c, e, s) => const Icon(Icons.directions_car_rounded, size: 60, color: Colors.purpleAccent),
                        ),
                      );
                    } else {
                      // Generic Animated Asset Preview
                      return SizedBox(
                        height: 120,
                        child: Image.asset(
                          item.imageUrl,
                          fit: BoxFit.contain,
                          errorBuilder: (c, e, s) => const Icon(Icons.stars_rounded, size: 60, color: Colors.purpleAccent),
                        ),
                      );
                    }
                  },
                ),
              ),
              const SizedBox(height: 20),

              // Price & Wallet Balance Indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Price', style: TextStyle(color: AppColors.getTextSecondary(isDark), fontSize: 12)),
                      Row(
                        children: [
                          const Icon(Icons.monetization_on_rounded, size: 18, color: Colors.orangeAccent),
                          const SizedBox(width: 4),
                          Text(
                            '${item.priceCoins > 0 ? item.priceCoins : 50000} Coins',
                            style: TextStyle(
                              color: AppColors.getTextPrimary(isDark),
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Your Balance', style: TextStyle(color: AppColors.getTextSecondary(isDark), fontSize: 12)),
                      Text(
                        '${wallet.coins} Coins',
                        style: TextStyle(
                          color: wallet.coins >= item.priceCoins ? Colors.green : Colors.redAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Bottom Action Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: isOwned
                    ? ElevatedButton.icon(
                        icon: const Icon(Icons.check_circle_rounded, color: Colors.white),
                        label: const Text('Equip in My Outfit', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          Navigator.push(context, MaterialPageRoute(builder: (c) => const OutfitScreen()));
                        },
                      )
                    : ElevatedButton.icon(
                        icon: const Icon(Icons.shopping_bag_rounded, color: Colors.white),
                        label: const Text('Buy Now', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _handleBuy(item);
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
