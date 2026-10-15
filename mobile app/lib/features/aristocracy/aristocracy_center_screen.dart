import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../providers/auth_provider.dart';
import '../../providers/noble_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../models/noble_model.dart';
import '../wallet/wallet_screen.dart';

class AristocracyCenterScreen extends StatefulWidget {
  const AristocracyCenterScreen({super.key});

  @override
  State<AristocracyCenterScreen> createState() => _AristocracyCenterScreenState();
}

class _AristocracyCenterScreenState extends State<AristocracyCenterScreen> {
  late PageController _cardPageController;
  int _selectedRankIndex = 3; // Default to Marquis (matches screenshot)

  final List<Map<String, dynamic>> _displayRanks = [
    {
      'id': 'baron',
      'name': 'Baron',
      'cost': 10000,
      'renewalCost': 10000,
      'rebatePercentage': 100,
      'duration': '30 days',
      'status': 'Not activated',
      'themeColors': [const Color(0xFF142236), const Color(0xFF1E3554), const Color(0xFF0D1726)],
      'cardGradient': [const Color(0xFF233B5D), const Color(0xFF15263F)],
      'badgeAsset': 'assets/nobles/baron_badge.webp',
      'frameAsset': 'assets/nobles/baron_frame.webp',
      'privileges': [
        {'name': 'Frame', 'asset': 'assets/nobles/baron_frame.webp', 'type': 'image'},
        {'name': 'Activate Effect', 'asset': 'assets/nobles/baron_badge.webp', 'type': 'image'},
        {'name': 'Identify Badge', 'asset': 'assets/nobles/baron_badge.webp', 'type': 'image'},
        {'name': 'Colored Username', 'color': const Color(0xFF29B6F6), 'type': 'colored_name'},
      ]
    },
    {
      'id': 'viscount',
      'name': 'Viscount',
      'cost': 50000,
      'renewalCost': 50000,
      'rebatePercentage': 100,
      'duration': '30 days',
      'status': 'Expired',
      'themeColors': [const Color(0xFF1B2A38), const Color(0xFF243B50), const Color(0xFF101B24)],
      'cardGradient': [const Color(0xFF2A4863), const Color(0xFF182D40)],
      'badgeAsset': 'assets/nobles/viscount_badge.webp',
      'frameAsset': 'assets/nobles/viscount_frame.webp',
      'privileges': [
        {'name': 'Profile Card', 'asset': 'assets/nobles/viscount_card.webp', 'type': 'image'},
        {'name': 'Frame', 'asset': 'assets/nobles/viscount_frame.webp', 'type': 'image'},
        {'name': 'Activate Effect', 'asset': 'assets/nobles/viscount_activate.webp', 'type': 'image'},
        {'name': 'Identify Badge', 'asset': 'assets/nobles/viscount_badge.webp', 'type': 'image'},
        {'name': 'Colored Username', 'color': const Color(0xFFFFA726), 'type': 'colored_name'},
      ]
    },
    {
      'id': 'count',
      'name': 'Count',
      'cost': 100000,
      'renewalCost': 100000,
      'rebatePercentage': 100,
      'duration': '30 days',
      'status': 'Not activated',
      'themeColors': [const Color(0xFF0F1E36), const Color(0xFF19325A), const Color(0xFF0A1324)],
      'cardGradient': [const Color(0xFF1F3D6E), const Color(0xFF112444)],
      'badgeAsset': 'assets/nobles/count_badge.webp',
      'frameAsset': 'assets/nobles/count_frame.webp',
      'privileges': [
        {'name': 'Profile Card', 'asset': 'assets/nobles/count_card.webp', 'type': 'image'},
        {'name': 'Frame', 'asset': 'assets/nobles/count_frame.webp', 'type': 'image'},
        {'name': 'Activate Effect', 'asset': 'assets/nobles/count_activate.webp', 'type': 'image'},
        {'name': 'Identify Badge', 'asset': 'assets/nobles/count_badge.webp', 'type': 'image'},
        {'name': 'Colored Username', 'color': const Color(0xFF42A5F5), 'type': 'colored_name'},
        {'name': 'Bubble', 'asset': 'assets/nobles/count_chat_bubble.webp', 'type': 'image'},
      ]
    },
    {
      'id': 'marquis',
      'name': 'Marquis',
      'cost': 300000,
      'renewalCost': 180000,
      'rebatePercentage': 100,
      'duration': '30 days',
      'status': 'Experience until 2026.10.08',
      'hasDiscount': true,
      'discountText': '60% off',
      'themeColors': [const Color(0xFF2C0710), const Color(0xFF4A0C1C), const Color(0xFF180309)],
      'cardGradient': [const Color(0xFF8A1E34), const Color(0xFF5A1021)],
      'badgeAsset': 'assets/nobles/marquis_badge.webp',
      'frameAsset': 'assets/nobles/marquis_frame.webp',
      'privileges': [
        {'name': 'Entrance Effect', 'asset': 'assets/nobles/marquis_entrance.webp', 'type': 'image'},
        {'name': 'Profile Card', 'asset': 'assets/nobles/tier-4-marquis_profilecard.webp', 'type': 'image'},
        {'name': 'Frame', 'asset': 'assets/nobles/marquis_frame.webp', 'type': 'image'},
        {'name': 'Activate Effect', 'asset': 'assets/nobles/marquis_activate.webp', 'type': 'image'},
        {'name': 'Identify Badge', 'asset': 'assets/nobles/marquis_badge.webp', 'type': 'image'},
        {'name': 'Colored Username', 'color': const Color(0xFFEF5350), 'type': 'colored_name'},
        {'name': 'Bubble', 'asset': 'assets/nobles/marquis_chat_bubble.webp', 'type': 'image'},
        {'name': 'World Notif', 'asset': 'assets/nobles/tier-4-marquis_worldnotif.webp', 'type': 'image'},
      ]
    },
    {
      'id': 'duke',
      'name': 'Duke',
      'cost': 800000,
      'renewalCost': 640000,
      'rebatePercentage': 80,
      'duration': '30 days',
      'status': 'Expired',
      'themeColors': [const Color(0xFF230836), const Color(0xFF3B1059), const Color(0xFF13041E)],
      'cardGradient': [const Color(0xFF5C1B8A), const Color(0xFF380E56)],
      'badgeAsset': 'assets/nobles/duke_badge.webp',
      'frameAsset': 'assets/nobles/duke_frame.webp',
      'privileges': [
        {'name': 'Entrance Effect', 'asset': 'assets/nobles/duke_entrance.webp', 'type': 'image'},
        {'name': 'Profile Card', 'asset': 'assets/nobles/tier-5-duke_profilecard.webp', 'type': 'image'},
        {'name': 'Frame', 'asset': 'assets/nobles/duke_frame.webp', 'type': 'image'},
        {'name': 'Activate Effect', 'asset': 'assets/nobles/duke_activate.webp', 'type': 'image'},
        {'name': 'Identify Badge', 'asset': 'assets/nobles/duke_badge.webp', 'type': 'image'},
        {'name': 'Colored Username', 'color': const Color(0xFFAB47BC), 'type': 'colored_name'},
        {'name': 'Bubble', 'asset': 'assets/nobles/duke_chat_bubble.webp', 'type': 'image'},
        {'name': 'Mic Wave', 'asset': 'assets/nobles/duke_mic.webp', 'type': 'image'},
        {'name': 'World Notif', 'asset': 'assets/nobles/tier-5-duke_worldnotif.webp', 'type': 'image'},
      ]
    },
    {
      'id': 'king',
      'name': 'King',
      'cost': 1500000,
      'renewalCost': 1200000,
      'rebatePercentage': 80,
      'duration': '30 days',
      'status': 'Expired',
      'themeColors': [const Color(0xFF2E1C0C), const Color(0xFF4A3015), const Color(0xFF1A0F06)],
      'cardGradient': [const Color(0xFF7C5428), const Color(0xFF4D3216)],
      'badgeAsset': 'assets/nobles/king_badge.webp',
      'frameAsset': 'assets/nobles/king_frame.webp',
      'privileges': [
        {'name': 'Entrance Effect', 'asset': 'assets/nobles/emperor_entrance.webp', 'type': 'image'},
        {'name': 'Profile Card', 'asset': 'assets/nobles/king_card.webp', 'type': 'image'},
        {'name': 'Frame', 'asset': 'assets/nobles/king_frame.webp', 'type': 'image'},
        {'name': 'Activate Effect', 'asset': 'assets/nobles/king_badge.webp', 'type': 'image'},
        {'name': 'Identify Badge', 'asset': 'assets/nobles/king_badge.webp', 'type': 'image'},
        {'name': 'Colored Username', 'color': const Color(0xFFFFD54F), 'type': 'colored_name'},
        {'name': 'Bubble', 'asset': 'assets/nobles/emperor_chat_bubble.webp', 'type': 'image'},
        {'name': 'Mic Wave', 'asset': 'assets/nobles/king_mic.webp', 'type': 'image'},
        {'name': 'World Notif', 'asset': 'assets/nobles/tier-6-king_worldnotif.webp', 'type': 'image'},
      ]
    },
    {
      'id': 'emperor',
      'name': 'Emperor',
      'cost': 3000000,
      'renewalCost': 2400000,
      'rebatePercentage': 80,
      'duration': '30 days',
      'status': 'Not activated',
      'themeColors': [const Color(0xFF261D09), const Color(0xFF423311), const Color(0xFF161004)],
      'cardGradient': [const Color(0xFF755B1B), const Color(0xFF47360E)],
      'badgeAsset': 'assets/nobles/emperor_badge.webp',
      'frameAsset': 'assets/nobles/emperor_frame.webp',
      'privileges': [
        {'name': 'Entrance Effect', 'asset': 'assets/nobles/emperor_entrance.webp', 'type': 'image'},
        {'name': 'Profile Card', 'asset': 'assets/nobles/tier-7-emperor_profilecard.webp', 'type': 'image'},
        {'name': 'Frame', 'asset': 'assets/nobles/emperor_frame.webp', 'type': 'image'},
        {'name': 'Activate Effect', 'asset': 'assets/nobles/emperor_activate.webp', 'type': 'image'},
        {'name': 'Identify Badge', 'asset': 'assets/nobles/emperor_badge.webp', 'type': 'image'},
        {'name': 'Colored Username', 'color': const Color(0xFFFFE082), 'type': 'colored_name'},
        {'name': 'Bubble', 'asset': 'assets/nobles/emperor_chat_bubble.webp', 'type': 'image'},
        {'name': 'Mic Wave', 'asset': 'assets/nobles/emperor_mic.webp', 'type': 'image'},
        {'name': 'World Notif', 'asset': 'assets/nobles/tier-7-emperor_worldnotif.webp', 'type': 'image'},
      ]
    },
    {
      'id': 'sovereign',
      'name': 'Sovereign',
      'cost': 0,
      'renewalCost': 0,
      'isLocked': true,
      'status': 'Not activated',
      'themeColors': [const Color(0xFF0F1221), const Color(0xFF171D36), const Color(0xFF090B14)],
      'cardGradient': [const Color(0xFF202747), const Color(0xFF12162B)],
      'badgeAsset': null,
      'frameAsset': null,
      'privileges': []
    }
  ];

