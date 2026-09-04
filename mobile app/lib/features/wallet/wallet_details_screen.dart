import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../models/categorized_transaction_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/wallet_details_provider.dart';
import '../../providers/wallet_provider.dart';

class WalletDetailsScreen extends StatefulWidget {
  const WalletDetailsScreen({super.key});

  @override
  State<WalletDetailsScreen> createState() => _WalletDetailsScreenState();
}

class _WalletDetailsScreenState extends State<WalletDetailsScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      context.read<WalletDetailsProvider>().loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppColors.getPrimary(isDark);
    final wallet = context.watch<WalletProvider>();
    final authProv = context.watch<AuthProvider>();
    final detailsProv = context.watch<WalletDetailsProvider>();

    final roleFilters = detailsProv.availableFiltersForRole(authProv.currentUser.role);
    final txs = detailsProv.transactions;

    return Scaffold(
      backgroundColor: AppColors.getBackground(isDark),
      appBar: AppBar(
        title: const Text('Diamond Details', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.getBackground(isDark),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await detailsProv.refreshData();
        },
        child: Column(
          children: [
            // Balance Reconciliation Card Header
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.getCard(isDark),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: primary.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Reconciled Wallet Balance',
                          style: TextStyle(fontSize: 12, color: AppColors.getTextSecondary(isDark)),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '💎 ${wallet.diamonds}',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppColors.getTextPrimary(isDark),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.5)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified_rounded, size: 14, color: Colors.greenAccent),
                        SizedBox(width: 4),
                        Text(
                          'Server Authoritative',
                          style: TextStyle(fontSize: 10, color: Colors.greenAccent, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Horizontal Filter Bar
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: roleFilters.map((filter) {
                  final isSel = detailsProv.selectedCategoryFilter.toLowerCase() == filter.toLowerCase();
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(
                        filter,
                        style: TextStyle(
                          color: isSel ? Colors.white : AppColors.getTextPrimary(isDark),
                          fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12,
                        ),
                      ),
                      selected: isSel,
                      selectedColor: primary,
                      backgroundColor: AppColors.getCard(isDark),
                      onSelected: (_) => detailsProv.setCategoryFilter(filter),
                    ),
                  );
                }).toList(),
              ),
            ),

            // Transaction History List
            Expanded(
              child: detailsProv.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : txs.isEmpty
                      ? _buildEmptyState(isDark)
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: txs.length + (detailsProv.hasMore ? 1 : 1),
                          itemBuilder: (ctx, idx) {
                            if (idx == txs.length) {
                              if (detailsProv.hasMore) {
                                return const Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                );
                              } else {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                                  child: Center(
                                    child: Text(
                                      '— End of Ledger History —',
                                      style: TextStyle(fontSize: 12, color: AppColors.getTextSecondary(isDark)),
                                    ),
                                  ),
                                );
                              }
                            }

                            final tx = txs[idx];
                            return _buildTransactionRow(context, tx, isDark);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionRow(BuildContext context, CategorizedTransactionModel tx, bool isDark) {
    final isCredit = tx.direction == TransactionDirection.credit;

    return Card(
      color: AppColors.getCard(isDark),
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        onTap: () {
          context.read<WalletDetailsProvider>().logAudit('receipt opened', extra: {'txId': tx.transactionId});
          _showTransactionReceiptBottomSheet(context, tx, isDark);
        },
        leading: CircleAvatar(
          backgroundColor: (isCredit ? Colors.green : Colors.red).withValues(alpha: 0.15),
          child: Icon(
            _getCategoryIcon(tx.category, isCredit),
            color: isCredit ? Colors.greenAccent : Colors.redAccent,
            size: 20,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                tx.category,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppColors.getTextPrimary(isDark),
                ),
              ),
            ),
            _buildStatusBadge(tx.status),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              isCredit ? 'From: ${tx.senderName}' : 'To: ${tx.receiverName}',
              style: TextStyle(fontSize: 11, color: AppColors.getTextSecondary(isDark)),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${tx.formattedDate}  ${tx.formattedTime}',
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
                Text(
                  tx.signedAmountString,
                  style: TextStyle(
                    color: isCredit ? Colors.greenAccent : Colors.redAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String cat, bool isCredit) {
    switch (cat.toLowerCase()) {
      case 'host salary':
      case 'agent salary':
        return Icons.workspace_premium_rounded;
      case 'transfer':
        return isCredit ? Icons.download_rounded : Icons.upload_rounded;
      case 'exchange':
        return Icons.currency_exchange_rounded;
      case 'withdrawal':
        return Icons.account_balance_wallet_rounded;
      case 'refund/reversal':
        return Icons.replay_rounded;
      case 'gift/reward':
      default:
        return isCredit ? Icons.card_giftcard_rounded : Icons.send_rounded;
    }
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    IconData icon;

    switch (status.toLowerCase()) {
      case 'completed':
        color = Colors.green;
        icon = Icons.check_circle_outline_rounded;
        break;
      case 'pending':
        color = Colors.amber;
        icon = Icons.hourglass_empty_rounded;
        break;
      case 'failed':
      case 'rejected':
        color = Colors.red;
        icon = Icons.cancel_outlined;
        break;
      case 'reversed':
      case 'refunded':
        color = Colors.purpleAccent;
        icon = Icons.replay_rounded;
        break;
      default:
        color = Colors.blue;
        icon = Icons.info_outline_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(
            status,
            style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined, size: 64, color: AppColors.getTextSecondary(isDark).withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          Text(
            'No transactions found',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(isDark)),
          ),
          const SizedBox(height: 4),
          Text(
            'Try selecting a different filter above.',
            style: TextStyle(fontSize: 12, color: AppColors.getTextSecondary(isDark)),
          ),
        ],
      ),
    );
  }

  void _showTransactionReceiptBottomSheet(BuildContext context, CategorizedTransactionModel tx, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1B182B),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (b) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          children: [
            // Sheet Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Transaction Receipt',
                  style: TextStyle(color: Colors.amberAccent, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.pop(b),
                ),
              ],
            ),
            const Divider(color: Colors.white24),
            const SizedBox(height: 10),

            // Main Receipt Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF25213B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  Text(
                    tx.signedAmountString,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: tx.direction == TransactionDirection.credit ? Colors.greenAccent : Colors.redAccent,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Status: ${tx.status}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Read-Only Server Authoritative Fields
            _receiptRow('Transaction ID', tx.transactionId),
            _receiptRow('Type', tx.category),
            _receiptRow('Status', tx.status),
            _receiptRow('Amount', tx.signedAmountString),
            _receiptRow('Fee', '${tx.fee} ${tx.currency}'),
            _receiptRow('Sender / Source', '${tx.senderName} (${tx.senderId})'),
            _receiptRow('Recipient / Destination', '${tx.receiverName} (${tx.receiverId})'),
            _receiptRow('Balance Before', '${tx.balanceBefore}'),
            _receiptRow('Balance After', '${tx.balanceAfter}'),
            _receiptRow('Server Date', tx.formattedDate),
            _receiptRow('Server Time', tx.formattedTime),
            _receiptRow('Timezone', tx.timezone),
            _receiptRow('Reference / Note', tx.reason),

            // Additional Category Specific Fields
            if (tx.failureReason != null) _receiptRow('Failure Reason', tx.failureReason!, isAlert: true),
            if (tx.reversalReason != null) _receiptRow('Reversal Reason', tx.reversalReason!, isAlert: true),

            if (tx.exchangeRate != null) ...[
              const Divider(color: Colors.white24),
              _receiptRow('Input Amount', '${tx.inputAmount} ${tx.inputCurrency}'),
              _receiptRow('Output Amount', '${tx.outputAmount} ${tx.outputCurrency}'),
              _receiptRow('Exchange Rate', '${tx.exchangeRate}'),
              _receiptRow('Config Version', tx.configVersion ?? 'v1.0'),
            ],

            if (tx.settlementType != null) ...[
              const Divider(color: Colors.white24),
              _receiptRow('Settlement Type', tx.settlementType!),
              _receiptRow('Target Period Cycle', tx.targetCycle ?? 'Current Cycle'),
              _receiptRow('Earning Source', tx.earningSource ?? 'Platform Operations'),
              _receiptRow('Settlement Reference', tx.settlementRef ?? 'N/A'),
            ],

            const SizedBox(height: 20),

            // Share / Export Action
            ElevatedButton.icon(
              icon: const Icon(Icons.ios_share_rounded),
              label: const Text('Export / Share Receipt'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.getPrimary(isDark),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                context.read<WalletDetailsProvider>().logAudit('export or share', extra: {'txId': tx.transactionId});
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Receipt #${tx.transactionId} exported successfully.')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _receiptRow(String label, String val, {bool isAlert = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              val,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isAlert ? Colors.redAccent : Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
