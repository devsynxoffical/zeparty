import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class InviteCodeScreen extends StatefulWidget {
  const InviteCodeScreen({super.key});

  @override
  State<InviteCodeScreen> createState() => _InviteCodeScreenState();
}

class _InviteCodeScreenState extends State<InviteCodeScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _isLoading = false;
  bool _isSuccess = false;

  void _submitCode() async {
    if (_controller.text.isEmpty) return;

    setState(() => _isLoading = true);
    
    // Simulate API call
    await Future.delayed(const Duration(seconds: 1));
    
    if (mounted) {
      setState(() {
        _isLoading = false;
        _isSuccess = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Successfully claimed invite reward!')),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppColors.getPrimary(isDark);

    return Scaffold(
      backgroundColor: AppColors.getBackground(isDark),
      appBar: AppBar(
        backgroundColor: AppColors.getBackground(isDark),
        title: Text('Enter Invite Code', style: TextStyle(color: AppColors.getTextPrimary(isDark))),
        iconTheme: IconThemeData(color: AppColors.getTextPrimary(isDark)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.mark_email_read_rounded, size: 80, color: Colors.blueAccent),
            const SizedBox(height: 24),
            Text(
              _isSuccess ? 'Reward Claimed!' : 'Got an invite code?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.getTextPrimary(isDark),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _isSuccess ? 'You have already redeemed an invite code.' : 'Enter your friend\'s invite code to claim exclusive rewards.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.getTextSecondary(isDark)),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _controller,
              enabled: !_isSuccess && !_isLoading,
              decoration: InputDecoration(
                hintText: 'Enter Code',
                filled: true,
                fillColor: AppColors.getCard(isDark),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: (_isSuccess || _isLoading) ? null : _submitCode,
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: AppColors.onPrimary(isDark: isDark),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Text(
                      _isSuccess ? 'Claimed' : 'Claim Reward',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
