import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/auth_provider.dart';

class HostPackageModel {
  final int diamonds;
  final double usdPayout;
  final String label;

  const HostPackageModel({
    required this.diamonds,
    required this.usdPayout,
    required this.label,
  });

  static const List<HostPackageModel> officialPackages = [
    HostPackageModel(diamonds: 25000, usdPayout: 2.00, label: '25K Diamonds'),
    HostPackageModel(diamonds: 50000, usdPayout: 4.00, label: '50K Diamonds'),
    HostPackageModel(diamonds: 100000, usdPayout: 8.00, label: '100K Diamonds'),
    HostPackageModel(diamonds: 500000, usdPayout: 40.00, label: '500K Diamonds'),
  ];
}

class HostTransferScreen extends StatefulWidget {
  const HostTransferScreen({super.key});

  @override
  State<HostTransferScreen> createState() => _HostTransferScreenState();
}

class _HostTransferScreenState extends State<HostTransferScreen> {
  HostPackageModel? _selectedPackage = HostPackageModel.officialPackages.first;
  final TextEditingController _customDiamondsController = TextEditingController();
  bool _isCustomAmount = false;

  static const double _conversionRate = 12500.0; // 12,500 diamonds = $1 USD (Section 3)

  @override
  void dispose() {
    _customDiamondsController.dispose();
    super.dispose();
  }

  bool _isWithdrawalDayAllowed() {
    final now = DateTime.now();
    return now.day == 1 || now.day == 15;
  }

  double _calculateUsdPayout(int diamonds) {
    return diamonds / _conversionRate;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppColors.getPrimary(isDark);
    final wallet = context.watch<WalletProvider>();

    final selectedDiamonds = _isCustomAmount
        ? (int.tryParse(_customDiamondsController.text.trim()) ?? 0)
        : (_selectedPackage?.diamonds ?? 0);
    final calculatedUsd = _calculateUsdPayout(selectedDiamonds);
    final isDateAllowed = _isWithdrawalDayAllowed();

    return Scaffold(
      backgroundColor: AppColors.getBackground(isDark),
      appBar: AppBar(
        title: const Text('Host Salary Conversion & Transfer', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.getBackground(isDark),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Policy Header Banner (Diagram 1 & Section 3)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [primary, Colors.deepPurple.shade900]),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: primary.withValues(alpha: 0.3), blurRadius: 10)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.verified_user_rounded, color: Colors.amberAccent, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'OFFICIAL HOST POLICY RATE',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '25,000 diamonds = \$2 USD  •  12,500 diamonds = \$1 USD',
                    style: TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Available Host Diamonds: ${wallet.diamonds} 💎',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Date Rule Status Banner (Section 3 & 6)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDateAllowed ? Colors.green.withValues(alpha: 0.15) : Colors.orange.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isDateAllowed ? Colors.green : Colors.orange),
              ),
              child: Row(
                children: [
                  Icon(isDateAllowed ? Icons.event_available_rounded : Icons.event_busy_rounded,
                      color: isDateAllowed ? Colors.green : Colors.orange, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isDateAllowed
                          ? 'Transfers active today (1st / 15th of the month).'
                          : 'Transfers enabled on the 1st and 15th of each month only.',
                      style: TextStyle(
                        color: isDateAllowed ? Colors.green : Colors.orange,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            Text('Select Preset Conversion Package', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.getTextPrimary(isDark))),
            const SizedBox(height: 12),

            // Package Grid (25K=$2, 50K=$4, 100K=$8, 500K=$40)
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: HostPackageModel.officialPackages.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 2.2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemBuilder: (context, index) {
                final pkg = HostPackageModel.officialPackages[index];
                final isSelected = !_isCustomAmount && _selectedPackage?.diamonds == pkg.diamonds;

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _isCustomAmount = false;
                      _selectedPackage = pkg;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected ? primary.withValues(alpha: 0.18) : AppColors.getCard(isDark),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? primary : AppColors.getBorder(isDark),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          pkg.label,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: AppColors.getTextPrimary(isDark),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '\$${pkg.usdPayout.toStringAsFixed(2)} USD',
                          style: TextStyle(
                            color: primary,
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 20),

            // Custom Amount Option
            GestureDetector(
              onTap: () => setState(() => _isCustomAmount = true),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _isCustomAmount ? primary.withValues(alpha: 0.15) : AppColors.getCard(isDark),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _isCustomAmount ? primary : AppColors.getBorder(isDark)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Custom Diamonds Amount (Min: 25,000 💎)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.getTextPrimary(isDark))),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _customDiamondsController,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() => _isCustomAmount = true),
                      decoration: InputDecoration(
                        hintText: 'Enter diamonds (e.g. 150000)',
                        isDense: true,
                        filled: true,
                        fillColor: AppColors.getSurface(isDark),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Final Transfer Review Card (Section 3)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.getCard(isDark),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.getBorder(isDark)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Final Transfer Review', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.getTextPrimary(isDark))),
                  const Divider(height: 20),
                  _buildReviewRow('Selected Diamonds', '$selectedDiamonds 💎', isDark),
                  _buildReviewRow('Formula Conversion Rate', '12,500 💎 = \$1 USD', isDark),
                  _buildReviewRow('Calculated USD Payout', '\$${calculatedUsd.toStringAsFixed(2)} USD', isDark, isHighlight: true),
                  _buildReviewRow('Platform Fee', '\$0.00 USD', isDark),
                  _buildReviewRow('Remaining Diamonds', '${(wallet.diamonds - selectedDiamonds).clamp(0, 9999999)} 💎', isDark),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Confirm Transfer Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                ),
                onPressed: selectedDiamonds < 25000 || selectedDiamonds > wallet.diamonds
                    ? null
                    : () {
                        _showFinalReviewConfirmation(context, selectedDiamonds, calculatedUsd, primary, isDark);
                      },
                child: Text(
                  'Confirm Transfer (\$${calculatedUsd.toStringAsFixed(2)} USD)',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewRow(String label, String value, bool isDark, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          Text(
            value,
            style: TextStyle(
              fontWeight: isHighlight ? FontWeight.w900 : FontWeight.bold,
              color: isHighlight ? AppColors.getPrimary(isDark) : AppColors.getTextPrimary(isDark),
              fontSize: isHighlight ? 14 : 12,
            ),
          ),
        ],
      ),
    );
  }

  void _showFinalReviewConfirmation(BuildContext context, int diamonds, double usd, Color primary, bool isDark) {
    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        backgroundColor: AppColors.getCard(isDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Confirm Salary Payout', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(isDark))),
        content: Text(
          'You are submitting $diamonds host diamonds for an official payout of \$${usd.toStringAsFixed(2)} USD.',
          style: TextStyle(color: AppColors.getTextSecondary(isDark), fontSize: 13),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dlgCtx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: primary),
            onPressed: () {
              Navigator.pop(dlgCtx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('🎉 Transfer request of \$${usd.toStringAsFixed(2)} USD submitted successfully!'),
                  backgroundColor: Colors.green[800],
                ),
              );
            },
            child: const Text('Submit Payout', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
