import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../models/user_model.dart';
import '../../widgets/user_avatar.dart';
import 'video_call_screen.dart';

class IncomingCallScreen extends StatelessWidget {
  final UserModel caller;
  final bool isVideoCall;

  const IncomingCallScreen({super.key, required this.caller, this.isVideoCall = true});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.bannerGradient,
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  UserAvatar(imageUrl: caller.avatarUrl, radius: 56, showVipFrame: true),
                  const SizedBox(height: 16),
                  Text(
                    caller.name,
                    style: const TextStyle(color: AppColors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Incoming ${isVideoCall ? "Video" : "Audio"} Call...',
                    style: TextStyle(color: AppColors.white.withValues(alpha: 0.8), fontSize: 16),
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Decline Call
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: AppColors.live,
                    child: IconButton(
                      icon: const Icon(Icons.call_end, color: AppColors.white, size: 36),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  // Accept Call
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: AppColors.warmGold,
                    child: IconButton(
                      icon: const Icon(Icons.call, color: AppColors.black, size: 36),
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (c) => VideoCallScreen(peerUser: caller)),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
