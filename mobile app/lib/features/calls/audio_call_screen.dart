import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../models/user_model.dart';
import '../../providers/call_provider.dart';
import '../../core/utils/formatters.dart';
import '../../widgets/user_avatar.dart';

class AudioCallScreen extends StatefulWidget {
  final UserModel peerUser;

  const AudioCallScreen({super.key, required this.peerUser});

  @override
  State<AudioCallScreen> createState() => _AudioCallScreenState();
}

class _AudioCallScreenState extends State<AudioCallScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CallProvider>().startCall(widget.peerUser, isVideo: false);
    });
  }

  @override
  void dispose() {
    context.read<CallProvider>().endCall();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final call = context.watch<CallProvider>();

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
                  UserAvatar(imageUrl: widget.peerUser.avatarUrl, radius: 56, showVipFrame: true),
                  const SizedBox(height: 16),
                  Text(
                    widget.peerUser.name,
                    style: const TextStyle(color: AppColors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppFormatters.formatDuration(Duration(seconds: call.callDurationSeconds)),
                    style: TextStyle(color: AppColors.white.withValues(alpha: 0.8), fontSize: 16),
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: call.isMuted ? AppColors.warmGold : AppColors.white.withValues(alpha: 0.2),
                    child: IconButton(
                      icon: Icon(call.isMuted ? Icons.mic_off : Icons.mic, color: call.isMuted ? AppColors.black : AppColors.white),
                      onPressed: () => call.toggleMute(),
                    ),
                  ),
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: AppColors.live,
                    child: IconButton(
                      icon: const Icon(Icons.call_end, color: AppColors.white, size: 36),
                      onPressed: () {
                        call.endCall();
                        Navigator.pop(context);
                      },
                    ),
                  ),
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: call.isSpeakerOn ? AppColors.warmGold : AppColors.white.withValues(alpha: 0.2),
                    child: IconButton(
                      icon: Icon(call.isSpeakerOn ? Icons.volume_up : Icons.volume_down, color: call.isSpeakerOn ? AppColors.black : AppColors.white),
                      onPressed: () => call.toggleSpeaker(),
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
