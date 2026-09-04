import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../widgets/design/premium_card.dart';
import '../../providers/escrow_provider.dart';
import '../../../../providers/auth_provider.dart';
import 'order_details_screen.dart';

class MyOrdersScreen extends StatelessWidget {
  const MyOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = AppColors.getPrimary(isDark);
    final user = context.watch<AuthProvider>().currentUser;
    final escrow = context.watch<EscrowProvider>();
    final orders = escrow.getUserOrders(user.id);

    return Scaffold(
      backgroundColor: AppColors.getBackground(isDark),
      appBar: AppBar(
        title: const Text('My P2P Orders'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: orders.isEmpty
          ? Center(
              child: Text(
                'No orders found.',
                style: TextStyle(color: AppColors.getTextSecondary(isDark)),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: orders.length,
              itemBuilder: (context, index) {
                final order = orders[index];
                final isBuyer = user.id == order.buyerId;

                return GestureDetector(
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => OrderDetailsScreen(order: order)));
                  },
                  child: PremiumCard(
                    padding: const EdgeInsets.all(16),
                    radius: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isBuyer ? AppColors.liveGreen.withValues(alpha: 0.1) : AppColors.danger.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    isBuyer ? 'BUY' : 'SELL',
                                    style: TextStyle(
                                      color: isBuyer ? AppColors.liveGreen : AppColors.danger,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  AppFormatters.formatTimeAgo(order.createdAt),
                                  style: TextStyle(color: AppColors.getTextSecondary(isDark), fontSize: 11),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: order.status == 'released' ? AppColors.success.withValues(alpha: 0.1) : primaryColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                order.status.toUpperCase(),
                                style: TextStyle(
                                  color: order.status == 'released' ? AppColors.success : primaryColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Fiat Amount',
                                  style: TextStyle(color: AppColors.getTextSecondary(isDark), fontSize: 11),
                                ),
                                Text(
                                  '${AppFormatters.formatCurrency(order.fiatAmount)} ${order.fiatCurrency}',
                                  style: TextStyle(color: AppColors.getTextPrimary(isDark), fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                              ],
                            ),
                            Icon(Icons.arrow_forward_rounded, color: AppColors.getBorderStrong(isDark), size: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'Coin Amount',
                                  style: TextStyle(color: AppColors.getTextSecondary(isDark), fontSize: 11),
                                ),
                                Row(
                                  children: [
                                    Text(
                                      '${order.coins} ',
                                      style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                    const Text('🪙', style: TextStyle(fontSize: 14)),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(Icons.person_outline, size: 14, color: AppColors.getTextSecondary(isDark)),
                            const SizedBox(width: 4),
                            Text(
                              isBuyer ? 'Seller: ${order.sellerName}' : 'Buyer: ${order.buyerName}',
                              style: TextStyle(color: AppColors.getTextSecondary(isDark), fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
