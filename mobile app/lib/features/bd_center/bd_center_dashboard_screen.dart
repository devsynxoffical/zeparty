import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/bd_center_provider.dart';
import '../../widgets/user_avatar.dart';
import '../../widgets/design/premium_card.dart';

import 'bd_invite_agent_screen.dart';
import 'bd_agent_list_screen.dart';
import 'bd_salary_screen.dart';

class BDCenterDashboardScreen extends StatelessWidget {
  const BDCenterDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppColors.getPrimary(isDark);
    final onPrimary = AppColors.onPrimary(isDark: isDark);
    final bd = context.watch<BDCenterProvider>();
    final authUser = context.watch<AuthProvider>().currentUser;

    final canAccessBd = authUser.isBd ||
        authUser.role == UserRole.bd ||
        authUser.role == UserRole.agency ||
        authUser.role == UserRole.admin;

    if (!canAccessBd) {
      return Scaffold(
        backgroundColor: AppColors.getBackground(isDark),
        appBar: AppBar(
          title: const Text('BD Center', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: AppColors.getBackground(isDark),
          elevation: 0,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.gpp_maybe_rounded, size: 64, color: Colors.orangeAccent),
                const SizedBox(height: 16),
                Text(
                  'Access Restricted',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.getTextPrimary(isDark),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'BD Center is restricted to authorized Business Development (BD) operators and admins.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.getTextSecondary(isDark),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: Text('Return to Profile', style: TextStyle(color: onPrimary, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.getBackground(isDark),
      appBar: AppBar(
        backgroundColor: AppColors.getBackground(isDark),
        elevation: 0,
        title: Text(
          'BD Center',
          style: TextStyle(
            color: AppColors.getTextPrimary(isDark),
            fontWeight: FontWeight.w900,
            fontSize: 20,
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // BD Account Header Summary Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: AppColors.getPremiumGradient(isDark),
                borderRadius: BorderRadius.circular(22),
                boxShadow: AppColors.primaryGlow(isDark, alpha: 0.3, blur: 16),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      UserAvatar(
                        imageUrl: bd.avatarUrl,
                        radius: 28,
                        showVipFrame: true,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    bd.nickname,
                                    style: TextStyle(
                                      color: onPrimary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.25),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'TIER ${bd.currentSalaryTier}',
                                    style: TextStyle(
                                      color: onPrimary,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 9,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'BD ID: ${bd.bdUserId} • ${bd.country}',
                              style: TextStyle(
                                color: onPrimary.withValues(alpha: 0.85),
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ─── DIAGRAM B: 4 REQUIRED BD CENTER SECTIONS ───
            Text(
              'BD Operations & Financials',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: AppColors.getTextPrimary(isDark),
              ),
            ),
            const SizedBox(height: 12),

            // [1] INVITE AGENT SECTION (Diagram B)
            _buildBdSectionCard(
              context,
              isDark: isDark,
              number: '1',
              title: 'INVITE AGENT',
              subtitle: 'Search user ID, review account, send agent invitation & track status',
              icon: Icons.person_add_alt_1_rounded,
              accentColor: const Color(0xFF3897F0),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BDInviteAgentScreen())),
            ),

            const SizedBox(height: 12),

            // [2] TEAM MEMBERS SECTION (Diagram B)
            _buildBdSectionCard(
              context,
              isDark: isDark,
              number: '2',
              title: 'TEAM MEMBERS',
              subtitle: 'View invited and approved agents with ID, join date & active status',
              icon: Icons.group_rounded,
              accentColor: const Color(0xFF00ACC1),
              trailingBadge: '${bd.agents.length} Members',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BDAgentListScreen())),
            ),

            const SizedBox(height: 12),

            // [3] BD SALARY RECORD SECTION (Diagram B)
            _buildBdSectionCard(
              context,
              isDark: isDark,
              number: '3',
              title: 'BD SALARY RECORD',
              subtitle: 'Monthly salary history, target value, commission & payout status',
              icon: Icons.receipt_long_rounded,
              accentColor: const Color(0xFFAB47BC),
              trailingBadge: '${bd.salaryHistory.length} Records',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BDSalaryScreen())),
            ),

            const SizedBox(height: 12),

            // [4] MONTHLY SALARY WALLET SECTION (Diagram B & Diagram C)
            _buildBdSalaryWalletCard(context, isDark: isDark, bd: bd),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildBdSectionCard(
    BuildContext context, {
    required bool isDark,
    required String number,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required VoidCallback onTap,
    String? trailingBadge,
  }) {
    final primaryText = AppColors.getTextPrimary(isDark);
    final secondaryText = AppColors.getTextSecondary(isDark);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.getCard(isDark),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: accentColor.withValues(alpha: 0.35), width: 1.2),
          boxShadow: AppColors.cardShadow,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: accentColor, size: 24),
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
                          title,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w900,
                            color: primaryText,
                            letterSpacing: 0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (trailingBadge != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            trailingBadge,
                            style: TextStyle(color: accentColor, fontSize: 9.5, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 11.5, color: secondaryText),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right_rounded, color: secondaryText, size: 20),
          ],
        ),
      ),
    );
  }

  // [4] MONTHLY SALARY WALLET CARD (Diagram B & C: Separate BD Salary Wallet)
  Widget _buildBdSalaryWalletCard(BuildContext context, {required bool isDark, required BDCenterProvider bd}) {
    final primaryText = AppColors.getTextPrimary(isDark);
    final secondaryText = AppColors.getTextSecondary(isDark);
    const walletColor = Color(0xFFFF9800);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.getCard(isDark),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: walletColor.withValues(alpha: 0.4), width: 1.5),
        boxShadow: [
          BoxShadow(color: walletColor.withValues(alpha: 0.15), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: walletColor.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.account_balance_wallet_rounded, color: walletColor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MONTHLY SALARY WALLET',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: primaryText,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Approved monthly BD salary payouts only',
                      style: TextStyle(fontSize: 11, color: secondaryText),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 14),

          // Wallet Balance Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Available Salary Balance', style: TextStyle(fontSize: 11, color: secondaryText)),
                  const SizedBox(height: 4),
                  Text(
                    '\$${bd.salaryWalletBalance.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: walletColor),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Total Received', style: TextStyle(fontSize: 11, color: secondaryText)),
                  const SizedBox(height: 4),
                  Text(
                    '\$${bd.totalSalaryReceived.toStringAsFixed(2)}',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryText),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Wallet Transaction Ledger
          Text('Recent Payout Transactions', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: secondaryText)),
          const SizedBox(height: 8),

          ...bd.walletTransactions.take(2).map((tx) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.getSurface(isDark),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: Colors.green, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          tx.title,
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: primaryText),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '+\$${tx.amount.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.green),
                      ),
                    ],
                  ),
                ),
              )),
        ],
      ),
    );
  }
}
