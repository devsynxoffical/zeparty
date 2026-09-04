import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../providers/wallet_provider.dart';

class RechargeAgencyMerchantScreen extends StatefulWidget {
  const RechargeAgencyMerchantScreen({super.key});

  @override
  State<RechargeAgencyMerchantScreen> createState() => _RechargeAgencyMerchantScreenState();
}

class _RechargeAgencyMerchantScreenState extends State<RechargeAgencyMerchantScreen> {
  final _userIdController = TextEditingController();
  final _amountController = TextEditingController();
  bool _isUserConfirmed = false;
  String _confirmedUserName = '';
  String _currentTab = 'users';

  @override
  void dispose() {
    _userIdController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _confirmUser() async {
    if (_userIdController.text.trim().isEmpty) return;
    
    setState(() {
      _isUserConfirmed = true;
      _confirmedUserName = 'Verified ${_currentTab == 'users' ? 'User' : 'Coin Seller'} (${_userIdController.text})';
    });
    
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${_currentTab == 'users' ? 'User' : 'Seller'} ID confirmed!')));
  }

  void _handleRecharge() {
    if (!_isUserConfirmed) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please confirm ID first.')));
      return;
    }

    final amountStr = _amountController.text.trim();
    if (amountStr.isEmpty) return;
    
    final amount = int.tryParse(amountStr) ?? 0;
    if (amount <= 0) return;

    final wallet = context.read<WalletProvider>();
    if (wallet.coins < amount) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Insufficient Gold Coins.')));
      return;
    }

    showDialog(
      context: context,
      builder: (c) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: AppColors.getCard(isDark),
          title: Text('Confirm Recharge', style: TextStyle(color: AppColors.getTextPrimary(isDark))),
          content: Text(
            'Recharge ${AppFormatters.formatNumber(amount)} Gold Coins to $_confirmedUserName?',
            style: TextStyle(color: AppColors.getTextSecondary(isDark)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(c);
                _processRecharge();
              },
              child: Text('Confirm', style: TextStyle(color: AppColors.getPrimary(isDark), fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _processRecharge() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => Center(child: CircularProgressIndicator(color: AppColors.getPrimary(Theme.of(context).brightness == Brightness.dark))),
    );

    await Future.delayed(const Duration(seconds: 1)); // API simulation

    if (mounted) {
      Navigator.pop(context); // loading
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recharge Successful!'), backgroundColor: Colors.green),
      );
      setState(() {
        _userIdController.clear();
        _amountController.clear();
        _isUserConfirmed = false;
        _confirmedUserName = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final wallet = context.watch<WalletProvider>();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.getBackground(isDark),
        appBar: AppBar(
          backgroundColor: AppColors.getBackground(isDark),
          title: Text('Recharge Agency', style: TextStyle(color: AppColors.getTextPrimary(isDark), fontWeight: FontWeight.bold, fontSize: 18.sp)),
          centerTitle: true,
          iconTheme: IconThemeData(color: AppColors.getTextPrimary(isDark)),
          actions: [
            IconButton(icon: Icon(Icons.refresh, color: AppColors.getTextPrimary(isDark)), onPressed: () {})
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Center(
                child: Image.asset('assets/images/game_treasure_chest.jpg', height: 120.h, errorBuilder: (c,e,s) => Icon(Icons.account_balance_wallet, size: 80.sp, color: Colors.amber)),
              ),
              const SizedBox(height: 16),
              
              Container(
                decoration: BoxDecoration(
                  color: AppColors.getCard(isDark),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.getPrimary(isDark).withValues(alpha: 0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TabBar(
                      onTap: (index) {
                        setState(() {
                          _currentTab = index == 0 ? 'users' : 'sellers';
                          _isUserConfirmed = false;
                          _userIdController.clear();
                        });
                      },
                      indicatorColor: AppColors.getPrimary(isDark),
                      labelColor: AppColors.getPrimary(isDark),
                      unselectedLabelColor: AppColors.getTextSecondary(isDark),
                      tabs: const [
                        Tab(text: 'Sell to users'),
                        Tab(text: 'Sell to coin sellers'),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_currentTab == 'users' ? 'User Id' : 'Seller Id', style: TextStyle(color: AppColors.getTextSecondary(isDark), fontSize: 13, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _userIdController,
                                  style: TextStyle(color: AppColors.getTextPrimary(isDark)),
                                  onChanged: (v) => setState(() => _isUserConfirmed = false),
                                  decoration: InputDecoration(
                                    hintText: _currentTab == 'users' ? 'Please enter user id' : 'Please enter seller id',
                                    hintStyle: TextStyle(color: AppColors.getTextSecondary(isDark)),
                                    filled: true,
                                    fillColor: isDark ? Colors.black26 : Colors.grey.shade100,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.getPrimary(isDark).withValues(alpha: 0.5))),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.getPrimary(isDark).withValues(alpha: 0.5))),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton(
                                onPressed: _confirmUser,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.black87,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                ),
                                child: const Text('Confirm', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                          if (_isUserConfirmed) ...[
                            const SizedBox(height: 8),
                            Text('Verified: $_confirmedUserName', style: const TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                          const SizedBox(height: 20),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Amount', style: TextStyle(color: AppColors.getTextSecondary(isDark), fontSize: 13, fontWeight: FontWeight.w600)),
                              Text('0 USD', style: TextStyle(color: AppColors.getTextSecondary(isDark), fontSize: 13)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _amountController,
                            keyboardType: TextInputType.number,
                            style: TextStyle(color: AppColors.getTextPrimary(isDark)),
                            decoration: InputDecoration(
                              hintText: 'Please enter gold\'s amount',
                              hintStyle: TextStyle(color: AppColors.getTextSecondary(isDark)),
                              filled: true,
                              fillColor: isDark ? Colors.black26 : Colors.grey.shade100,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.getPrimary(isDark).withValues(alpha: 0.5))),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.getPrimary(isDark).withValues(alpha: 0.5))),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            ),
                          ),
                          const SizedBox(height: 24),
                          
                          SizedBox(
                            width: double.infinity,
                            height: 50.h,
                            child: ElevatedButton.icon(
                              onPressed: _handleRecharge,
                              icon: const Icon(Icons.monetization_on, color: Colors.orange),
                              label: Text('Recharge Now', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp, color: Colors.black87)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25.r)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.getCard(isDark),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.getPrimary(isDark).withValues(alpha: 0.5)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.account_balance_wallet, color: AppColors.getPrimary(isDark)),
                        const SizedBox(width: 8),
                        Text('My gold', style: TextStyle(color: AppColors.getTextPrimary(isDark), fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset('assets/images/coin_ze.png', width: 40, height: 40, errorBuilder: (c,e,s) => const Icon(Icons.monetization_on, size: 40, color: Colors.orange)),
                        const SizedBox(width: 12),
                        Text(
                          AppFormatters.formatNumber(wallet.coins),
                          style: TextStyle(color: AppColors.getTextPrimary(isDark), fontSize: 36, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 50.h,
                      child: ElevatedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.monetization_on, color: Colors.white),
                        label: const Text('Recharge Now', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.getPrimary(isDark),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25.r)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: AppColors.getCard(isDark),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.getPrimary(isDark).withValues(alpha: 0.5)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Phone Number: +1 234567890', style: TextStyle(color: AppColors.getTextSecondary(isDark), fontSize: 14)),
                    Icon(Icons.edit, color: AppColors.getTextSecondary(isDark), size: 18),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
