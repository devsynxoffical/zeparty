import 'package:flutter/material.dart';
import '../../core/services/api_client.dart';
import '../../core/theme/app_colors.dart';

class CoinExchangeScreen extends StatefulWidget {
  const CoinExchangeScreen({super.key});

  @override
  State<CoinExchangeScreen> createState() => _CoinExchangeScreenState();
}

class _CoinExchangeScreenState extends State<CoinExchangeScreen> {
  final TextEditingController _amountController = TextEditingController();
  bool _isLoading = true;
  bool _isCalculating = false;
  bool _isExecuting = false;

  Map<String, dynamic>? _previewResult;
  String _selectedMode = 'COINS_TO_DIAMONDS'; // COINS_TO_DIAMONDS or DIAMONDS_TO_COINS

  @override
  void initState() {
    super.initState();
    _fetchExchangeStatus();
    _amountController.addListener(_onAmountChanged);
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _fetchExchangeStatus() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiClient.instance.get('/v1/wallet/exchange-transfer/status');
      if (response.statusCode == 200 && response.data?['success'] == true) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
    } catch (_) {}

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _onAmountChanged() {
    final text = _amountController.text.trim();
    if (text.isEmpty) {
      setState(() => _previewResult = null);
      return;
    }
    final amount = double.tryParse(text);
    if (amount != null && amount > 0) {
      _calculatePreview(amount);
    } else {
      setState(() => _previewResult = null);
    }
  }

  Future<void> _calculatePreview(double amount) async {
    setState(() => _isCalculating = true);
    try {
      final response = await ApiClient.instance.post('/v1/wallet/exchange-transfer/preview', data: {
        'type': _selectedMode,
        'amount': amount,
      });

      if (response.statusCode == 200 && response.data?['success'] == true) {
        setState(() {
          _previewResult = response.data['data'] as Map<String, dynamic>?;
          _isCalculating = false;
        });
        return;
      }
    } catch (_) {}

    if (mounted) {
      setState(() => _isCalculating = false);
    }
  }

  Future<void> _executeExchange() async {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) return;

    setState(() => _isExecuting = true);
    try {
      final response = await ApiClient.instance.post('/v1/wallet/exchange-transfer/convert', data: {
        'type': _selectedMode,
        'amount': amount,
      });

      if (mounted) {
        if (response.statusCode == 200 && response.data?['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.data['message']?.toString() ?? 'Exchange completed successfully!'),
              backgroundColor: const Color(0xFF00E676),
            ),
          );
          _amountController.clear();
          _fetchExchangeStatus();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.data['message']?.toString() ?? 'Exchange failed'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Exchange request submitted: $e'),
            backgroundColor: const Color(0xFFFF9100),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExecuting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B071A) : AppColors.getBackground(isDark),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Coin Exchange & Conversion',
          style: TextStyle(
            color: AppColors.getTextPrimary(isDark),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.getTextPrimary(isDark)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFF5C76B)))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // App Standard Banner Header with Overflow Protection
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF5E2495), Color(0xFF3B106E), Color(0xFF210549)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFF5C76B).withValues(alpha: 0.35), width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF3B106E).withValues(alpha: 0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        )
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF5C76B).withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.currency_exchange_rounded, color: Color(0xFFF5C76B), size: 24),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Instant Currency Converter',
                                style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Convert Coins into Diamonds or vice versa seamlessly using real-time rates.',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12, height: 1.35),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Mode Switcher
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedMode = 'COINS_TO_DIAMONDS';
                                _onAmountChanged();
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                gradient: _selectedMode == 'COINS_TO_DIAMONDS'
                                    ? const LinearGradient(colors: [Color(0xFFF5C76B), Color(0xFFD4AF37), Color(0xFFB8812E)])
                                    : null,
                                color: _selectedMode == 'COINS_TO_DIAMONDS' ? null : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  'Coins ➔ Diamonds',
                                  style: TextStyle(
                                    color: _selectedMode == 'COINS_TO_DIAMONDS' ? Colors.black : AppColors.getTextSecondary(isDark),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedMode = 'DIAMONDS_TO_COINS';
                                _onAmountChanged();
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                gradient: _selectedMode == 'DIAMONDS_TO_COINS'
                                    ? const LinearGradient(colors: [Color(0xFFF5C76B), Color(0xFFD4AF37), Color(0xFFB8812E)])
                                    : null,
                                color: _selectedMode == 'DIAMONDS_TO_COINS' ? null : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  'Diamonds ➔ Coins',
                                  style: TextStyle(
                                    color: _selectedMode == 'DIAMONDS_TO_COINS' ? Colors.black : AppColors.getTextSecondary(isDark),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  Text(
                    'Enter Amount to Convert',
                    style: TextStyle(color: AppColors.getTextPrimary(isDark), fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: AppColors.getTextPrimary(isDark), fontSize: 16, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                      hintText: 'e.g. 1000',
                      hintStyle: TextStyle(color: AppColors.getTextSecondary(isDark).withValues(alpha: 0.5), fontSize: 15),
                      suffixIcon: _isCalculating
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFF5C76B)),
                              ),
                            )
                          : const Icon(Icons.calculate_rounded, color: Color(0xFFF5C76B)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFFF5C76B)),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Real-time Preview Calculation Summary
                  if (_previewResult != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5C76B).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFF5C76B).withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.stars_rounded, color: Color(0xFFF5C76B), size: 20),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Conversion Summary',
                                  style: TextStyle(color: Color(0xFFF5C76B), fontWeight: FontWeight.bold, fontSize: 14),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const Divider(color: Colors.white12, height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Receive Output:', style: TextStyle(color: AppColors.getTextSecondary(isDark), fontSize: 13)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${_previewResult!['convertedAmount'] ?? _previewResult!['outputAmount'] ?? '0'} ${_selectedMode == 'COINS_TO_DIAMONDS' ? 'Diamonds' : 'Coins'}',
                                  textAlign: TextAlign.end,
                                  style: TextStyle(color: AppColors.getTextPrimary(isDark), fontWeight: FontWeight.bold, fontSize: 15),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Applied Exchange Rate:', style: TextStyle(color: AppColors.getTextSecondary(isDark), fontSize: 12)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${_previewResult!['rate'] ?? '1.0'}',
                                  textAlign: TextAlign.end,
                                  style: TextStyle(color: AppColors.getTextSecondary(isDark), fontSize: 12, fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 28),

                  // Submit Button with Luxury Gold Gradient
                  GestureDetector(
                    onTap: _isExecuting ? null : _executeExchange,
                    child: Container(
                      width: double.infinity,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFF5C76B), Color(0xFFD4AF37), Color(0xFFB8812E)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFD4AF37).withValues(alpha: 0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: _isExecuting
                          ? const CircularProgressIndicator(color: Colors.black)
                          : const Text(
                              'Confirm Exchange Now',
                              style: TextStyle(color: Colors.black, fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
