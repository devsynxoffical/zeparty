import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/merchant_provider.dart';

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
    _tabController = TabController(length: 2, vsync: this);
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
          indicatorColor: primary,
          labelColor: primary,
          unselectedLabelColor: AppColors.getTextSecondary(isDark),
          tabs: const [
            Tab(icon: Icon(Icons.send_to_mobile_rounded), text: 'Execute Recharge'),
            Tab(icon: Icon(Icons.receipt_long_rounded), text: 'Merchant Ledger'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildExecuteRechargeTab(context, merchProv, merchant, isDark, primary),
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
}
