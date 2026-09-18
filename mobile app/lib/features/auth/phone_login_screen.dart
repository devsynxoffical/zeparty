import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/design/gold_button.dart';
import '../../widgets/app_logo.dart';
import '../../providers/auth_provider.dart';
import 'otp_screen.dart';

class CountryItem {
  final String name;
  final String code;
  final String flag;
  final String dialCode;

  const CountryItem({
    required this.name,
    required this.code,
    required this.flag,
    required this.dialCode,
  });
}

class PhoneLoginScreen extends StatefulWidget {
  const PhoneLoginScreen({super.key});

  @override
  State<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends State<PhoneLoginScreen> {
  final _phoneController = TextEditingController();

  static const List<CountryItem> _countries = [
    CountryItem(name: 'United States', code: 'US', flag: '🇺🇸', dialCode: '+1'),
    CountryItem(name: 'United Kingdom', code: 'GB', flag: '🇬🇧', dialCode: '+44'),
    CountryItem(name: 'Canada', code: 'CA', flag: '🇨🇦', dialCode: '+1'),
    CountryItem(name: 'India', code: 'IN', flag: '🇮🇳', dialCode: '+91'),
    CountryItem(name: 'Pakistan', code: 'PK', flag: '🇵🇰', dialCode: '+92'),
    CountryItem(name: 'Saudi Arabia', code: 'SA', flag: '🇸🇦', dialCode: '+966'),
    CountryItem(name: 'United Arab Emirates', code: 'AE', flag: '🇦🇪', dialCode: '+971'),
    CountryItem(name: 'Germany', code: 'DE', flag: '🇩🇪', dialCode: '+49'),
    CountryItem(name: 'France', code: 'FR', flag: '🇫🇷', dialCode: '+33'),
    CountryItem(name: 'Australia', code: 'AU', flag: '🇦🇺', dialCode: '+61'),
    CountryItem(name: 'Brazil', code: 'BR', flag: '🇧🇷', dialCode: '+55'),
    CountryItem(name: 'Japan', code: 'JP', flag: '🇯🇵', dialCode: '+81'),
  ];

  CountryItem _selectedCountry = _countries.first;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _showCountryPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = _countries.where((c) {
              final query = searchQuery.toLowerCase();
              return c.name.toLowerCase().contains(query) || c.dialCode.contains(query) || c.code.toLowerCase().contains(query);
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.getBorder(Theme.of(context).brightness == Brightness.dark),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Select Country', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  TextField(
                    onChanged: (val) => setModalState(() => searchQuery = val),
                    decoration: InputDecoration(
                      hintText: 'Search country or code...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        return ListTile(
                          leading: Text(item.flag, style: const TextStyle(fontSize: 24)),
                          title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                          trailing: Text(item.dialCode, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                          onTap: () {
                            setState(() => _selectedCountry = item);
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _sendOtp() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty || phone.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid phone number')),
      );
      return;
    }

    final fullNumber = '${_selectedCountry.dialCode}$phone'.replaceAll(' ', '');
    final auth = context.read<AuthProvider>();
    final success = await auth.requestOtp(fullNumber);

    if (mounted) {
      if (success) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (c) => OtpScreen(phoneNumber: fullNumber)),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(auth.errorMessage ?? 'Failed to send OTP. Please try again.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Phone Sign In'), elevation: 0),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(
                child: AppLogo(
                  size: 72,
                  showGlow: true,
                  showBorder: true,
                  borderRadius: 18,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Enter Mobile Number',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'We will send a 4-digit verification SMS code',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 32),

              // Country & Phone Row
              Row(
                children: [
                  GestureDetector(
                    onTap: _showCountryPicker,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: AppColors.getBorder(isDark).withValues(alpha: 0.6),
                          width: 1.2,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        color: AppColors.getSurface(isDark),
                      ),
                      child: Row(
                        children: [
                          Text(_selectedCountry.flag, style: const TextStyle(fontSize: 22)),
                          const SizedBox(width: 6),
                          Text(_selectedCountry.dialCode, style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(isDark))),
                          const Icon(Icons.arrow_drop_down, size: 20),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        hintText: 'Phone number',
                        filled: true,
                        fillColor: AppColors.getSurface(isDark),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: AppColors.getBorder(isDark), width: 1.2),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: AppColors.getBorder(isDark).withValues(alpha: 0.6), width: 1.2),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: AppColors.getPrimary(isDark), width: 1.8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              GoldButton(
                text: 'Send OTP Verification',
                onPressed: context.watch<AuthProvider>().isLoading ? null : _sendOtp,
                isLoading: context.watch<AuthProvider>().isLoading,
                height: 52,
                radius: 14,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
