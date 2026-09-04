import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../providers/wallet_provider.dart';
import '../../../../widgets/design/premium_card.dart';
import '../../../../widgets/design/gold_button.dart';
import 'p2p_trading_screen.dart';
import 'my_orders_screen.dart';
import 'create_offer_screen.dart';

class CoinCenterScreen extends StatelessWidget {
  const CoinCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = AppColors.getPrimary(isDark);
    final wallet = context.watch<WalletProvider>();

    return Scaffold(
      backgroundColor: AppColors.getBackground(isDark),
      appBar: AppBar(
        title: const Text('P2P Coin Center'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Escrow/Wallet Balance Banner
            PremiumCard(
              padding: const EdgeInsets.all(20),
              radius: 20,
              gradient: AppColors.getPremiumGradient(isDark),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Available Balance',
                          style: TextStyle(
                            color: AppColors.getOnPrimary(isDark).withValues(alpha: 0.8),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Text('🪙', style: TextStyle(fontSize: 24)),
                            const SizedBox(width: 8),
                            Text(
                              AppFormatters.formatNumber(wallet.coins),
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: AppColors.getOnPrimary(isDark),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.getOnPrimary(isDark).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.lock_outline, size: 14, color: AppColors.getOnPrimary(isDark)),
                              const SizedBox(width: 6),
                              Text(
                                'In Escrow: ${AppFormatters.formatNumber(wallet.lockedCoins)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.getOnPrimary(isDark),
                                ),
                              ),
                            ],
                          ),
                        )
                      ],
                    ),
                  ),
                  Icon(Icons.currency_exchange_rounded, size: 60, color: AppColors.getOnPrimary(isDark).withValues(alpha: 0.2)),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Quick Actions Grid
            Text(
              'Quick Actions',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: _buildActionCard(
                    context,
                    title: 'P2P Trading',
                    subtitle: 'Buy or Sell Coins',
                    icon: Icons.storefront_rounded,
                    isDark: isDark,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const P2PTradingScreen())),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionCard(
                    context,
                    title: 'My Orders',
                    subtitle: 'Active & History',
                    icon: Icons.receipt_long_rounded,
                    isDark: isDark,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyOrdersScreen())),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildActionCard(
                    context,
                    title: 'Post Ad',
                    subtitle: 'Create Offer',
                    icon: Icons.add_business_rounded,
                    isDark: isDark,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateOfferScreen())),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionCard(
                    context,
                    title: 'Escrow Guide',
                    subtitle: 'How it works',
                    icon: Icons.security_rounded,
                    isDark: isDark,
                    onTap: () {
                      _showEscrowGuide(context, isDark, primaryColor);
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 30),

            // Trending / Recent
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Market Trends',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const P2PTradingScreen())),
                  child: Text('View All', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            
            PremiumCard(
              padding: const EdgeInsets.all(16),
              radius: 16,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Current Sell Price (Avg)', style: TextStyle(color: AppColors.getTextSecondary(isDark))),
                      Text('\$0.05 / Coin', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(isDark))),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Current Buy Price (Avg)', style: TextStyle(color: AppColors.getTextSecondary(isDark))),
                      Text('\$0.048 / Coin', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(isDark))),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final primaryColor = AppColors.getPrimary(isDark);
    return GestureDetector(
      onTap: onTap,
      child: PremiumCard(
        padding: const EdgeInsets.all(16),
        radius: 16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: primaryColor, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(fontSize: 11, color: AppColors.getTextSecondary(isDark)),
            ),
          ],
        ),
      ),
    );
  }

  void _showEscrowGuide(BuildContext context, bool isDark, Color primaryColor) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (c) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.getCard(isDark),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.getBorder(isDark),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Icon(Icons.security_rounded, color: primaryColor, size: 28),
                const SizedBox(width: 12),
                const Text(
                  'How Escrow Works',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildGuideStep(isDark, '1', 'Place Order', 'Buyer places an order on a Seller\'s ad.'),
            const SizedBox(height: 16),
            _buildGuideStep(isDark, '2', 'Coins Locked', 'Seller\'s coins are securely locked in Escrow.'),
            const SizedBox(height: 16),
            _buildGuideStep(isDark, '3', 'Make Payment', 'Buyer pays Seller via agreed external method.'),
            const SizedBox(height: 16),
            _buildGuideStep(isDark, '4', 'Coins Released', 'Seller confirms payment and coins are released to Buyer.'),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: GoldButton(
                text: 'Got it',
                onPressed: () => Navigator.pop(c),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildGuideStep(bool isDark, String step, String title, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: AppColors.getPrimary(isDark).withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              step,
              style: TextStyle(
                color: AppColors.getPrimary(isDark),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 4),
              Text(desc, style: TextStyle(fontSize: 12, color: AppColors.getTextSecondary(isDark))),
            ],
          ),
        ),
      ],
    );
  }
}
