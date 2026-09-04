import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../widgets/design/premium_card.dart';
import '../../../../widgets/design/gold_button.dart';
import '../../providers/p2p_provider.dart';
import '../../models/p2p_offer.dart';
import '../../../../providers/auth_provider.dart';

class CreateOfferScreen extends StatefulWidget {
  const CreateOfferScreen({super.key});

  @override
  State<CreateOfferScreen> createState() => _CreateOfferScreenState();
}

class _CreateOfferScreenState extends State<CreateOfferScreen> {
  final _formKey = GlobalKey<FormState>();
  String _offerType = 'sell'; // 'buy' or 'sell'
  double _fiatPrice = 0.05;
  int _totalCoins = 1000;
  int _minLimit = 10;
  int _maxLimit = 1000;
  final List<String> _selectedPayments = ['Bank Transfer'];

  final List<String> _availablePayments = ['Bank Transfer', 'PayPal', 'Zelle', 'CashApp'];

  void _submitOffer() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      final auth = context.read<AuthProvider>();
      final user = auth.currentUser;
      
      final newOffer = P2POffer(
        id: const Uuid().v4(),
        sellerId: user.id,
        sellerName: user.name,
        sellerAvatar: user.avatarUrl,
        type: _offerType,
        totalCoins: _totalCoins,
        availableCoins: _totalCoins,
        fiatPricePerCoin: _fiatPrice,
        fiatCurrency: 'USD',
        acceptedPaymentMethods: _selectedPayments,
        minLimit: _minLimit,
        maxLimit: _maxLimit,
        status: 'active',
        createdAt: DateTime.now(),
      );

      context.read<P2PProvider>().createOffer(newOffer);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Offer Created Successfully!'), backgroundColor: AppColors.success),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = AppColors.getPrimary(isDark);

    return Scaffold(
      backgroundColor: AppColors.getBackground(isDark),
      appBar: AppBar(
        title: const Text('Create Offer'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'I want to...',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildChoiceChip('Sell Coins', _offerType == 'sell', isDark, primaryColor, () {
                      setState(() => _offerType = 'sell');
                    }),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildChoiceChip('Buy Coins', _offerType == 'buy', isDark, primaryColor, () {
                      setState(() => _offerType = 'buy');
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              PremiumCard(
                padding: const EdgeInsets.all(20),
                radius: 16,
                child: Column(
                  children: [
                    _buildTextField(
                      isDark: isDark,
                      label: 'Price per Coin (USD)',
                      initialValue: _fiatPrice.toString(),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onSaved: (val) => _fiatPrice = double.tryParse(val ?? '') ?? 0.0,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      isDark: isDark,
                      label: 'Total Coins',
                      initialValue: _totalCoins.toString(),
                      keyboardType: TextInputType.number,
                      onSaved: (val) => _totalCoins = int.tryParse(val ?? '') ?? 0,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            isDark: isDark,
                            label: 'Min Limit (\$)',
                            initialValue: _minLimit.toString(),
                            keyboardType: TextInputType.number,
                            onSaved: (val) => _minLimit = int.tryParse(val ?? '') ?? 0,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField(
                            isDark: isDark,
                            label: 'Max Limit (\$)',
                            initialValue: _maxLimit.toString(),
                            keyboardType: TextInputType.number,
                            onSaved: (val) => _maxLimit = int.tryParse(val ?? '') ?? 0,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Payment Methods',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _availablePayments.map((method) {
                  final isSelected = _selectedPayments.contains(method);
                  return FilterChip(
                    label: Text(method),
                    selected: isSelected,
                    selectedColor: primaryColor.withValues(alpha: 0.2),
                    checkmarkColor: primaryColor,
                    labelStyle: TextStyle(
                      color: isSelected ? primaryColor : AppColors.getTextSecondary(isDark),
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    backgroundColor: AppColors.getCard(isDark),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: isSelected ? primaryColor : AppColors.getBorder(isDark)),
                    ),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedPayments.add(method);
                        } else {
                          _selectedPayments.remove(method);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: GoldButton(
                  text: 'Post Offer',
                  onPressed: _submitOffer,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChoiceChip(String text, bool isSelected, bool isDark, Color primaryColor, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? primaryColor.withValues(alpha: 0.15) : AppColors.getCard(isDark),
          border: Border.all(color: isSelected ? primaryColor : AppColors.getBorder(isDark), width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isSelected ? primaryColor : AppColors.getTextSecondary(isDark),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required bool isDark,
    required String label,
    required String initialValue,
    required TextInputType keyboardType,
    required FormFieldSetter<String> onSaved,
  }) {
    return TextFormField(
      initialValue: initialValue,
      keyboardType: keyboardType,
      style: TextStyle(color: AppColors.getTextPrimary(isDark)),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: AppColors.getTextSecondary(isDark)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.getBorder(isDark)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.getPrimary(isDark)),
        ),
      ),
      validator: (val) => val == null || val.isEmpty ? 'Required' : null,
      onSaved: onSaved,
    );
  }
}
