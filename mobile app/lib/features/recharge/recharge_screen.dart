import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/utils/formatters.dart';
import '../../models/recharge_plan_model.dart';
import '../../providers/wallet_provider.dart';
import '../../widgets/design/gold_button.dart';
import '../../widgets/design/premium_card.dart';
import 'cumulative_recharge_screen.dart';

class RechargeScreen extends StatefulWidget {
  const RechargeScreen({super.key});

  @override
  State<RechargeScreen> createState() => _RechargeScreenState();
}

class _RechargeScreenState extends State<RechargeScreen> {
  bool _isProcessing = false;
  String? _processingPlanId;

  // Fallback defaults if backend is unreachable initially
  static const List<RechargePlanModel> _defaultPlans = [
    RechargePlanModel(id: 'plan_1', name: 'Bronze Starter Pack', coinAmount: 1000, bonusCoins: 50, priceUSD: 0.99, badgeText: 'Starter Pack'),
    RechargePlanModel(id: 'plan_2', name: 'Silver Popular Pack', coinAmount: 5000, bonusCoins: 400, priceUSD: 4.99, badgeText: 'Popular Choice'),
    RechargePlanModel(id: 'plan_3', name: 'Gold Mega Pack', coinAmount: 12000, bonusCoins: 1500, priceUSD: 9.99, isRecommended: true, badgeText: 'Best Value 🔥'),
    RechargePlanModel(id: 'plan_4', name: 'Platinum Super Pack', coinAmount: 50000, bonusCoins: 8000, priceUSD: 39.99, badgeText: 'VIP Super Pack 👑'),
    RechargePlanModel(id: 'plan_5', name: 'Diamond Royal Pack', coinAmount: 120000, bonusCoins: 25000, priceUSD: 99.99, badgeText: 'Royal Deal 💎'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WalletProvider>().fetchRechargePlans();
      context.read<WalletProvider>().fetchWallet();
    });
  }

  Future<void> _handlePlanPurchase(RechargePlanModel plan) async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
      _processingPlanId = plan.id;
    });

    final wallet = context.read<WalletProvider>();
    final result = await wallet.createPaymentIntent(
      planId: plan.id,
      paymentProvider: 'STRIPE',
    );

    if (!mounted) return;
    setState(() {
      _isProcessing = false;
      _processingPlanId = null;
    });

    if (result != null) {
      await wallet.fetchWallet();
      await wallet.fetchLedger(refresh: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🎉 Payment intent created for ${plan.name}! Order ID: ${result['orderId'] ?? result['clientSecret'] ?? 'Initiated'}'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(wallet.errorMessage ?? 'Payment initiation failed. Please try again.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final primary = AppColors.getPrimary(isDark);
    final wallet = context.watch<WalletProvider>();

    final displayPlans = wallet.plans.isNotEmpty ? wallet.plans : _defaultPlans;

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
      body: RefreshIndicator(
        onRefresh: () async {
          await wallet.fetchRechargePlans();
          await wallet.fetchWallet();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
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
                    color: AppColors.getCard(isDark),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.getBorder(isDark)),
                  ),
                  child: Row(
                    children: [
                      const Text('🎁', style: TextStyle(fontSize: 22)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Cumulative Recharge Event',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: AppColors.getTextPrimary(isDark),
                              ),
                            ),
                            Text(
                              'Unlock milestone SVIP badges and exclusive gifts',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.getTextSecondary(isDark),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 14),
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

              // Dynamic List of Coin Packs from Backend
              ...displayPlans.map((plan) {
                final isCurrentPlanProcessing = _isProcessing && _processingPlanId == plan.id;

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
                                      plan.name,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14.5,
                                        color: AppColors.getTextPrimary(isDark),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (plan.badgeText.isNotEmpty) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        gradient: AppColors.getAccentGradient(isDark),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        plan.badgeText,
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
                                '${AppFormatters.formatNumber(plan.coinAmount)} Coins ${plan.bonusCoins > 0 ? '+ ${plan.bonusCoins} Bonus' : ''}',
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
                          text: '\$${plan.priceUSD.toStringAsFixed(2)}',
                          isLoading: isCurrentPlanProcessing,
                          height: 38,
                          width: 78,
                          radius: 12,
                          expand: false,
                          onPressed: _isProcessing ? null : () => _handlePlanPurchase(plan),
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
      ),
    );
  }
}
