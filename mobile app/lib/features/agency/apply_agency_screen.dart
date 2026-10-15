import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/agency_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/user_model.dart';
import 'agency_center_screen.dart';

class ApplyAgencyScreen extends StatefulWidget {
  const ApplyAgencyScreen({super.key});

  @override
  State<ApplyAgencyScreen> createState() => _ApplyAgencyScreenState();
}

class _ApplyAgencyScreenState extends State<ApplyAgencyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _phoneController = TextEditingController();

  final List<TextEditingController> _hostIdControllers = List.generate(
    5,
    (_) => TextEditingController(),
  );

  bool _isResubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _phoneController.dispose();
    for (final c in _hostIdControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _submitApplication(UserModel authUser, AgencyProvider agencyProv) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validate phone number format (must contain country code, e.g. +1..., +92..., +971...)
    final phone = _phoneController.text.trim();
    if (!phone.startsWith('+') || phone.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid phone number with country code (e.g. +1 555 123 4567 or +92 300 1234567).'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    // Validate that all 5 host IDs are entered
    final hostIds = _hostIdControllers.map((c) => c.text.trim()).toList();
    if (hostIds.any((id) => id.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All five external host IDs must be provided.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    // Validate that all 5 host IDs are distinct (no duplicates)
    final distinctHostIds = hostIds.toSet();
    if (distinctHostIds.length != 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All five external host IDs must be distinct. Duplicate IDs are not permitted.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final success = await agencyProv.submitAgencyApplication(
      applicantUserId: authUser.id,
      applicantZePartyId: authUser.id.length > 8 ? authUser.id.substring(0, 8) : authUser.id,
      applicantName: authUser.name,
      applicantAvatar: authUser.avatarUrl,
      agencyName: _nameController.text.trim(),
      description: _descController.text.trim(),
      phoneNumber: phone,
      externalHostIds: hostIds,
    );

    if (!mounted) return;

    if (success) {
      setState(() {
        _isResubmitting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 Agency application submitted successfully! Awaiting admin review.'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to submit application. Please check all fields and try again.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _showAdminReviewQueue(BuildContext context, AgencyProvider agencyProv, UserModel authUser, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: BoxDecoration(
            color: AppColors.getCard(isDark),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Admin: Agency Applications', style: TextStyle(color: AppColors.getTextPrimary(isDark), fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: agencyProv.adminApplicationQueue.isEmpty
                    ? Center(
                        child: Text('No applications in queue.', style: TextStyle(color: AppColors.getTextSecondary(isDark))),
                      )
                    : ListView.separated(
                        itemCount: agencyProv.adminApplicationQueue.length,
                        separatorBuilder: (_, index) => const SizedBox(height: 14),
                        itemBuilder: (c, idx) {
                          final app = agencyProv.adminApplicationQueue[idx];
                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.getBackground(isDark),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.getBorder(isDark)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        app.agencyName,
                                        style: TextStyle(color: AppColors.getTextPrimary(isDark), fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: app.isPending ? Colors.amber.withValues(alpha: 0.2) : (app.isApproved ? Colors.green.withValues(alpha: 0.2) : Colors.red.withValues(alpha: 0.2)),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        app.status,
                                        style: TextStyle(
                                          color: app.isPending ? Colors.amber : (app.isApproved ? Colors.green : Colors.red),
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text('Applicant: ${app.applicantName} (ZeParty ID: ${app.applicantZePartyId})', style: TextStyle(color: AppColors.getTextSecondary(isDark), fontSize: 12)),
                                Text('Phone: ${app.phoneNumber}', style: TextStyle(color: AppColors.getTextSecondary(isDark), fontSize: 12)),
                                Text('Description: ${app.description}', style: TextStyle(color: AppColors.getTextSecondary(isDark), fontSize: 12)),
                                const SizedBox(height: 8),
                                Text('External App Host References (5):', style: TextStyle(color: AppColors.getPrimary(isDark), fontSize: 12, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: app.externalHostIds.asMap().entries.map((e) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.purple.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text('Host ${e.key + 1}: ${e.value}', style: const TextStyle(color: Colors.purpleAccent, fontSize: 11)),
                                    );
                                  }).toList(),
                                ),
                                if (app.isPending) ...[
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          icon: const Icon(Icons.check_circle_rounded, size: 16),
                                          label: const Text('Approve'),
                                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                                          onPressed: () async {
                                            await agencyProv.approveAgencyApplication(
                                              applicationId: app.id,
                                              adminUserId: authUser.id,
                                            );
                                            if (c.mounted) Navigator.pop(ctx);
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          icon: const Icon(Icons.cancel_rounded, size: 16),
                                          label: const Text('Reject'),
                                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                                          onPressed: () {
                                            final reasonCtrl = TextEditingController(text: 'Insufficient external host references or documentation.');
                                            showDialog(
                                              context: context,
                                              builder: (d) => AlertDialog(
                                                title: const Text('Rejection Reason'),
                                                content: TextField(
                                                  controller: reasonCtrl,
                                                  decoration: const InputDecoration(labelText: 'Reason for rejection'),
                                                ),
                                                actions: [
                                                  TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')),
                                                  ElevatedButton(
                                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                                    onPressed: () async {
                                                      Navigator.pop(d);
                                                      await agencyProv.rejectAgencyApplication(
                                                        applicationId: app.id,
                                                        adminUserId: authUser.id,
                                                        rejectionReason: reasonCtrl.text.trim(),
                                                      );
                                                      if (c.mounted) Navigator.pop(ctx);
                                                    },
                                                    child: const Text('Confirm Reject', style: TextStyle(color: Colors.white)),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppColors.getPrimary(isDark);
    final authUser = context.watch<AuthProvider>().currentUser;
    final agencyProv = context.watch<AgencyProvider>();
    final myApp = agencyProv.myApplication;
    final isAdmin = authUser.role == UserRole.admin;

    return Scaffold(
      backgroundColor: AppColors.getBackground(isDark),
      appBar: AppBar(
        title: const Text('Apply / Create Agency', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: AppColors.getBackground(isDark),
        actions: [
          if (isAdmin || agencyProv.adminApplicationQueue.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.admin_panel_settings_rounded, color: Colors.amberAccent),
              tooltip: 'Admin Application Queue',
              onPressed: () => _showAdminReviewQueue(context, agencyProv, authUser, isDark),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // If user has a pending or rejected application and is not resubmitting:
            if (myApp != null && !_isResubmitting) ...[
              if (myApp.isPending) ...[
                // PENDING STATUS CARD
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.4), width: 1.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(color: Colors.amber, shape: BoxShape.circle),
                            child: const Icon(Icons.hourglass_top_rounded, color: Colors.black, size: 20),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Application Pending Admin Approval',
                              style: TextStyle(color: Colors.amber, fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Your application for "${myApp.agencyName}" has been submitted and is currently under administrative evaluation.',
                        style: TextStyle(color: AppColors.getTextPrimary(isDark), fontSize: 13, height: 1.4),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Submitted on: ${myApp.submittedAt.toString().substring(0, 16)}',
                        style: TextStyle(color: AppColors.getTextSecondary(isDark), fontSize: 11),
                      ),
                      const Divider(height: 24),
                      Text('Submitted Information:', style: TextStyle(color: AppColors.getTextPrimary(isDark), fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 6),
                      Text('• Agency Name: ${myApp.agencyName}', style: TextStyle(color: AppColors.getTextSecondary(isDark), fontSize: 12)),
                      Text('• Description: ${myApp.description}', style: TextStyle(color: AppColors.getTextSecondary(isDark), fontSize: 12)),
                      Text('• Phone: ${myApp.phoneNumber}', style: TextStyle(color: AppColors.getTextSecondary(isDark), fontSize: 12)),
                      const SizedBox(height: 6),
                      Text('• External Host References (5):', style: TextStyle(color: AppColors.getTextSecondary(isDark), fontSize: 12)),
                      ...myApp.externalHostIds.asMap().entries.map(
                            (e) => Padding(
                              padding: const EdgeInsets.only(left: 12, top: 2),
                              child: Text('  Host ID ${e.key + 1}: ${e.value}', style: TextStyle(color: AppColors.getTextSecondary(isDark), fontSize: 12)),
                            ),
                          ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline_rounded, color: Colors.amber, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Submitting an application does not grant Agency Owner privileges until approved by administration. Duplicate submissions are disabled while pending.',
                                style: TextStyle(color: AppColors.getTextSecondary(isDark), fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ] else if (myApp.isRejected) ...[
                // REJECTED STATUS CARD
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.4), width: 1.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                            child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Application Not Approved',
                              style: TextStyle(color: Colors.redAccent, fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Reason: ${myApp.rejectionReason ?? 'Application did not meet agency criteria.'}',
                        style: TextStyle(color: AppColors.getTextPrimary(isDark), fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: primary, foregroundColor: Colors.white),
                        onPressed: () {
                          setState(() {
                            _isResubmitting = true;
                            _nameController.text = myApp.agencyName;
                            _descController.text = myApp.description;
                            _phoneController.text = myApp.phoneNumber;
                            for (int i = 0; i < myApp.externalHostIds.length && i < 5; i++) {
                              _hostIdControllers[i].text = myApp.externalHostIds[i];
                            }
                          });
                        },
                        child: const Text('Update Details & Re-apply'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ] else if (myApp.isApproved) ...[
                // APPROVED STATUS CARD
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.green.withValues(alpha: 0.4), width: 1.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                            child: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Application Approved! 🎉',
                              style: TextStyle(color: Colors.green, fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Congratulations! Your agency "${myApp.agencyName}" has been approved. You are now designated as Agency Owner.',
                        style: TextStyle(color: AppColors.getTextPrimary(isDark), fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                          onPressed: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (_) => const AgencyCenterScreen()),
                            );
                          },
                          child: const Text('Open Agency Center', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ] else ...[
              // APPLICATION FORM
              Text(
                'Register New Agency',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(isDark)),
              ),
              const SizedBox(height: 8),
              Text(
                'Submit your agency details to apply for an agency. Administrative review and approval is required before Agency Center is activated.',
                style: TextStyle(fontSize: 13, color: AppColors.getTextSecondary(isDark), height: 1.4),
              ),
              const SizedBox(height: 24),

              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Field 1: Agency Name
                    TextFormField(
                      controller: _nameController,
                      style: TextStyle(color: AppColors.getTextPrimary(isDark)),
                      decoration: const InputDecoration(
                        labelText: 'Agency Name',
                        hintText: 'Enter your agency name',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.business_rounded),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Agency Name is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Field 2: Description & Focus
                    TextFormField(
                      controller: _descController,
                      maxLines: 3,
                      style: TextStyle(color: AppColors.getTextPrimary(isDark)),
                      decoration: const InputDecoration(
                        labelText: 'Agency Description & Focus',
                        hintText: 'Describe your agency, content focus, and management plans',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                        prefixIcon: Icon(Icons.description_rounded),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Agency Description is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Field 3: Phone Number with Country Code
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      style: TextStyle(color: AppColors.getTextPrimary(isDark)),
                      decoration: const InputDecoration(
                        labelText: 'Phone Number with Country Code',
                        hintText: '+1 555 123 4567 or +92 300 1234567',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.phone_rounded),
                        helperText: 'Must include international country code (e.g. +1, +44, +92, +971)',
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Phone number with country code is required';
                        }
                        if (!val.trim().startsWith('+')) {
                          return 'Phone number must start with country code "+"';
                        }
                        if (val.trim().length < 8) {
                          return 'Please enter a valid phone number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // Field 4: Five Host References from Another App
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.getCard(isDark),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.getBorder(isDark)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.purple.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.groups_rounded, color: Colors.purpleAccent, size: 20),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Five External Host References',
                                  style: TextStyle(
                                    color: AppColors.getTextPrimary(isDark),
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Enter the five host IDs you plan to bring from another app. These are external app references for administrative evaluation and do not link to existing ZeParty accounts.',
                            style: TextStyle(color: AppColors.getTextSecondary(isDark), fontSize: 12, height: 1.4),
                          ),
                          const SizedBox(height: 16),

                          // 5 Separate Host ID Fields
                          ...List.generate(5, (index) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: TextFormField(
                                controller: _hostIdControllers[index],
                                style: TextStyle(color: AppColors.getTextPrimary(isDark)),
                                decoration: InputDecoration(
                                  labelText: 'External Host ID ${index + 1}',
                                  hintText: 'e.g. host_id_${index + 1} from external app',
                                  border: const OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.person_pin_rounded, color: Colors.purple.shade200, size: 20),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                ),
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) {
                                    return 'Host ID ${index + 1} is required';
                                  }
                                  return null;
                                },
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Submission Button: "Submit Agency Application"
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                        ),
                        onPressed: agencyProv.isLoading ? null : () => _submitApplication(authUser, agencyProv),
                        child: agencyProv.isLoading
                            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                            : const Text('Submit Agency Application', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
