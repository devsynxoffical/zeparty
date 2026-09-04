import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../providers/wallet_provider.dart';

class DiamondPackage {
  final int diamonds;
  final int coins;
  DiamondPackage(this.diamonds, this.coins);
}

class DiamondExchangeScreen extends StatefulWidget {
  const DiamondExchangeScreen({super.key});

  @override
  State<DiamondExchangeScreen> createState() => _DiamondExchangeScreenState();
}

class _DiamondExchangeScreenState extends State<DiamondExchangeScreen> {
  DiamondPackage? _selectedPackage;

  final List<DiamondPackage> _packages = [
    DiamondPackage(2000000, 510000),
    DiamondPackage(10000000, 2500000),
    DiamondPackage(20000000, 5100000),
    DiamondPackage(40000000, 10200000),
    DiamondPackage(100000000, 25500000),
    DiamondPackage(200000000, 51000000),
  ];

  void _handleExchange() {
    if (_selectedPackage == null) return;
    
    final wallet = context.read<WalletProvider>();
    if (wallet.diamonds < 40000) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Minimum 40,000 Diamonds required.')));
      return;
    }

    if (wallet.diamonds < _selectedPackage!.diamonds) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Insufficient diamonds for this package.')));
      return;
    }

    showDialog(
      context: context,
      builder: (c) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: AppColors.getCard(isDark),
          title: Text('Confirm Exchange', style: TextStyle(color: AppColors.getTextPrimary(isDark))),
          content: Text(
            'Exchange ${AppFormatters.formatNumber(_selectedPackage!.diamonds)} Diamonds for ${AppFormatters.formatNumber(_selectedPackage!.coins)} Gold Coins?',
            style: TextStyle(color: AppColors.getTextSecondary(isDark)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(c);
                _processExchange();
              },
              child: Text('Confirm', style: TextStyle(color: AppColors.getPrimary(isDark), fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _processExchange() async {
    if (_selectedPackage == null) return;
    final package = _selectedPackage!;
    final dia = package.diamonds;
    final coins = package.coins;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => Center(child: CircularProgressIndicator(color: AppColors.getPrimary(Theme.of(context).brightness == Brightness.dark))),
    );

    await Future.delayed(const Duration(milliseconds: 600)); // Smooth transition

    if (!mounted) return;

    final wallet = context.read<WalletProvider>();
    final success = wallet.exchangeDiamondsToCoins(dia, coins);

    Navigator.pop(context); // loading

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✨ Successfully exchanged ${AppFormatters.formatNumber(dia)} Diamonds for ${AppFormatters.formatNumber(coins)} Gold Coins!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context); // close screen
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Insufficient diamonds for exchange.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

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
        iconTheme: IconThemeData(color: AppColors.getTextPrimary(isDark)),
        actions: [
          IconButton(icon: Icon(Icons.refresh, color: AppColors.getTextPrimary(isDark)), onPressed: () {})
        ],
      ),
      body: Column(
        children: [
          _buildBalanceCard(wallet.diamonds, isDark),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 2.2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: _packages.length,
              itemBuilder: (context, index) {
                return _buildPackageCard(_packages[index], isDark);
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 50.h,
                child: ElevatedButton(
                  onPressed: _selectedPackage == null ? null : _handleExchange,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.getTextPrimary(isDark),
                    foregroundColor: AppColors.getBackground(isDark),
                    disabledBackgroundColor: Colors.grey.shade800,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25.r)),
                  ),
                  child: Text('Submit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp)),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildBalanceCard(int balance, bool isDark) {
    return Container(
      margin: const EdgeInsets.all(16),
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.getCard(isDark),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('My Balance', style: TextStyle(color: AppColors.getTextSecondary(isDark), fontSize: 14)),
              Text('Details >', style: TextStyle(color: AppColors.getTextSecondary(isDark), fontSize: 12)),
            ],
          ),
          const SizedBox(height: 16),
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

  Widget _buildPackageCard(DiamondPackage pkg, bool isDark) {
    final bool isSelected = _selectedPackage == pkg;

    return GestureDetector(
      onTap: () => setState(() => _selectedPackage = pkg),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? AppColors.getPrimary(isDark).withValues(alpha: 0.2) : AppColors.getCard(isDark),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.getPrimary(isDark) : (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05)),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('💎', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 4),
                Text(
                  AppFormatters.formatNumber(pkg.diamonds),
                  style: TextStyle(color: AppColors.getTextPrimary(isDark), fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.monetization_on, color: Colors.orange, size: 12),
                const SizedBox(width: 4),
                Text(
                  AppFormatters.formatNumber(pkg.coins),
                  style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
