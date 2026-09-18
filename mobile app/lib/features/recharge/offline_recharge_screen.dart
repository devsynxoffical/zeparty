import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/seller_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/design/gold_button.dart';

class OfflineRechargeScreen extends StatefulWidget {
  const OfflineRechargeScreen({super.key});

  @override
  State<OfflineRechargeScreen> createState() => _OfflineRechargeScreenState();
}

class _OfflineRechargeScreenState extends State<OfflineRechargeScreen> {
  final _amountController = TextEditingController(text: '49.99');
  final _txIdController = TextEditingController();
  String _selectedMethod = 'Bank Wire Transfer';
  XFile? _selectedImageFile;
  final ImagePicker _picker = ImagePicker();

  final List<String> _methods = [
    'Bank Wire Transfer',
    'Mobile Wallet (EasyPaisa / JazzCash / BKash)',
    'USDT / Crypto Transfer',
    'Local Authorized Cash Agent'
  ];

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (picked != null) {
        setState(() {
          _selectedImageFile = picked;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Image selection failed: $e')),
      );
    }
  }

  void _showImagePickerOptions(bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.getCard(isDark),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.camera_alt_rounded, color: AppColors.getPrimary(isDark)),
              title: Text('Take Photo', style: TextStyle(color: AppColors.getTextPrimary(isDark))),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: Icon(Icons.photo_library_rounded, color: AppColors.getPrimary(isDark)),
              title: Text('Choose from Gallery', style: TextStyle(color: AppColors.getTextPrimary(isDark))),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final primary = AppColors.getPrimary(isDark);

    return Scaffold(
      backgroundColor: AppColors.getBackground(isDark),
      appBar: AppBar(
        backgroundColor: AppColors.getBackground(isDark),
        title: Text('📝 Manual & Offline Recharge',
          style: TextStyle(color: AppColors.getTextPrimary(isDark), fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Instruction Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: primary.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: primary, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Deposit payment via bank wire or mobile money. Submit receipt below to request manually approved coin credit from local Coin Sellers.',
                      style: TextStyle(fontSize: 12, color: AppColors.getTextPrimary(isDark)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Text('1. Select Payment Channel',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(isDark))),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.getCard(isDark),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.getBorder(isDark)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedMethod,
                  isExpanded: true,
                  dropdownColor: AppColors.getCard(isDark),
                  style: TextStyle(color: AppColors.getTextPrimary(isDark), fontWeight: FontWeight.w600, fontSize: 13),
                  items: _methods.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedMethod = val);
                  },
                ),
              ),
            ),

            const SizedBox(height: 20),

            CustomTextField(
              label: '2. Deposit Amount (\$ USD)',
              hint: 'e.g. 49.99',
              controller: _amountController,
              keyboardType: TextInputType.number,
              prefixIcon: Icons.attach_money_rounded,
            ),

            const SizedBox(height: 20),

            CustomTextField(
              label: '3. Transaction / Reference ID',
              hint: 'TRX-8930192840',
              controller: _txIdController,
              prefixIcon: Icons.receipt_long_rounded,
            ),

            const SizedBox(height: 20),

            Text('4. Upload Payment Proof Screenshot',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(isDark))),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => _showImagePickerOptions(isDark),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.getCard(isDark),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.getBorder(isDark), style: BorderStyle.solid),
                ),
                child: Column(
                  children: [
                    if (_selectedImageFile != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          File(_selectedImageFile!.path),
                          height: 140,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('Tap to change screenshot',
                        style: TextStyle(fontSize: 12, color: primary, fontWeight: FontWeight.bold)),
                    ] else ...[
                      Column(
                        children: [
                          Icon(Icons.cloud_upload_rounded, color: primary, size: 40),
                          const SizedBox(height: 8),
                          Text('Tap to select payment receipt screenshot',
                            style: TextStyle(fontWeight: FontWeight.bold, color: primary)),
                          const SizedBox(height: 4),
                          Text('Supports Camera & Photo Gallery',
                            style: TextStyle(fontSize: 11, color: AppColors.getTextSecondary(isDark))),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            GoldButton(
              text: 'Submit to Admin Review Queue',
              icon: Icons.send_rounded,
              isLoading: context.watch<WalletProvider>().isLoading,
              onPressed: context.watch<WalletProvider>().isLoading
                  ? null
                  : () async {
                      if (_txIdController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter valid Transaction / Reference Number.')),
                        );
                        return;
                      }

                      final amountUsd = double.tryParse(_amountController.text) ?? 49.99;
                      final wallet = context.read<WalletProvider>();

                      final success = await wallet.submitOfflineRecharge(
                        amountUSD: amountUsd,
                        bankName: _selectedMethod,
                        receiptPhotoUrl: _selectedImageFile?.path ?? 'https://storage.zeparty.com/receipts/placeholder.jpg',
                        transactionRef: _txIdController.text.trim(),
                      );

                      if (mounted) {
                        if (success) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('🎉 Offline recharge submitted to Admin Review Queue! Status: Pending Approval.'),
                              backgroundColor: Color(0xFF16A34A),
                            ),
                          );
                          Navigator.pop(context);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(wallet.errorMessage ?? 'Submission failed. Please try again.'),
                              backgroundColor: Colors.redAccent,
                            ),
                          );
                        }
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }
}
