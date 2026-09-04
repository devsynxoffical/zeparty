import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_provider.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/design/gold_button.dart';
import '../../widgets/design/premium_card.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/user_model.dart';
import '../../core/utils/formatters.dart';
import '../coin_marketplace/presentation/screens/create_offer_screen.dart';
import '../coin_marketplace/presentation/screens/coin_center_screen.dart';

class WithdrawalScreen extends StatefulWidget {
  const WithdrawalScreen({super.key});

  @override
  State<WithdrawalScreen> createState() => _WithdrawalScreenState();
}

class _WithdrawalScreenState extends State<WithdrawalScreen> {
  final _coinsController = TextEditingController(text: '10000');
  final _accountController = TextEditingController();
  String _selectedPayout = 'JazzCash';
  double _calculatedUsd = 100.00;

  final List<String> _payoutMethods = ['JazzCash', 'Easypaisa', 'Bank Transfer'];

  @override
  void initState() {
    super.initState();
    _coinsController.addListener(_updateConversion);
  }

  @override
  void dispose() {
    _coinsController.removeListener(_updateConversion);
    _coinsController.dispose();
    _accountController.dispose();
    super.dispose();
  }

  void _updateConversion() {
    final coins = int.tryParse(_coinsController.text) ?? 0;
    setState(() {
      // 10,000 Coins = $100 USD (Conversion rate: 100 coins = $1)
      _calculatedUsd = coins / 100.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final wallet = context.watch<WalletProvider>();
    final user = context.watch<AuthProvider>().currentUser;
    final onPrimary = AppColors.onPrimary(isDark: isDark);
    final isSeller = user.role == UserRole.seller;

    return Scaffold(
      backgroundColor: AppColors.getBackground(isDark),
      appBar: AppBar(
        backgroundColor: AppColors.getBackground(isDark),
        title: Text(isSeller ? 'P2P Coin Seller Hub' : 'Sell Coins & Withdraw',
          style: TextStyle(color: AppColors.getTextPrimary(isDark), fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: isSeller 
          ? _buildSellerP2PFlow(isDark, wallet, onPrimary)
          : _buildStandardWithdrawFlow(isDark, wallet, onPrimary),
      ),
    );
  }

  Widget _buildSellerP2PFlow(bool isDark, WalletProvider wallet, Color onPrimary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Available Coins Header Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: AppColors.getAccentGradient(isDark),
            borderRadius: BorderRadius.circular(22),
            boxShadow: AppColors.primaryGlow(isDark, alpha: 0.3, blur: 16, spread: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Merchant Available Balance',
                style: TextStyle(color: onPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text(
                '${AppFormatters.formatNumber(wallet.coins)} Coins',
                style: TextStyle(
                  color: onPrimary,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.verified_user_rounded, color: Colors.white, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'Verified Merchant Seller status active',
                    style: TextStyle(color: onPrimary.withValues(alpha: 0.9), fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),

        Text(
          'P2P Selling Guidelines',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(isDark)),
        ),
        const SizedBox(height: 12),
        PremiumCard(
          padding: const EdgeInsets.all(16),
          radius: 16,
          child: Column(
            children: [
              _buildStepRow(Icons.playlist_add_rounded, 'Create P2P Offer', 'List the amount of coins you wish to sell and specify your payment details.', isDark),
              const Divider(height: 24),
              _buildStepRow(Icons.people_alt_rounded, 'Buyer Acceptance', 'Wait for a buyer to request purchase and complete the local payment transfer.', isDark),
              const Divider(height: 24),
              _buildStepRow(Icons.price_check_rounded, 'Confirm & Release', 'Verify payment receipt on your JazzCash/Easypaisa/Bank, then release the escrowed coins.', isDark),
            ],
          ),
        ),
        const SizedBox(height: 36),

        SizedBox(
          width: double.infinity,
          child: GoldButton(
            text: 'Create P2P Sell Offer',
            icon: Icons.add_circle_rounded,
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (c) => const CreateOfferScreen()));
            },
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (c) => const CoinCenterScreen()));
            },
            icon: const Icon(Icons.storefront_rounded, color: AppColors.metallicGold),
            label: const Text('Go to P2P Trading Board', style: TextStyle(color: AppColors.metallicGold, fontWeight: FontWeight.bold)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.metallicGold, width: 1.5),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStepRow(IconData icon, String title, String description, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.metallicGold, size: 24),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(isDark), fontSize: 13)),
              const SizedBox(height: 4),
              Text(description, style: TextStyle(color: AppColors.getTextSecondary(isDark), fontSize: 11)),
            ],
          ),
        )
      ],
    );
  }

  Widget _buildStandardWithdrawFlow(bool isDark, WalletProvider wallet, Color onPrimary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Available Coins Header Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: AppColors.getAccentGradient(isDark),
            borderRadius: BorderRadius.circular(22),
            boxShadow: AppColors.primaryGlow(isDark, alpha: 0.3, blur: 16, spread: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Available Coin Balance',
                style: TextStyle(color: onPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text(
                '${AppFormatters.formatNumber(wallet.coins)} Coins',
                style: TextStyle(
                  color: onPrimary,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Exchange Rate: 100 Coins = \$1.00 USD',
                style: TextStyle(color: onPrimary.withValues(alpha: 0.7), fontSize: 11),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),

        Text('1. Enter Coins to Sell',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(isDark))),
        const SizedBox(height: 10),
        CustomTextField(
          label: 'Coin Amount',
          hint: '10000',
          controller: _coinsController,
          keyboardType: TextInputType.number,
          prefixIcon: Icons.monetization_on_rounded,
        ),
        const SizedBox(height: 8),
        
        // Live conversion display
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.getCard(isDark),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.getBorder(isDark)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Estimated Payout:', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
              Text(
                '\$${_calculatedUsd.toStringAsFixed(2)} USD',
                style: const TextStyle(color: AppColors.metallicGold, fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        Text('2. Select Withdrawal Method',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(isDark))),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.getCard(isDark),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.getBorder(isDark)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedPayout,
              isExpanded: true,
              dropdownColor: AppColors.getCard(isDark),
              style: TextStyle(color: AppColors.getTextPrimary(isDark), fontWeight: FontWeight.w600, fontSize: 13),
              items: _payoutMethods.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedPayout = val);
              },
            ),
          ),
        ),

        const SizedBox(height: 24),

        CustomTextField(
          label: '3. Payout Account / Phone Details',
          hint: 'Account Number, Phone Number or IBAN',
          controller: _accountController,
          prefixIcon: Icons.account_balance_wallet_rounded,
        ),

        const SizedBox(height: 36),

        SizedBox(
          width: double.infinity,
          child: GoldButton(
            text: 'Confirm Sale & Withdraw',
            icon: Icons.check_circle_rounded,
            onPressed: () {
              final coins = int.tryParse(_coinsController.text) ?? 0;
              final account = _accountController.text.trim();

              if (coins <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid coin amount to sell')),
                );
                return;
              }
              if (coins > wallet.coins) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Insufficient coin balance!')),
                );
                return;
              }
              if (account.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please fill in your payout account details')),
                );
                return;
              }

              final success = wallet.sellCoinsAndWithdraw(
                coinAmount: coins,
                cashAmountUSD: _calculatedUsd,
                payoutMethod: _selectedPayout,
                accountDetails: account,
              );

              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Sold $coins Coins for \$${_calculatedUsd.toStringAsFixed(2)} USD successfully!'),
                    backgroundColor: const Color(0xFF16A34A),
                  ),
                );
                Navigator.pop(context);
              }
            },
          ),
        ),
      ],
    );
  }
}
