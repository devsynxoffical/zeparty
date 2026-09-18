import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';

class AgoraRtcService {
  String _currentAppId = 'YOUR_AGORA_APP_ID';
  RtcEngine? _engine;
  bool _isInitialized = false;

  final _activeSpeakerController = StreamController<int>.broadcast();
  Stream<int> get activeSpeakerStream => _activeSpeakerController.stream;

  Future<void> initialize({String? appId}) async {
    final targetAppId = (appId != null && appId.isNotEmpty) ? appId : _currentAppId;
    if (_isInitialized && _engine != null && targetAppId == _currentAppId) {
      return;
    }
    _currentAppId = targetAppId;

    try {
      await [Permission.microphone].request();
      _engine = createAgoraRtcEngine();
      await _engine!.initialize(RtcEngineContext(
        appId: _currentAppId,
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
      ));

      _engine!.registerEventHandler(
        RtcEngineEventHandler(
          onActiveSpeaker: (RtcConnection connection, int uid) {
            _activeSpeakerController.add(uid);
          },
          onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
            debugPrint('[AgoraRtcService] Successfully joined channel: ${connection.channelId}');
          },
          onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
            debugPrint('[AgoraRtcService] Remote user joined Agora channel: $remoteUid');
          },
          onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
            debugPrint('[AgoraRtcService] Remote user left Agora channel: $remoteUid');
          },
        ),
      );

      await _engine!.enableAudioVolumeIndication(interval: 200, smooth: 3, reportVad: true);
      _isInitialized = true;
    } catch (e) {
      debugPrint('[AgoraRtcService] Engine initialization failed (fallback): $e');
    }
  }

  Future<void> joinChannel(String token, String channelName, int uid, {bool isHost = false, String? appId}) async {
    if (!_isInitialized || _engine == null) {
      await initialize(appId: appId);
    }
    if (_engine == null) return;

    try {
      await _engine!.setClientRole(
        role: isHost ? ClientRoleType.clientRoleBroadcaster : ClientRoleType.clientRoleAudience,
      );

      await _engine!.joinChannel(
        token: token,
        channelId: channelName,
        uid: uid,
        options: ChannelMediaOptions(
          autoSubscribeAudio: true,
          publishMicrophoneTrack: isHost,
          clientRoleType: isHost ? ClientRoleType.clientRoleBroadcaster : ClientRoleType.clientRoleAudience,
        ),
      );
    } catch (e) {
      debugPrint('[AgoraRtcService] Join channel error: $e');
    }
  }

  Future<void> switchRole({required bool isHost}) async {
    try {
      await _engine?.setClientRole(
        role: isHost ? ClientRoleType.clientRoleBroadcaster : ClientRoleType.clientRoleAudience,
      );
      await _engine?.updateChannelMediaOptions(
        ChannelMediaOptions(
          publishMicrophoneTrack: isHost,
          clientRoleType: isHost ? ClientRoleType.clientRoleBroadcaster : ClientRoleType.clientRoleAudience,
        ),
      );
    } catch (e) {
      debugPrint('[AgoraRtcService] switchRole error: $e');
    }
  }

  Future<void> leaveChannel() async {
    try {
      await _engine?.leaveChannel();
    } catch (_) {}
  }

  Future<void> muteLocalAudio(bool muted) async {
    try {
      await _engine?.muteLocalAudioStream(muted);
    } catch (_) {}
  }

  Future<void> dispose() async {
    try {
      await _engine?.leaveChannel();
      await _engine?.release();
    } catch (_) {}
    _engine = null;
    _isInitialized = false;
  }
}
