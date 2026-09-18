import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/wallet_details_provider.dart';
import 'diamond_exchange_screen.dart';
import 'diamond_transfer_screen.dart';
import 'wallet_details_screen.dart';

class DiamondsWalletScreen extends StatelessWidget {
  const DiamondsWalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final wallet = context.watch<WalletProvider>();

    return Scaffold(
      backgroundColor: AppColors.getBackground(isDark),
      appBar: AppBar(
        backgroundColor: AppColors.getBackground(isDark),
        title: Text('Wallet', style: TextStyle(color: AppColors.getTextPrimary(isDark), fontWeight: FontWeight.bold, fontSize: 18.sp)),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.getTextPrimary(isDark), size: 20.sp),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: AppColors.getTextPrimary(isDark)),
            onPressed: () {
              context.read<WalletProvider>().fetchWallet();
              context.read<WalletDetailsProvider>().refreshData();
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildBalanceCard(context, wallet.diamonds, isDark),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: _buildActionCard(context, 'Exchange Gold\nCoins', Icons.currency_exchange_rounded, isDark, true)),
                const SizedBox(width: 16),
                Expanded(child: _buildActionCard(context, 'Transfer', Icons.move_up_rounded, isDark, false)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceCard(BuildContext context, int balance, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.getCard(isDark),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('My Balance', style: TextStyle(color: AppColors.getTextSecondary(isDark), fontSize: 14)),
              // Module 21: Visible Details action with at least 44x44 logical px touch target
              InkWell(
                key: const Key('diamond_details_button'),
                onTap: () {
                  context.read<WalletDetailsProvider>().logAudit('Details opened');
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const WalletDetailsScreen()),
                  );
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Details',
                        style: TextStyle(color: AppColors.getPrimary(isDark), fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.getPrimary(isDark)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('💎', style: TextStyle(fontSize: 32)),
              const SizedBox(width: 12),
              Text(
                AppFormatters.formatNumber(balance),
                style: TextStyle(
                  color: AppColors.getTextPrimary(isDark),
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(BuildContext context, String title, IconData icon, bool isDark, bool isExchange) {
    return GestureDetector(
      onTap: () {
        if (isExchange) {
          Navigator.push(context, MaterialPageRoute(builder: (c) => const DiamondExchangeScreen()));
        } else {
          Navigator.push(context, MaterialPageRoute(builder: (c) => const DiamondTransferScreen()));
        }
      },
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          color: isExchange ? AppColors.getCard(isDark) : (isDark ? const Color(0xFF1F1F1F) : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isExchange ? AppColors.getPrimary(isDark).withValues(alpha: 0.5) : (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05))),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 5),
            )
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isExchange ? AppColors.getPrimary(isDark).withValues(alpha: 0.1) : (isDark ? Colors.white12 : Colors.grey.shade100),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isExchange ? AppColors.getPrimary(isDark) : Colors.blueAccent,
                size: 28,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isExchange ? AppColors.getPrimary(isDark) : AppColors.getTextPrimary(isDark),
                fontWeight: FontWeight.bold,
                fontSize: 13,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
