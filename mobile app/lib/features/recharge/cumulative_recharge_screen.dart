import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/cumulative_recharge_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cumulative_recharge_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../widgets/design/gold_button.dart';
import '../../widgets/design/premium_card.dart';

class CumulativeRechargeScreen extends StatefulWidget {
  const CumulativeRechargeScreen({super.key});

  @override
  State<CumulativeRechargeScreen> createState() => _CumulativeRechargeScreenState();
}

class _CumulativeRechargeScreenState extends State<CumulativeRechargeScreen> {
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _claimReward(int milestoneLevel, CumulativeRechargeProvider recharge, WalletProvider wallet) async {
    final success = await recharge.claimMilestone(milestoneLevel, wallet);
    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Cumulative recharge milestone claimed successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to claim this milestone. Threshold not met or already claimed.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppColors.getPrimary(isDark);
    final onPrimary = AppColors.onPrimary(isDark: isDark);
    final user = context.watch<AuthProvider>().currentUser;
    final recharge = context.watch<CumulativeRechargeProvider>();
    final wallet = context.watch<WalletProvider>();
    final event = recharge.currentEvent;
    final rem = event.remainingTime;

    return Scaffold(
      backgroundColor: AppColors.getBackground(isDark),
      appBar: AppBar(
        backgroundColor: AppColors.getBackground(isDark),
        title: Text(
          'Recharge Rewards',
          style: TextStyle(
            color: AppColors.getTextPrimary(isDark),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── User & Cumulative Header ───
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: AppColors.getPremiumGradient(isDark),
                borderRadius: BorderRadius.circular(22),
                boxShadow: AppColors.primaryGlow(isDark, alpha: 0.3, blur: 16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundImage: NetworkImage(user.avatarUrl),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.name,
                              style: TextStyle(
                                color: onPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              'ID: ${user.id} • Event: ${event.title}',
                              style: TextStyle(
                                color: onPrimary.withValues(alpha: 0.8),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Divider(color: onPrimary.withValues(alpha: 0.2), height: 1),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'My Cumulative Recharge',
                              style: TextStyle(color: onPrimary.withValues(alpha: 0.8), fontSize: 11),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '\$${recharge.cumulativeRechargeUsd.toStringAsFixed(2)} USD',
                              style: TextStyle(
                                color: onPrimary,
                                fontWeight: FontWeight.w900,
                                fontSize: 22,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Countdown timer badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: onPrimary.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.timer_outlined, color: Colors.white, size: 13),
                            const SizedBox(width: 4),
                            Text(
                              '${rem.inDays}d ${rem.inHours % 24}h ${rem.inMinutes % 60}m',
                              style: TextStyle(
                                color: onPrimary,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: event.overallProgress,
                      minHeight: 8,
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Recharge \$${(300.0 - recharge.cumulativeRechargeUsd).clamp(0.0, 3000.0).toStringAsFixed(2)} more to unlock next milestone reward!',
                    style: TextStyle(color: onPrimary.withValues(alpha: 0.85), fontSize: 10),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 22),

            // ─── Milestone Reward Tiers ───
            Text(
              'Cumulative Milestones & Rewards',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: AppColors.getTextPrimary(isDark),
              ),
            ),
            const SizedBox(height: 12),

            ...event.milestones.map((m) {
              final isAchieved = recharge.cumulativeRechargeUsd >= m.thresholdUsd;
              final isClaimed = m.status == MilestoneClaimStatus.claimed;
              final isClaimable = isAchieved && !isClaimed;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: PremiumCard(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  radius: 16,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: primary.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Text(m.specialRewardIcon, style: const TextStyle(fontSize: 20)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                Text(
                                  'Recharge \$${m.thresholdUsd.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: AppColors.getTextPrimary(isDark),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: primary.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '+${AppFormatters.formatNumber(m.bonusCoins)} Coins',
                                    style: TextStyle(
                                      color: primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              m.specialRewardName,
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.getTextSecondary(isDark),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Claim / Status Button
                      if (isClaimed)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.greenAccent, width: 0.8),
                          ),
                          child: const Text(
                            'CLAIMED ✓',
                            style: TextStyle(
                              color: Colors.greenAccent,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      else if (isClaimable)
                        GoldButton(
                          text: 'Claim',
                          width: 72,
                          height: 34,
                          onPressed: () => _claimReward(m.level, recharge, wallet),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.softBlack : AppColors.champagneSoft,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.getBorder(isDark)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.lock_rounded, size: 11, color: Colors.grey),
                              const SizedBox(width: 3),
                              Text(
                                '\$${(m.thresholdUsd - recharge.cumulativeRechargeUsd).clamp(0, 99999).toStringAsFixed(0)} left',
                                style: const TextStyle(fontSize: 10, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
