import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/merchant_provider.dart';
import '../../providers/usd_balance_provider.dart';

class MerchantCenterScreen extends StatefulWidget {
  const MerchantCenterScreen({super.key});

  @override
  State<MerchantCenterScreen> createState() => _MerchantCenterScreenState();
}

class _MerchantCenterScreenState extends State<MerchantCenterScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _recipientIdController = TextEditingController(text: 'user_1002');
  final TextEditingController _recipientNameController = TextEditingController(text: 'Sophia Rose');
  final TextEditingController _coinsController = TextEditingController(text: '500000');
  final TextEditingController _pinController = TextEditingController(text: '1234');

  String _selectedRecipientType = 'User Recharge'; // 'User Recharge' or 'Coin Seller Recharge'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _recipientIdController.dispose();
    _recipientNameController.dispose();
    _coinsController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppColors.getPrimary(isDark);
    final merchProv = context.watch<MerchantProvider>();
    final merchant = merchProv.merchant;

    return Scaffold(
      backgroundColor: AppColors.getBackground(isDark),
      appBar: AppBar(
        title: Text(merchant.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.getBackground(isDark),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: primary,
          labelColor: primary,
          unselectedLabelColor: AppColors.getTextSecondary(isDark),
          tabs: const [
            Tab(icon: Icon(Icons.send_to_mobile_rounded), text: 'Execute Recharge'),
            Tab(icon: Icon(Icons.monetization_on_rounded), text: 'USD Balance'),
            Tab(icon: Icon(Icons.receipt_long_rounded), text: 'Merchant Ledger'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildExecuteRechargeTab(context, merchProv, merchant, isDark, primary),
          _buildMerchantUsdBalanceTab(context, isDark, primary),
          _buildMerchantLedgerTab(context, merchProv, isDark),
        ],
      ),
    );
  }

  Widget _buildExecuteRechargeTab(BuildContext context, MerchantProvider prov, merchant, bool isDark, Color primary) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dashboard Header
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)]),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [BoxShadow(color: const Color(0xFF8E2DE2).withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Merchant ID: ${merchant.id}', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(8)),
                      child: Text(merchant.status, style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 11)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Available Merchant Coins', style: TextStyle(color: Colors.white70, fontSize: 11)),
                        Text('${merchant.availableCoins} 🪙', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Distributed Today', style: TextStyle(color: Colors.amberAccent, fontSize: 11)),
                        Text('${merchant.todaysTotalCoins} 🪙', style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Two Recipient Types Toggle
          Text('Select Recipient Target Type', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(isDark))),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Center(
                    child: Text(
                      'User Recharge',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                  selected: _selectedRecipientType == 'User Recharge',
                  selectedColor: primary,
                  backgroundColor: AppColors.getCard(isDark),
                  labelStyle: TextStyle(
                    color: _selectedRecipientType == 'User Recharge' ? Colors.black : AppColors.getTextPrimary(isDark),
                    fontWeight: FontWeight.bold,
                  ),
                  onSelected: (sel) {
                    if (sel) {
                      setState(() {
                        _selectedRecipientType = 'User Recharge';
                        _recipientIdController.text = 'user_1002';
                        _recipientNameController.text = 'Sophia Rose';
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ChoiceChip(
                  label: const Center(
                    child: Text(
                      'Coin Seller Recharge',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                  selected: _selectedRecipientType == 'Coin Seller Recharge',
                  selectedColor: primary,
                  backgroundColor: AppColors.getCard(isDark),
                  labelStyle: TextStyle(
                    color: _selectedRecipientType == 'Coin Seller Recharge' ? Colors.black : AppColors.getTextPrimary(isDark),
                    fontWeight: FontWeight.bold,
                  ),
                  onSelected: (sel) {
                    if (sel) {
                      setState(() {
                        _selectedRecipientType = 'Coin Seller Recharge';
                        _recipientIdController.text = 'seller_8801';
                        _recipientNameController.text = 'Danial Coin Agency';
                      });
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Recharge Form
          Text('Destination Account Info', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(isDark))),
          const SizedBox(height: 10),

          TextField(
            controller: _recipientIdController,
            style: TextStyle(color: AppColors.getTextPrimary(isDark)),
            decoration: InputDecoration(
              labelText: _selectedRecipientType == 'User Recharge' ? 'User ID' : 'Coin Seller ID',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: _recipientNameController,
            style: TextStyle(color: AppColors.getTextPrimary(isDark)),
            decoration: const InputDecoration(labelText: 'Recipient Name / Business Label', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: _coinsController,
            keyboardType: TextInputType.number,
            style: TextStyle(color: AppColors.getTextPrimary(isDark)),
            decoration: const InputDecoration(labelText: 'Coin Amount', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: _pinController,
            obscureText: true,
            keyboardType: TextInputType.number,
            style: TextStyle(color: AppColors.getTextPrimary(isDark)),
            decoration: const InputDecoration(labelText: 'Merchant Security PIN (Default: 1234)', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.flash_on_rounded),
              label: Text('Execute $_selectedRecipientType', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _selectedRecipientType == 'User Recharge' ? primary : Colors.amber.shade800,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                final coins = int.tryParse(_coinsController.text.trim()) ?? 0;
                final pin = _pinController.text.trim();

                final err = prov.executeMerchantRecharge(
                  recipientType: _selectedRecipientType,
                  recipientId: _recipientIdController.text.trim(),
                  recipientName: _recipientNameController.text.trim(),
                  coinAmount: coins,
                  pin: pin,
                );

                if (err == null) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('🎉 Merchant successfully executed $_selectedRecipientType of $coins coins!'), backgroundColor: Colors.green));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ $err'), backgroundColor: Colors.redAccent));
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMerchantLedgerTab(BuildContext context, MerchantProvider prov, bool isDark) {
    final txs = prov.transactions;

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: txs.length,
      itemBuilder: (ctx, idx) {
        final tx = txs[idx];
        final isUser = tx.recipientType == 'User Recharge';

        return Card(
          color: AppColors.getCard(isDark),
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: Icon(isUser ? Icons.person_rounded : Icons.storefront_rounded, color: isUser ? Colors.blueAccent : Colors.amberAccent),
            title: Text('${tx.coinAmount} Coins • ${tx.recipientType}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: Text('To: ${tx.recipientName} (${tx.recipientId})\nDest: ${tx.destinationBalanceType}\nTx ID: ${tx.transactionId}', style: const TextStyle(fontSize: 11, color: Colors.white60)),
            trailing: Text(tx.status, style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 11)),
          ),
        );
      },
    );
  }

  // ── Tab 2: Merchant USD Balance Section (Change Request 15) ──
  Widget _buildMerchantUsdBalanceTab(BuildContext context, bool isDark, Color primary) {
    final usdProv = context.watch<UsdBalanceProvider>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // USD Balance Overview Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)]),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: const Color(0xFF8E2DE2).withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Merchant USD Balance', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(8)),
                      child: const Text('Distinct from Coins', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 10)),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Available USD', style: TextStyle(color: Colors.white70, fontSize: 11)),
                        Text('\$${usdProv.merchantAvailableUsd.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Total Received USD', style: TextStyle(color: Colors.white70, fontSize: 11)),
                        Text('\$${usdProv.merchantTotalReceivedUsd.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Action Buttons: Exchange to Coins & Transfer USD
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.currency_exchange_rounded),
                  label: const Text('Exchange to Coins', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber.shade800,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () {
                    _showMerchantExchangeDialog(context, usdProv);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.send_rounded),
                  label: const Text('Transfer USD', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.getTextPrimary(isDark),
                    side: BorderSide(color: primary),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () {
                    _showMerchantTransferUsdDialog(context, usdProv);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // USD Transaction History Ledger
          Text('USD Transfer & Payout History', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(isDark))),
          const SizedBox(height: 10),

          if (usdProv.merchantUsdTransactions.isEmpty)
            const Text('No USD transactions logged.', style: TextStyle(color: Colors.grey, fontSize: 12))
          else
            ...usdProv.merchantUsdTransactions.map((tx) => Card(
              color: AppColors.getCard(isDark),
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: tx.type == 'Payout Withdrawal' ? Colors.green.withValues(alpha: 0.2) : Colors.purple.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(tx.type == 'Payout Withdrawal' ? Icons.south_west_rounded : Icons.north_east_rounded, color: tx.type == 'Payout Withdrawal' ? Colors.greenAccent : Colors.purpleAccent, size: 20),
                ),
                title: Text('${tx.type} • \$${tx.usdAmount.toStringAsFixed(2)} USD', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.getTextPrimary(isDark))),
                subtitle: Text('From: ${tx.senderName} (${tx.senderRole})\nAgency: ${tx.agencyName ?? 'N/A'}\nRef: ${tx.referenceId} • ${tx.timestamp.toString().substring(0, 16)}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                trailing: Text(tx.status, style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 11)),
              ),
            )),
        ],
      ),
    );
  }

  void _showMerchantExchangeDialog(BuildContext context, UsdBalanceProvider usdProv) {
    final usdController = TextEditingController(text: '20.00');
    const rate = 10000;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final usdVal = double.tryParse(usdController.text.trim()) ?? 0.0;
          final calculatedCoins = (usdVal * rate).toInt();

          return AlertDialog(
            backgroundColor: AppColors.getCard(isDark),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                const Icon(Icons.currency_exchange_rounded, color: Colors.amberAccent),
                const SizedBox(width: 8),
                Text('Exchange USD to Gold Coins', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(isDark))),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.purple.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Admin Exchange Rate:', style: TextStyle(fontSize: 11, color: Colors.purpleAccent, fontWeight: FontWeight.bold)),
                      Text('\$1 USD = $rate Coins (Fee: \$0)', style: const TextStyle(fontSize: 11, color: Colors.purpleAccent, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: usdController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'USD Amount',
                    prefixText: '\$ ',
                    suffixText: 'USD',
                    hintText: 'Available: \$${usdProv.merchantAvailableUsd.toStringAsFixed(2)}',
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (v) => setDlgState(() {}),
                ),
                const SizedBox(height: 14),
                Text('Coins to be credited: $calculatedCoins 🪙', style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent, foregroundColor: Colors.white),
                onPressed: () {
                  final err = usdProv.exchangeUsdToCoins(entityType: 'Merchant', usdAmount: usdVal, ratePerDollar: rate);
                  if (err == null) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('🎉 Merchant exchanged \$$usdVal USD into $calculatedCoins Gold Coins!'), backgroundColor: Colors.green));
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ $err'), backgroundColor: Colors.redAccent));
                  }
                },
                child: const Text('Confirm Exchange', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showMerchantTransferUsdDialog(BuildContext context, UsdBalanceProvider usdProv) {
    SellerMerchantRecipient? selectedRecipient = usdProv.coinSellers.first;
    final amountController = TextEditingController(text: '100.00');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;

          return AlertDialog(
            backgroundColor: AppColors.getCard(isDark),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                const Icon(Icons.send_rounded, color: Colors.blueAccent),
                const SizedBox(width: 8),
                Text('Transfer USD', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(isDark))),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Select Recipient (Coin Seller or Merchant)', style: TextStyle(fontSize: 11, color: Colors.white70)),
                const SizedBox(height: 6),
                DropdownButtonFormField<SellerMerchantRecipient>(
                  value: selectedRecipient,
                  dropdownColor: const Color(0xFF1E1B2E),
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                  items: [...usdProv.coinSellers, ...usdProv.merchants].map((r) => DropdownMenuItem(
                    value: r,
                    child: Text('${r.name} (${r.type})', style: const TextStyle(fontSize: 12)),
                  )).toList(),
                  onChanged: (v) => setDlgState(() => selectedRecipient = v),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'USD Amount to Transfer',
                    prefixText: '\$ ',
                    hintText: 'Available: \$${usdProv.merchantAvailableUsd.toStringAsFixed(2)}',
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
                onPressed: () {
                  final amt = double.tryParse(amountController.text.trim()) ?? 0.0;
                  if (selectedRecipient == null) return;

                  final err = usdProv.transferUsd(senderType: 'Merchant', recipient: selectedRecipient!, usdAmount: amt);
                  if (err == null) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('🎉 Merchant transferred \$$amt USD to ${selectedRecipient!.name}!'), backgroundColor: Colors.green));
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ $err'), backgroundColor: Colors.redAccent));
                  }
                },
                child: const Text('Confirm USD Transfer', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }
}
