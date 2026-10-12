import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../providers/wallet_provider.dart';
import '../../../../providers/mystery_provider.dart';
import '../../../../models/mystery_suit_model.dart';
import '../../wallet/wallet_screen.dart';

class MysteryScreen extends StatelessWidget {
  const MysteryScreen({super.key});

  void _showInsufficientCoinsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF1A0A33),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.r),
          side: BorderSide(color: const Color(0xFFAB47BC).withValues(alpha: 0.5)),
        ),
        title: const Row(
          children: [
            Icon(Icons.monetization_on_rounded, color: Color(0xFFFFD54F), size: 24),
            SizedBox(width: 8),
            Text('Insufficient Coins', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'You need 800,000 coins to unlock the 30-day Mystery Suit privileges. Please recharge your wallet.',
          style: TextStyle(color: Color(0xFFD6C8E8), fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFD54F),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletScreen()));
            },
            child: const Text('Recharge Now', style: TextStyle(fontWeight: FontWeight.bold)),
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
      builder: (c) => const Center(
        child: CircularProgressIndicator(color: Color(0xFFD500F9)),
      ),
    );

    final success = await mystery.purchaseMysterySuit(wallet);
    if (context.mounted) Navigator.pop(context);

    if (success && context.mounted) {
      showDialog(
        context: context,
        builder: (c) => AlertDialog(
          backgroundColor: const Color(0xFF1B0B33),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: const BorderSide(color: Color(0xFFFFD54F), width: 1.4),
          ),
          title: const Center(
            child: Text('🎉 Mystery Suit Activated!', style: TextStyle(color: Color(0xFFFFD54F), fontWeight: FontWeight.w900)),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/animations/mystery_badge.webp', width: 90, height: 90, fit: BoxFit.contain),
              const SizedBox(height: 12),
              const Text(
                'Your Phantom Hypercar arrival, dynamic avatar frame, mystic medal and custom chat bubble are now unlocked for 30 days!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFFE1D3F8), fontSize: 13, height: 1.4),
              ),
            ],
          ),
          actions: [
            Center(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD54F),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                ),
                onPressed: () => Navigator.pop(c),
                child: const Text('Awesome!', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      );
    }
  }

  void _previewPrivilege(BuildContext context, String title, String assetPath, String description) {
    showDialog(
      context: context,
      builder: (c) => Dialog(
        backgroundColor: const Color(0xFF1A0A33),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22.r),
          side: BorderSide(color: const Color(0xFFAB47BC).withValues(alpha: 0.6), width: 1.2),
        ),
        child: Padding(
          padding: EdgeInsets.all(20.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(color: const Color(0xFFFFD54F), fontSize: 18.sp, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16.h),
              Container(
                height: 140.h,
                width: double.infinity,
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  gradient: const RadialGradient(
                    colors: [Color(0xFF331362), Color(0xFF120524)],
                    radius: 0.85,
                  ),
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(color: const Color(0xFF9C27B0).withValues(alpha: 0.4)),
                ),
                child: Center(
                  child: Image.asset(
                    assetPath,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(Icons.stars_rounded, size: 64, color: Color(0xFFFFD54F)),
                  ),
                ),
              ),
              SizedBox(height: 14.h),
              Text(
                description,
                textAlign: TextAlign.center,
                style: TextStyle(color: const Color(0xFFD6C8E8), fontSize: 12.5.sp, height: 1.45),
              ),
              SizedBox(height: 18.h),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD54F),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
                  padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 8.h),
                ),
                onPressed: () => Navigator.pop(c),
                child: const Text('Close Preview', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletProvider>();
    final mystery = context.watch<MysteryProvider>();
    final pkg = mystery.currentPackage;

    return Scaffold(
      backgroundColor: const Color(0xFF0C0517),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Mystery Suit',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 18.sp,
            letterSpacing: 0.6,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20.sp),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long_rounded, color: Colors.white),
            tooltip: 'Privilege Info',
            onPressed: () {
              showModalBottomSheet(
                context: context,
                backgroundColor: const Color(0xFF180A30),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
                  side: BorderSide(color: const Color(0xFFAB47BC).withValues(alpha: 0.4)),
                ),
                builder: (_) => Padding(
                  padding: EdgeInsets.all(22.w),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.verified_rounded, color: Color(0xFFFFD54F), size: 22),
                          const SizedBox(width: 8),
                          Text('Mystery Suit Status', style: TextStyle(color: Colors.white, fontSize: 17.sp, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        mystery.isActive
                            ? 'Status: Active\nDuration remaining: ${mystery.expiryDate != null ? mystery.expiryDate!.difference(DateTime.now()).inDays : 0} days'
                            : 'Status: Inactive\nPrice: 800,000 Coins / 30 Days\nFree 7-Day trial available for Duke aristocracy and above.',
                        style: const TextStyle(color: Color(0xFFD6C8E8), fontSize: 13, height: 1.5),
                      ),
                      const SizedBox(height: 18),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0C0517),
              Color(0xFF16092B),
              Color(0xFF0A0314),
            ],
          ),
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.only(bottom: 24.h),
          child: Column(
            children: [
              _buildIntroBanner(context),
              SizedBox(height: 22.h),
              _buildPrivilegeTitle(),
              SizedBox(height: 16.h),
              _buildPrivilegeGrid(context),
              SizedBox(height: 22.h),
              _buildDukeFreeTrialPill(context),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomBar(context, mystery, wallet, pkg),
    );
  }

  Widget _buildIntroBanner(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      constraints: BoxConstraints(minHeight: 146.h),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22.r),
        gradient: const LinearGradient(
          colors: [Color(0xFF261048), Color(0xFF130726)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: const Color(0xFFAB47BC).withValues(alpha: 0.4), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7B1FA2).withValues(alpha: 0.28),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Glowing Animated Mystery Mascot on the right
          Positioned(
            right: 10.w,
            bottom: 6.h,
            top: 6.h,
            child: Image.asset(
              'assets/animations/mystery_badge.webp',
              width: 120.w,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Image.asset(
                'assets/animations/mystery-suit_badge.webp',
                width: 120.w,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const SizedBox(),
              ),
            ),
          ),

          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'MYSTERY\nINTRODUCTION',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22.sp,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    height: 1.22,
                    shadows: [
                      Shadow(
                        color: const Color(0xFFD500F9).withValues(alpha: 0.6),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 14.h),
                InkWell(
                  onTap: () => _previewPrivilege(
                    context,
                    'Phantom Hypercar Entrance',
                    'assets/animations/mystery_entry.webp',
                    'Cinematic arrival vortex with supersonic sound effects, purple lightning bursts, and golden neon tire tracks across the room.',
                  ),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 6.h),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFCC80),
                      borderRadius: BorderRadius.circular(20.r),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFCC80).withValues(alpha: 0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.play_arrow_rounded, color: Color(0xFFE65100), size: 19),
                        SizedBox(width: 4.w),
                        Text(
                          'Play',
                          style: TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.w900,
                            fontSize: 13.5.sp,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivilegeTitle() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 42.w,
          height: 1.2,
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Colors.transparent, Color(0xFFFFD54F)]),
          ),
        ),
        Container(
          margin: EdgeInsets.symmetric(horizontal: 12.w),
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 8.h),
          decoration: BoxDecoration(
            color: const Color(0xFF1B0B33),
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(color: const Color(0xFFFFD54F).withValues(alpha: 0.45), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7B1FA2).withValues(alpha: 0.2),
                blurRadius: 10,
              ),
            ],
          ),
          child: Text(
            'Privilege Details',
            style: TextStyle(
              color: const Color(0xFFFFF7E6),
              fontWeight: FontWeight.bold,
              fontSize: 14.5.sp,
              letterSpacing: 0.3,
            ),
          ),
        ),
        Container(
          width: 42.w,
          height: 1.2,
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xFFFFD54F), Colors.transparent]),
          ),
        ),
      ],
    );
  }

  Widget _buildPrivilegeGrid(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Column(
        children: [
          // Card 1: Exclusive Entrance Effect (Wide Card)
          _buildLargePrivilegeCard(
            title: 'Exclusive Entrance Effect',
            subtitle: 'Phantom Hypercar special entry effect',
            imagePath: 'assets/animations/mystery_entry.webp',
            onTap: () => _previewPrivilege(
              context,
              'Exclusive Entrance Effect',
              'assets/animations/mystery_entry.webp',
              'Grand arrival animation with purple starlight vortex and Phantom Hypercar splash across any party room.',
            ),
          ),
          SizedBox(height: 12.h),

          // Cards 2 & 3: Dynamic Avatar & Mystic Medal (Two in a Row)
          Row(
            children: [
              Expanded(
                child: _buildSquarePrivilegeCard(
                  title: 'Exclusive Dynamic\nAvatar',
                  imagePath: 'assets/animations/mystery_frame.webp',
                  onTap: () => _previewPrivilege(
                    context,
                    'Exclusive Dynamic Avatar Frame',
                    'assets/animations/mystery_frame.webp',
                    'Pulsing cosmic purple and gold crown aura frame around your avatar in rooms and profiles.',
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: _buildSquarePrivilegeCard(
                  title: 'Mystic\nMedal',
                  imagePath: 'assets/animations/mystery_medal.webp',
                  onTap: () => _previewPrivilege(
                    context,
                    'Mystic Medal of Honor',
                    'assets/animations/mystery_medal.webp',
                    'Glowing neon-violet high-status identity medal in chat rooms, leaderboards, and user profiles.',
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),

          // Card 4: Chat Bubble (Wide Card)
          _buildLargePrivilegeCard(
            title: 'Chat Bubble',
            subtitle: 'Stand out with exclusive mystery messages',
            imagePath: 'assets/animations/mystery_bubble.webp',
            onTap: () => _previewPrivilege(
              context,
              'Mystery Gilded Chat Bubble',
              'assets/animations/mystery_bubble.webp',
              'Majestic royal-purple speech bubble with golden crystal wings and luminous typography on every message.',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLargePrivilegeCard({
    required String title,
    required String subtitle,
    required String imagePath,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.r),
      child: Container(
        constraints: BoxConstraints(minHeight: 96.h),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16.r),
          gradient: const LinearGradient(
            colors: [Color(0xFF220D42), Color(0xFF140628)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: const Color(0xFFAB47BC).withValues(alpha: 0.32), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7B1FA2).withValues(alpha: 0.16),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: const Color(0xFFFFD54F),
                      fontWeight: FontWeight.bold,
                      fontSize: 15.sp,
                      letterSpacing: 0.2,
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: const Color(0xFFCEBFDF),
                      fontSize: 12.sp,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 12.w),
            Image.asset(
              imagePath,
              width: 80.w,
              height: 56.h,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(Icons.stars_rounded, color: Color(0xFFFFD54F), size: 44),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSquarePrivilegeCard({
    required String title,
    required String imagePath,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.r),
      child: Container(
        height: 118.h,
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16.r),
          gradient: const LinearGradient(
            colors: [Color(0xFF220D42), Color(0xFF140628)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: const Color(0xFFAB47BC).withValues(alpha: 0.32), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7B1FA2).withValues(alpha: 0.16),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                title,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13.sp,
                  height: 1.25,
                ),
              ),
            ),
            SizedBox(width: 8.w),
            Image.asset(
              imagePath,
              width: 52.w,
              height: 52.h,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(Icons.stars_rounded, color: Color(0xFFFFD54F), size: 36),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDukeFreeTrialPill(BuildContext context) {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('👑 Duke aristocracy accounts automatically receive 7 days Mystery Suit free trial upon level upgrade!'),
            backgroundColor: Color(0xFF7B1FA2),
          ),
        );
      },
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20.w),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Dukes and above can enjoy 7 days for free',
              style: TextStyle(
                color: const Color(0xFFFFE082),
                fontWeight: FontWeight.bold,
                fontSize: 13.sp,
                letterSpacing: 0.2,
              ),
            ),
            SizedBox(width: 4.w),
            Icon(Icons.chevron_right_rounded, color: const Color(0xFFFFE082), size: 18.sp),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context, MysteryProvider mystery, WalletProvider wallet, MysterySuitModel pkg) {
    final isAlreadyActive = mystery.isActive;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: const Color(0xFF0C0517),
        border: Border(top: BorderSide(color: const Color(0xFFAB47BC).withValues(alpha: 0.25))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 14,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 52.h,
          child: ElevatedButton(
            onPressed: () => _handlePurchase(context, mystery, wallet),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFD54F),
              foregroundColor: Colors.black,
              elevation: 4,
              shadowColor: const Color(0xFFFFD54F).withValues(alpha: 0.4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26.r)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  isAlreadyActive ? 'Extend (' : 'Buy(',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16.sp, color: Colors.black87),
                ),
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFFFA000)),
                  child: const Icon(Icons.monetization_on_rounded, color: Colors.white, size: 16),
                ),
                SizedBox(width: 5.w),
                Text(
                  '${pkg.price}/${pkg.durationDays}day)',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16.sp, color: Colors.black87),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
