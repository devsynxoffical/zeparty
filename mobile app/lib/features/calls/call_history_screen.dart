import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/dummy_data.dart';
import '../../widgets/user_avatar.dart';

class CallHistoryScreen extends StatelessWidget {
  const CallHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Call History')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: DummyData.popularUsers.length,
        itemBuilder: (context, index) {
          final user = DummyData.popularUsers[index];
          final isMissed = index % 2 == 1;

          return ListTile(
            leading: UserAvatar(imageUrl: user.avatarUrl, radius: 22),
            title: Text(user.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Row(
              children: [
                Icon(
                  isMissed ? Icons.call_missed : Icons.call_received,
                  color: isMissed ? AppColors.live : AppColors.success,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(isMissed ? 'Missed Video Call' : 'Incoming Call • 12m 45s'),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.videocam_rounded, color: AppColors.primary),
              onPressed: () {},
            ),
          );
        },
      ),
    );
  }
}
