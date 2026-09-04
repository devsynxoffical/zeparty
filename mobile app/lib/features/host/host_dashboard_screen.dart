import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/utils/formatters.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/design/gold_button.dart';
import '../../widgets/design/premium_card.dart';
import '../withdrawal/withdrawal_screen.dart';
import '../wallet/diamond_exchange_screen.dart';

class HostDashboardScreen extends StatefulWidget {
  const HostDashboardScreen({super.key});

  @override
  State<HostDashboardScreen> createState() => _HostDashboardScreenState();
}

class _HostDashboardScreenState extends State<HostDashboardScreen> {
  // Configurable Host Targets & Rules
  final double _monthlyDollarTarget = 2500.0;
  final double _achievedDollarAmount = 1450.75;
  final int _requiredHostingMinutesPerDay = 120; // 2 hours/day
  final int _todayHostedMinutes = 85; // 1 hr 25 min
  final int _eligibilityDaysCompleted = 11;
  final int _eligibilityDaysRequired = 15;

  double get _dollarProgress => (_achievedDollarAmount / _monthlyDollarTarget).clamp(0.0, 1.0);
  double get _remainingDollarAmount => (_monthlyDollarTarget - _achievedDollarAmount).clamp(0.0, double.infinity);
  int get _remainingTodayMinutes => (_requiredHostingMinutesPerDay - _todayHostedMinutes).clamp(0, 120);

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final primary = AppColors.getPrimary(isDark);
    final onPrimary = AppColors.onPrimary(isDark: isDark);
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;

    return Scaffold(
      backgroundColor: AppColors.getBackground(isDark),
      appBar: AppBar(
        backgroundColor: AppColors.getBackground(isDark),
        title: Text(
          '🎙️ Host Center',
          style: TextStyle(
            color: AppColors.getTextPrimary(isDark),
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.currency_exchange_rounded, color: primary),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (c) => const DiamondExchangeScreen()),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Host Header Card ───
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: AppColors.getPremiumGradient(isDark),
                borderRadius: BorderRadius.circular(20),
                boxShadow: AppColors.primaryGlow(isDark, alpha: 0.3, blur: 14),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundImage: NetworkImage(user.avatarUrl),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                user.name,
                                style: TextStyle(
                                  color: onPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.greenAccent.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'OFFICIAL HOST ✓',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Host ID: ${user.id} • ${user.agencyName ?? "Direct Agency"}',
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
            ),

            const SizedBox(height: 18),

            // ─── Financial Balance & Actions ───
            PremiumCard(
              padding: const EdgeInsets.all(18),
              radius: 18,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'My Eligible Income Balance',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.getTextSecondary(isDark),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.diamond_rounded, color: Colors.purpleAccent, size: 24),
                          const SizedBox(width: 6),
                          Text(
                            AppFormatters.formatNumber(user.diamonds),
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: AppColors.getTextPrimary(isDark),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '≈ \$${_achievedDollarAmount.toStringAsFixed(2)} USD',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: GoldButton(
                          text: 'Exchange Gold Coins',
                          height: 42,
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (c) => const DiamondExchangeScreen()),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: primary),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (c) => const WithdrawalScreen()),
                            );
                          },
                          child: Text(
                            'Transfer to Seller',
                            style: TextStyle(color: primary, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // ─── Dollar Target & Progress ───
            PremiumCard(
              padding: const EdgeInsets.all(18),
              radius: 18,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Monthly Performance Goal',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.getTextPrimary(isDark),
                        ),
                      ),
                      Text(
                        '${(_dollarProgress * 100).toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: _dollarProgress,
                      minHeight: 8,
                      backgroundColor: AppColors.getBorder(isDark),
                      valueColor: AlwaysStoppedAnimation<Color>(primary),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildTargetStat('Target', '\$${_monthlyDollarTarget.toStringAsFixed(0)}', isDark),
                      _buildTargetStat('Achieved', '\$${_achievedDollarAmount.toStringAsFixed(2)}', isDark, highlight: true),
                      _buildTargetStat('Remaining', '\$${_remainingDollarAmount.toStringAsFixed(2)}', isDark),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // ─── 15-Day Policy & Daily 2-Hour Hosting Requirement Tracker ───
            PremiumCard(
              padding: const EdgeInsets.all(18),
              radius: 18,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.timer_rounded, color: Colors.orangeAccent, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Daily Hosting & 15-Day Eligibility Rule',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13.5,
                          color: AppColors.getTextPrimary(isDark),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Today's Hosting Time Clock
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.softBlack : AppColors.champagneSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Today's Active Hosting", style: TextStyle(fontSize: 11, color: AppColors.getTextSecondary(isDark))),
                            Text(
                              '${(_todayHostedMinutes ~/ 60)}h ${(_todayHostedMinutes % 60)}m / ${(_requiredHostingMinutesPerDay ~/ 60)}h Required',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: primary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: (_todayHostedMinutes / _requiredHostingMinutesPerDay).clamp(0.0, 1.0),
                            minHeight: 6,
                            backgroundColor: AppColors.getBorder(isDark),
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.greenAccent),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Remaining Today: $_remainingTodayMinutes mins',
                              style: TextStyle(fontSize: 10, color: AppColors.getTextSecondary(isDark)),
                            ),
                            Text(
                              '15-Day Rule: $_eligibilityDaysCompleted/$_eligibilityDaysRequired Days Met',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.greenAccent),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Notice: Live Hosts can transfer eligible diamond earnings to an authorized Coin Seller upon fulfilling the configured 15-day eligibility cycle and daily 2-hour broadcasting quota.',
                    style: TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: AppColors.getTextSecondary(isDark),
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

  Widget _buildTargetStat(String label, String value, bool isDark, {bool highlight = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11, color: AppColors.getTextSecondary(isDark)),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: highlight ? Colors.greenAccent : AppColors.getTextPrimary(isDark),
          ),
        ),
      ],
    );
  }
}
