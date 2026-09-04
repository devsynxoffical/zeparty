import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../providers/wallet_provider.dart';
import '../../../../providers/mystery_provider.dart';
import '../../../../models/mystery_suit_model.dart';
import '../../wallet/wallet_screen.dart';

class MysteryScreen extends StatelessWidget {
  const MysteryScreen({super.key});

  void _showInsufficientCoinsDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: AppColors.getCard(isDark),
        title: Text('Insufficient Coins', style: TextStyle(color: AppColors.getTextPrimary(isDark))),
        content: Text('You do not have enough coins to purchase the Mystery Suit.', style: TextStyle(color: AppColors.getTextSecondary(isDark))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (c) => const WalletScreen()));
            },
            child: Text('Recharge', style: TextStyle(color: AppColors.getPrimary(isDark))),
          ),
        ],
      ),
    );
  }

  void _handlePurchase(BuildContext context, MysteryProvider mystery, WalletProvider wallet) async {
    final pkg = mystery.currentPackage;
    if (wallet.coins < pkg.price) {
      _showInsufficientCoinsDialog(context);
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(child: CircularProgressIndicator(color: Colors.deepPurpleAccent)),
    );

    final success = await mystery.purchaseMysterySuit(wallet);
    if (context.mounted) Navigator.pop(context); // pop loading

    if (success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Mystery Suit Activated!'), backgroundColor: AppColors.success),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final wallet = context.watch<WalletProvider>();
    final mystery = context.watch<MysteryProvider>();
    final pkg = mystery.currentPackage;

    return Scaffold(
      backgroundColor: AppColors.getBackground(isDark), // Use standard background
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Mystery Suit', style: TextStyle(color: AppColors.getTextPrimary(isDark), fontWeight: FontWeight.bold)),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.getTextPrimary(isDark), size: 20.sp),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.receipt_long, color: AppColors.getTextPrimary(isDark)),
            onPressed: () {
              // Open history
            },
          )
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 120),
            child: Column(
              children: [
                _buildIntroBanner(isDark),
                const SizedBox(height: 24),
                _buildPrivilegeTitle(isDark),
                const SizedBox(height: 16),
                _buildPrivilegeGrid(isDark),
                const SizedBox(height: 24),
                _buildDescriptionSection(pkg, isDark),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(context, mystery, wallet, pkg, isDark),
    );
  }

  Widget _buildIntroBanner(bool isDark) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      constraints: BoxConstraints(minHeight: 140.h),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24.r),
        color: AppColors.getCard(isDark),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: 0,
            bottom: 0,
            child: Opacity(
              opacity: 0.5,
              child: Image.asset('assets/images/mystery_hero.png', height: 140, errorBuilder: (c,e,s) => const SizedBox(width: 140)),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(20.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'MYSTERY\nINTRODUCTION',
                  style: TextStyle(
                    color: AppColors.getTextPrimary(isDark),
                    fontSize: 22.sp,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                SizedBox(height: 12.h),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.play_circle_fill, color: Colors.deepOrange, size: 16),
                      SizedBox(width: 6),
                      Text('Play', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivilegeTitle(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(width: 40.w, height: 1, decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.transparent, AppColors.getPrimary(isDark)]))),
        Container(
          margin: EdgeInsets.symmetric(horizontal: 12.w),
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 8.h),
          decoration: BoxDecoration(
            color: AppColors.getCard(isDark),
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(color: AppColors.getPrimary(isDark).withValues(alpha: 0.5)),
          ),
          child: Text('Privilege Details', style: TextStyle(color: AppColors.getTextPrimary(isDark), fontWeight: FontWeight.bold, fontSize: 16.sp)),
        ),
        Container(width: 40.w, height: 1, decoration: BoxDecoration(gradient: LinearGradient(colors: [AppColors.getPrimary(isDark), Colors.transparent]))),
      ],
    );
  }

  Widget _buildPrivilegeGrid(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          _buildLargePrivilegeCard('Exclusive Entrance Effect', 'Cool special effect entrance', 'assets/images/profile_mystery.jpg', isDark),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildSquarePrivilegeCard('Exclusive Dynamic\nAvatar', 'assets/images/profile_mystery.jpg', isDark)),
              const SizedBox(width: 12),
              Expanded(child: _buildSquarePrivilegeCard('Mystic\nMedal', 'assets/images/profile_mystery.jpg', isDark)),
            ],
          ),
          const SizedBox(height: 12),
          _buildLargePrivilegeCard('Chat Bubble', 'Stand out with chat messages', 'assets/images/profile_mystery.jpg', isDark),
        ],
      ),
    );
  }

  Widget _buildLargePrivilegeCard(String title, String subtitle, String imagePath, bool isDark) {
    return Container(
      height: 100.h,
      decoration: BoxDecoration(
        color: AppColors.getCard(isDark),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.1)),
      ),
      child: Stack(
        children: [
          Positioned(
            right: 0,
            bottom: -20.h,
            child: Opacity(
              opacity: 0.4,
              child: Image.asset(imagePath, width: 120.sp, height: 120.sp, fit: BoxFit.cover, errorBuilder: (c,e,s) => Icon(Icons.star, size: 80.sp, color: AppColors.getPrimary(isDark).withValues(alpha: 0.2))),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title, style: TextStyle(color: AppColors.getPrimary(isDark), fontWeight: FontWeight.bold, fontSize: 15.sp)),
                SizedBox(height: 4.h),
                Text(subtitle, style: TextStyle(color: AppColors.getTextSecondary(isDark), fontSize: 12.sp)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSquarePrivilegeCard(String title, String imagePath, bool isDark) {
    return Container(
      height: 110.h,
      decoration: BoxDecoration(
        color: AppColors.getCard(isDark),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.1)),
      ),
      child: Stack(
        children: [
          Positioned(
            right: 0,
            bottom: -15.h,
            child: Opacity(
              opacity: 0.4,
              child: Image.asset(imagePath, width: 80.sp, height: 80.sp, fit: BoxFit.cover, errorBuilder: (c,e,s) => Icon(Icons.star, size: 60.sp, color: AppColors.getPrimary(isDark).withValues(alpha: 0.2))),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(12.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: TextStyle(color: AppColors.getTextPrimary(isDark), fontWeight: FontWeight.bold, fontSize: 13.sp),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDescriptionSection(MysterySuitModel pkg, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.getCard(isDark),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Text('Description', style: TextStyle(color: AppColors.getTextPrimary(isDark), fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Text(pkg.description, style: TextStyle(color: AppColors.getTextSecondary(isDark), fontSize: 13, height: 1.5)),
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context, MysteryProvider mystery, WalletProvider wallet, MysterySuitModel pkg, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.getBackground(isDark),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, -5))],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Dukes and above can enjoy 7 days for free', style: TextStyle(color: AppColors.getTextPrimary(isDark), fontWeight: FontWeight.bold, fontSize: 13.sp)),
                SizedBox(width: 4.w),
                Icon(Icons.chevron_right, color: AppColors.getTextPrimary(isDark), size: 16.sp),
              ],
            ),
            SizedBox(height: 12.h),
            SizedBox(
              width: double.infinity,
              height: 50.h,
              child: ElevatedButton(
                onPressed: () => _handlePurchase(context, mystery, wallet),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.getPrimary(isDark),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25.r)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Buy(', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp)),
                    Icon(Icons.monetization_on, color: Colors.orange, size: 18.sp),
                    SizedBox(width: 4.w),
                    Text('${pkg.price}/${pkg.durationDays}day)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
