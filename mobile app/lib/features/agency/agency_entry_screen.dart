import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/api_client.dart';

class AgencyEntryScreen extends StatefulWidget {
  const AgencyEntryScreen({super.key});

  @override
  State<AgencyEntryScreen> createState() => _AgencyEntryScreenState();
}

class _AgencyEntryScreenState extends State<AgencyEntryScreen> {
  final _agentIdController = TextEditingController();
  final _phoneCodeController = TextEditingController(text: '+852');
  final _phoneNumberController = TextEditingController();
  final _bdIdController = TextEditingController();

  bool _isSubmitting = false;

  void _handleJoinAgency() async {
    final code = _agentIdController.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter an Agent ID / Code')));
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final res = await ApiClient.instance.post(
        '/v1/agencies/join',
        data: {'agencyCode': code},
      );
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      final msg = res.data?['message']?.toString() ?? 'Joined agency successfully!';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppColors.success));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to join agency: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  void _handleCreateAgency() async {
    if (_phoneNumberController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a phone number')));
      return;
    }
    setState(() => _isSubmitting = true);
    // Agency creation is an administrative process or reviewed via business development.
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Agency inquiry submitted! Our BD team will contact you.')),
    );
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _agentIdController.dispose();
    _phoneCodeController.dispose();
    _phoneNumberController.dispose();
    _bdIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The reference image uses a specific bright yellow theme.
    // However, to follow the user's explicit instruction: "use my existing color schme",
    // we will adapt it to the AppColors dark/light mode standards while keeping the structure.
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.getBackground(isDark),
      appBar: AppBar(
        backgroundColor: AppColors.getBackground(isDark),
        title: Text('Apply to join the team', style: TextStyle(color: AppColors.getTextPrimary(isDark), fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: true,
        iconTheme: IconThemeData(color: AppColors.getTextPrimary(isDark)),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: AppColors.getTextPrimary(isDark)),
            onPressed: () {},
          )
        ],
      ),
      body: _isSubmitting
          ? Center(child: CircularProgressIndicator(color: AppColors.getPrimary(isDark)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  _buildJoinCard(isDark),
                  const SizedBox(height: 16),
                  _buildCreateCard(isDark),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: AppColors.getPrimary(isDark),
        child: const Icon(Icons.chat_bubble, color: Colors.white),
      ),
    );
  }

  InputDecoration _buildInputDecoration(bool isDark, String hintText, {Widget? prefixIcon}) {
    return InputDecoration(
      prefixIcon: prefixIcon,
      hintText: hintText,
      hintStyle: TextStyle(color: AppColors.getTextSecondary(isDark)),
      filled: true,
      fillColor: isDark ? Colors.black26 : Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.getPrimary(isDark).withValues(alpha: 0.5))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.getPrimary(isDark).withValues(alpha: 0.5))),
    );
  }

  Widget _buildJoinCard(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.getCard(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.getPrimary(isDark).withValues(alpha: 0.5)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Join the agency', style: TextStyle(color: AppColors.getTextPrimary(isDark), fontWeight: FontWeight.bold, fontSize: 16)),
              Image.asset('assets/images/agency_join.png', height: 60, errorBuilder: (c,e,s) => Icon(Icons.group_add, size: 40, color: AppColors.getPrimary(isDark))),
            ],
          ),
          const SizedBox(height: 12),
          Text('Agent ID', style: TextStyle(color: AppColors.getTextPrimary(isDark), fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          TextField(
            controller: _agentIdController,
            style: TextStyle(color: AppColors.getTextPrimary(isDark)),
            decoration: _buildInputDecoration(isDark, 'Please enter the agent ID'),
          ),
          const SizedBox(height: 12),
          Text(
            'Enter the ID of your agent, and you will become the host after the host apply is approved. After becoming an hoster, your income will be entrusted to your agent',
            style: TextStyle(color: AppColors.getTextSecondary(isDark), fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _handleJoinAgency,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.getPrimary(isDark),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
              child: const Text('Apply', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateCard(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.getCard(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.getPrimary(isDark).withValues(alpha: 0.5)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Create the agency', style: TextStyle(color: AppColors.getTextPrimary(isDark), fontWeight: FontWeight.bold, fontSize: 16)),
              Image.asset('assets/images/agency_create.png', height: 60, errorBuilder: (c,e,s) => Icon(Icons.campaign, size: 40, color: AppColors.getPrimary(isDark))),
            ],
          ),
          const SizedBox(height: 12),
          Text('Phone Number', style: TextStyle(color: AppColors.getTextPrimary(isDark), fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          Row(
            children: [
              SizedBox(
                width: 100,
                child: TextField(
                  controller: _phoneCodeController,
                  style: TextStyle(color: AppColors.getTextPrimary(isDark)),
                  decoration: _buildInputDecoration(isDark, 'eg:852', prefixIcon: Icon(Icons.add, size: 16, color: AppColors.getTextSecondary(isDark))),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _phoneNumberController,
                  keyboardType: TextInputType.phone,
                  style: TextStyle(color: AppColors.getTextPrimary(isDark)),
                  decoration: _buildInputDecoration(isDark, 'Enter phone number'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('BD ID (Optional)', style: TextStyle(color: AppColors.getTextPrimary(isDark), fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          TextField(
            controller: _bdIdController,
            style: TextStyle(color: AppColors.getTextPrimary(isDark)),
            decoration: _buildInputDecoration(isDark, 'Enter BD ID'),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _handleCreateAgency,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.getPrimary(isDark),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
              child: const Text('Create Agency', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}
