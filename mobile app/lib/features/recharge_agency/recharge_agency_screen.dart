import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/services/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/recharge_agency_provider.dart';
import '../../models/recharge_agency_model.dart';
import '../../providers/usd_balance_provider.dart';
import '../../widgets/user_avatar.dart';

class RechargeAgencyScreen extends StatefulWidget {
  const RechargeAgencyScreen({super.key});

  @override
  State<RechargeAgencyScreen> createState() => _RechargeAgencyScreenState();
}

class _RechargeAgencyScreenState extends State<RechargeAgencyScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _userIdController = TextEditingController();
  final TextEditingController _coinsController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();
  final ScrollController _historyScrollController = ScrollController();

  late AnimationController _shakeAnimationController;
  late Animation<double> _shakeAnimation;

  VerifiedRecipientModel? _verifiedRecipient;
  String? _verificationError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

    _shakeAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 10)
        .chain(CurveTween(curve: Curves.elasticIn))
        .animate(_shakeAnimationController);

    _historyScrollController.addListener(() {
      if (_historyScrollController.position.pixels >=
          _historyScrollController.position.maxScrollExtent - 200) {
        context.read<RechargeAgencyProvider>().fetchRechargeHistory();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      final user = auth.currentUser;
      final wallet = context.read<WalletProvider>();
      final agencyProv = context.read<RechargeAgencyProvider>();

      agencyProv.syncForSeller(
        sellerId: user.id,
        sellerName: user.displayName.isNotEmpty ? '${user.displayName} Recharge Agency' : 'Coin Reseller Agency',
        countryCode: user.region.isNotEmpty ? user.region : 'GLOBAL',
        initialCoins: user.sellerBalance > 0 ? user.sellerBalance : wallet.sellerBalance,
      );

      agencyProv.fetchRechargeHistory(refresh: true);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _userIdController.dispose();
    _coinsController.dispose();
    _pinController.dispose();
    _historyScrollController.dispose();
    _shakeAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppColors.getPrimary(isDark);
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;

    // Strict role check: decorative badge alone does not grant recharge permissions
    final bool isAuthorizedSeller = user.isSeller ||
        user.role == UserRole.seller ||
        user.role == UserRole.admin ||
        user.badge.toLowerCase().contains('seller') ||
        user.customTitles.any((t) => t.toLowerCase().contains('seller'));

    if (!isAuthorizedSeller) {
      return Scaffold(
        backgroundColor: AppColors.getBackground(isDark),
        appBar: AppBar(
          title: const Text('Recharge Agency', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: AppColors.getBackground(isDark),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.gpp_bad_rounded, size: 64, color: Colors.redAccent),
                const SizedBox(height: 16),
                Text(
                  'Access Denied',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(isDark)),
                ),
                const SizedBox(height: 8),
                Text(
                  'This account does not have an active, approved Coins Seller role or portal assignment. Contact platform administration.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.getTextSecondary(isDark)),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(backgroundColor: primary, foregroundColor: Colors.white),
                  child: const Text('Back to Profile'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final sellerProv = context.watch<RechargeAgencyProvider>();

    return Scaffold(
      backgroundColor: AppColors.getBackground(isDark),
      appBar: AppBar(
        title: Text(sellerProv.sellerName, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.getBackground(isDark),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: primary,
          labelColor: primary,
          unselectedLabelColor: AppColors.getTextSecondary(isDark),
          tabs: const [
            Tab(icon: Icon(Icons.flash_on_rounded), text: 'Recharge Coins'),
            Tab(icon: Icon(Icons.monetization_on_rounded), text: 'USD Balance'),
            Tab(icon: Icon(Icons.contact_phone_rounded), text: 'Saved Customers'),
            Tab(icon: Icon(Icons.history_rounded), text: 'History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRechargeCoinsTab(context, sellerProv, isDark, primary),
          _buildUsdBalanceTab(context, isDark, primary),
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
                  decoration: const InputDecoration(
                    labelText: 'Enter Recipient User ID (e.g. user_1002)',
                    hintText: 'Enter public user ID or username',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) {
                    prov.clearVerifiedRecipient();
                    if (_verifiedRecipient != null || _verificationError != null) {
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
                icon: prov.isVerifyingRecipient
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.search),
                label: const Text('Verify'),
                style: ElevatedButton.styleFrom(backgroundColor: primary, foregroundColor: Colors.white),
                onPressed: prov.isVerifyingRecipient
                    ? null
                    : () async {
                        final uid = _userIdController.text.trim();
                        final res = await prov.verifyRecipient(uid);
                        if (!mounted) return;
                        setState(() {
                          _verifiedRecipient = res;
                          _verificationError = prov.verificationError;
                        });
                      },
              ),
            ],
          ),
          if (_verificationError != null)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _verificationError!,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),

          // Step 3: Verified Recipient Card
          if (_verifiedRecipient != null) ...[
            const SizedBox(height: 16),
            Card(
              color: AppColors.getCard(isDark),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.greenAccent.withValues(alpha: 0.4)),
              ),
              child: ListTile(
                leading: UserAvatar(
                  imageUrl: _verifiedRecipient!.profileImage,
                  name: _verifiedRecipient!.nickname,
                  radius: 20,
                ),
                title: Row(
                  children: [
                    Flexible(
                      child: Text(
                        _verifiedRecipient!.nickname,
                        style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(isDark)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (_verifiedRecipient!.isVerified)
                      const Icon(Icons.verified, color: Colors.blueAccent, size: 16),
                  ],
                ),
                subtitle: Text(
                  'ID: ${_verifiedRecipient!.publicUserId} • ${_verifiedRecipient!.isVerified ? "Verified User" : "Unverified"} (${_verifiedRecipient!.countryCode})',
                  style: const TextStyle(fontSize: 11, color: Colors.greenAccent),
                ),
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

            // Step 4 & 5: Enter Amount & 6-digit Security PIN
            TextField(
              controller: _coinsController,
              keyboardType: TextInputType.number,
              style: TextStyle(color: AppColors.getTextPrimary(isDark)),
              decoration: const InputDecoration(
                labelText: 'Coin Amount to Recharge',
                hintText: 'e.g. 5000',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),

            AnimatedBuilder(
              animation: _shakeAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(_shakeAnimation.value, 0),
                  child: child,
                );
              },
              child: TextField(
                controller: _pinController,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                style: TextStyle(color: AppColors.getTextPrimary(isDark)),
                decoration: const InputDecoration(
                  labelText: '6-Digit Seller Security PIN',
                  hintText: 'Enter 6-digit security PIN',
                  border: OutlineInputBorder(),
                  counterText: '',
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Step 6: Execute Confirmation Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                icon: prov.isExecutingTransfer
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.flash_on_rounded),
                label: Text(
                  prov.isExecutingTransfer ? 'Processing Transfer...' : 'Confirm & Recharge Coins',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: prov.isExecutingTransfer ? Colors.grey : Colors.green,
                  foregroundColor: Colors.white,
                ),
                onPressed: prov.isExecutingTransfer
                    ? null
                    : () async {
                        final coins = int.tryParse(_coinsController.text.trim()) ?? 0;
                        final pin = _pinController.text.trim();

                        if (coins <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please enter a valid coin amount greater than 0.')),
                          );
                          return;
                        }

                        if (pin.isEmpty) {
                          _shakePinField();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please enter your 6-digit security PIN.')),
                          );
                          return;
                        }

                        final authUser = context.read<AuthProvider>().currentUser;
                        final walletProv = context.read<WalletProvider>();

                        try {
                          final result = await prov.executeRechargeTransfer(
                            recipientIdentifier: _verifiedRecipient!.accountId,
                            coins: coins,
                            pin: pin,
                          );

                          if (!mounted) return;
                          _coinsController.clear();
                          _pinController.clear();
                          setState(() => _verifiedRecipient = null);

                          // Invalidate/refresh wallet balance if self recharge
                          if (result.recipientPublicId == authUser.username || result.transactionId.contains(authUser.id)) {
                            walletProv.fetchWallet();
                          }

                          _showTransferSuccessDialog(result, isDark);
                        } catch (e) {
                          if (!mounted) return;
                          _handleTransferError(e);
                        }
                      },
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _shakePinField() {
    _shakeAnimationController.forward(from: 0.0);
  }

  void _handleTransferError(dynamic error) {
    String code = '';
    String message = 'Transfer failed. Please check your inputs and try again.';
    if (error is ApiException) {
      code = error.code ?? '';
      message = error.message;
    }

    if (code == 'USER_NOT_FOUND') {
      setState(() {
        _verificationError = 'Recipient user ID does not exist. Please check the ID.';
      });
    } else if (code == 'INSUFFICIENT_SELLER_COINS' ||
        code == 'INSUFFICIENT_SELLER_BALANCE' ||
        message.toLowerCase().contains('insufficient')) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.inventory_2_outlined, color: Colors.orangeAccent),
              SizedBox(width: 8),
              Text('Insufficient Inventory'),
            ],
          ),
          content: const Text(
            'Insufficient inventory. Your reseller balance is lower than the transfer amount.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } else if (code == 'INVALID_SECURITY_PIN' || code == 'INVALID_PIN' || code == 'INCORRECT_PIN') {
      _shakePinField();
      _pinController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Incorrect security PIN. Please try again.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } else if (code == 'SELLER_SUSPENDED' ||
        code == 'SELLER_ACCOUNT_INACTIVE' ||
        code == 'SELLER_NOT_ACTIVE') {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.block_rounded, color: Colors.redAccent),
              SizedBox(width: 8),
              Text('Account Suspended'),
            ],
          ),
          content: const Text(
            'Seller account is suspended or inactive. Please contact support.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Contact Support'),
            ),
          ],
        ),
      );
    } else if (code == 'RATE_LIMIT_EXCEEDED' ||
        code == 'TOO_MANY_REQUESTS' ||
        (error is ApiException && error.statusCode == 429)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Too many requests. Please wait a moment before trying again.'),
          backgroundColor: Colors.orangeAccent,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _showTransferSuccessDialog(SellerRechargeResult result, bool isDark) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.getCard(isDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 28),
            SizedBox(width: 8),
            Text('Recharge Successful!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Successfully transferred ${AppFormatters.formatNumber(result.coins)} Coins to ${result.recipientName.isNotEmpty ? result.recipientName : "Recipient"}.',
              style: TextStyle(color: AppColors.getTextPrimary(isDark)),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Authoritative Reference ID:', style: TextStyle(color: Colors.white70, fontSize: 11)),
                  const SizedBox(height: 4),
                  SelectableText(
                    result.referenceId,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.amberAccent, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Remaining Balance: ${AppFormatters.formatNumber(result.remainingSellerBalanceCoins)} Coins',
                    style: TextStyle(color: AppColors.getTextSecondary(isDark), fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('Copy Ref ID'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: result.referenceId));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Transaction reference copied to clipboard!')),
              );
            },
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Done', style: TextStyle(color: Colors.white)),
          ),
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
                    title: Text(c.recipientName, style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(isDark))),
                    subtitle: Text('Linked ID: ${c.linkedUserId} • ${c.contactNumber} • ${c.label}', style: TextStyle(fontSize: 11, color: AppColors.getTextSecondary(isDark))),
                    trailing: IconButton(
                      icon: const Icon(Icons.flash_on_rounded, color: Colors.greenAccent),
                      tooltip: 'Select & Recharge',
                      onPressed: () async {
                        setState(() {
                          _userIdController.text = c.linkedUserId;
                          _verifiedRecipient = null;
                          _verificationError = null;
                          _tabController.animateTo(0);
                        });
                        final res = await prov.verifyRecipient(c.linkedUserId);
                        if (!mounted) return;
                        setState(() {
                          _verifiedRecipient = res;
                          _verificationError = prov.verificationError;
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
    if (prov.isLoadingHistory && prov.transactions.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (prov.historyError != null && prov.transactions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.wifi_off_rounded, size: 48, color: Colors.redAccent),
              const SizedBox(height: 12),
              Text(prov.historyError!, textAlign: TextAlign.center, style: TextStyle(color: AppColors.getTextSecondary(isDark))),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(backgroundColor: primary, foregroundColor: Colors.white),
                onPressed: () => prov.fetchRechargeHistory(refresh: true),
              ),
            ],
          ),
        ),
      );
    }

    final txs = prov.transactions;
    if (txs.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => prov.fetchRechargeHistory(refresh: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.25),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.history_toggle_off_rounded, size: 48, color: Colors.grey),
                  const SizedBox(height: 12),
                  Text('No Agency Transactions Yet', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(isDark))),
                  const SizedBox(height: 4),
                  Text('Pull down to refresh or perform a coin recharge.', style: TextStyle(fontSize: 12, color: AppColors.getTextSecondary(isDark))),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => prov.fetchRechargeHistory(refresh: true),
      child: ListView.builder(
        controller: _historyScrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: txs.length + (prov.isLoadingMoreHistory ? 1 : 0),
        itemBuilder: (ctx, idx) {
          if (idx == txs.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final tx = txs[idx];
          return Card(
            color: AppColors.getCard(isDark),
            margin: const EdgeInsets.only(bottom: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: UserAvatar(imageUrl: tx.recipientAvatarUrl, name: tx.recipientName, radius: 18),
              title: Text('Recharged ${AppFormatters.formatNumber(tx.coins)} Coins', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(isDark))),
              subtitle: Text('To: ${tx.recipientName} (@${tx.recipientUserId})\nRef: ${tx.transactionId}', style: TextStyle(fontSize: 11, color: AppColors.getTextSecondary(isDark))),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    tx.status,
                    style: TextStyle(
                      color: tx.status.toLowerCase() == 'successful'
                          ? Colors.greenAccent
                          : (tx.status.toLowerCase() == 'pending' ? Colors.orangeAccent : Colors.redAccent),
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${tx.timestamp.hour.toString().padLeft(2, '0')}:${tx.timestamp.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(fontSize: 10, color: AppColors.getMuted(isDark)),
                  ),
                ],
              ),
              onTap: () {
                Clipboard.setData(ClipboardData(text: tx.transactionId));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Copied Ref: ${tx.transactionId}')),
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _showAddCustomerDialog(BuildContext context, RechargeAgencyProvider prov) {
    final nameCtrl = TextEditingController();
    final uidCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final labelCtrl = TextEditingController(text: 'Regular Customer');
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (d) => AlertDialog(
        backgroundColor: AppColors.getCard(isDark),
        title: Text('Add Saved Customer Number', style: TextStyle(color: AppColors.getTextPrimary(isDark), fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, style: TextStyle(color: AppColors.getTextPrimary(isDark)), decoration: InputDecoration(labelText: 'Customer Name', labelStyle: TextStyle(color: AppColors.getTextSecondary(isDark)))),
            const SizedBox(height: 10),
            TextField(controller: uidCtrl, style: TextStyle(color: AppColors.getTextPrimary(isDark)), decoration: InputDecoration(labelText: 'Linked User ID (e.g. user_1002)', labelStyle: TextStyle(color: AppColors.getTextSecondary(isDark)))),
            const SizedBox(height: 10),
            TextField(controller: phoneCtrl, style: TextStyle(color: AppColors.getTextPrimary(isDark)), decoration: InputDecoration(labelText: 'Mobile / WhatsApp Number', labelStyle: TextStyle(color: AppColors.getTextSecondary(isDark)))),
            const SizedBox(height: 10),
            TextField(controller: labelCtrl, style: TextStyle(color: AppColors.getTextPrimary(isDark)), decoration: InputDecoration(labelText: 'Label', labelStyle: TextStyle(color: AppColors.getTextSecondary(isDark)))),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: Text('Cancel', style: TextStyle(color: AppColors.getTextSecondary(isDark)))),
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

  // ── Tab 2: Seller USD Balance Section (Change Request 15) ──
  Widget _buildUsdBalanceTab(BuildContext context, bool isDark, Color primary) {
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
              gradient: const LinearGradient(colors: [Color(0xFF00B09B), Color(0xFF96C93D)]),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: const Color(0xFF00B09B).withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Coin Seller USD Balance', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(8)),
                      child: const Text('Distinct from Coins', style: TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 10)),
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
                        Text('\$${usdProv.sellerAvailableUsd.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Total Received USD', style: TextStyle(color: Colors.white70, fontSize: 11)),
                        Text('\$${usdProv.sellerTotalReceivedUsd.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
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
                    _showSellerExchangeDialog(context, usdProv);
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
                    _showSellerTransferUsdDialog(context, usdProv);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // USD Transaction History Ledger
          Text('USD Transfer & Payout History', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(isDark))),
          const SizedBox(height: 10),

          if (usdProv.sellerUsdTransactions.isEmpty)
            const Text('No USD transactions logged.', style: TextStyle(color: Colors.grey, fontSize: 12))
          else
            ...usdProv.sellerUsdTransactions.map((tx) => Card(
              color: AppColors.getCard(isDark),
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: tx.type == 'Payout Withdrawal' ? Colors.green.withValues(alpha: 0.2) : Colors.amber.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(tx.type == 'Payout Withdrawal' ? Icons.south_west_rounded : Icons.north_east_rounded, color: tx.type == 'Payout Withdrawal' ? Colors.greenAccent : Colors.amberAccent, size: 20),
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

  void _showSellerExchangeDialog(BuildContext context, UsdBalanceProvider usdProv) {
    final usdController = TextEditingController(text: '10.00');
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
                  decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Admin Exchange Rate:', style: TextStyle(fontSize: 11, color: Colors.amberAccent, fontWeight: FontWeight.bold)),
                      Text('\$1 USD = $rate Coins (Fee: \$0)', style: const TextStyle(fontSize: 11, color: Colors.amberAccent, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: usdController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(color: AppColors.getTextPrimary(isDark)),
                  decoration: InputDecoration(
                    labelText: 'USD Amount',
                    labelStyle: TextStyle(color: AppColors.getTextSecondary(isDark)),
                    prefixText: '\$ ',
                    suffixText: 'USD',
                    hintText: 'Available: \$${usdProv.sellerAvailableUsd.toStringAsFixed(2)}',
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (v) => setDlgState(() {}),
                ),
                const SizedBox(height: 14),
                Text('Coins to be credited: $calculatedCoins 🪙', style: TextStyle(color: isDark ? Colors.greenAccent : Colors.green.shade700, fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: TextStyle(color: AppColors.getTextSecondary(isDark)))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade800, foregroundColor: Colors.white),
                onPressed: () {
                  final err = usdProv.exchangeUsdToCoins(entityType: 'Coin Seller', usdAmount: usdVal, ratePerDollar: rate);
                  if (err == null) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('🎉 Exchanged \$$usdVal USD into $calculatedCoins Gold Coins!'), backgroundColor: Colors.green));
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

  void _showSellerTransferUsdDialog(BuildContext context, UsdBalanceProvider usdProv) {
    SellerMerchantRecipient? selectedRecipient = usdProv.merchants.first;
    final amountController = TextEditingController(text: '50.00');

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
                Text('Select Recipient (Coin Seller or Merchant)', style: TextStyle(fontSize: 11, color: AppColors.getTextSecondary(isDark))),
                const SizedBox(height: 6),
                DropdownButtonFormField<SellerMerchantRecipient>(
                  initialValue: selectedRecipient,
                  dropdownColor: AppColors.getCard(isDark),
                  style: TextStyle(color: AppColors.getTextPrimary(isDark)),
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                  items: [...usdProv.coinSellers, ...usdProv.merchants].map((r) => DropdownMenuItem(
                    value: r,
                    child: Text('${r.name} (${r.type})', style: TextStyle(fontSize: 12, color: AppColors.getTextPrimary(isDark))),
                  )).toList(),
                  onChanged: (v) => setDlgState(() => selectedRecipient = v),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(color: AppColors.getTextPrimary(isDark)),
                  decoration: InputDecoration(
                    labelText: 'USD Amount to Transfer',
                    labelStyle: TextStyle(color: AppColors.getTextSecondary(isDark)),
                    prefixText: '\$ ',
                    hintText: 'Available: \$${usdProv.sellerAvailableUsd.toStringAsFixed(2)}',
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: TextStyle(color: AppColors.getTextSecondary(isDark)))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
                onPressed: () {
                  final amt = double.tryParse(amountController.text.trim()) ?? 0.0;
                  if (selectedRecipient == null) return;

                  final err = usdProv.transferUsd(senderType: 'Coin Seller', recipient: selectedRecipient!, usdAmount: amt);
                  if (err == null) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('🎉 Transferred \$$amt USD to ${selectedRecipient!.name}!'), backgroundColor: Colors.green));
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
