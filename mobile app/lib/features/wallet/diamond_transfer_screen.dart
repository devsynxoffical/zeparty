import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/wallet_date_gate.dart';
import '../../models/categorized_transaction_model.dart';
import '../../providers/wallet_details_provider.dart';
import '../../providers/wallet_provider.dart';

class ReceiverAccount {
  final String id;
  final String linkedUserId;
  final String name;
  final String avatarUrl;
  final String type; // 'Coin Seller' or 'Merchant'
  final String country;
  final String flag;
  final bool isApproved;
  final bool isTransferEnabled;
  final bool isOnline;
  final double ratePerDiamond; // e.g. 1.00 Coin or $0.008 USD per Diamond
  final String supportedService;

  const ReceiverAccount({
    required this.id,
    required this.linkedUserId,
    required this.name,
    required this.avatarUrl,
    required this.type,
    required this.country,
    required this.flag,
    this.isApproved = true,
    this.isTransferEnabled = true,
    this.isOnline = true,
    this.ratePerDiamond = 1.00,
    this.supportedService = 'Instant P2P Liquidity',
  });
}

class TransferPackage {
  final int diamonds;
  final double usdPayout;
  final double feeDiamonds;

  const TransferPackage({
    required this.diamonds,
    required this.usdPayout,
    required this.feeDiamonds,
  });
}

class DiamondTransferScreen extends StatefulWidget {
  const DiamondTransferScreen({super.key});

  @override
  State<DiamondTransferScreen> createState() => _DiamondTransferScreenState();
}

class _DiamondTransferScreenState extends State<DiamondTransferScreen> {
  // State
  String _selectedReceiverType = 'Coin Sellers'; // 'Coin Sellers' or 'Merchants'
  String _searchQuery = '';
  ReceiverAccount? _selectedReceiver;
  TransferPackage? _selectedPackage;
  int? _customAmount;
  bool _isCustom = false;
  
  // Verification & Quote State
  String? _verificationToken;
  DateTime? _quoteExpiryTime;
  Timer? _timer;
  int _secondsRemaining = 180;
  
  String? get verificationToken => _verificationToken;
  DateTime? get quoteExpiryTime => _quoteExpiryTime;
  
  // Processing guards
  bool _isSubmitting = false;
  bool _adminOverrideDateGate = false; // Admin testing toggle

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _customAmountController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();

  final List<ReceiverAccount> _allReceivers = const [
    ReceiverAccount(
      id: 'seller_8801',
      linkedUserId: 'user_1002',
      name: 'Sophia Rose Liquidity',
      avatarUrl: 'https://i.pravatar.cc/150?img=32',
      type: 'Coin Seller',
      country: 'United States',
      flag: '🇺🇸',
      ratePerDiamond: 1.00,
    ),
    ReceiverAccount(
      id: 'seller_8802',
      linkedUserId: 'user_1003',
      name: 'Alex Rivera Exchange',
      avatarUrl: 'https://i.pravatar.cc/150?img=11',
      type: 'Coin Seller',
      country: 'United Kingdom',
      flag: '🇬🇧',
      ratePerDiamond: 1.00,
    ),
    ReceiverAccount(
      id: 'merch_9901',
      linkedUserId: 'user_5001',
      name: 'ZeParty Global Merchant Desk',
      avatarUrl: 'https://i.pravatar.cc/150?img=60',
      type: 'Merchant',
      country: 'Global',
      flag: '🌐',
      ratePerDiamond: 0.008,
      supportedService: 'Official Merchant Payout',
    ),
    ReceiverAccount(
      id: 'merch_9902',
      linkedUserId: 'user_5002',
      name: 'Emirates Prime Merchant',
      avatarUrl: 'https://i.pravatar.cc/150?img=47',
      type: 'Merchant',
      country: 'UAE',
      flag: '🇦🇪',
      ratePerDiamond: 0.0082,
      supportedService: 'Direct Bank Settlement',
    ),
  ];

  final List<TransferPackage> _packages = const [
    TransferPackage(diamonds: 25000, usdPayout: 2.0, feeDiamonds: 0),
    TransferPackage(diamonds: 50000, usdPayout: 4.0, feeDiamonds: 0),
    TransferPackage(diamonds: 100000, usdPayout: 8.0, feeDiamonds: 0),
    TransferPackage(diamonds: 500000, usdPayout: 40.0, feeDiamonds: 0),
  ];

