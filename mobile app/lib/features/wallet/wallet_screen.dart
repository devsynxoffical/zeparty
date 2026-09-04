import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/auth_guard.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/wallet_date_gate.dart';
import '../../providers/wallet_provider.dart';
import '../../widgets/wallet_card.dart';
import '../recharge/recharge_screen.dart';
import 'agency_recharge_screen.dart';
import 'wallet_details_screen.dart';
import 'coin_records_screen.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  Future<void> _refreshWallet() async {
    await Future.delayed(const Duration(milliseconds: 400));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = AppColors.getPrimary(isDark);
    final wallet = context.watch<WalletProvider>();

    return Scaffold(
      backgroundColor: AppColors.getBackground(isDark),
      appBar: AppBar(
        title: const Text('My Wallet'),
        backgroundColor: AppColors.getBackground(isDark),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded, color: Colors.amberAccent),
            tooltip: 'Coin Records',
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const CoinRecordsScreen()));
            },
          ),
          IconButton(
            icon: const Icon(Icons.receipt_long_rounded, color: Colors.white70),
            tooltip: 'Diamond Details',
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletDetailsScreen()));
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshWallet,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Coin Balance Card
              WalletCard(
                title: 'Coin Balance',
                balance: AppFormatters.formatNumber(wallet.coins),
                icon: Image.asset('assets/images/coin_ze.png', width: 28, height: 28),
                gradient: AppColors.getAccentGradient(isDark),
                action: () {
                  AuthGuard.require(context, () {
                    Navigator.push(context, MaterialPageRoute(builder: (c) => const RechargeScreen()));
                  }, reason: 'Sign in to top up coins');
                },
              ),
              const SizedBox(height: 16),

              // 2. Action Buttons: Top Up & Buy from Authorized Sellers
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.add_circle_rounded),
                      label: const Text('Top Up Coins'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () {
                        AuthGuard.require(context, () {
                          Navigator.push(context, MaterialPageRoute(builder: (c) => const RechargeScreen()));
                        }, reason: 'Sign in to top up coins');
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.storefront_rounded),
                      label: const Text('Authorized Sellers'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.getTextPrimary(isDark),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: primaryColor.withValues(alpha: 0.5)),
                      ),
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (c) => const AgencyRechargeScreen()));
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 3. Module 19: Permanent Date Gate Notice Banner
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1B2E),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.amber, width: 1.5),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline_rounded, size: 22, color: Colors.amberAccent),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        WalletDateGate.restrictionNotice,
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 4. Wallet Details Link Tile
              InkWell(
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletDetailsScreen()));
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.getCard(isDark),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.history_toggle_off_rounded, color: primaryColor),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Categorized Wallet Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.getTextPrimary(isDark))),
                              Text('View Diamond & Coin History', style: TextStyle(fontSize: 11, color: AppColors.getTextSecondary(isDark))),
                            ],
                          ),
                        ],
                      ),
                      Icon(Icons.chevron_right_rounded, color: AppColors.getTextSecondary(isDark)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
