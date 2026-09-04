import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/design/gold_button.dart';
import '../../widgets/app_logo.dart';
import '../../providers/host_agency_provider.dart';

class BecomeHostScreen extends StatefulWidget {
  const BecomeHostScreen({super.key});

  @override
  State<BecomeHostScreen> createState() => _BecomeHostScreenState();
}

class _BecomeHostScreenState extends State<BecomeHostScreen> {
  final _realNameController = TextEditingController();
  final _idNumberController = TextEditingController();
  final _bioController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onPrimary = AppColors.onPrimary(isDark: isDark);

    return Scaffold(
      appBar: AppBar(title: const Text('Become an Official Host')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: AppColors.getAccentGradient(isDark),
                borderRadius: BorderRadius.circular(20),
                boxShadow: AppColors.primaryGlow(isDark, alpha: 0.28, blur: 16),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppLogo(size: 48, showBorder: true, borderRadius: 12),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Host Privileges & Earnings', style: TextStyle(color: onPrimary, fontWeight: FontWeight.bold, fontSize: 17)),
                        const SizedBox(height: 6),
                        Text('• Cash out gift earnings to USD bank accounts\n• Official Host verified badge\n• Higher traffic recommendation on Explore page', style: TextStyle(color: onPrimary, fontSize: 12, height: 1.4)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            CustomTextField(
              label: 'Full Legal Name',
              hint: 'e.g. Danial Khan',
              controller: _realNameController,
            ),
            const SizedBox(height: 16),

            CustomTextField(
              label: 'ID Card / Passport Number',
              hint: 'e.g. A987102948',
              controller: _idNumberController,
            ),
            const SizedBox(height: 16),

            CustomTextField(
              label: 'Streaming Experience & Talent Bio',
              hint: 'Tell us about your content specialty...',
              controller: _bioController,
            ),

            const SizedBox(height: 32),

            GoldButton(
              text: 'Submit Host Application',
              onPressed: () {
                context.read<HostAgencyProvider>().applyForHost(
                      _realNameController.text,
                      _idNumberController.text,
                      _bioController.text,
                    );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Host application submitted! Application status: Pending Approval.')),
                );
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}
