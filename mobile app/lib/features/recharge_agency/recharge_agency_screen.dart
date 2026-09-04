import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/recharge_agency_provider.dart';
import '../../widgets/user_avatar.dart';

class RechargeAgencyScreen extends StatefulWidget {
  const RechargeAgencyScreen({super.key});

  @override
  State<RechargeAgencyScreen> createState() => _RechargeAgencyScreenState();
}

class _RechargeAgencyScreenState extends State<RechargeAgencyScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _userIdController = TextEditingController();
  final TextEditingController _coinsController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();

  Map<String, dynamic>? _verifiedRecipient;
  String? _verificationError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _userIdController.dispose();
    _coinsController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppColors.getPrimary(isDark);
    final sellerProv = context.watch<RechargeAgencyProvider>();

    return Scaffold(
      backgroundColor: AppColors.getBackground(isDark),
      appBar: AppBar(
        title: Text(sellerProv.sellerName, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.getBackground(isDark),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: primary,
          labelColor: primary,
          unselectedLabelColor: AppColors.getTextSecondary(isDark),
          tabs: const [
            Tab(icon: Icon(Icons.flash_on_rounded), text: 'Recharge Coins'),
            Tab(icon: Icon(Icons.contact_phone_rounded), text: 'Saved Customers'),
            Tab(icon: Icon(Icons.history_rounded), text: 'History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRechargeCoinsTab(context, sellerProv, isDark, primary),
          _buildSavedCustomersTab(context, sellerProv, isDark, primary),
          _buildHistoryTab(context, sellerProv, isDark, primary),
        ],
      ),
    );
  }

  // ── Tab 1: Recharge Coins (Steps 1–6) ──
  Widget _buildRechargeCoinsTab(BuildContext context, RechargeAgencyProvider prov, bool isDark, Color primary) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dashboard Overview Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [primary, Colors.blue.shade900]),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Seller ID: ${prov.sellerId}', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(8)),
                      child: Text(prov.countryCode, style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 10)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Available Balance', style: TextStyle(color: Colors.white70, fontSize: 11)),
                        Text('${prov.availableCoins} Coins', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Today Recharged', style: TextStyle(color: Colors.amberAccent, fontSize: 11)),
                        Text('${prov.todaysRechargeTotal} Coins', style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          Text('Recharge Recipient Verification', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(isDark))),
          const SizedBox(height: 12),

          // Step 1 & 2: Enter & Verify User ID
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _userIdController,
                  style: TextStyle(color: AppColors.getTextPrimary(isDark)),
                  decoration: const InputDecoration(labelText: 'Enter Recipient User ID (e.g. user_1002)', border: OutlineInputBorder()),
                  onChanged: (_) {
                    if (_verifiedRecipient != null) {
                      setState(() {
                        _verifiedRecipient = null;
                        _verificationError = null;
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                icon: const Icon(Icons.search),
                label: const Text('Verify'),
                style: ElevatedButton.styleFrom(backgroundColor: primary, foregroundColor: Colors.white),
                onPressed: () {
                  final uid = _userIdController.text.trim();
                  final res = prov.verifyUser(uid);
                  setState(() {
                    if (res != null && res.containsKey('error')) {
                      _verificationError = res['error'] as String;
                      _verifiedRecipient = null;
                    } else {
                      _verificationError = null;
                      _verifiedRecipient = res;
                    }
                  });
                },
              ),
            ],
          ),
          if (_verificationError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('❌ $_verificationError', style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
            ),

          // Step 3: Verified Recipient Card
          if (_verifiedRecipient != null) ...[
            const SizedBox(height: 16),
            Card(
              color: AppColors.getCard(isDark),
              child: ListTile(
                leading: UserAvatar(imageUrl: _verifiedRecipient!['avatarUrl'] as String, radius: 20),
                title: Text(_verifiedRecipient!['name'] as String, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('ID: ${_verifiedRecipient!['userId']} • Status: ${_verifiedRecipient!['status']}', style: const TextStyle(fontSize: 11, color: Colors.greenAccent)),
                trailing: const Icon(Icons.check_circle_rounded, color: Colors.greenAccent),
              ),
            ),
            const SizedBox(height: 16),

            // Step 4 & 5: Enter Amount & Summary
            TextField(
              controller: _coinsController,
              keyboardType: TextInputType.number,
              style: TextStyle(color: AppColors.getTextPrimary(isDark)),
              decoration: const InputDecoration(labelText: 'Coin Amount to Recharge', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 14),

            TextField(
              controller: _pinController,
              obscureText: true,
              keyboardType: TextInputType.number,
              style: TextStyle(color: AppColors.getTextPrimary(isDark)),
              decoration: const InputDecoration(labelText: 'Seller Security PIN (Default: 1234)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 20),

            // Step 6: Execute Confirmation Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.flash_on_rounded),
                label: const Text('Confirm & Recharge Coins', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                onPressed: () {
                  final coins = int.tryParse(_coinsController.text.trim()) ?? 0;
                  final pin = _pinController.text.trim();
                  final err = prov.executeRecharge(
                    recipientUserId: _verifiedRecipient!['userId'] as String,
                    recipientName: _verifiedRecipient!['name'] as String,
                    recipientAvatarUrl: _verifiedRecipient!['avatarUrl'] as String,
                    coins: coins,
                    pin: pin,
                  );

                  if (err == null) {
                    _coinsController.clear();
                    _pinController.clear();
                    setState(() => _verifiedRecipient = null);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('🎉 Successfully recharged $coins coins!'), backgroundColor: Colors.green));
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ $err'), backgroundColor: Colors.redAccent));
                  }
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Tab 2: Saved Customers ──
  Widget _buildSavedCustomersTab(BuildContext context, RechargeAgencyProvider prov, bool isDark, Color primary) {
    final list = prov.savedCustomers;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Saved Customers (${list.length})', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(isDark))),
              ElevatedButton.icon(
                icon: const Icon(Icons.person_add_rounded),
                label: const Text('Add Number'),
                style: ElevatedButton.styleFrom(backgroundColor: primary, foregroundColor: Colors.white),
                onPressed: () => _showAddCustomerDialog(context, prov),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              itemCount: list.length,
              itemBuilder: (ctx, idx) {
                final c = list[idx];
                return Card(
                  color: AppColors.getCard(isDark),
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: const Icon(Icons.contact_phone_rounded, color: Colors.blueAccent),
                    title: Text(c.recipientName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Linked ID: ${c.linkedUserId} • ${c.contactNumber} • ${c.label}', style: const TextStyle(fontSize: 11, color: Colors.white70)),
                    trailing: IconButton(
                      icon: const Icon(Icons.flash_on_rounded, color: Colors.greenAccent),
                      tooltip: 'Select & Recharge',
                      onPressed: () {
                        setState(() {
                          _userIdController.text = c.linkedUserId;
                          _verifiedRecipient = prov.verifyUser(c.linkedUserId);
                          _tabController.animateTo(0);
                        });
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab 3: History ──
  Widget _buildHistoryTab(BuildContext context, RechargeAgencyProvider prov, bool isDark, Color primary) {
    final txs = prov.transactions;

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: txs.length,
      itemBuilder: (ctx, idx) {
        final tx = txs[idx];
        return Card(
          color: AppColors.getCard(isDark),
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: UserAvatar(imageUrl: tx.recipientAvatarUrl, radius: 18),
            title: Text('Recharged ${tx.coins} Coins', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('To: ${tx.recipientName} (${tx.recipientUserId})\nTx ID: ${tx.transactionId}', style: const TextStyle(fontSize: 11, color: Colors.white60)),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(tx.status, style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 11)),
                Text('${tx.timestamp.hour}:${tx.timestamp.minute}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAddCustomerDialog(BuildContext context, RechargeAgencyProvider prov) {
    final nameCtrl = TextEditingController();
    final uidCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final labelCtrl = TextEditingController(text: 'Regular Customer');

    showDialog(
      context: context,
      builder: (d) => AlertDialog(
        backgroundColor: const Color(0xFF1E1B2E),
        title: const Text('Add Saved Customer Number', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Customer Name', labelStyle: TextStyle(color: Colors.white70))),
            const SizedBox(height: 10),
            TextField(controller: uidCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Linked User ID (e.g. user_1002)', labelStyle: TextStyle(color: Colors.white70))),
            const SizedBox(height: 10),
            TextField(controller: phoneCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Mobile / WhatsApp Number', labelStyle: TextStyle(color: Colors.white70))),
            const SizedBox(height: 10),
            TextField(controller: labelCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Label', labelStyle: TextStyle(color: Colors.white70))),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel', style: TextStyle(color: Colors.white60))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
            onPressed: () {
              if (uidCtrl.text.trim().isEmpty || nameCtrl.text.trim().isEmpty) return;
              prov.addSavedCustomer(linkedUserId: uidCtrl.text.trim(), recipientName: nameCtrl.text.trim(), label: labelCtrl.text.trim(), contactNumber: phoneCtrl.text.trim());
              Navigator.pop(d);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🎉 Customer number saved!'), backgroundColor: Colors.green));
            },
            child: const Text('Save Number', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
