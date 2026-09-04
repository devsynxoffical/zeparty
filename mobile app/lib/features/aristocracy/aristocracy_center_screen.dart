import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../providers/noble_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../models/noble_model.dart';
import '../../widgets/design/gold_button.dart';
import '../wallet/wallet_screen.dart';

class AristocracyCenterScreen extends StatefulWidget {
  const AristocracyCenterScreen({super.key});

  @override
  State<AristocracyCenterScreen> createState() => _AristocracyCenterScreenState();
}

class _AristocracyCenterScreenState extends State<AristocracyCenterScreen> {
  late PageController _pageController;
  int _currentPageIndex = 4; // Default to Duke or active rank

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.38, initialPage: _currentPageIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final noble = context.read<NobleProvider>();
      noble.fetchNobleData();
      final activeIndex = noble.ranks.indexWhere((r) => r.id == noble.activeRankId);
      if (activeIndex != -1 && mounted) {
        setState(() => _currentPageIndex = activeIndex);
        _pageController.jumpToPage(activeIndex);
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _handleActivate(NobleRank rank) async {
    final wallet = context.read<WalletProvider>();
    if (wallet.coins < rank.firstMonthCost) {
      _showInsufficientCoinsDialog();
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => Center(child: CircularProgressIndicator(color: AppColors.getPrimary(Theme.of(context).brightness == Brightness.dark))),
    );

    final success = await context.read<NobleProvider>().activateRank(rank, wallet);
    if (mounted) Navigator.pop(context);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🎉 Successfully activated ${rank.name} Aristocracy! Rebate awarded: +${AppFormatters.formatNumber(rank.returnedCoins)} coins'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  void _handleSend(NobleRank rank) {
    showDialog(
      context: context,
      builder: (ctx) {
        final idController = TextEditingController();
        return AlertDialog(
          backgroundColor: AppColors.getCard(Theme.of(context).brightness == Brightness.dark),
          title: Text('Send ${rank.name} Aristocracy Gift'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Gift ${rank.name} rank to a friend or favorite creator.'),
              const SizedBox(height: 12),
              TextField(
                controller: idController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Recipient User ID',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('🎉 ${rank.name} gift dispatched to user ${idController.text.trim()}!'),
                    backgroundColor: AppColors.success,
                  ),
                );
              },
              child: const Text('Send Gift', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _showInsufficientCoinsDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: AppColors.getCard(isDark),
        title: Text('Insufficient Coins', style: TextStyle(color: AppColors.getTextPrimary(isDark))),
        content: Text('You do not have enough coins to activate this rank.', style: TextStyle(color: AppColors.getTextSecondary(isDark))),
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

  @override
  Widget build(BuildContext context) {
    final noble = context.watch<NobleProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (noble.isLoading || noble.ranks.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.getBackground(isDark),
        body: Center(child: CircularProgressIndicator(color: AppColors.getPrimary(isDark))),
      );
    }

    final currentRank = noble.ranks[_currentPageIndex.clamp(0, noble.ranks.length - 1)];
    final isActive = noble.activeRankId == currentRank.id;

    return Scaffold(
      backgroundColor: AppColors.getBackground(isDark),
      appBar: AppBar(
        backgroundColor: AppColors.getBackground(isDark),
        elevation: 0,
        title: Text(
          'Aristocracy',
          style: TextStyle(color: AppColors.getTextPrimary(isDark), fontWeight: FontWeight.bold, fontSize: 18.sp),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  SizedBox(height: 12.h),
                  _buildTopCard(currentRank, noble, isDark),
                  SizedBox(height: 18.h),
                  _buildRankSelector(noble, isDark),
                  SizedBox(height: 16.h),
                  _buildSentCoinRequirementCard(currentRank, noble, isDark),
                  SizedBox(height: 20.h),
                  _buildPrivilegeCategory('Display & Visual Privileges', currentRank.privileges.where((p) => p.category == 'display').toList(), isDark),
                  SizedBox(height: 16.h),
                  if (currentRank.privileges.any((p) => p.category == 'mic')) ...[
                    _buildPrivilegeCategory('Microphone & Stage Halo', currentRank.privileges.where((p) => p.category == 'mic').toList(), isDark),
                    SizedBox(height: 16.h),
                  ],
                  _buildPrivilegeCategory('Functional Privileges', currentRank.privileges.where((p) => p.category == 'functional').toList(), isDark),
                  SizedBox(height: 24.h),
                ],
              ),
            ),
          ),
          _buildBottomPurchaseBar(currentRank, isActive, isDark),
        ],
      ),
    );
  }

