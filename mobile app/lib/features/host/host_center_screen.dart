import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/agency_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/usd_balance_provider.dart';
import '../../core/policy/agency_host_policy.dart';

class HostCenterScreen extends StatefulWidget {
  const HostCenterScreen({super.key});

  @override
  State<HostCenterScreen> createState() => _HostCenterScreenState();
}

class _HostCenterScreenState extends State<HostCenterScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppColors.getPrimary(isDark);
    final authUser = context.watch<AuthProvider>().currentUser;
    final agencyProv = context.watch<AgencyProvider>();

    final audioHost = agencyProv.getAudioHostByUserId(authUser.id);

    if (audioHost == null) {
      final matchingAgencies = agencyProv.searchAgencies(_searchQuery);
      final existingReq = agencyProv.getHostRequestForUser(authUser.id);

      return Scaffold(
        backgroundColor: AppColors.getBackground(isDark),
        appBar: AppBar(
          title: const Text('Audio Host Center'),
          backgroundColor: AppColors.getBackground(isDark),
          elevation: 0,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search Header
              Text(
                'Join an Agency to Become a Host',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.getTextPrimary(isDark),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Search by Agency ID or Name to apply for host roster membership.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.getTextSecondary(isDark),
                ),
              ),
              const SizedBox(height: 16),

              // Search Input Field
              TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val),
                style: TextStyle(color: AppColors.getTextPrimary(isDark)),
                decoration: InputDecoration(
                  hintText: 'Search Agency by ID (e.g. agency_101)...',
                  hintStyle: TextStyle(color: AppColors.getTextSecondary(isDark)),
                  prefixIcon: Icon(Icons.search_rounded, color: primary),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppColors.getCard(isDark),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              if (existingReq != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: existingReq.status == 'Pending'
                        ? Colors.amber.withValues(alpha: 0.15)
                        : (existingReq.status == 'Accepted' ? Colors.green.withValues(alpha: 0.15) : Colors.red.withValues(alpha: 0.15)),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: existingReq.status == 'Pending'
                          ? Colors.amber
                          : (existingReq.status == 'Accepted' ? Colors.green : Colors.red),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        existingReq.status == 'Pending'
                            ? Icons.hourglass_top_rounded
                            : (existingReq.status == 'Accepted' ? Icons.check_circle_rounded : Icons.cancel_rounded),
                        color: existingReq.status == 'Pending'
                            ? Colors.amber
                            : (existingReq.status == 'Accepted' ? Colors.green : Colors.red),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Application Status: ${existingReq.status}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            Text(
                              'Agency: ${existingReq.agencyName} (${existingReq.agencyId})',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              Text(
                'Available Agencies (${matchingAgencies.length})',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.getTextPrimary(isDark),
                ),
              ),
              const SizedBox(height: 12),

              if (matchingAgencies.isEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(24),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.getCard(isDark),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'No agencies match "$_searchQuery"',
                    style: TextStyle(color: AppColors.getTextSecondary(isDark)),
                  ),
                ),
              ] else ...[
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: matchingAgencies.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, idx) {
                    final agency = matchingAgencies[idx];
                    final isPendingThis = existingReq != null && existingReq.agencyId == agency.id && existingReq.status == 'Pending';

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.getCard(isDark),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: primary.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundImage: NetworkImage(agency.logoUrl),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  agency.name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: AppColors.getTextPrimary(isDark),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'ID: ${agency.id} • ${agency.totalHosts} Hosts',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.getTextSecondary(isDark),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  agency.description,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.getTextSecondary(isDark).withValues(alpha: 0.8),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isPendingThis ? Colors.grey : primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: isPendingThis
                                ? null
                                : () {
                                    final res = agencyProv.submitHostJoinRequest(
                                      agencyId: agency.id,
                                      userId: authUser.id,
                                      userName: authUser.name,
                                      userAvatar: authUser.avatarUrl,
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(res),
                                        backgroundColor: AppColors.success,
                                      ),
                                    );
                                    setState(() {});
                                  },
                            child: Text(isPendingThis ? 'Pending' : 'Join'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      );
    }

    final currentPolicy = AgencyHostPolicy.getLevelForDiamonds(audioHost.achievedDiamonds);
    final nextPolicy = AgencyHostPolicy.getNextLevel(currentPolicy.level);

    final progressPct = nextPolicy != null
        ? (audioHost.achievedDiamonds / nextPolicy.diamondTarget).clamp(0.0, 1.0)
        : 1.0;

    return Scaffold(
      backgroundColor: AppColors.getBackground(isDark),
      appBar: AppBar(
        title: const Text('Audio Host Center'),
        backgroundColor: AppColors.getBackground(isDark),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Host Header Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [primary, Colors.deepPurple.shade900]),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: primary.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(audioHost.userName, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(12)),
                        child: Text('Level ${currentPolicy.level}', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('Agency: ${audioHost.agencyName} (ID: ${audioHost.agencyId})', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 14),

                  // Progress Bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Achieved: ${audioHost.achievedDiamonds} 💎', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      Text(nextPolicy != null ? 'Next Target: ${nextPolicy.diamondTarget} 💎' : 'MAX LEVEL', style: const TextStyle(color: Colors.amberAccent, fontSize: 11)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progressPct,
                      minHeight: 10,
                      backgroundColor: Colors.white24,
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.greenAccent),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Salary Breakdown Card (Shared Policy Module 14)
            Card(
              color: AppColors.getCard(isDark),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('15-Day Cycle Salary & Policy Breakdown', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(isDark))),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Basic Total Salary:'),
                        Text('\$${currentPolicy.basicTotalSalaryUsd.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Host Basic Salary (You):', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                        Text('\$${currentPolicy.hostBasicSalaryUsd.toStringAsFixed(2)}', style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Agency Share:', style: TextStyle(color: Colors.amberAccent)),
                        Text('\$${currentPolicy.agencySalaryUsd.toStringAsFixed(2)}', style: const TextStyle(color: Colors.amberAccent)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Special ID Bonus:', style: TextStyle(color: Colors.purpleAccent)),
                        Text(currentPolicy.specialIdBonus, style: const TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Valid Days Tracker Card (Audio Host 2-Hour Daily Unmuted Requirement)
            Card(
              color: AppColors.getCard(isDark),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Valid Days Tracker (2 Hours/Day Requirement)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(isDark))),
                    const SizedBox(height: 8),
                    const Text(
                      'Audio Hosts require 2 hours (120 mins) online & unmuted in room per valid day.',
                      style: TextStyle(fontSize: 11, color: Colors.white70),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Required Valid Days: ${currentPolicy.validDaysRequired} days',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Completed: ${audioHost.completedValidDays} / ${currentPolicy.validDaysRequired}',
                          style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(audioHost.isTodayValid ? Icons.check_circle_rounded : Icons.access_time_filled_rounded, color: audioHost.isTodayValid ? Colors.greenAccent : Colors.orangeAccent, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            audioHost.isTodayValid
                                ? 'Today Status: VALID (${audioHost.dailyOnlineMinutes} mins completed)'
                                : 'Today Status: IN PROGRESS (${audioHost.dailyOnlineMinutes} / 120 mins)',
                            style: TextStyle(color: audioHost.isTodayValid ? Colors.greenAccent : Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Host Personal USD Salary & Withdrawal Card (Change Request 11)
            Consumer<UsdBalanceProvider>(
              builder: (context, usdProv, _) {
                return Card(
                  color: AppColors.getCard(isDark),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Host Personal USD Salary', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(isDark))),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
                              child: const Text('15-Day Payout Eligible', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 11)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [Colors.green.shade900, Colors.teal.shade900]),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Available Host Salary', style: TextStyle(color: Colors.white70, fontSize: 11)),
                                  Text('\$${usdProv.audioHostAvailableBalance.toStringAsFixed(2)} USD', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22)),
                                ],
                              ),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.account_balance_wallet_rounded, size: 18),
                                label: const Text('Withdraw', style: TextStyle(fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.amber,
                                  foregroundColor: Colors.black,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: () {
                                  _showHostWithdrawalDialog(context, usdProv, audioHost.userName, authUser.id, audioHost.agencyName);
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // 15-Day Payout Periods Table
                        Text('15-Day Payout Periods', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(isDark))),
                        const SizedBox(height: 8),
                        ...usdProv.audioHostSalaryPeriods.map((period) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(period.periodLabel, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                  Text('Earned: \$${period.earnedAmount.toStringAsFixed(2)} | Pending: \$${period.pendingAmount.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white60, fontSize: 10)),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: period.status == 'Eligible' ? Colors.green.withValues(alpha: 0.2) : Colors.blue.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(period.status, style: TextStyle(color: period.status == 'Eligible' ? Colors.greenAccent : Colors.lightBlueAccent, fontWeight: FontWeight.bold, fontSize: 11)),
                              ),
                            ],
                          ),
                        )),
                        const SizedBox(height: 12),

                        // Withdrawal History
                        Text('Host Withdrawal History', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(isDark))),
                        const SizedBox(height: 8),
                        if (usdProv.audioHostWithdrawalHistory.isEmpty)
                          const Text('No withdrawal requests yet.', style: TextStyle(fontSize: 11, color: Colors.white60))
                        else
                          ...usdProv.audioHostWithdrawalHistory.map((tx) => ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(tx.recipientType == 'Coin Seller' ? Icons.storefront_rounded : Icons.business_center_rounded, color: Colors.amberAccent),
                            title: Text('\$${tx.usdAmount.toStringAsFixed(2)} USD ➔ ${tx.recipientName}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                            subtitle: Text('Recipient Type: ${tx.recipientType}\nPeriod: ${tx.payoutPeriod} | Ref: ${tx.referenceId}', style: const TextStyle(color: Colors.white54, fontSize: 10)),
                            trailing: Text(tx.status, style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 11)),
                          )),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showHostWithdrawalDialog(BuildContext context, UsdBalanceProvider usdProv, String hostName, String hostId, String agencyName) {
    String recipientType = 'Coin Seller'; // 'Coin Seller' or 'Merchant'
    SellerMerchantRecipient? selectedRecipient = usdProv.coinSellers.first;
    final amountController = TextEditingController(text: usdProv.audioHostAvailableBalance.toStringAsFixed(2));

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
                      const Text('Withdraw Host USD Salary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
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

                  const Text('Select Authorized Recipient', style: TextStyle(fontSize: 12, color: Colors.white70)),
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

                  const Text('Enter Withdrawal Amount (USD)', style: TextStyle(fontSize: 12, color: Colors.white70)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      prefixText: '\$ ',
                      suffixText: 'USD',
                      hintText: 'Available: \$${usdProv.audioHostAvailableBalance.toStringAsFixed(2)}',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check_circle_rounded),
                      label: const Text('Confirm Withdrawal Request', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        final amt = double.tryParse(amountController.text.trim()) ?? 0.0;
                        if (selectedRecipient == null) return;

                        final err = usdProv.requestAudioHostWithdrawal(
                          recipient: selectedRecipient!,
                          amountUsd: amt,
                          payoutPeriod: 'Sep 16 - Sep 30, 2026',
                          senderName: hostName,
                          senderId: hostId,
                          agencyName: agencyName,
                        );

                        if (err == null) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('🎉 Withdrawal of \$$amt USD to ${selectedRecipient!.name} requested successfully!'), backgroundColor: Colors.green),
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
}
