import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/animations/app_animations.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/design/gold_button.dart';
import '../../providers/wallet_provider.dart';

class CoinSellerScreen extends StatefulWidget {
  const CoinSellerScreen({super.key});

  @override
  State<CoinSellerScreen> createState() => _CoinSellerScreenState();
}

class _CoinSellerScreenState extends State<CoinSellerScreen> {
  final _userIdController = TextEditingController(text: 'user_1002');
  final _amountController = TextEditingController(text: '5000');

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final wallet = context.watch<WalletProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Coin Seller Dashboard')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: AppColors.getPremiumGradient(isDark),
                borderRadius: BorderRadius.circular(20),
                boxShadow: AppColors.primaryGlow(isDark, alpha: 0.25, blur: 16),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  children: [
                    const MetallicShine(bandWidth: 0.4, beginX: -0.7),
                    Padding(
                      padding: const EdgeInsets.all(18),
                      child: Row(
                        children: [
                          const Text('🪙', style: TextStyle(fontSize: 32)),
                          const SizedBox(width: 14),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Seller Stock Balance',
                                style: TextStyle(
                                  color: AppColors.onPrimary(isDark: isDark),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '${wallet.coins} Coins',
                                style: TextStyle(
                                  color: AppColors.onPrimary(isDark: isDark),
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            Text('Distribute Coins to User', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            CustomTextField(
              label: 'Recipient User ID / Username',
              hint: 'e.g. user_1002',
              controller: _userIdController,
              prefixIcon: Icons.person_search_rounded,
            ),
            const SizedBox(height: 16),

            CustomTextField(
              label: 'Coin Amount',
              hint: 'e.g. 5000',
              controller: _amountController,
              keyboardType: TextInputType.number,
              prefixIcon: Icons.generating_tokens,
            ),

            const SizedBox(height: 24),

            GoldButton(
              text: 'Transfer Coins Now',
              icon: Icons.send_rounded,
              onPressed: () {
                final amount = int.tryParse(_amountController.text) ?? 0;
                if (amount <= 0) return;
                wallet.distributeCoinsToUser(_userIdController.text, amount);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Successfully transferred $amount coins to ${_userIdController.text}! Audit record created.')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
