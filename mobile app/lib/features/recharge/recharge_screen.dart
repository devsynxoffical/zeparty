import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/utils/formatters.dart';
import '../../providers/wallet_provider.dart';
import '../../widgets/design/gold_button.dart';
import '../../widgets/design/premium_card.dart';
import 'cumulative_recharge_screen.dart';

class RechargePlan {
  final String title;
  final int coins;
  final int bonusCoins;
  final double priceUSD;
  final bool isRecommended;
  final String badge;

  const RechargePlan({
    required this.title,
    required this.coins,
    required this.bonusCoins,
    required this.priceUSD,
    this.isRecommended = false,
    required this.badge,
  });
}

class RechargeScreen extends StatelessWidget {
  const RechargeScreen({super.key});

  static const List<RechargePlan> plans = [
    RechargePlan(title: 'Bronze Starter Pack', coins: 1000, bonusCoins: 50, priceUSD: 0.99, badge: 'Starter Pack'),
    RechargePlan(title: 'Silver Popular Pack', coins: 5000, bonusCoins: 400, priceUSD: 4.99, badge: 'Popular Choice'),
    RechargePlan(title: 'Gold Mega Pack', coins: 12000, bonusCoins: 1500, priceUSD: 9.99, isRecommended: true, badge: 'Best Value 🔥'),
    RechargePlan(title: 'Platinum Super Pack', coins: 50000, bonusCoins: 8000, priceUSD: 39.99, badge: 'VIP Super Pack 👑'),
    RechargePlan(title: 'Diamond Royal Pack', coins: 120000, bonusCoins: 25000, priceUSD: 99.99, badge: 'Royal Deal 💎'),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final primary = AppColors.getPrimary(isDark);
    final wallet = context.watch<WalletProvider>();

    return Scaffold(
      backgroundColor: AppColors.getBackground(isDark),
      appBar: AppBar(
        backgroundColor: AppColors.getBackground(isDark),
        title: Text(
          '🪙 Recharge Coin Packs',
          style: TextStyle(
            color: AppColors.getTextPrimary(isDark),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current Balance Header Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: AppColors.getAccentGradient(isDark),
                borderRadius: BorderRadius.circular(20),
                boxShadow: AppColors.primaryGlow(isDark, alpha: 0.3, blur: 16),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Text('🪙', style: TextStyle(fontSize: 28)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Current Coin Balance',
                          style: TextStyle(
                            color: AppColors.onPrimary(isDark: isDark).withValues(alpha: 0.85),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${AppFormatters.formatNumber(wallet.coins)} Coins',
                          style: TextStyle(
                            color: AppColors.onPrimary(isDark: isDark),
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Cumulative Recharge Event Entry Banner
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (c) => const CumulativeRechargeScreen()),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF311B92), Color(0xFF673AB7), Color(0xFFFFB300)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.deepPurple.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Text('🎁', style: TextStyle(fontSize: 26)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Grand Cumulative Recharge Event',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Unlock milestone bonus coins & luxury items',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 10.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        children: [
                          Text('Rewards', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                          SizedBox(width: 4),
                          Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 10),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),
            Text(
              'Select Coin Package',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppColors.getTextPrimary(isDark),
              ),
            ),
            const SizedBox(height: 12),

            // List of Coin Packs
            ...plans.map((plan) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: PremiumCard(
                  padding: const EdgeInsets.all(16),
                  radius: 18,
                  premium: plan.isRecommended,
                  glowing: plan.isRecommended,
                  borderColor: plan.isRecommended ? AppColors.getBorderStrong(isDark) : null,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: plan.isRecommended
                              ? primary.withValues(alpha: 0.15)
                              : AppColors.getSurface(isDark),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: plan.isRecommended
                                ? AppColors.getBorderStrong(isDark)
                                : AppColors.getBorder(isDark),
                            width: 1,
                          ),
                        ),
                        child: const Text('🪙', style: TextStyle(fontSize: 26)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    plan.title,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14.5,
                                      color: AppColors.getTextPrimary(isDark),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (plan.isRecommended) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      gradient: AppColors.getAccentGradient(isDark),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      plan.badge,
                                      style: TextStyle(
                                        color: AppColors.onPrimary(isDark: isDark),
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${AppFormatters.formatNumber(plan.coins)} Coins + ${plan.bonusCoins} Bonus',
                              style: TextStyle(
                                color: primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      GoldButton(
                        text: '\$${plan.priceUSD}',
                        height: 38,
                        width: 78,
                        radius: 12,
                        expand: false,
                        onPressed: () {
                          wallet.rechargeCoins(plan.coins + plan.bonusCoins, plan.priceUSD);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Successfully purchased ${plan.title}! ${plan.coins + plan.bonusCoins} coins added.'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
