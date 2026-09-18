import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../models/store_item_model.dart';
import '../../providers/store_provider.dart';
import '../../providers/wallet_provider.dart';
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Successfully purchased ${item.name}! Check your backpack.'), backgroundColor: AppColors.success),
      );
    } else if (mounted) {
      final error = context.read<StoreProvider>().errorMessage;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error ?? 'Failed to purchase item'), backgroundColor: AppColors.error),
      );
    }
  }

  void _handleSend(StoreItemModel item) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Store items are bound to account upon purchase. Use live room gifting to send gifts to friends!')),
    );
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
              onPressed: () => context.read<StoreProvider>().fetchStoreItems(),
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
        body: LuxBackground(
          showGlow: true,
          child: storeProvider.isLoading
              ? Center(child: CircularProgressIndicator(color: AppColors.getPrimary(isDark)))
              : TabBarView(
                  children: categories.map((category) {
                    final items = storeProvider.getItemsByCategory(category);
                    return _buildCategoryGrid(items, isDark);
                  }).toList(),
                ),
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
          item.imageUrl.startsWith('http')
              ? Image.network(
                  item.imageUrl,
                  height: 60,
                  fit: BoxFit.contain,
                  errorBuilder: (c, e, s) => const Icon(Icons.star_rounded, size: 40, color: Colors.amber),
                )
              : item.imageUrl.isNotEmpty
                  ? Image.asset(
                      item.imageUrl,
                      height: 60,
                      fit: BoxFit.contain,
                      errorBuilder: (c, e, s) => const Icon(Icons.star_rounded, size: 40, color: Colors.amber),
                    )
                  : const Icon(Icons.shopping_bag_rounded, size: 40, color: Colors.purpleAccent),
          
          const Spacer(),
          
          // Price
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.monetization_on_rounded, size: 15, color: Colors.orangeAccent),
              const SizedBox(width: 4),
              Text(
                item.priceCoins.toString(),
                style: TextStyle(color: primaryText, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          
          const SizedBox(height: 10),
          
          // Buy Button
          GestureDetector(
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
