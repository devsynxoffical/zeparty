import 'package:flutter/material.dart';
import '../features/profile/visitors_screen.dart';

/// Reusable sheet wrapper or modal for VisitorsScreen
class VisitorsListSheet extends StatelessWidget {
  final String? targetUserId;
  const VisitorsListSheet({super.key, this.targetUserId});

  static Future<void> show(BuildContext context, {String? targetUserId}) {
    return Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => VisitorsScreen(targetUserId: targetUserId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return VisitorsScreen(targetUserId: targetUserId);
  }
}
