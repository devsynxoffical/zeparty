import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/bd_center_provider.dart';
import '../../providers/usd_balance_provider.dart';
import '../../providers/messaging_provider.dart';
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

            // [1B] INVITE AGENCY OWNER SECTION (Change Request 14)
            _buildBdSectionCard(
              context,
              isDark: isDark,
              number: '1B',
              title: 'INVITE AGENCY OWNER',
              subtitle: 'Invite existing user ID to become an Agency Owner under your BD',
              icon: Icons.admin_panel_settings_rounded,
              accentColor: Colors.amberAccent,
              onTap: () => _showInviteAgencyOwnerDialog(context, bd),
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
    final usdProv = context.watch<UsdBalanceProvider>();

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
                      'BD COMMISSION & SALARY WALLET',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: primaryText,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Period: ${usdProv.bdCurrentEarningPeriod} • Commission Earned: \$${usdProv.bdCommissionEarned.toStringAsFixed(2)}',
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
                  Text('Available BD USD Balance', style: TextStyle(fontSize: 11, color: secondaryText)),
                  const SizedBox(height: 4),
                  Text(
                    '\$${usdProv.bdAvailableBalance.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: walletColor),
                  ),
                ],
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.account_balance_wallet_rounded, size: 16),
                label: const Text('Withdraw USD', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: walletColor,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  _showBDWithdrawalDialog(context, usdProv, bd.nickname, bd.bdUserId);
                },
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Wallet Transaction Ledger
          Text('Recent BD Withdrawal History', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: secondaryText)),
          const SizedBox(height: 8),

          if (usdProv.bdWithdrawalHistory.isEmpty)
            Text('No BD withdrawals logged.', style: TextStyle(fontSize: 11, color: secondaryText))
          else
            ...usdProv.bdWithdrawalHistory.take(3).map((tx) => Padding(
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
                            'To ${tx.recipientName} (${tx.recipientType})',
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: primaryText),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '-\$${tx.usdAmount.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.redAccent),
                        ),
                      ],
                    ),
                  ),
                )),
        ],
      ),
    );
  }

  void _showBDWithdrawalDialog(BuildContext context, UsdBalanceProvider usdProv, String bdName, String bdId) {
    String recipientType = 'Coin Seller';
    SellerMerchantRecipient? selectedRecipient = usdProv.coinSellers.first;
    final amountController = TextEditingController(text: usdProv.bdAvailableBalance.toStringAsFixed(2));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final availableRecipients = recipientType == 'Coin Seller' ? usdProv.coinSellers : usdProv.merchants;
          if (!availableRecipients.contains(selectedRecipient)) {
            selectedRecipient = availableRecipients.first;
          }

          return Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            decoration: BoxDecoration(
              color: AppColors.getCard(isDark),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Withdraw BD Commission & Salary', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white)),
                      IconButton(icon: const Icon(Icons.close, color: Colors.white70), onPressed: () => Navigator.pop(context)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('Select Recipient Type', style: TextStyle(fontSize: 12, color: Colors.white70)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('Coin Sellers')),
                          selected: recipientType == 'Coin Seller',
                          selectedColor: Colors.amber,
                          onSelected: (sel) {
                            if (sel) {
                              setSheetState(() {
                                recipientType = 'Coin Seller';
                                selectedRecipient = usdProv.coinSellers.first;
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('Merchants')),
                          selected: recipientType == 'Merchant',
                          selectedColor: Colors.purpleAccent,
                          onSelected: (sel) {
                            if (sel) {
                              setSheetState(() {
                                recipientType = 'Merchant';
                                selectedRecipient = usdProv.merchants.first;
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  const Text('Select Recipient', style: TextStyle(fontSize: 12, color: Colors.white70)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<SellerMerchantRecipient>(
                    value: selectedRecipient,
                    dropdownColor: const Color(0xFF1E1B2E),
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                    items: availableRecipients.map((r) => DropdownMenuItem(
                      value: r,
                      child: Text('${r.name} (${r.agencyName})', style: const TextStyle(fontSize: 13)),
                    )).toList(),
                    onChanged: (val) {
                      setSheetState(() {
                        selectedRecipient = val;
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  const Text('Enter Amount (USD)', style: TextStyle(fontSize: 12, color: Colors.white70)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      prefixText: '\$ ',
                      suffixText: 'USD',
                      hintText: 'Available: \$${usdProv.bdAvailableBalance.toStringAsFixed(2)}',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check_circle_rounded),
                      label: const Text('Confirm BD Withdrawal Request', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber.shade800,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        final amt = double.tryParse(amountController.text.trim()) ?? 0.0;
                        if (selectedRecipient == null) return;

                        final err = usdProv.requestBDWithdrawal(
                          recipient: selectedRecipient!,
                          amountUsd: amt,
                          senderName: bdName,
                          senderId: bdId,
                        );

                        if (err == null) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('🎉 BD Withdrawal of \$$amt USD to ${selectedRecipient!.name} recorded!'), backgroundColor: Colors.green),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('❌ $err'), backgroundColor: Colors.redAccent),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showInviteAgencyOwnerDialog(BuildContext context, BDCenterProvider bd) {
    final userIdController = TextEditingController(text: 'user_1002');
    String? verifiedName = 'Sophia Rose';
    String? errorText;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;

          return AlertDialog(
            backgroundColor: AppColors.getCard(isDark),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                const Icon(Icons.admin_panel_settings_rounded, color: Colors.amberAccent),
                const SizedBox(width: 8),
                Text('Invite Agency Owner', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(isDark))),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Enter an existing ZeParty User ID to send an official Agency Owner invitation.',
                  style: TextStyle(fontSize: 12, color: Colors.white70),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: userIdController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'User ID',
                    border: OutlineInputBorder(),
                    hintText: 'e.g. user_1002 or 339102',
                  ),
                  onChanged: (val) {
                    setDialogState(() {
                      if (val.trim().isEmpty) {
                        verifiedName = null;
                        errorText = 'Please enter a user ID.';
                      } else {
                        verifiedName = val.trim() == 'user_1002' ? 'Sophia Rose' : (val.trim() == 'user_1003' ? 'Alex Rivera' : 'Verified Recipient ${val.trim()}');
                        errorText = null;
                      }
                    });
                  },
                ),
                if (verifiedName != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 18),
                        const SizedBox(width: 8),
                        Text('Target: $verifiedName', style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
                if (errorText != null) ...[
                  const SizedBox(height: 8),
                  Text(errorText!, style: const TextStyle(color: Colors.redAccent, fontSize: 11)),
                ],
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
                onPressed: () {
                  final targetId = userIdController.text.trim();
                  if (targetId.isEmpty) return;

                  // Dispatch Official Inbox notification
                  final messaging = context.read<MessagingProvider>();
                  messaging.sendOfficialInvitation(
                    title: 'Agency Owner Invitation',
                    content: '${bd.nickname} invited you to become an Agency Owner.',
                    invitationType: 'Agency Owner',
                    invitationId: 'inv_bd_${DateTime.now().millisecondsSinceEpoch}',
                    inviterName: bd.nickname,
                    targetId: targetId,
                  );

                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('✉️ Agency Owner invitation sent to $targetId ($verifiedName) via ZeParty Official Inbox!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
                child: const Text('Send Invitation', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }
}