  @override
  void dispose() {
    _timer?.cancel();
    _searchController.dispose();
    _customAmountController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  void _onReceiverSelected(ReceiverAccount receiver) {
    setState(() {
      _selectedReceiver = receiver;
      // Clear previous quote/verification state when changing receiver
      _verificationToken = 'VERIFIED_TOK_${DateTime.now().millisecondsSinceEpoch}';
      _selectedPackage = null;
      _customAmount = null;
      _isCustom = false;
      _startQuoteTimer();
    });
  }

  void _startQuoteTimer() {
    _timer?.cancel();
    _secondsRemaining = 180; // 3 minute quote validity
    _quoteExpiryTime = DateTime.now().add(const Duration(minutes: 3));
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_secondsRemaining <= 1) {
        t.cancel();
        setState(() {
          _verificationToken = null; // Expire quote
          _secondsRemaining = 0;
        });
      } else {
        setState(() {
          _secondsRemaining--;
        });
      }
    });
  }

  int get _effectiveDiamonds {
    if (_isCustom && _customAmount != null) return _customAmount!;
    if (_selectedPackage != null) return _selectedPackage!.diamonds;
    return 0;
  }

  double get _effectiveFee {
    if (_isCustom && _customAmount != null) return _customAmount! * 0.01;
    if (_selectedPackage != null) return _selectedPackage!.feeDiamonds;
    return 0.0;
  }

  bool get _isDateAllowed {
    if (_adminOverrideDateGate) return true;
    return WalletDateGate.isDateAllowed(DateTime.now());
  }

  List<ReceiverAccount> get _filteredReceivers {
    final targetType = _selectedReceiverType == 'Coin Sellers' ? 'Coin Seller' : 'Merchant';
    return _allReceivers.where((r) {
      if (r.type != targetType) return false;
      if (!r.isApproved || !r.isTransferEnabled) return false; // Filter unapproved/disabled
      if (_searchQuery.trim().isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return r.name.toLowerCase().contains(q) ||
          r.id.toLowerCase().contains(q) ||
          r.linkedUserId.toLowerCase().contains(q) ||
          r.country.toLowerCase().contains(q);
    }).toList();
  }

  void _promptSecureConfirmation() {
    if (_selectedReceiver == null || _effectiveDiamonds <= 0) return;
    _pinController.clear();

    showDialog(
      context: context,
      builder: (c) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: const Color(0xFF1B182B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.security_rounded, color: Colors.amberAccent),
              SizedBox(width: 8),
              Text('Secure Authorization', style: TextStyle(color: Colors.white, fontSize: 16)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Enter your 4-digit Wallet PIN to confirm transfer of ${AppFormatters.formatNumber(_effectiveDiamonds)} Diamonds to ${_selectedReceiver!.name}.',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _pinController,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.amberAccent, fontSize: 24, letterSpacing: 8),
                decoration: InputDecoration(
                  hintText: '••••',
                  hintStyle: const TextStyle(color: Colors.white30),
                  filled: true,
                  fillColor: const Color(0xFF25213B),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.getPrimary(isDark)),
              onPressed: () {
                if (_pinController.text.length == 4) {
                  Navigator.pop(c);
                  _executeAtomicTransfer();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid 4-digit PIN.')),
                  );
                }
              },
              child: const Text('Confirm & Pay', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _executeAtomicTransfer() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    // Show loading progress
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.amberAccent)),
    );

    final wallet = context.read<WalletProvider>();
    final detailsProv = context.read<WalletDetailsProvider>();

    final totalDeduction = _effectiveDiamonds + _effectiveFee.toInt();
    final balanceBefore = wallet.diamonds.toDouble();

    await Future.delayed(const Duration(milliseconds: 600)); // Server validation

    if (mounted) {
      Navigator.pop(context); // Close loading dialog

      // Perform atomic deduction in WalletProvider
      final success = wallet.transferDiamonds(
        totalDeduction,
        _selectedReceiver!.id,
        _selectedReceiver!.type,
      );

      if (success) {
        final balanceAfter = wallet.diamonds.toDouble();
        final txId = 'trf_${DateTime.now().millisecondsSinceEpoch}';

        // Add ledger record to WalletDetailsProvider under Transfer category
        final ledgerTx = CategorizedTransactionModel(
          transactionId: txId,
          category: 'Transfer',
          amount: _effectiveDiamonds.toDouble(),
          currency: 'Diamonds',
          direction: TransactionDirection.debit,
          senderName: 'Me',
          senderId: 'user_1001',
          receiverName: _selectedReceiver!.name,
          receiverId: _selectedReceiver!.id,
          balanceBefore: balanceBefore,
          balanceAfter: balanceAfter,
          status: 'Completed',
          timestamp: DateTime.now(),
          reason: 'P2P Liquidity Transfer to ${_selectedReceiver!.type}',
          fee: _effectiveFee,
        );

        detailsProv.logAudit('transfer completed', extra: {'txId': txId, 'receiver': _selectedReceiver!.id});
        detailsProv.refreshData();

        _showSuccessReceipt(txId, ledgerTx, balanceBefore, balanceAfter);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transfer failed: Insufficient wallet balance.')),
        );
      }

      setState(() => _isSubmitting = false);
    }
  }

  void _showSuccessReceipt(String txId, CategorizedTransactionModel tx, double before, double after) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      backgroundColor: const Color(0xFF1B182B),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (b) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 64),
            const SizedBox(height: 8),
            const Text('Transfer Successful!', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Transaction Ref ID: $txId', style: const TextStyle(color: Colors.white60, fontSize: 11)),
            const Divider(color: Colors.white24, height: 24),

            _receiptDetailRow('Receiver Name', _selectedReceiver!.name),
            _receiptDetailRow('Receiver Type', _selectedReceiver!.type),
            _receiptDetailRow('Receiver ID', _selectedReceiver!.id),
            _receiptDetailRow('Transferred Amount', '${AppFormatters.formatNumber(_effectiveDiamonds)} Diamonds'),
            _receiptDetailRow('Fee', '${_effectiveFee.toStringAsFixed(0)} Diamonds'),
            _receiptDetailRow('Balance Before', '${before.toInt()} Diamonds'),
            _receiptDetailRow('Balance After', '${after.toInt()} Diamonds'),
            _receiptDetailRow('Server Date/Time', '${tx.formattedDate} ${tx.formattedTime}'),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.getPrimary(Theme.of(context).brightness == Brightness.dark)),
                onPressed: () {
                  Navigator.pop(b); // close receipt
                  Navigator.pop(context); // return to wallet
                },
                child: const Text('Back to Wallet', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _receiptDetailRow(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          Text(v, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppColors.getPrimary(isDark);
    final wallet = context.watch<WalletProvider>();

    return Scaffold(
      backgroundColor: AppColors.getBackground(isDark),
      appBar: AppBar(
        title: const Text('Transfer Receiver Directory', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.getBackground(isDark),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.admin_panel_settings_rounded, color: Colors.amberAccent),
            tooltip: 'Admin Transfer Policy Toggle',
            onPressed: () {
              setState(() {
                _adminOverrideDateGate = !_adminOverrideDateGate;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Admin Date Gate Override: ${_adminOverrideDateGate ? "ENABLED (Testing)" : "DISABLED"}')),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Permanent Date Restriction Notice (Module 19 Rule)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _isDateAllowed ? const Color(0xFF1E1B2E) : Colors.amber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.amber, width: 1.2),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: Colors.amberAccent, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _isDateAllowed
                          ? 'Today is an authorized settlement day (1st / 15th). Transfers are fully enabled.'
                          : WalletDateGate.restrictionNotice,
                      style: TextStyle(
                        fontSize: 11,
                        color: _isDateAllowed ? Colors.greenAccent : Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 2. Receiver Type Selector (Coin Sellers vs Merchants)
            Row(
              children: ['Coin Sellers', 'Merchants'].map((type) {
                final isSel = _selectedReceiverType == type;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Center(
                        child: Text(
                          type,
                          style: TextStyle(
                            color: isSel ? Colors.white : AppColors.getTextPrimary(isDark),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      selected: isSel,
                      selectedColor: primary,
                      backgroundColor: AppColors.getCard(isDark),
                      onSelected: (_) {
                        setState(() {
                          _selectedReceiverType = type;
                          _selectedReceiver = null;
                          _selectedPackage = null;
                          _verificationToken = null;
                        });
                      },
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),

            // 3. Search Bar
            TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
              style: TextStyle(color: AppColors.getTextPrimary(isDark), fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search by Seller ID, Merchant ID, User ID or Country...',
                hintStyle: TextStyle(color: AppColors.getTextSecondary(isDark), fontSize: 12, overflow: TextOverflow.ellipsis),
                prefixIcon: const Icon(Icons.search_rounded, color: Colors.grey, size: 20),
                filled: false,
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.black26),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.black26),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
            const SizedBox(height: 16),

            // 4. Receiver Directory Cards List
            Text(
              'Select Approved ${_selectedReceiverType == 'Coin Sellers' ? 'Coin Seller' : 'Merchant'}',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.getTextPrimary(isDark)),
            ),
            const SizedBox(height: 8),

            SizedBox(
              height: 155.h,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _filteredReceivers.length,
                itemBuilder: (ctx, idx) {
                  final rec = _filteredReceivers[idx];
                  final isSel = _selectedReceiver?.id == rec.id;
                  return _buildReceiverCard(rec, isSel, isDark);
                },
              ),
            ),
            const SizedBox(height: 20),

            // 5. Package / Amount Selector (Step 2)
            if (_selectedReceiver != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Select Transfer Package',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.getTextPrimary(isDark)),
                  ),
                  if (_secondsRemaining > 0)
                    Text(
                      'Quote valid: ${_secondsRemaining}s',
                      style: const TextStyle(fontSize: 11, color: Colors.amberAccent, fontWeight: FontWeight.bold),
                    ),
                ],
              ),
              const SizedBox(height: 10),

              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 2.2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: _packages.length,
                itemBuilder: (ctx, idx) {
                  final pkg = _packages[idx];
                  final isSel = !_isCustom && _selectedPackage?.diamonds == pkg.diamonds;
                  return _buildPackageCard(pkg, isSel, isDark);
                },
              ),
              const SizedBox(height: 16),

              // Final Review & Balance Check
              _buildFinalReviewCard(wallet.diamonds, isDark),
              const SizedBox(height: 20),

              // Submit Action Button
              SizedBox(
                width: double.infinity,
                height: 50.h,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: Text(
                    !_isDateAllowed
                        ? 'Submit Disabled (1st & 15th Only)'
                        : 'Review & Confirm Transfer',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade800,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: (!_isDateAllowed || _effectiveDiamonds <= 0 || wallet.diamonds < (_effectiveDiamonds + _effectiveFee))
                      ? null
                      : _promptSecureConfirmation,
                ),
              ),
            ] else ...[
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Text(
                    'Tap an approved ${_selectedReceiverType.toLowerCase()} above to continue.',
                    style: TextStyle(color: AppColors.getTextSecondary(isDark), fontSize: 12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReceiverCard(ReceiverAccount rec, bool isSel, bool isDark) {
    return GestureDetector(
      onTap: () => _onReceiverSelected(rec),
      child: Container(
        width: 220.w,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSel ? AppColors.getPrimary(isDark).withValues(alpha: 0.18) : AppColors.getCard(isDark),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSel ? AppColors.getPrimary(isDark) : (isDark ? Colors.white12 : Colors.black12),
            width: isSel ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundImage: NetworkImage(rec.avatarUrl),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rec.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.getTextPrimary(isDark)),
                      ),
                      Text('${rec.flag} ${rec.country}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${rec.type} • ID: ${rec.id}',
                style: const TextStyle(fontSize: 10, color: Colors.amberAccent, fontWeight: FontWeight.bold),
              ),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Availability:', style: TextStyle(fontSize: 10, color: Colors.grey)),
                Row(
                  children: [
                    Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                    const Text('Online', style: TextStyle(fontSize: 10, color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPackageCard(TransferPackage pkg, bool isSel, bool isDark) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isCustom = false;
          _selectedPackage = pkg;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSel ? AppColors.getPrimary(isDark).withValues(alpha: 0.2) : AppColors.getCard(isDark),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSel ? AppColors.getPrimary(isDark) : (isDark ? Colors.white12 : Colors.black12),
            width: isSel ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '💎 ${AppFormatters.formatNumber(pkg.diamonds)}',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.getTextPrimary(isDark)),
            ),
            const SizedBox(height: 2),
            Text(
              'Payout: \$${pkg.usdPayout.toStringAsFixed(0)} USD',
              style: const TextStyle(fontSize: 10, color: Colors.greenAccent, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinalReviewCard(int userBalance, bool isDark) {
    final effectiveDeduction = _effectiveDiamonds + _effectiveFee.toInt();
    final balanceAfter = userBalance - effectiveDeduction;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.getCard(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Final Transfer Review', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.amberAccent)),
          const Divider(color: Colors.white24),
          _reviewRow('Receiver', '${_selectedReceiver!.name} (${_selectedReceiver!.id})'),
          _reviewRow('Receiver Type', _selectedReceiver!.type),
          _reviewRow('Transfer Amount', '${AppFormatters.formatNumber(_effectiveDiamonds)} Diamonds'),
          _reviewRow('Platform Fee', '${_effectiveFee.toStringAsFixed(0)} Diamonds'),
          _reviewRow('Total Deduction', '${AppFormatters.formatNumber(effectiveDeduction)} Diamonds'),
          _reviewRow('Balance Before', '${AppFormatters.formatNumber(userBalance)} Diamonds'),
          _reviewRow('Balance After', '${AppFormatters.formatNumber(balanceAfter)} Diamonds', isHighlight: true),
        ],
      ),
    );
  }

  Widget _reviewRow(String k, String v, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              v,
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isHighlight ? Colors.greenAccent : Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
