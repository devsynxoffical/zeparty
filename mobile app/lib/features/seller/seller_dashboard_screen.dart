import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/seller_provider.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/design/gold_button.dart';

class SellerDashboardScreen extends StatefulWidget {
  const SellerDashboardScreen({super.key});

  @override
  State<SellerDashboardScreen> createState() => _SellerDashboardScreenState();
}

class _SellerDashboardScreenState extends State<SellerDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _userIdController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final _transferFormKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _userIdController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _showProofDialog(BuildContext context, OfflineRechargeRequest request) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.getCard(isDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Payment Proof - ${request.id}',
          style: TextStyle(color: AppColors.getTextPrimary(isDark), fontSize: 18, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('User: ${request.userName} (${request.userId})',
                style: TextStyle(color: AppColors.getTextSecondary(isDark), fontSize: 13)),
            const SizedBox(height: 4),
            Text('Package: ${request.packageTitle}',
                style: TextStyle(color: AppColors.getPrimary(isDark), fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 4),
            Text('Method: ${request.paymentMethod}',
                style: TextStyle(color: AppColors.getTextSecondary(isDark), fontSize: 13)),
            const SizedBox(height: 4),
            Text('Ref #: ${request.referenceNumber}',
                style: TextStyle(color: AppColors.getBorderStrong(isDark), fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 16),
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: request.proofImagePath != null
                    ? Image.network(
                        request.proofImagePath!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.receipt_long_rounded, size: 48, color: AppColors.primary),
                              SizedBox(height: 8),
                              Text('Official Payment Receipt Attached',
                                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                            ],
                          ),
                        ),
                      )
                    : const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.verified_user_rounded, size: 48, color: AppColors.success),
                            SizedBox(height: 8),
                            Text('Payment Proof Verified via Bank Gateway',
                                style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                          ],
                        ),
                      ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: AppColors.black),
            onPressed: () {
              Navigator.pop(ctx);
              final sellerProvider = Provider.of<SellerProvider>(context, listen: false);
              final success = sellerProvider.approveRequest(request.id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(success
                      ? 'Recharge request ${request.id} approved! ${request.coins} coins transferred.'
                      : 'Insufficient seller balance to approve request!'),
                  backgroundColor: success ? AppColors.success : AppColors.error,
                ),
              );
            },
            child: const Text('Approve Payment'),
          ),
        ],
      ),
    );
  }

  void _handleDirectTransfer() {
    if (_transferFormKey.currentState!.validate()) {
      final userId = _userIdController.text.trim();
      final amount = int.parse(_amountController.text.trim());
      final sellerProvider = Provider.of<SellerProvider>(context, listen: false);

      final success = sellerProvider.directTransfer(userId: userId, coinAmount: amount);

      if (success) {
        _userIdController.clear();
        _amountController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully sent $amount coins to $userId!'),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed: Insufficient seller coin balance!'),
            backgroundColor: AppColors.error,
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
    final sellerProvider = Provider.of<SellerProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Coin Seller Portal'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: primary,
          labelColor: primary,
          unselectedLabelColor: AppColors.getTextSecondary(isDark),
          tabs: const [
            Tab(icon: Icon(Icons.pending_actions_rounded), text: 'Pending'),
            Tab(icon: Icon(Icons.send_rounded), text: 'Direct Send'),
            Tab(icon: Icon(Icons.history_rounded), text: 'Audit Logs'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Seller Stats Banner
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: AppColors.getAccentGradient(isDark),
              borderRadius: BorderRadius.circular(20),
              boxShadow: AppColors.primaryGlow(isDark, alpha: 0.28, blur: 15),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Text('Seller Stock Balance',
                        style: TextStyle(color: onPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.monetization_on, color: onPrimary, size: 20),
                        const SizedBox(width: 4),
                        Text(
                          '${sellerProvider.sellerBalance}',
                          style: TextStyle(color: onPrimary, fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(height: 40, width: 1, color: onPrimary.withValues(alpha: 0.25)),
                Column(
                  children: [
                    Text('Total Distributed',
                        style: TextStyle(color: onPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.check_circle_outline, color: isDark ? Colors.lightGreenAccent : const Color(0xFF16A34A), size: 20),
                        const SizedBox(width: 4),
                        Text(
                          '${sellerProvider.totalDistributedCoins}',
                          style: TextStyle(color: onPrimary, fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // 1. Pending Requests Tab
                sellerProvider.pendingRequests.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.done_all_rounded, size: 64, color: AppColors.getTextSecondary(isDark)),
                            const SizedBox(height: 12),
                            Text('All offline recharge requests processed!',
                                style: TextStyle(color: AppColors.getTextSecondary(isDark), fontSize: 15)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: sellerProvider.pendingRequests.length,
                        itemBuilder: (context, index) {
                          final req = sellerProvider.pendingRequests[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            color: AppColors.getCard(isDark),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundImage: NetworkImage(req.userAvatar),
                                        radius: 20,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(req.userName,
                                                style: TextStyle(
                                                    color: AppColors.getTextPrimary(isDark), fontWeight: FontWeight.bold, fontSize: 15)),
                                            Text('ID: ${req.userId}',
                                                style: TextStyle(color: AppColors.getTextSecondary(isDark), fontSize: 12)),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: primary.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          '+${req.coins} Coins',
                                          style: TextStyle(color: primary, fontWeight: FontWeight.bold, fontSize: 13),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Divider(height: 24, color: AppColors.getBorder(isDark)),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Amount: \$${req.priceUsd.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          color: AppColors.getTextPrimary(isDark),
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                      Text(
                                        req.paymentMethod,
                                        style: TextStyle(
                                          color: AppColors.getTextSecondary(isDark),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Ref: ${req.referenceNumber}',
                                    style: TextStyle(
                                      color: primary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 14),

                                  // Non-scrollable, 100% responsive action buttons row
                                  Row(
                                    children: [
                                      // View Proof
                                      Expanded(
                                        flex: 3,
                                        child: OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                                            side: BorderSide(color: AppColors.getBorderStrong(isDark)),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          ),
                                          onPressed: () => _showProofDialog(context, req),
                                          icon: Icon(Icons.remove_red_eye_rounded, size: 16, color: primary),
                                          label: Text(
                                            'View Proof',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: primary,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),

                                      // Reject icon
                                      Container(
                                        decoration: BoxDecoration(
                                          color: AppColors.error.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                                        ),
                                        child: IconButton(
                                          icon: const Icon(Icons.close_rounded, color: AppColors.error, size: 20),
                                          constraints: const BoxConstraints(minWidth: 42, minHeight: 42),
                                          padding: EdgeInsets.zero,
                                          tooltip: 'Reject',
                                          onPressed: () {
                                            sellerProvider.rejectRequest(req.id);
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text('Request ${req.id} rejected.')),
                                            );
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 8),

                                      // Approve button
                                      Expanded(
                                        flex: 3,
                                        child: ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: primary,
                                            foregroundColor: onPrimary,
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                                            elevation: 0,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          ),
                                          onPressed: () {
                                            final ok = sellerProvider.approveRequest(req.id);
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text(ok
                                                    ? 'Approved ${req.coins} coins to ${req.userId}'
                                                    : 'Insufficient Seller Balance!'),
                                                backgroundColor: ok ? AppColors.success : AppColors.error,
                                              ),
                                            );
                                          },
                                          icon: Icon(Icons.check_rounded, size: 17, color: onPrimary),
                                          label: Text(
                                            'Approve',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: onPrimary,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                // 2. Direct Transfer Tab
                SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _transferFormKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Direct Coin Distribution',
                            style: TextStyle(color: AppColors.getTextPrimary(isDark), fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Text('Search user by User ID and transfer coins directly from seller stock.',
                            style: TextStyle(color: AppColors.getTextSecondary(isDark), fontSize: 13)),
                        const SizedBox(height: 24),
                        CustomTextField(
                          controller: _userIdController,
                          label: 'Target User ID (e.g. USR-8821)',
                          hint: 'Enter recipient User ID',
                          prefixIcon: Icons.badge_rounded,
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return 'Please enter User ID';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        CustomTextField(
                          controller: _amountController,
                          label: 'Coin Amount',
                          hint: 'Enter number of coins to transfer',
                          prefixIcon: Icons.monetization_on_rounded,
                          keyboardType: TextInputType.number,
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return 'Enter coin amount';
                            final num = int.tryParse(val.trim());
                            if (num == null || num <= 0) return 'Enter valid positive number';
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        GoldButton(
                          text: 'Transfer Coins Now',
                          icon: Icons.send_rounded,
                          onPressed: _handleDirectTransfer,
                        ),
                      ],
                    ),
                  ),
                ),

                // 3. Distribution Audit Logs Tab
                ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: sellerProvider.distributionLogs.length,
                  itemBuilder: (context, index) {
                    final log = sellerProvider.distributionLogs[index];
                    return Card(
                      color: AppColors.getCard(isDark),
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: log.type == 'direct_transfer'
                              ? primary.withValues(alpha: 0.2)
                              : AppColors.success.withValues(alpha: 0.2),
                          child: Icon(
                            log.type == 'direct_transfer' ? Icons.send_rounded : Icons.verified_rounded,
                            color: log.type == 'direct_transfer' ? primary : AppColors.success,
                          ),
                        ),
                        title: Text('Distributed ${log.amount} Coins',
                            style: TextStyle(color: AppColors.getTextPrimary(isDark), fontWeight: FontWeight.bold)),
                        subtitle: Text('Recipient: ${log.userId} • Ref: ${log.reference}',
                            style: TextStyle(color: AppColors.getTextSecondary(isDark), fontSize: 12)),
                        trailing: Text(
                          '${log.timestamp.hour}:${log.timestamp.minute.toString().padLeft(2, '0')}',
                          style: TextStyle(color: AppColors.getTextSecondary(isDark), fontSize: 11),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
