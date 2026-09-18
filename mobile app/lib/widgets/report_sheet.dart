import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/repositories/report_repository.dart';
import '../core/services/api_client.dart';

/// Standard violation reasons supported by backend
const List<Map<String, String>> kViolationCategories = [
  {'key': 'HARASSMENT', 'label': 'Harassment or Bullying', 'desc': 'Targeting individuals with insults or intimidation'},
  {'key': 'INAPPROPRIATE_CONTENT', 'label': 'Inappropriate Content', 'desc': 'Nudity, sexual content, or graphic violence'},
  {'key': 'SPAM', 'label': 'Spam or Fraud', 'desc': 'Repetitive advertising, scams, or false promises'},
  {'key': 'IMPERSONATION', 'label': 'Impersonation', 'desc': 'Pretending to be another user or official staff'},
  {'key': 'UNDERAGE', 'label': 'Underage User', 'desc': 'User is under the platform minimum age limit'},
  {'key': 'HATE_SPEECH', 'label': 'Hate Speech', 'desc': 'Attacking protected groups or inciting hatred'},
  {'key': 'OTHER', 'label': 'Other Violation', 'desc': 'Other community rule violations'},
];

/// Universal bottom sheet for reporting users, rooms, posts, comments, or messages
class ReportSheet extends StatefulWidget {
  final String targetTitle;
  final String? reportedUserId;
  final String? reportedRoomId;
  final String? reportedPostId;
  final String? reportedCommentId;
  final String? reportedMessageId;

  const ReportSheet({
    super.key,
    required this.targetTitle,
    this.reportedUserId,
    this.reportedRoomId,
    this.reportedPostId,
    this.reportedCommentId,
    this.reportedMessageId,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String targetTitle,
    String? reportedUserId,
    String? reportedRoomId,
    String? reportedPostId,
    String? reportedCommentId,
    String? reportedMessageId,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ReportSheet(
        targetTitle: targetTitle,
        reportedUserId: reportedUserId,
        reportedRoomId: reportedRoomId,
        reportedPostId: reportedPostId,
        reportedCommentId: reportedCommentId,
        reportedMessageId: reportedMessageId,
      ),
    );
  }

  @override
  State<ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<ReportSheet> {
  String _selectedViolation = 'INAPPROPRIATE_CONTENT';
  String _selectedPriority = 'MEDIUM';
  final TextEditingController _descController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    if (_isSubmitting) return;

    setState(() => _isSubmitting = true);

    try {
      final result = await ReportRepository.instance.submitReport(
        reportedUserId: widget.reportedUserId,
        reportedRoomId: widget.reportedRoomId,
        reportedPostId: widget.reportedPostId,
        reportedCommentId: widget.reportedCommentId,
        reportedMessageId: widget.reportedMessageId,
        violationType: _selectedViolation,
        description: _descController.text.trim().isNotEmpty ? _descController.text.trim() : null,
        priority: _selectedPriority,
      );

      if (!mounted) return;

      final isDuplicate = result['meta']?['isDuplicate'] as bool? ?? false;
      final serverMsg = result['meta']?['message'] as String? ?? 'Report submitted successfully.';

      Navigator.pop(context, true);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.shield_outlined, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isDuplicate
                      ? 'You have already reported this recently. Our moderation team is on it.'
                      : '🛡️ $serverMsg',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          backgroundColor: isDuplicate ? Colors.orange : AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit report: $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle Bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Row(
              children: [
                const Icon(Icons.report_problem_rounded, color: Colors.redAccent, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Report ${widget.targetTitle}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const Text(
                        'Help keep ZeParty safe and welcoming for everyone.',
                        style: TextStyle(color: Colors.grey, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const Divider(height: 24),

            // Reason Selector
            const Text(
              'SELECT REASON FOR REPORT',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.0),
            ),
            const SizedBox(height: 8),

            ...kViolationCategories.map((cat) {
              final isSelected = _selectedViolation == cat['key'];
              return InkWell(
                onTap: () => setState(() => _selectedViolation = cat['key']!),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.redAccent.withValues(alpha: 0.12)
                        : isDark
                            ? Colors.white.withValues(alpha: 0.03)
                            : Colors.black.withValues(alpha: 0.02),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? Colors.redAccent : Theme.of(context).dividerColor,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                        color: isSelected ? Colors.redAccent : Colors.grey,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cat['label']!,
                              style: TextStyle(
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              cat['desc']!,
                              style: const TextStyle(fontSize: 10, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),

            const SizedBox(height: 12),

            // Optional Details Field
            const Text(
              'ADDITIONAL DETAILS (OPTIONAL)',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.0),
            ),
            const SizedBox(height: 6),

            TextField(
              controller: _descController,
              maxLines: 3,
              maxLength: 1000,
              decoration: InputDecoration(
                hintText: 'Describe what happened or provide context...',
                hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                filled: true,
                fillColor: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),

            const SizedBox(height: 16),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                onPressed: _isSubmitting ? null : _submitReport,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text(
                        'Submit Violation Report',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
