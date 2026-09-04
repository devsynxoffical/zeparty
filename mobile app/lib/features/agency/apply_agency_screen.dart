import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/agency_provider.dart';
import '../../providers/auth_provider.dart';
import 'agency_center_screen.dart';

class ApplyAgencyScreen extends StatefulWidget {
  const ApplyAgencyScreen({super.key});

  @override
  State<ApplyAgencyScreen> createState() => _ApplyAgencyScreenState();
}

class _ApplyAgencyScreenState extends State<ApplyAgencyScreen> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppColors.getPrimary(isDark);
    final authUser = context.watch<AuthProvider>().currentUser;

    return Scaffold(
      backgroundColor: AppColors.getBackground(isDark),
      appBar: AppBar(
        title: const Text('Apply / Create Agency'),
        backgroundColor: AppColors.getBackground(isDark),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Register New Agency', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(isDark))),
            const SizedBox(height: 8),
            Text('Submit your agency details to register your agency and open Agency Center.', style: TextStyle(fontSize: 13, color: AppColors.getTextSecondary(isDark))),
            const SizedBox(height: 24),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Agency Name', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Agency Description & Focus', border: OutlineInputBorder()),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: primary, foregroundColor: Colors.white),
                onPressed: () {
                  final name = _nameController.text.trim();
                  final desc = _descController.text.trim();
                  if (name.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter an agency name.')));
                    return;
                  }

                  // 1. Register Agency in Provider
                  context.read<AgencyProvider>().registerAgency(
                    name: name,
                    description: desc.isEmpty ? 'Official ZeParty Agency' : desc,
                    ownerUserId: authUser.id,
                    ownerName: authUser.name,
                  );

                  // 2. Notify User
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('🎉 Agency created successfully! Opening Agency Center...'),
                      backgroundColor: Colors.green,
                    ),
                  );

                  // 3. Directly open AgencyCenterScreen for testing purpose
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const AgencyCenterScreen()),
                  );
                },
                child: const Text('Create Agency & Open Center', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