  Widget _buildTopCard(NobleRank rank, NobleProvider noble, bool isDark) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: rank.colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22.r),
        boxShadow: [
          BoxShadow(
            color: rank.colors.first.withValues(alpha: 0.4),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      rank.name,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26.sp,
                        fontWeight: FontWeight.w900,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    if (noble.activeRankId == rank.id) ...[
                      SizedBox(width: 8.w),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                        decoration: BoxDecoration(
                          color: Colors.greenAccent.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(6.r),
                          border: Border.all(color: Colors.greenAccent, width: 0.8),
                        ),
                        child: Text('ACTIVE ✓', style: TextStyle(color: Colors.white, fontSize: 9.sp, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: 6.h),
                Text(
                  'Activation: ${AppFormatters.formatNumber(rank.firstMonthCost)} coins • ${rank.durationDays} Days',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12.sp),
                ),
                SizedBox(height: 4.h),
                Text(
                  'Rebate: ${rank.returnPercentage}% Return (${AppFormatters.formatNumber(rank.returnedCoins)} coins)',
                  style: TextStyle(color: const Color(0xFFFFE082), fontSize: 11.sp, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.all(14.w),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Text('👑', style: TextStyle(fontSize: 34)),
          ),
        ],
      ),
    );
  }

  Widget _buildRankSelector(NobleProvider noble, bool isDark) {
    return SizedBox(
      height: 70.h,
      child: PageView.builder(
        controller: _pageController,
        itemCount: noble.ranks.length,
        onPageChanged: (idx) => setState(() => _currentPageIndex = idx),
        itemBuilder: (context, index) {
          final rank = noble.ranks[index];
          final isSelected = index == _currentPageIndex;
          return GestureDetector(
            onTap: () {
              _pageController.animateToPage(index, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: EdgeInsets.symmetric(horizontal: 6.w, vertical: isSelected ? 4.h : 10.h),
              decoration: BoxDecoration(
                gradient: isSelected
                    ? LinearGradient(colors: rank.colors)
                    : null,
                color: isSelected ? null : AppColors.getCard(isDark),
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(
                  color: isSelected ? Colors.amber : AppColors.getBorder(isDark),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Center(
                child: Text(
                  rank.name,
                  style: TextStyle(
                    color: isSelected ? Colors.white : AppColors.getTextPrimary(isDark),
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: isSelected ? 14.sp : 12.sp,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSentCoinRequirementCard(NobleRank rank, NobleProvider noble, bool isDark) {
    final progress = (noble.eligibleSentCoins / rank.requiredSentCoins).clamp(0.0, 1.0);
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.getCard(isDark),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.getBorder(isDark)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Sent-Coin Threshold Qualification',
                style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(isDark)),
              ),
              Text(
                '${AppFormatters.formatNumber(noble.eligibleSentCoins)} / ${AppFormatters.formatNumber(rank.requiredSentCoins)}',
                style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.bold, color: AppColors.getPrimary(isDark)),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(4.r),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6.h,
              backgroundColor: AppColors.getBorder(isDark),
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.getPrimary(isDark)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivilegeCategory(String title, List<NoblePrivilege> privs, bool isDark) {
    if (privs.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 13.5.sp, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(isDark)),
          ),
          SizedBox(height: 10.h),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: privs.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 10.w,
              mainAxisSpacing: 10.h,
              childAspectRatio: 0.95,
            ),
            itemBuilder: (context, index) {
              final p = privs[index];
              return Container(
                padding: EdgeInsets.all(10.w),
                decoration: BoxDecoration(
                  color: AppColors.getCard(isDark),
                  borderRadius: BorderRadius.circular(14.r),
                  border: Border.all(color: AppColors.getBorder(isDark)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(p.icon, color: Colors.orangeAccent, size: 26.sp),
                    SizedBox(height: 8.h),
                    Text(
                      p.name,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.getTextPrimary(isDark),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBottomPurchaseBar(NobleRank rank, bool isActive, bool isDark) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.getCard(isDark),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 10, offset: const Offset(0, -3)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 13.h),
                  side: BorderSide(color: AppColors.getPrimary(isDark)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
                ),
                onPressed: () => _handleSend(rank),
                child: Text('Send Gift', style: TextStyle(color: AppColors.getPrimary(isDark), fontWeight: FontWeight.bold)),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              flex: 2,
              child: GoldButton(
                text: isActive ? 'Renew (${AppFormatters.formatNumber(rank.firstMonthCost)})' : 'Activate (${AppFormatters.formatNumber(rank.firstMonthCost)})',
                onPressed: () => _handleActivate(rank),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
