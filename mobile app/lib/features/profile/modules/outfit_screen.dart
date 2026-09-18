import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../models/user_asset_model.dart';
import '../../../../providers/backpack_provider.dart';

class OutfitScreen extends StatefulWidget {
  const OutfitScreen({super.key});

  @override
  State<OutfitScreen> createState() => _OutfitScreenState();
}

class _OutfitScreenState extends State<OutfitScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BackpackProvider>().fetchBackpack();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _toggleEquip(UserAssetModel userAsset) async {
    final backpack = context.read<BackpackProvider>();
    if (userAsset.isEquipped) {
      final success = await backpack.unequipAsset(userAsset.id);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unequipped ${userAsset.asset?.name ?? 'item'}'), duration: const Duration(seconds: 1)),
        );
      }
    } else {
      final success = await backpack.equipAsset(userAsset.id);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Equipped ${userAsset.asset?.name ?? 'item'}! ✨'), duration: const Duration(seconds: 1)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppColors.getPrimary(isDark);
    final backpack = context.watch<BackpackProvider>();

    return Scaffold(
      backgroundColor: AppColors.getBackground(isDark),
      appBar: AppBar(
        backgroundColor: AppColors.getBackground(isDark),
        title: Text('My Backpack & Outfits', style: TextStyle(color: AppColors.getTextPrimary(isDark), fontWeight: FontWeight.bold)),
        iconTheme: IconThemeData(color: AppColors.getTextPrimary(isDark)),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => context.read<BackpackProvider>().fetchBackpack(refresh: true),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: primary,
          unselectedLabelColor: AppColors.getTextSecondary(isDark),
          indicatorColor: primary,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: 'Bubbles'),
            Tab(text: 'Frames'),
            Tab(text: 'Cars'),
            Tab(text: 'Effects'),
          ],
        ),
      ),
      body: backpack.isLoading && backpack.userAssets.isEmpty
          ? Center(child: CircularProgressIndicator(color: primary))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildAssetCategoryGrid('BUBBLE', isDark),
                _buildAssetCategoryGrid('FRAME', isDark),
                _buildAssetCategoryGrid('VEHICLE', isDark),
                _buildAssetCategoryGrid('EFFECT', isDark),
              ],
            ),
    );
  }

  Widget _buildAssetCategoryGrid(String typeKeyword, bool isDark) {
    final backpack = context.watch<BackpackProvider>();
    final items = backpack.userAssets.where((ua) {
      final type = ua.asset?.assetType ?? '';
      return type.toUpperCase().contains(typeKeyword);
    }).toList();

    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.checkroom_rounded, size: 64, color: AppColors.getTextSecondary(isDark).withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text('No items owned in this category', style: TextStyle(color: AppColors.getTextSecondary(isDark))),
            const SizedBox(height: 8),
            Text('Visit the Store to unlock new styles', style: TextStyle(fontSize: 12, color: AppColors.getTextSecondary(isDark).withValues(alpha: 0.7))),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.76,
      ),
      itemCount: items.length,
      itemBuilder: (context, idx) {
        final item = items[idx];
        final isEquipped = item.isEquipped;
        final isExpired = item.isExpired;
        final daysLeft = item.expiresAt.difference(DateTime.now()).inDays;

        Color cardBorderColor = AppColors.getBorder(isDark);
        if (isEquipped) cardBorderColor = AppColors.metallicGold;
        if (isExpired) cardBorderColor = Colors.red.withValues(alpha: 0.3);

        return Container(
          decoration: BoxDecoration(
            color: AppColors.getCard(isDark),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: cardBorderColor, width: isEquipped ? 1.8 : 1),
            boxShadow: isEquipped ? [
              BoxShadow(
                color: AppColors.metallicGold.withValues(alpha: 0.15),
                blurRadius: 8,
                offset: const Offset(0, 3),
              )
            ] : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Badge Status
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isEquipped
                      ? AppColors.metallicGold.withValues(alpha: 0.2)
                      : isExpired
                          ? Colors.red.withValues(alpha: 0.1)
                          : Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  isEquipped ? 'EQUIPPED' : (isExpired ? 'EXPIRED' : (daysLeft > 0 ? '$daysLeft DAYS' : 'ACTIVE')),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: isEquipped
                        ? AppColors.metallicGold
                        : (isExpired ? Colors.red : Colors.green),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Asset Icon / Image
              item.asset?.imageUrl != null && item.asset!.imageUrl.startsWith('http')
                  ? Image.network(
                      item.asset!.imageUrl,
                      width: 54,
                      height: 54,
                      fit: BoxFit.contain,
                      errorBuilder: (c, e, s) => const Icon(Icons.style_rounded, size: 44, color: AppColors.gold),
                    )
                  : const Icon(Icons.style_rounded, size: 44, color: AppColors.gold),

              const SizedBox(height: 10),

              // Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  item.asset?.name ?? 'Owned Asset',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.getTextPrimary(isDark),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Equip / Unequip Button
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isEquipped ? Colors.grey[700] : AppColors.getPrimary(isDark),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  minimumSize: Size.zero,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: isExpired ? null : () => _toggleEquip(item),
                child: Text(
                  isEquipped ? 'Unequip' : 'Equip',
                  style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
