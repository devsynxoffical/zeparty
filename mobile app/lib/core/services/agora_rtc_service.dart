import 'dart:async';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';

class AgoraRtcService {
  static const String appId = "YOUR_AGORA_APP_ID"; // Placeholder for API keys
  RtcEngine? _engine;
  
  final _activeSpeakerController = StreamController<int>.broadcast();
  Stream<int> get activeSpeakerStream => _activeSpeakerController.stream;

  Future<void> initialize() async {
    await [Permission.microphone].request();
    
    _engine = createAgoraRtcEngine();
    await _engine!.initialize(const RtcEngineContext(
      appId: appId,
      channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
    ));

    _engine!.registerEventHandler(
      RtcEngineEventHandler(
        onActiveSpeaker: (RtcConnection connection, int uid) {
          _activeSpeakerController.add(uid);
        },
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          // Joined channel
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          // User joined
        },
        onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
          // User left
        },
      ),
    );

    await _engine!.enableAudioVolumeIndication(interval: 200, smooth: 3, reportVad: true);
  }

  Future<void> joinChannel(String token, String channelName, int uid, {bool isHost = false}) async {
    if (_engine == null) return;
    
    await _engine!.setClientRole(
      role: isHost ? ClientRoleType.clientRoleBroadcaster : ClientRoleType.clientRoleAudience,
    );

    await _engine!.joinChannel(
      token: token,
      channelId: channelName,
      uid: uid,
      options: const ChannelMediaOptions(
        autoSubscribeAudio: true,
        publishMicrophoneTrack: true,
      ),
    );
  }

  Future<void> leaveChannel() async {
    await _engine?.leaveChannel();
  }

  Future<void> muteLocalAudio(bool muted) async {
    await _engine?.muteLocalAudioStream(muted);
  }

  Future<void> dispose() async {
    await _engine?.release();
    _activeSpeakerController.close();
  }
}
