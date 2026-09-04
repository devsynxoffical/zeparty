import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../models/live_host_application_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/live_host_provider.dart';

class ApplyLiveHostScreen extends StatefulWidget {
  const ApplyLiveHostScreen({super.key});

  @override
  State<ApplyLiveHostScreen> createState() => _ApplyLiveHostScreenState();
}

class _ApplyLiveHostScreenState extends State<ApplyLiveHostScreen> {
  final _formKey = GlobalKey<FormState>();
  final _legalNameController = TextEditingController(text: 'Danial Khan');
  final _displayNameController = TextEditingController(text: 'Danial Official Live');
  final _dobController = TextEditingController(text: '1998-05-12');
  final _cityController = TextEditingController(text: 'Lahore');
  final _languagesController = TextEditingController(text: 'English, Urdu');
  final _phoneController = TextEditingController(text: '+92 300 1234567');
  final _idNumberController = TextEditingController(text: '35201-1234567-1');
  final _introController = TextEditingController(text: 'Professional music & entertainment host on ZeParty.');

  String _selectedGender = 'Male';
  String _selectedCategory = 'Music';
  String _selectedIdType = 'National ID';

  bool _agreeRules = true;
  bool _agreePayoutTerms = true;

  @override
  void dispose() {
    _legalNameController.dispose();
    _displayNameController.dispose();
    _dobController.dispose();
    _cityController.dispose();
    _languagesController.dispose();
    _phoneController.dispose();
    _idNumberController.dispose();
    _introController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppColors.getPrimary(isDark);
    final authUser = context.watch<AuthProvider>().currentUser;
    final liveHostProv = context.watch<LiveHostProvider>();
    final existingApp = liveHostProv.getApplicationByUserId(authUser.id);

    final isLocked = existingApp != null && (existingApp.status == 'Submitted' || existingApp.status == 'Under Review' || existingApp.status == 'Approved');

    return Scaffold(
      backgroundColor: AppColors.getBackground(isDark),
      appBar: AppBar(
        title: const Text('Become a Live Host (Direct)'),
        backgroundColor: AppColors.getBackground(isDark),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── 1. Policy & Eligibility Header Card ───
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF1E1B2E), Color(0xFF2A2440)]),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: primary.withValues(alpha: 0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.verified_rounded, color: Colors.amber, size: 24),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Direct Live Host System — No Agency Required',
                            style: TextStyle(color: AppColors.getTextPrimary(isDark), fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Live Hosts register directly with ZeParty. No agency fees, no agency commission, and 100% direct salary payouts to your wallet.',
                      style: TextStyle(color: AppColors.getTextSecondary(isDark), fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    const Divider(color: Colors.white24),
                    const SizedBox(height: 8),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Expected Review SLA', style: TextStyle(fontSize: 10, color: Colors.grey)),
                            Text('24 – 48 Hours', style: TextStyle(color: primary, fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Daily Requirement', style: TextStyle(fontSize: 10, color: Colors.grey)),
                            const Text('1 Verified Hour / Day', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Application Status', style: TextStyle(fontSize: 10, color: Colors.grey)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: (existingApp?.status == 'Approved' ? Colors.green : Colors.amber).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                existingApp?.status ?? 'Not Submitted',
                                style: TextStyle(
                                  color: existingApp?.status == 'Approved' ? Colors.greenAccent : Colors.amberAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              // ─── 2. Personal & Identity Info ───
              Text('1. Personal Identity Verification', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(isDark))),
              const SizedBox(height: 12),

              TextFormField(
                controller: _legalNameController,
                readOnly: isLocked,
                style: TextStyle(color: AppColors.getTextPrimary(isDark)),
                decoration: const InputDecoration(labelText: 'Full Legal Name (Matching ID)', border: OutlineInputBorder()),
                validator: (v) => (v == null || v.isEmpty) ? 'Legal name required' : null,
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _displayNameController,
                readOnly: isLocked,
                style: TextStyle(color: AppColors.getTextPrimary(isDark)),
                decoration: const InputDecoration(labelText: 'Streaming Display Name', border: OutlineInputBorder()),
                validator: (v) => (v == null || v.isEmpty) ? 'Display name required' : null,
              ),
              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _dobController,
                      readOnly: isLocked,
                      style: TextStyle(color: AppColors.getTextPrimary(isDark)),
                      decoration: const InputDecoration(labelText: 'Date of Birth', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedGender,
                      dropdownColor: AppColors.getCard(isDark),
                      decoration: const InputDecoration(labelText: 'Gender', border: OutlineInputBorder()),
                      items: ['Male', 'Female', 'Other'].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                      onChanged: isLocked ? null : (v) => setState(() => _selectedGender = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _phoneController,
                readOnly: isLocked,
                style: TextStyle(color: AppColors.getTextPrimary(isDark)),
                decoration: const InputDecoration(labelText: 'Verified Phone / Mobile', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 14),

              DropdownButtonFormField<String>(
                initialValue: _selectedIdType,
                dropdownColor: AppColors.getCard(isDark),
                decoration: const InputDecoration(labelText: 'Government ID Type', border: OutlineInputBorder()),
                items: ['National ID', 'Passport', 'Driving License'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: isLocked ? null : (v) => setState(() => _selectedIdType = v!),
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _idNumberController,
                readOnly: isLocked,
                style: TextStyle(color: AppColors.getTextPrimary(isDark)),
                decoration: const InputDecoration(labelText: 'Government ID Number', border: OutlineInputBorder()),
                validator: (v) => (v == null || v.isEmpty) ? 'ID number required' : null,
              ),
              const SizedBox(height: 22),

              // ─── 3. Streaming Profile & Audition ───
              Text('2. Live Content & Audition', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(isDark))),
              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                dropdownColor: AppColors.getCard(isDark),
                decoration: const InputDecoration(labelText: 'Primary Content Category', border: OutlineInputBorder()),
                items: ['Music', 'Gaming', 'Chat', 'Dance', 'Talk Show'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: isLocked ? null : (v) => setState(() => _selectedCategory = v!),
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _introController,
                readOnly: isLocked,
                maxLines: 2,
                style: TextStyle(color: AppColors.getTextPrimary(isDark)),
                decoration: const InputDecoration(labelText: 'Short Host Bio / Introduction', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 20),

              // Hardware & Liveness Test Card
              Card(
                color: AppColors.getCard(isDark),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.verified_user_rounded, color: Colors.greenAccent),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Real-time Liveness Selfie & ID Match', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                Text('Matched 99.4% to Gov ID • 256-bit Encrypted', style: TextStyle(fontSize: 11, color: AppColors.getTextSecondary(isDark))),
                              ],
                            ),
                          ),
                          const Icon(Icons.check_circle, color: Colors.green),
                        ],
                      ),
                      const Divider(),
                      Row(
                        children: [
                          const Icon(Icons.videocam_rounded, color: Colors.blueAccent),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Camera, Microphone & Network Test', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                Text('1080p HD Video • Clear Audio • 18ms Latency', style: TextStyle(fontSize: 11, color: AppColors.getTextSecondary(isDark))),
                              ],
                            ),
                          ),
                          const Icon(Icons.check_circle, color: Colors.green),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ─── 4. Terms & Submission ───
              CheckboxListTile(
                value: _agreeRules,
                title: const Text('I agree to ZeParty Live Host Rules and 1 Hour Daily Streaming Requirement.', style: TextStyle(fontSize: 12)),
                onChanged: isLocked ? null : (v) => setState(() => _agreeRules = v!),
              ),
              CheckboxListTile(
                value: _agreePayoutTerms,
                title: const Text('I accept Direct Platform Salary Payout Terms (Level 1–25 policy, 0% agency fees).', style: TextStyle(fontSize: 12)),
                onChanged: isLocked ? null : (v) => setState(() => _agreePayoutTerms = v!),
              ),
              const SizedBox(height: 20),

              if (isLocked)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
                  child: const Text(
                    '🔒 Application Submitted & Locked for Review. Verified identity fields cannot be modified while under review.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: primary, foregroundColor: Colors.white),
                    onPressed: () {
                      if (!_formKey.currentState!.validate()) return;
                      if (!_agreeRules || !_agreePayoutTerms) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please accept the Live Host rules and payout terms.'), backgroundColor: Colors.orange));
                        return;
                      }

                      final app = LiveHostApplicationModel(
                        id: 'app_lh_${DateTime.now().millisecondsSinceEpoch}',
                        userId: authUser.id,
                        legalName: _legalNameController.text.trim(),
                        displayName: _displayNameController.text.trim(),
                        dateOfBirth: _dobController.text.trim(),
                        gender: _selectedGender,
                        country: 'GLOBAL',
                        city: _cityController.text.trim(),
                        languages: _languagesController.text.trim(),
                        category: _selectedCategory,
                        schedule: 'Daily 20:00 GMT',
                        phoneOrEmail: _phoneController.text.trim(),
                        govIdType: _selectedIdType,
                        govIdNumber: _idNumberController.text.trim(),
                        frontIdUrl: 'https://example.com/id_front.jpg',
                        backIdUrl: 'https://example.com/id_back.jpg',
                        selfieUrl: authUser.avatarUrl,
                        status: 'Submitted',
                        submittedAt: DateTime.now(),
                      );

                      final msg = liveHostProv.submitApplication(app);
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.green));
                    },
                    child: const Text('Submit Direct Live Host Application', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
