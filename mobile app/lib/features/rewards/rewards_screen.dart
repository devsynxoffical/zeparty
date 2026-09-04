import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../widgets/design/gold_button.dart';
import '../../widgets/design/premium_card.dart';

class RewardsScreen extends StatefulWidget {
  const RewardsScreen({super.key});

  @override
  State<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<RewardsScreen> {
  int _claimedDays = 3;
  bool _watchingAd = false;
  bool _adWatchedToday = false;
  bool _gameTaskClaimed = false;
  bool _giftTaskClaimed = false;
  Timer? _adTimer;

  @override
  void dispose() {
    _adTimer?.cancel();
    super.dispose();
  }

  void _watchAd(BuildContext context, bool isDark, WalletProvider wallet) {
    if (_adWatchedToday) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ You\'ve already claimed your ad reward today. Come back tomorrow!')),
      );
      return;
    }
    setState(() => _watchingAd = true);

    _adTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _watchingAd = false;
          _adWatchedToday = true;
        });
        wallet.rechargeCoins(100, 0.0);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF16A34A),
            content: Row(children: const [
              Text('🎉', style: TextStyle(fontSize: 20)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '+100 ZeCoins earned from watching ad!',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ]),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final wallet = context.watch<WalletProvider>();
    final authProvider = context.watch<AuthProvider>();
    final primary = AppColors.getPrimary(isDark);
    final onPrimary = AppColors.onPrimary(isDark: isDark);

    final user = authProvider.currentUser;
    final rawName = user.username.isNotEmpty ? user.username : (user.name.isNotEmpty ? user.name : 'ZEPARTY');
    final cleanName = rawName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
    final userPart = cleanName.substring(0, min(6, cleanName.length)).padRight(4, 'X');
    final cleanId = user.id.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
    final idPart = cleanId.length >= 4 ? cleanId.substring(0, 4) : cleanId.padRight(4, '0');
    final referralCode = 'ZEP-$userPart-$idPart';

    return Scaffold(
      backgroundColor: AppColors.getBackground(isDark),
      appBar: AppBar(
        backgroundColor: AppColors.getBackground(isDark),
        title: Text(
          '🎁 Rewards & Referrals',
          style: TextStyle(
            color: AppColors.getTextPrimary(isDark),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Balance Banner Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: AppColors.getAccentGradient(isDark),
                borderRadius: BorderRadius.circular(22),
                boxShadow: AppColors.primaryGlow(isDark, alpha: 0.3, blur: 16, spread: 1),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ZeParty Rewards Balance',
                          style: TextStyle(
                            color: onPrimary.withValues(alpha: 0.85),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Text('🪙', style: TextStyle(fontSize: 26)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${wallet.coins} Coins',
                                style: TextStyle(
                                  color: onPrimary,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Complete daily tasks & invite friends to earn!',
                          style: TextStyle(
                            color: onPrimary.withValues(alpha: 0.75),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.black.withValues(alpha: 0.2)
                          : AppColors.white.withValues(alpha: 0.25),
                      shape: BoxShape.circle,
                    ),
                    child: const Text('💰', style: TextStyle(fontSize: 30)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 22),

            // ─── 7-Day Check-in Section ───
            _sectionTitle('📅 7-Day Daily Check-in Streak', isDark),
            const SizedBox(height: 12),
            SizedBox(
              height: 96,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: 7,
                itemBuilder: (context, index) {
                  final dayNum = index + 1;
                  final isClaimed = dayNum <= _claimedDays;
                  final isToday = dayNum == _claimedDays + 1;
                  final coins = dayNum * 50;
                  return GestureDetector(
                    onTap: () {
                      if (isToday) {
                        setState(() => _claimedDays++);
                        wallet.rechargeCoins(coins, 0.0);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: const Color(0xFF16A34A),
                            content: Text('🎉 Day $dayNum bonus claimed: +$coins ZeCoins!'),
                          ),
                        );
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: 72,
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: isToday || isClaimed ? AppColors.getAccentGradient(isDark) : null,
                        color: !isToday && !isClaimed ? AppColors.getCard(isDark) : null,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isToday || isClaimed ? primary : AppColors.getBorder(isDark),
                          width: isToday ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Day $dayNum',
                            style: TextStyle(
                              color: isClaimed || isToday ? onPrimary : AppColors.getTextSecondary(isDark),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Icon(
                            isClaimed ? Icons.check_circle_rounded : Icons.monetization_on_rounded,
                            color: isClaimed
                                ? (isDark ? Colors.lightGreenAccent : const Color(0xFF16A34A))
                                : primary,
                            size: 22,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '+$coins',
                            style: TextStyle(
                              color: isClaimed || isToday ? onPrimary : AppColors.getTextPrimary(isDark),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 24),

            // ─── Daily Tasks ───
            _sectionTitle('⚡ Daily Quests & Rewards', isDark),
            const SizedBox(height: 12),

            // 1. Watch Ad Task
            PremiumCard(
              padding: const EdgeInsets.all(14),
              radius: 16,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.ondemand_video_rounded, color: primary, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Watch Sponsored Video Ad',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5,
                            color: AppColors.getTextPrimary(isDark),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '+100 ZeCoins per ad • 1 claim per day',
                          style: TextStyle(color: primary, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        if (_adWatchedToday)
                          const Text(
                            '✅ Claimed for today',
                            style: TextStyle(color: Color(0xFF16A34A), fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _watchingAd
                      ? SizedBox(
                          width: 44,
                          height: 44,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              CircularProgressIndicator(color: primary, strokeWidth: 2.5),
                              Text('5s', style: TextStyle(color: primary, fontSize: 10, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        )
                      : ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _adWatchedToday ? AppColors.getBorder(isDark) : primary,
                            foregroundColor: _adWatchedToday ? AppColors.getTextSecondary(isDark) : onPrimary,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: _adWatchedToday ? null : () => _watchAd(context, isDark, wallet),
                          child: Text(_adWatchedToday ? 'Done' : 'Watch'),
                        ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // 2. Play Mini Game Task
            _buildTaskTile(
              context,
              isDark,
              title: 'Play 1 Mini Game in Lobby',
              reward: '+150 ZeCoins',
              icon: Icons.sports_esports_rounded,
              isClaimed: _gameTaskClaimed,
              onClaim: () {
                if (_gameTaskClaimed) return;
                setState(() => _gameTaskClaimed = true);
                wallet.rechargeCoins(150, 0.0);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    backgroundColor: Color(0xFF16A34A),
                    content: Text('🎉 +150 ZeCoins claimed for playing mini game!'),
                  ),
                );
              },
            ),

            const SizedBox(height: 10),

            // 3. Send Gifts Task
            _buildTaskTile(
              context,
              isDark,
              title: 'Send Gifts in Live Stream',
              reward: '+250 ZeCoins',
              icon: Icons.card_giftcard_rounded,
              isClaimed: _giftTaskClaimed,
              onClaim: () {
                if (_giftTaskClaimed) return;
                setState(() => _giftTaskClaimed = true);
                wallet.rechargeCoins(250, 0.0);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    backgroundColor: Color(0xFF16A34A),
                    content: Text('🎉 +250 ZeCoins claimed for sending stream gifts!'),
                  ),
                );
              },
            ),

            const SizedBox(height: 24),

            // ─── Referral Program ───
            _sectionTitle('🤝 Referral Program & Invites', isDark),
            const SizedBox(height: 12),

            PremiumCard(
              padding: const EdgeInsets.all(18),
              radius: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: primary.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.group_add_rounded, color: primary, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Invite Friends & Earn Diamonds',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: AppColors.getTextPrimary(isDark),
                              ),
                            ),
                            Text(
                              '💎 500 Diamonds per qualified referral',
                              style: TextStyle(color: primary, fontSize: 11.5, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Referral Stats Row
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: primary.withValues(alpha: 0.2)),
                          ),
                          child: Column(
                            children: [
                              Text(
                                '3 Users',
                                style: TextStyle(
                                  color: primary,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Invited Friends',
                                style: TextStyle(
                                  color: AppColors.getTextSecondary(isDark),
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: primary.withValues(alpha: 0.2)),
                          ),
                          child: Column(
                            children: [
                              Text(
                                '1,500 💎',
                                style: TextStyle(
                                  color: primary,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Earned Diamonds',
                                style: TextStyle(
                                  color: AppColors.getTextSecondary(isDark),
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  Text(
                    'Your Exclusive Referral Code',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: AppColors.getTextSecondary(isDark),
                    ),
                  ),
                  const SizedBox(height: 8),

                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: primary.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            referralCode,
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              color: primary,
                              letterSpacing: 1.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: referralCode));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('✅ Referral code copied to clipboard!')),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.copy_rounded, color: primary, size: 18),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  GoldButton(
                    text: 'Share Referral Link',
                    icon: Icons.share_rounded,
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: 'https://zeparty.app/invite/$referralCode'));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('📤 Referral link copied! Share with friends to earn 500 diamonds.'),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 16),

                  // Referral Rules Box
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.getSurface(isDark),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'How It Works:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.getTextPrimary(isDark),
                            fontSize: 12.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        ...[
                          '1. Share your code or link with friends',
                          '2. Friend enters code during sign up',
                          '3. Friend joins a live stream or mini game',
                          '4. You receive 500 Diamonds instantly!',
                        ].map((rule) => Padding(
                              padding: const EdgeInsets.only(bottom: 3),
                              child: Text(
                                rule,
                                style: TextStyle(fontSize: 11, color: AppColors.getTextSecondary(isDark)),
                              ),
                            )),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 15.5,
        fontWeight: FontWeight.bold,
        color: AppColors.getTextPrimary(isDark),
      ),
    );
  }

  Widget _buildTaskTile(
    BuildContext context,
    bool isDark, {
    required String title,
    required String reward,
    required IconData icon,
    required bool isClaimed,
    required VoidCallback onClaim,
  }) {
    final primary = AppColors.getPrimary(isDark);
    final onPrimary = AppColors.onPrimary(isDark: isDark);
    return PremiumCard(
      padding: const EdgeInsets.all(14),
      radius: 16,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: AppColors.getTextPrimary(isDark),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  reward,
                  style: TextStyle(color: primary, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isClaimed ? AppColors.getBorder(isDark) : primary,
              foregroundColor: isClaimed ? AppColors.getTextSecondary(isDark) : onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: isClaimed ? null : onClaim,
            child: Text(isClaimed ? 'Claimed' : 'Claim'),
          ),
        ],
      ),
    );
  }
}
