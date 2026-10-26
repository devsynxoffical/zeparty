import 'package:flutter/material.dart';
import '../features/profile/profile_rooms_screen.dart';
import '../models/user_model.dart';

/// Reusable Joined Rooms Tab / Launcher widget
class JoinedRoomsTab extends StatelessWidget {
  final UserModel user;
  const JoinedRoomsTab({super.key, required this.user});

  static Future<void> show(BuildContext context, UserModel user) {
    return Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProfileRoomsScreen(user: user)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ProfileRoomsScreen(user: user);
  }
}
