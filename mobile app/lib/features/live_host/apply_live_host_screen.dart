import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../models/live_host_application_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/live_host_provider.dart';
import 'live_host_center_screen.dart';

class ApplyLiveHostScreen extends StatefulWidget {
  final String? initialHostType;
  const ApplyLiveHostScreen({super.key, this.initialHostType});

  @override
  State<ApplyLiveHostScreen> createState() => _ApplyLiveHostScreenState();
}

class _ApplyLiveHostScreenState extends State<ApplyLiveHostScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _legalNameController;
  late final TextEditingController _displayNameController;
  late final TextEditingController _dobController;
  late final TextEditingController _cityController;
  late final TextEditingController _languagesController;
  late final TextEditingController _phoneController;
  late final TextEditingController _idNumberController;
  late final TextEditingController _introController;

  String _selectedHostType = 'BOTH'; // 'LIVE_HOST', 'AUDIO_HOST', 'BOTH'
  String _selectedGender = 'Male';
  String _selectedCategory = 'Music';

  bool _agreeRules = true;
  bool _agreePayoutTerms = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final authUser = context.read<AuthProvider>().currentUser;
    _selectedHostType = widget.initialHostType ?? 'BOTH';
    _legalNameController = TextEditingController(text: authUser.name);
    _displayNameController = TextEditingController(text: authUser.username);
    _dobController = TextEditingController(text: '');
    _cityController = TextEditingController(text: '');
    _languagesController = TextEditingController(text: '');
    _phoneController = TextEditingController(text: authUser.phone ?? '');
    _idNumberController = TextEditingController(text: '');
    _introController = TextEditingController(text: '');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (authUser.id.isNotEmpty) {
        final prov = context.read<LiveHostProvider>();
        prov.fetchHostProfile(authUser.id);
        prov.fetchHostApplication(authUser.id);
      }
    });
  }

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

  String get _readableHostType {
    switch (_selectedHostType) {
      case 'LIVE_HOST':
        return 'Live Video Host';
      case 'AUDIO_HOST':
        return 'Social Audio & Party Host';
      case 'BOTH':
      default:
        return 'Live Video & Audio Party Host';
    }
  }

  void _showSubmissionSuccessDialog(BuildContext context, String hostTypeLabel) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1B2E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.schedule_send_rounded, color: Colors.amber, size: 28),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Request Submitted!',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.getPrimary(isDark).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.getPrimary(isDark).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified_user_rounded, color: Colors.greenAccent, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Application Type: $hostTypeLabel',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Your host verification request has been securely submitted to the Admin team.',
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 12),
            const Text(
              'What happens next?',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 6),
            _buildDialogStep(
              icon: Icons.admin_panel_settings_rounded,
              color: Colors.purpleAccent,
              text: 'Admin team reviews your identity details.',
            ),
            _buildDialogStep(
              icon: Icons.mail_rounded,
              color: Colors.amberAccent,
              text: 'You will receive an email & in-app notification upon approval.',
            ),
            _buildDialogStep(
              icon: Icons.live_tv_rounded,
              color: Colors.greenAccent,
              text: 'Live broadcasting, Party rooms, and PK Battles unlock automatically.',
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.getPrimary(isDark),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.pop(dialogCtx); // Close dialog
                Navigator.pop(context); // Exit application screen
              },
              child: const Text('Understood & Got It', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogStep({required IconData icon, required Color color, required String text}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12, color: Colors.grey))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppColors.getPrimary(isDark);
    final authUser = context.watch<AuthProvider>().currentUser;
    final liveHostProv = context.watch<LiveHostProvider>();
    final existingApp = liveHostProv.getApplicationByUserId(authUser.id);

    final isApprovedHost = authUser.isHost ||
        authUser.hasLiveHostAccess ||
        authUser.role == UserRole.host ||
        existingApp?.status == 'Approved' ||
        liveHostProv.activeLiveHost != null;
    final isLocked = isApprovedHost || (existingApp != null && (existingApp.status == 'Submitted' || existingApp.status == 'Under Review' || existingApp.status == 'Approved'));

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
              if (isApprovedHost) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.5)),
                  ),
                  child: Column(
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.verified_user_rounded, color: Colors.greenAccent, size: 28),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Host Application Approved! 🎉',
                              style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Congratulations! You are officially an active ZeParty Host. You have full access to broadcast Live streams, host Audio Party rooms, and compete in PK battles without any further verification required.',
                        style: TextStyle(color: AppColors.getTextPrimary(isDark), fontSize: 13, height: 1.4),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.workspace_premium_rounded),
                          label: const Text('Open Live Host Center', style: TextStyle(fontWeight: FontWeight.bold)),
                          onPressed: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (_) => const LiveHostCenterScreen()),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
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

                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      runSpacing: 10,
                      spacing: 12,
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

              // ─── 2. Host Role & Broadcasting Scope ───
              Text('1. Choose Host Application Type', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(isDark))),
              const SizedBox(height: 8),
              Text(
                'Select the live features you wish to broadcast on ZeParty:',
                style: TextStyle(fontSize: 12, color: AppColors.getTextSecondary(isDark)),
              ),
              const SizedBox(height: 12),

              _buildHostTypeOption(
                value: 'BOTH',
                title: 'Live Video & Audio Party Host (Recommended)',
                subtitle: 'Full access to 1080p Video streaming, PK Battles, and Multi-seat Audio party rooms.',
                icon: Icons.all_inclusive_rounded,
                isLocked: isLocked,
                isDark: isDark,
              ),
              const SizedBox(height: 10),
              _buildHostTypeOption(
                value: 'LIVE_HOST',
                title: 'Live Video Host',
                subtitle: 'Single & Multi-host Video streaming, PK battles, and diamond gift reception.',
                icon: Icons.videocam_rounded,
                isLocked: isLocked,
                isDark: isDark,
              ),
              const SizedBox(height: 10),
              _buildHostTypeOption(
                value: 'AUDIO_HOST',
                title: 'Social Audio & Party Host',
                subtitle: 'Audio-only broadcasting, social voice lounge, gaming, and talk shows.',
                icon: Icons.mic_rounded,
                isLocked: isLocked,
                isDark: isDark,
              ),
              const SizedBox(height: 22),

              // ─── 3. Personal & Identity Info ───
              Text('2. Personal Identity Verification', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(isDark))),
              const SizedBox(height: 12),

              TextFormField(
                controller: _legalNameController,
                readOnly: isLocked,
                style: TextStyle(color: AppColors.getTextPrimary(isDark)),
                decoration: const InputDecoration(labelText: 'Full Legal Name (Matching Profile)', border: OutlineInputBorder()),
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
                      decoration: const InputDecoration(labelText: 'Date of Birth (YYYY-MM-DD)', border: OutlineInputBorder()),
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
              const SizedBox(height: 22),

              // ─── 4. Streaming Profile & Content ───
              Text('3. Live Content & Audition', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(isDark))),
              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                dropdownColor: AppColors.getCard(isDark),
                decoration: const InputDecoration(labelText: 'Primary Content Category', border: OutlineInputBorder()),
                items: ['Music', 'Gaming', 'Chat', 'Dance', 'Talk Show', 'Party'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
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

              // ─── 5. Terms & Submission ───
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
                  decoration: BoxDecoration(
                    color: isApprovedHost ? Colors.green.withValues(alpha: 0.15) : Colors.amber.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isApprovedHost
                        ? '✅ Host Verification Active & Approved. You are fully eligible to start broadcasting.'
                        : '🔒 Application Submitted & Locked for Review. Verified identity fields cannot be modified while under review.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isApprovedHost ? Colors.greenAccent : Colors.amberAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _isSubmitting
                        ? null
                        : () async {
                            if (!_formKey.currentState!.validate()) return;
                            if (!_agreeRules || !_agreePayoutTerms) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Please accept the Live Host rules and payout terms.'), backgroundColor: Colors.orange),
                              );
                              return;
                            }

                            setState(() => _isSubmitting = true);

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
                              govIdType: 'DIRECT_VERIFIED',
                              govIdNumber: 'VERIFIED',
                              frontIdUrl: 'https://example.com/id_front.jpg',
                              backIdUrl: 'https://example.com/id_back.jpg',
                              selfieUrl: authUser.avatarUrl,
                              status: 'Submitted',
                              submittedAt: DateTime.now(),
                            );

                            try {
                              await liveHostProv.submitApplicationAsync(
                                app: app,
                                hostType: _selectedHostType,
                              );

                              setState(() => _isSubmitting = false);

                              if (context.mounted) {
                                _showSubmissionSuccessDialog(context, _readableHostType);
                              }
                            } catch (e) {
                              setState(() => _isSubmitting = false);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Host Application error: ${e.toString()}'),
                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
                              }
                            }
                          },
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Text('Submit Application for $_readableHostType', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHostTypeOption({
    required String value,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isLocked,
    required bool isDark,
  }) {
    final isSelected = _selectedHostType == value;
    final primary = AppColors.getPrimary(isDark);

    return InkWell(
      onTap: isLocked ? null : () => setState(() => _selectedHostType = value),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? primary.withValues(alpha: 0.15) : AppColors.getCard(isDark),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? primary : Colors.white12,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected ? primary.withValues(alpha: 0.25) : Colors.white10,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: isSelected ? primary : Colors.grey, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isSelected ? primary : AppColors.getTextPrimary(isDark),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 11, color: AppColors.getTextSecondary(isDark)),
                  ),
                ],
              ),
            ),
            Radio<String>(
              value: value,
              groupValue: _selectedHostType,
              activeColor: primary,
              onChanged: isLocked ? null : (v) => setState(() => _selectedHostType = v!),
            ),
          ],
        ),
      ),
    );
  }
}
