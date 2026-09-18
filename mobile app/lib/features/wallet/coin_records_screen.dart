import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../providers/auth_provider.dart';
import '../../providers/wallet_provider.dart';

class CoinRecordItem {
  final String id;
  final String category;
  final String description;
  final int amount; // positive for credit/income, negative for debit/expense
  final DateTime timestamp;
  final String status;
  final String senderOrReceiver;
  final int balanceBefore;
  final int balanceAfter;

  const CoinRecordItem({
    required this.id,
    required this.category,
    required this.description,
    required this.amount,
    required this.timestamp,
    required this.status,
    required this.senderOrReceiver,
    required this.balanceBefore,
    required this.balanceAfter,
  });

  bool get isIncome => amount > 0;
}

class CoinRecordsScreen extends StatefulWidget {
  const CoinRecordsScreen({super.key});

  @override
  State<CoinRecordsScreen> createState() => _CoinRecordsScreenState();
}

class _CoinRecordsScreenState extends State<CoinRecordsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedDateFilter = '30 Days';
  String _selectedCategoryFilter = 'All Types';

  final List<CoinRecordItem> _allRecords = [];

  static const List<String> _dateFilters = ['Today', '7 Days', '30 Days', 'Custom Range'];
  static const List<String> _categoryFilters = ['All Types', 'Gifting', 'Transfers', 'Recharges', 'Games', 'Store Purchases'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WalletProvider>().fetchLedger();
    });
  }

  List<CoinRecordItem> _getRecordsFromWallet(WalletProvider wallet) {
    if (wallet.transactions.isNotEmpty) {
      return wallet.transactions.map((tx) {
        final amt = tx.amount.round();
        return CoinRecordItem(
          id: tx.id,
          category: tx.type,
          description: tx.title,
          amount: amt,
          timestamp: tx.date,
          status: tx.status,
          senderOrReceiver: tx.targetUserId ?? 'ZeParty System',
          balanceBefore: (tx.balanceAfter ?? 0) - amt,
          balanceAfter: tx.balanceAfter ?? 0,
        );
      }).toList();
    }
    return _allRecords;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<CoinRecordItem> _filterRecords(int tabIndex, WalletProvider wallet) {
    final list = _getRecordsFromWallet(wallet);
    return list.where((item) {
      // 1. Tab Direction Filter (0: All, 1: Income, 2: Expense)
      if (tabIndex == 1 && !item.isIncome) return false;
      if (tabIndex == 2 && item.isIncome) return false;

      // 2. Category Filter
      if (_selectedCategoryFilter != 'All Types' && item.category != _selectedCategoryFilter) {
        return false;
      }

      // 3. Date Range Filter
      final diff = DateTime.now().difference(item.timestamp).inDays;
      if (_selectedDateFilter == 'Today' && diff > 0) return false;
      if (_selectedDateFilter == '7 Days' && diff > 7) return false;
      if (_selectedDateFilter == '30 Days' && diff > 30) return false;

      return true;
    }).toList();
  }

  void _showRecordReceiptModal(BuildContext context, CoinRecordItem record, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.getCard(isDark),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Coin Transaction Record', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close, size: 20)),
                ],
              ),
              const Divider(),
              const SizedBox(height: 10),

              // Banner Amount
              Center(
                child: Column(
                  children: [
                    Text(
                      '${record.amount > 0 ? '+' : ''}${AppFormatters.formatNumber(record.amount)} 🪙',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: record.isIncome ? Colors.greenAccent : Colors.redAccent,
                      ),
                    ),
                    Text(record.description, style: TextStyle(fontSize: 12, color: AppColors.getTextSecondary(isDark))),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              _buildDetailRow('Transaction ID', record.id, isDark),
              _buildDetailRow('Category', record.category, isDark),
              _buildDetailRow('Status', record.status, isDark, isHighlight: true),
              _buildDetailRow('Party / Recipient', record.senderOrReceiver, isDark),
              _buildDetailRow('Timestamp', '${record.timestamp.year}-${record.timestamp.month.toString().padLeft(2, '0')}-${record.timestamp.day.toString().padLeft(2, '0')} ${record.timestamp.hour.toString().padLeft(2, '0')}:${record.timestamp.minute.toString().padLeft(2, '0')}', isDark),
              _buildDetailRow('Balance Before', '${AppFormatters.formatNumber(record.balanceBefore)} 🪙', isDark),
              _buildDetailRow('Balance After', '${AppFormatters.formatNumber(record.balanceAfter)} 🪙', isDark),

              const SizedBox(height: 20),

              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.getPrimary(isDark),
                  minimumSize: const Size(double.infinity, 44),
                ),
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: const Text('Copy Transaction ID'),
                onPressed: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Copied TX ID: ${record.id}')),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String val, bool isDark, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: AppColors.getTextSecondary(isDark))),
          Text(
            val,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isHighlight ? Colors.greenAccent : AppColors.getTextPrimary(isDark),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final wallet = context.watch<WalletProvider>();
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: AppColors.getBackground(isDark),
      appBar: AppBar(
        title: const Text('Coin Records', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.getBackground(isDark),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.getPrimary(isDark),
          labelColor: AppColors.getPrimary(isDark),
          unselectedLabelColor: AppColors.getTextSecondary(isDark),
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(text: 'All Records'),
            Tab(text: 'Income 🟢'),
            Tab(text: 'Expense 🔴'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Coin Reconciled Balance Header Card
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFF381575), AppColors.getCard(isDark)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.getPrimary(isDark).withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Reconciled Coin Balance', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(
                      '🪙 ${AppFormatters.formatNumber(wallet.coins)}',
                      style: const TextStyle(color: Colors.amberAccent, fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Role: ${auth.currentUser.role.name.toUpperCase()}',
                    style: const TextStyle(color: Colors.amberAccent, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

          // Filters Bar: Date & Category Dropdowns
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedDateFilter,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: _dateFilters.map((d) => DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(fontSize: 12)))).toList(),
                    onChanged: (val) => setState(() => _selectedDateFilter = val!),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedCategoryFilter,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: _categoryFilters.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12)))).toList(),
                    onChanged: (val) => setState(() => _selectedCategoryFilter = val!),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // TabBar View Lists
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildRecordsList(0, isDark),
                _buildRecordsList(1, isDark),
                _buildRecordsList(2, isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordsList(int tabIndex, bool isDark) {
    final wallet = context.watch<WalletProvider>();
    final records = _filterRecords(tabIndex, wallet);

    if (records.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text('No Coin Records Found', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(isDark))),
            const SizedBox(height: 4),
            Text('Try adjusting the date range or category filters.', style: TextStyle(fontSize: 11, color: AppColors.getTextSecondary(isDark))),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: records.length,
      itemBuilder: (ctx, idx) {
        final record = records[idx];
        return Card(
          color: AppColors.getCard(isDark),
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: ListTile(
            onTap: () => _showRecordReceiptModal(context, record, isDark),
            leading: CircleAvatar(
              backgroundColor: (record.isIncome ? Colors.green : Colors.red).withValues(alpha: 0.15),
              child: Icon(
                record.isIncome ? Icons.download_rounded : Icons.upload_rounded,
                color: record.isIncome ? Colors.greenAccent : Colors.redAccent,
                size: 20,
              ),
            ),
            title: Text(record.description, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.getTextPrimary(isDark))),
            subtitle: Text('${record.category} • ${record.senderOrReceiver}', style: TextStyle(fontSize: 10.5, color: AppColors.getTextSecondary(isDark))),
            trailing: Text(
              '${record.isIncome ? '+' : ''}${AppFormatters.formatNumber(record.amount)} 🪙',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: record.isIncome ? Colors.greenAccent : Colors.redAccent,
              ),
            ),
          ),
        );
      },
    );
  }
}