  @override
  void initState() {
    super.initState();
    _cardPageController = PageController(viewportFraction: 0.84, initialPage: _selectedRankIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final noble = context.read<NobleProvider>();
      noble.fetchNobleData();
      final activeIndex = _displayRanks.indexWhere((r) => r['id'] == noble.activeRankId);
      if (activeIndex != -1 && mounted) {
        setState(() => _selectedRankIndex = activeIndex);
        if (_cardPageController.hasClients) {
          _cardPageController.jumpToPage(activeIndex);
        }
      }
    });
  }

  @override
  void dispose() {
    _cardPageController.dispose();
    super.dispose();
  }

  void _onRankSelected(int index) {
    if (index < 0 || index >= _displayRanks.length) return;
    setState(() => _selectedRankIndex = index);
    _cardPageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  void _handleActivate(Map<String, dynamic> rankData) async {
    if (rankData['isLocked'] == true) return;
    final wallet = context.read<WalletProvider>();
    final cost = rankData['renewalCost'] as int;

    if (wallet.coins < cost) {
      _showInsufficientCoinsDialog();
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(child: CircularProgressIndicator(color: Color(0xFFFFD700))),
    );

    final rank = NobleRank(
      id: rankData['id'],
      name: rankData['name'],
      requiredSentCoins: cost * 2,
      firstMonthCost: cost,
      returnPercentage: rankData['rebatePercentage'] ?? 80,
      durationDays: 30,
      colors: rankData['cardGradient'],
      badgeAsset: rankData['badgeAsset'] ?? '',
      privileges: [],
    );

    final success = await context.read<NobleProvider>().activateRank(rank, wallet);
    if (mounted) Navigator.pop(context);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🎉 Successfully activated ${rankData['name']} Aristocracy!'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  void _handleSend(Map<String, dynamic> rankData) {
    if (rankData['isLocked'] == true) return;
    final idController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2C0710),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
          title: Text(
            'Send ${rankData['name']} Aristocracy',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Gift ${rankData['name']} status directly to another user.',
                style: TextStyle(color: Colors.white70, fontSize: 13.sp),
              ),
              SizedBox(height: 16.h),
              TextField(
                controller: idController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Recipient User ID',
                  labelStyle: const TextStyle(color: Colors.white60),
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.white30),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Color(0xFFFFD700)),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFD700),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('🎉 ${rankData['name']} gift sent to user ${idController.text.trim()}!'),
                    backgroundColor: AppColors.success,
                  ),
                );
              },
              child: const Text('Send', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _showInsufficientCoinsDialog() {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF2C0710),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
        title: const Text('Insufficient Coins', style: TextStyle(color: Colors.white)),
        content: const Text('You do not have enough coins to activate this rank.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (c) => const WalletScreen()));
            },
            child: const Text('Recharge', style: TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showAristocracyLeaderboardSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.72,
          decoration: BoxDecoration(
            color: const Color(0xFF161A2B),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
            border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              SizedBox(height: 12.h),
              Container(width: 40.w, height: 4.h, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2.r))),
              SizedBox(height: 14.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.emoji_events_rounded, color: Color(0xFFFFD700), size: 24),
                  SizedBox(width: 8.w),
                  Text('Aristocracy Honor Roll', style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.bold)),
                ],
              ),
              SizedBox(height: 16.h),
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  children: [
                    _buildHonorPlayerTile('1', 'Emperor Alex', 'Emperor', 'assets/nobles/emperor_badge.webp', 'assets/nobles/emperor_frame.webp', '12,500,000 coins', const Color(0xFFFFD700)),
                    _buildHonorPlayerTile('2', 'King Arthur', 'King', 'assets/nobles/king_badge.webp', 'assets/nobles/king_frame.webp', '8,200,000 coins', const Color(0xFFE0E0E0)),
                    _buildHonorPlayerTile('3', 'Duke Sterling', 'Duke', 'assets/nobles/duke_badge.webp', 'assets/nobles/duke_frame.webp', '5,100,000 coins', const Color(0xFFCD7F32)),
                    _buildHonorPlayerTile('4', 'Marquis Elena', 'Marquis', 'assets/nobles/marquis_badge.webp', 'assets/nobles/marquis_frame.webp', '3,400,000 coins', Colors.white54),
                    _buildHonorPlayerTile('5', 'Count Victor', 'Count', 'assets/nobles/count_badge.webp', 'assets/nobles/count_frame.webp', '1,800,000 coins', Colors.white54),
                    _buildHonorPlayerTile('6', 'Viscount Mia', 'Viscount', 'assets/nobles/viscount_badge.webp', 'assets/nobles/viscount_frame.webp', '950,000 coins', Colors.white54),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHonorPlayerTile(String rankNum, String name, String title, String badgeAsset, String frameAsset, String coins, Color rankColor) {
    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: const Color(0xFF20263C),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 24.w,
            child: Text(rankNum, style: TextStyle(color: rankColor, fontWeight: FontWeight.bold, fontSize: 16.sp)),
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              Container(width: 38.w, height: 38.h, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.black38), child: Center(child: Text(name[0], style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16.sp)))),
              Image.asset(frameAsset, width: 56.w, height: 56.h, fit: BoxFit.contain, errorBuilder: (c, e, s) => const SizedBox.shrink()),
            ],
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.bold)),
                Text(title, style: TextStyle(color: const Color(0xFFFFD700), fontSize: 11.sp, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          Image.asset(badgeAsset, width: 34.w, height: 34.h, fit: BoxFit.contain, errorBuilder: (c, e, s) => const Icon(Icons.shield, color: Color(0xFFFFD700))),
        ],
      ),
    );
  }

  void _showAristocracyMenuSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
          decoration: BoxDecoration(
            color: const Color(0xFF161A2B),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40.w, height: 4.h, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2.r))),
              SizedBox(height: 16.h),
              Text('Aristocracy Options', style: TextStyle(color: Colors.white, fontSize: 17.sp, fontWeight: FontWeight.bold)),
              SizedBox(height: 16.h),
              _buildMenuItem(Icons.rule_rounded, 'Aristocracy Rules & Rebate Policy', () {
                Navigator.pop(ctx);
                _showRulesDialog();
              }),
              _buildMenuItem(Icons.card_membership_rounded, 'My Aristocracy Privileges', () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Viewing active privileges summary')));
              }),
              _buildMenuItem(Icons.card_giftcard_rounded, 'Gift History', () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aristocracy gift history loaded')));
              }),
              _buildMenuItem(Icons.help_outline_rounded, 'Help & Support', () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Support ticket created for Aristocracy')));
              }),
              SizedBox(height: 12.h),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMenuItem(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFFFFD700), size: 22.sp),
      title: Text(title, style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white38, size: 14),
      onTap: onTap,
    );
  }

  void _showRulesDialog() {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF161A2B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
        title: const Text('📜 Aristocracy Rules', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('1. First Month Activation:', style: TextStyle(color: const Color(0xFFFFD700), fontWeight: FontWeight.bold, fontSize: 13.sp)),
              Text('Activating an Aristocracy tier grants 100% or 80% coin rebates back into your wallet instantly as an installment return.', style: TextStyle(color: Colors.white70, fontSize: 12.sp)),
              SizedBox(height: 10.h),
              Text('2. Monthly Renewal:', style: TextStyle(color: const Color(0xFFFFD700), fontWeight: FontWeight.bold, fontSize: 13.sp)),
              Text('Renewing active ranks grants exclusive discount rates (up to 60% off) and preserves all your visual and room privileges.', style: TextStyle(color: Colors.white70, fontSize: 12.sp)),
              SizedBox(height: 10.h),
              Text('3. Privileges Access:', style: TextStyle(color: const Color(0xFFFFD700), fontWeight: FontWeight.bold, fontSize: 13.sp)),
              Text('Entrance effects, animated profile cards, avatar frames, chat bubbles, mic halos, and colored usernames stay active during the 30-day period.', style: TextStyle(color: Colors.white70, fontSize: 12.sp)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Got it', style: TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authUser = context.watch<AuthProvider>().currentUser;
    final activeRankData = _displayRanks[_selectedRankIndex];
    final isLocked = activeRankData['isLocked'] == true;
    final themeColors = (activeRankData['themeColors'] as List<Color>);
    final noble = context.watch<NobleProvider>();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: themeColors,
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Aristocracy',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18.sp),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.emoji_events_rounded, color: Color(0xFFFFD700)),
              onPressed: _showAristocracyLeaderboardSheet,
            ),
            IconButton(
              icon: const Icon(Icons.more_horiz_rounded, color: Colors.white),
              onPressed: _showAristocracyMenuSheet,
            ),
          ],
        ),

        // TOP CARD CAROUSEL SLIDING (INDEPENDENT CAROUSEL AS REQUESTED BY USER)
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    SizedBox(height: 12.h),

                    // TOP CARD SWIPEABLE CAROUSEL
                    _buildTopCardCarousel(authUser),

                    SizedBox(height: 14.h),

                    // CURVED ARC SLIDER NAVIGATION
                    _buildCurvedArcRankSlider(),

                    SizedBox(height: 16.h),

                    // DISPLAY PRIVILEGES HEADER & GRID
                    _buildDisplayPrivilegesSection(activeRankData, isLocked, authUser),

                    SizedBox(height: 24.h),
                  ],
                ),
              ),
            ),

            // BOTTOM FIXED PURCHASE BAR
            _buildBottomBar(activeRankData, noble),
          ],
        ),
      ),
    );
  }

  Widget _buildTopCardCarousel(dynamic user) {
    return SizedBox(
      height: 235.h,
      child: PageView.builder(
        controller: _cardPageController,
        itemCount: _displayRanks.length,
        onPageChanged: (index) {
          setState(() => _selectedRankIndex = index);
        },
        itemBuilder: (context, index) {
          final rank = _displayRanks[index];
          final isSovereign = rank['id'] == 'sovereign';
          final cardGradients = (rank['cardGradient'] as List<Color>);

          return AnimatedBuilder(
            animation: _cardPageController,
            builder: (context, child) {
              double pageOffset = 0.0;
              if (_cardPageController.position.haveDimensions) {
                pageOffset = (_cardPageController.page ?? _selectedRankIndex.toDouble()) - index;
              } else {
                pageOffset = (_selectedRankIndex - index).toDouble();
              }

              final scale = (1.0 - (pageOffset.abs() * 0.12)).clamp(0.85, 1.0);
              final opacity = (1.0 - (pageOffset.abs() * 0.45)).clamp(0.5, 1.0);

              return Transform.scale(
                scale: scale,
                child: Opacity(
                  opacity: opacity,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.topCenter,
                    children: [
                      // MAIN BANNER CARD
                      Container(
                        margin: EdgeInsets.only(top: 32.h, left: 6.w, right: 6.w),
                        padding: EdgeInsets.fromLTRB(18.w, 38.h, 18.w, 14.h),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22.r),
                          gradient: LinearGradient(
                            colors: cardGradients,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: cardGradients.first.withValues(alpha: 0.5),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            ),
                          ],
                          border: Border.all(
                            color: const Color(0xFFFFD700).withValues(alpha: 0.7),
                            width: 1.5,
                          ),
                        ),
                        child: Stack(
                          children: [
                            if (isSovereign)
                              Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 60.w,
                                      height: 60.h,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white10,
                                      ),
                                      child: const Icon(Icons.help_outline_rounded, color: Colors.white54, size: 36),
                                    ),
                                    SizedBox(height: 8.h),
                                    Text(
                                      'Stay tuned',
                                      style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              )
                            else ...[
                              // LEFT SIDE COIN COSTS & REBATE
                              Positioned(
                                left: 4.w,
                                top: 6.h,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Image.asset(
                                          'assets/icons/ic_coin.png',
                                          width: 22.w,
                                          height: 22.h,
                                          errorBuilder: (c, e, s) => const Icon(Icons.monetization_on_rounded, color: Color(0xFFFFD700), size: 22),
                                        ),
                                        SizedBox(width: 6.w),
                                        Text(
                                          AppFormatters.formatNumber(rank['renewalCost']),
                                          style: TextStyle(
                                            color: const Color(0xFFFFD700),
                                            fontSize: 19.sp,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Padding(
                                      padding: EdgeInsets.only(left: 28.w),
                                      child: Text(
                                        'Renewal cost',
                                        style: TextStyle(color: Colors.white70, fontSize: 11.sp),
                                      ),
                                    ),
                                    SizedBox(height: 12.h),

                                    // INSTALLMENT RETURN ROW
                                    Row(
                                      children: [
                                        Image.asset(
                                          'assets/icons/ic_coin.png',
                                          width: 22.w,
                                          height: 22.h,
                                          errorBuilder: (c, e, s) => const Icon(Icons.monetization_on_rounded, color: Color(0xFFFFD700), size: 22),
                                        ),
                                        SizedBox(width: 6.w),
                                        Text(
                                          AppFormatters.formatNumber(rank['renewalCost']),
                                          style: TextStyle(
                                            color: const Color(0xFFFFD700),
                                            fontSize: 19.sp,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 3.h),
                                    Row(
                                      children: [
                                        Container(
                                          padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFF4081),
                                            borderRadius: BorderRadius.circular(10.r),
                                          ),
                                          child: Text(
                                            '${rank['rebatePercentage']}%',
                                            style: TextStyle(color: Colors.white, fontSize: 9.5.sp, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        SizedBox(width: 4.w),
                                        Text(
                                          'Installment return >',
                                          style: TextStyle(color: Colors.white, fontSize: 11.sp, fontWeight: FontWeight.w500),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              // RIGHT SIDE ANIMATED 3D SHIELD BADGE (PROMINENT LARGE SIZE: 118.w x 118.h)
                              Positioned(
                                right: 0,
                                top: 0,
                                child: Image.asset(
                                  rank['badgeAsset'],
                                  width: 118.w,
                                  height: 118.h,
                                  fit: BoxFit.contain,
                                  errorBuilder: (c, e, s) => const Icon(Icons.shield_rounded, size: 80, color: Color(0xFFFFD700)),
                                ),
                              ),

                              Positioned(
                                right: 0,
                                top: 0,
                                child: Icon(Icons.help_outline_rounded, color: Colors.white38, size: 16.sp),
                              ),
                            ],
                          ],
                        ),
                      ),

                      // TOP CENTER AVATAR WITH ORNATE GOLDEN CROWN FRAME
                      if (!isSovereign)
                        Positioned(
                          top: 0,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 56.w,
                                height: 56.h,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.black45,
                                ),
                                child: ClipOval(
                                  child: (user?.avatarUrl != null && user!.avatarUrl!.isNotEmpty)
                                      ? Image.network(user.avatarUrl!, fit: BoxFit.cover, errorBuilder: (c, e, s) => _buildAvatarFallback(user))
                                      : _buildAvatarFallback(user),
                                ),
                              ),
                              if (rank['frameAsset'] != null)
                                Image.asset(
                                  rank['frameAsset'],
                                  width: 98.w,
                                  height: 98.h,
                                  fit: BoxFit.contain,
                                  errorBuilder: (c, e, s) => const SizedBox.shrink(),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildAvatarFallback(dynamic user) {
    final name = user?.username ?? 'U';
    return Center(
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : 'U',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18.sp),
      ),
    );
  }

  // CURVED ARC RANK SLIDER TRACK LINE
  Widget _buildCurvedArcRankSlider() {
    final activeRank = _displayRanks[_selectedRankIndex];
    final prevIndex = (_selectedRankIndex - 1).clamp(0, _displayRanks.length - 1);
    final nextIndex = (_selectedRankIndex + 1).clamp(0, _displayRanks.length - 1);

    return Column(
      children: [
        SizedBox(
          height: 60.h,
          width: double.infinity,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // CURVED ARC TRACK PAINT
              CustomPaint(
                size: Size(300.w, 40.h),
                painter: ArcTrackPainter(),
              ),

              // RANKS ON ARC (PREV, CENTER ACTIVE, NEXT)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // PREV RANK
                  GestureDetector(
                    onTap: () => _onRankSelected(prevIndex),
                    child: Opacity(
                      opacity: 0.5,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _displayRanks[prevIndex]['name'],
                            style: TextStyle(color: Colors.white, fontSize: 12.sp, fontWeight: FontWeight.w500),
                          ),
                          SizedBox(height: 4.h),
                          Container(
                            width: 8.w,
                            height: 8.h,
                            decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white54),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ACTIVE CENTER RANK
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        activeRank['name'],
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w900,
                          shadows: const [
                            Shadow(color: Color(0xFFFFD700), blurRadius: 10),
                          ],
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Container(
                        width: 12.w,
                        height: 12.h,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(color: Colors.white.withValues(alpha: 0.9), blurRadius: 8, spreadRadius: 2),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // NEXT RANK
                  GestureDetector(
                    onTap: () => _onRankSelected(nextIndex),
                    child: Opacity(
                      opacity: 0.5,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _displayRanks[nextIndex]['name'],
                            style: TextStyle(color: Colors.white, fontSize: 12.sp, fontWeight: FontWeight.w500),
                          ),
                          SizedBox(height: 4.h),
                          Container(
                            width: 8.w,
                            height: 8.h,
                            decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white54),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // SUBTITLE EXPIRATION / STATUS BADGE
        Container(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 3.h),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Text(
            activeRank['status'] ?? 'Not activated',
            style: TextStyle(color: Colors.white70, fontSize: 11.sp, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  // DISPLAY PRIVILEGES SECTION
  Widget _buildDisplayPrivilegesSection(Map<String, dynamic> rankData, bool isLocked, dynamic user) {
    if (isLocked) {
      return Container(
        padding: EdgeInsets.symmetric(vertical: 40.h),
        child: Column(
          children: [
            Icon(Icons.shield_outlined, size: 48.sp, color: Colors.white24),
            SizedBox(height: 10.h),
            Text(
              'Just look forward to it',
              style: TextStyle(color: Colors.white54, fontSize: 14.sp, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    final List<Map<String, dynamic>> privileges = (rankData['privileges'] as List<dynamic>).cast<Map<String, dynamic>>();

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // —— DISPLAY PRIVILEGES —— HEADER WITH ELEGANT LINES
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(width: 40.w, height: 1.h, color: Colors.white30),
              SizedBox(width: 10.w),
              Text(
                'Display privileges',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(width: 10.w),
              Container(width: 40.w, height: 1.h, color: Colors.white30),
            ],
          ),
          SizedBox(height: 14.h),

          // 2-COLUMN PRIVILEGE CARDS GRID
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: privileges.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12.w,
              mainAxisSpacing: 12.h,
              childAspectRatio: 1.22,
            ),
            itemBuilder: (context, index) {
              final item = privileges[index];

              return Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.all(4.w),
                          child: item['type'] == 'colored_name'
                              ? _buildColoredNamePreview(item['color'], user)
                              : Image.asset(
                                  item['asset'],
                                  fit: BoxFit.contain,
                                  errorBuilder: (c, e, s) => const Icon(Icons.star_rounded, color: Color(0xFFFFD700), size: 42),
                                ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.only(bottom: 8.h),
                      child: Text(
                        item['name'],
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11.5.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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

  Widget _buildColoredNamePreview(Color color, dynamic user) {
    final name = user?.username ?? 'User Name';
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(
        name,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12.sp,
          shadows: [
            Shadow(color: color.withValues(alpha: 0.8), blurRadius: 6),
          ],
        ),
      ),
    );
  }

  // BOTTOM FIXED PURCHASE BAR
  Widget _buildBottomBar(Map<String, dynamic> rankData, NobleProvider noble) {
    final cost = rankData['cost'] as int;
    final renewalCost = rankData['renewalCost'] as int;
    final isActive = noble.activeRankId == rankData['id'];
    final hasDiscount = rankData['hasDiscount'] == true;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.12))),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // LEFT SEND ACTION COLUMN
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/icons/ic_coin.png',
                        width: 16.w,
                        height: 16.h,
                        errorBuilder: (c, e, s) => const Icon(Icons.monetization_on_rounded, color: Color(0xFFFFD700), size: 16),
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        '${AppFormatters.formatNumber(cost)} / 30 days',
                        style: TextStyle(color: Colors.white, fontSize: 11.5.sp, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  SizedBox(height: 4.h),
                  GestureDetector(
                    onTap: () => _handleSend(rankData),
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(vertical: 8.h),
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(24.r),
                        border: Border.all(color: const Color(0xFFFFD700), width: 1.2),
                      ),
                      child: Text(
                        'Send',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.sp),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(width: 12.w),

            // RIGHT RENEW / ACTIVATE ACTION COLUMN
            Expanded(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset(
                            'assets/icons/ic_coin.png',
                            width: 16.w,
                            height: 16.h,
                            errorBuilder: (c, e, s) => const Icon(Icons.monetization_on_rounded, color: Color(0xFFFFD700), size: 16),
                          ),
                          SizedBox(width: 4.w),
                          Text(
                            '${AppFormatters.formatNumber(renewalCost)} / 30 days',
                            style: TextStyle(color: Colors.white, fontSize: 11.5.sp, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(width: 2.w),
                          Icon(Icons.help_outline_rounded, color: Colors.white54, size: 12.sp),
                        ],
                      ),
                      SizedBox(height: 4.h),
                      GestureDetector(
                        onTap: () => _handleActivate(rankData),
                        child: Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(vertical: 8.h),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFFF8E1), Color(0xFFFFD54F)],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                            borderRadius: BorderRadius.circular(24.r),
                            boxShadow: const [
                              BoxShadow(color: Color(0xFFFFC107), blurRadius: 8, offset: Offset(0, 2)),
                            ],
                          ),
                          child: Text(
                            isActive ? 'Renew' : 'Activate',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: const Color(0xFF3E2723), fontWeight: FontWeight.w900, fontSize: 13.sp),
                          ),
                        ),
                      ),
                    ],
                  ),

                  if (hasDiscount)
                    Positioned(
                      top: 18.h,
                      right: -2.w,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF1744),
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                        child: Text(
                          rankData['discountText'] ?? '60% off',
                          style: TextStyle(color: Colors.white, fontSize: 8.5.sp, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// CUSTOM PAINTER FOR CURVED ARC TRACK LINE
class ArcTrackPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final path = Path()
      ..moveTo(0, size.height * 0.7)
      ..quadraticBezierTo(
        size.width * 0.5,
        size.height * 0.1,
        size.width,
        size.height * 0.7,
      );

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
