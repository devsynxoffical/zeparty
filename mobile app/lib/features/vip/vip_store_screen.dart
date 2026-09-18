import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_provider.dart';
import '../../models/vip_item_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/vip_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../widgets/vip_card.dart';
import '../../widgets/design/premium_banner.dart';
import '../../widgets/design/gold_button.dart';

class VipStoreScreen extends StatefulWidget {
  const VipStoreScreen({super.key});

  @override
  State<VipStoreScreen> createState() => _VipStoreScreenState();
}

class _VipStoreScreenState extends State<VipStoreScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<VipProvider>().fetchVipCatalog();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showPurchaseConfirm(BuildContext context, bool isDark, VipItemModel item) {
    final wallet = Provider.of<WalletProvider>(context, listen: false);
    final vip = Provider.of<VipProvider>(context, listen: false);

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.getCard(isDark),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4,
              decoration: BoxDecoration(color: AppColors.getBorder(isDark), borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Text(item.icon, style: const TextStyle(fontSize: 56)),
            const SizedBox(height: 12),
            Text(item.title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(isDark))),
            const SizedBox(height: 6),
            Text(item.description, style: TextStyle(fontSize: 13, color: AppColors.getTextSecondary(isDark)), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('🪙', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 6),
                Text('${item.coinPrice} Coins', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.gold)),
              ],
            ),
            const SizedBox(height: 6),
            Text('Your balance: 🪙 ${wallet.coins}', style: TextStyle(fontSize: 12, color: AppColors.getTextSecondary(isDark))),
            const SizedBox(height: 24),
            wallet.coins >= item.coinPrice
                ? GoldButton(
                    text: 'Confirm Purchase',
                    height: 52,
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final success = await vip.purchaseVipItem(item.id, wallet);
                      if (success && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: AppColors.getPrimary(isDark),
                            content: Row(children: [
                              const Text('🎉', style: TextStyle(fontSize: 20)),
                              const SizedBox(width: 10),
                              Text('${item.title} unlocked!', style: TextStyle(color: AppColors.onPrimary(isDark: isDark), fontWeight: FontWeight.bold)),
                            ]),
                          ),
                        );
                      }
                    },
                  )
                : GoldOutlinedButton(
                    text: 'Insufficient Coins',
                    height: 52,
                    foregroundColor: AppColors.mutedText,
                    onPressed: () {},
                  ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final vipProvider = context.watch<VipProvider>();
    final auth = context.watch<AuthProvider>();
    final primary = AppColors.getPrimary(isDark);
    final userVipLevel = auth.currentUser.wealthLevel;

    return Scaffold(
      backgroundColor: AppColors.getBackground(isDark),
      appBar: AppBar(
        backgroundColor: AppColors.getBackground(isDark),
        title: Text('👑 VIP Privilege Store',
          style: TextStyle(color: AppColors.getTextPrimary(isDark), fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: primary,
          labelColor: primary,
          unselectedLabelColor: AppColors.getTextSecondary(isDark),
          tabs: const [Tab(text: 'Store Catalog'), Tab(text: 'My VIP Items')],
        ),
      ),
      body: Column(
        children: [
          // VIP Status Banner
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: PremiumBanner(
              title: userVipLevel > 0 ? 'VIP Level $userVipLevel Active' : 'VIP Membership',
              subtitle: 'Exclusive entrance effects, frames and room badges',
              value: userVipLevel > 0 ? '👑 VIP $userVipLevel' : 'Member',
              footer: '🏅 Badge • 🎬 Entry FX • 🖼️ Frame • 📊 Priority • 🔒 VIP Room',
              trailing: const Text('👑', style: TextStyle(fontSize: 40)),
            ),
          ),

          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // ─── All Catalog Items ───
                vipProvider.isLoading && vipProvider.vipItems.isEmpty
                    ? Center(child: CircularProgressIndicator(color: primary))
                    : vipProvider.vipItems.isEmpty
                        ? Center(
                            child: Text(
                              'No VIP items available currently.',
                              style: TextStyle(color: AppColors.getTextSecondary(isDark)),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: vipProvider.vipItems.length,
                            itemBuilder: (context, index) {
                              final item = vipProvider.vipItems[index];
                              final owned = item.isOwned;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: VipCard(
                                  item: item,
                                  onBuy: owned ? null : () => _showPurchaseConfirm(context, isDark, item),
                                ),
                              );
                            },
                          ),

                // ─── Owned Items ───
                vipProvider.ownedItems.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('🛍️', style: TextStyle(fontSize: 60)),
                            const SizedBox(height: 12),
                            Text('No VIP items yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(isDark))),
                            Text('Visit the store catalog to unlock exclusive privileges', style: TextStyle(fontSize: 13, color: AppColors.getTextSecondary(isDark))),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: vipProvider.ownedItems.length,
                        itemBuilder: (context, index) {
                          final item = vipProvider.ownedItems[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: VipCard(item: item, onBuy: null),
                          );
                        },
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
