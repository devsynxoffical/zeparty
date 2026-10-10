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

    return Container(
      decoration: BoxDecoration(
        color: cardColor.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
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
              if (item.isVipExclusive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.amber, width: 0.8),
                  ),
                  child: const Text('VIP', style: TextStyle(color: Colors.amber, fontSize: 9, fontWeight: FontWeight.bold)),
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
    );
  }
}
