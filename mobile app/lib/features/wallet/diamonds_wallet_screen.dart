import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../providers/auth_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/wallet_details_provider.dart';
import 'wallet_details_screen.dart';

class DiamondsWalletScreen extends StatefulWidget {
  const DiamondsWalletScreen({super.key});

  @override
  State<DiamondsWalletScreen> createState() => _DiamondsWalletScreenState();
}

class _DiamondsWalletScreenState extends State<DiamondsWalletScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshAuthoritativeWallet();
    });
  }

  Future<void> _refreshAuthoritativeWallet() async {
    final auth = context.read<AuthProvider>();
    if (auth.currentUser.id.isNotEmpty) {
      await context.read<WalletProvider>().syncWithUser(auth.currentUser);
    } else {
      await context.read<WalletProvider>().fetchWallet();
    }
    if (mounted) {
      context.read<WalletDetailsProvider>().refreshData();
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
        title: Text(
          'Wallet',
          style: TextStyle(
            color: AppColors.getTextPrimary(isDark),
            fontWeight: FontWeight.bold,
            fontSize: 18.sp,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.getTextPrimary(isDark), size: 20.sp),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: AppColors.getTextPrimary(isDark)),
            tooltip: 'Refresh Balance',
            onPressed: () {
              _refreshAuthoritativeWallet();
            },
          )
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshAuthoritativeWallet,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              if (wallet.isLoading && wallet.wallet == null)
                _buildLoadingCard(isDark)
              else if (wallet.errorMessage != null && wallet.wallet == null)
                _buildErrorCard(context, wallet.errorMessage!, isDark)
              else
                _buildBalanceCard(context, wallet.diamonds, isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingCard(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.getCard(isDark),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: AppColors.getPrimary(isDark),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Verifying authoritative wallet balance...',
            style: TextStyle(
              color: AppColors.getTextSecondary(isDark),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(BuildContext context, String message, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.getCard(isDark),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.redAccent.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded, size: 36, color: Colors.redAccent),
          const SizedBox(height: 12),
          Text(
            'Unable to fetch diamond balance',
            style: TextStyle(
              color: AppColors.getTextPrimary(isDark),
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.getTextSecondary(isDark),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.getPrimary(isDark),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _refreshAuthoritativeWallet,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Retry'),
          ),
        ],
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
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('💎', style: TextStyle(fontSize: 34)),
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
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
