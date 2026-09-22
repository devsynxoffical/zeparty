import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';

class AgoraRtcService {
  static final AgoraRtcService instance = AgoraRtcService._internal();
  factory AgoraRtcService() => instance;
  AgoraRtcService._internal();

  String _currentAppId = '970ca35de60c44645bbae8a215061401';
  RtcEngine? _engine;
  bool _isInitialized = false;
  bool _isVideoEnabled = false;
  int? _currentUid;
  String? _currentChannel;

  final _activeSpeakerController = StreamController<int>.broadcast();
  final _remoteUsersController = StreamController<Set<int>>.broadcast();
  final _firstRemoteVideoFrameController = StreamController<int>.broadcast();
  final Set<int> _remoteUids = <int>{};

  Stream<int> get activeSpeakerStream => _activeSpeakerController.stream;
  Stream<Set<int>> get remoteUsersStream => _remoteUsersController.stream;
  Stream<int> get firstRemoteVideoFrameStream => _firstRemoteVideoFrameController.stream;
  Set<int> get remoteUids => Set.unmodifiable(_remoteUids);

  RtcEngine? get engine => _engine;
  bool get isInitialized => _isInitialized;
  bool get isVideoEnabled => _isVideoEnabled;
  int? get currentUid => _currentUid;
  String? get currentChannel => _currentChannel;

  Future<void> initialize({String? appId, bool enableVideo = true}) async {
    final targetAppId = (appId != null && appId.isNotEmpty) ? appId : _currentAppId;
    if (_isInitialized && _engine != null && targetAppId == _currentAppId) {
      if (enableVideo && !_isVideoEnabled) {
        await _setupVideo();
      }
      return;
    }
    _currentAppId = targetAppId;

    try {
      if (enableVideo) {
        await [Permission.camera, Permission.microphone].request();
      } else {
        await [Permission.microphone].request();
      }

      _engine = createAgoraRtcEngine();
      await _engine!.initialize(RtcEngineContext(
        appId: _currentAppId,
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
        audioScenario: AudioScenarioType.audioScenarioGameStreaming,
      ));

      _engine!.registerEventHandler(
        RtcEngineEventHandler(
          onActiveSpeaker: (RtcConnection connection, int uid) {
            _activeSpeakerController.add(uid);
          },
          onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
            debugPrint('[AgoraRtcService] Joined channel: ${connection.channelId}, local UID: ${connection.localUid}');
            _currentChannel = connection.channelId;
            _currentUid = connection.localUid;
          },
          onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
            debugPrint('[AgoraRtcService] Remote user joined Agora channel: $remoteUid');
            _remoteUids.add(remoteUid);
            _remoteUsersController.add(Set.from(_remoteUids));
          },
          onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
            debugPrint('[AgoraRtcService] Remote user left Agora channel: $remoteUid');
            _remoteUids.remove(remoteUid);
            _remoteUsersController.add(Set.from(_remoteUids));
          },
          onFirstRemoteVideoFrame: (RtcConnection connection, int remoteUid, int width, int height, int elapsed) {
            debugPrint('[AgoraRtcService] First remote video frame rendered from UID: $remoteUid ($width x $height)');
            _firstRemoteVideoFrameController.add(remoteUid);
          },
          onError: (ErrorCodeType err, String msg) {
            debugPrint('[AgoraRtcService] Agora Engine Error: $err, $msg');
          },
        ),
      );

      // Low latency audio profile
      await _engine!.setAudioProfile(
        profile: AudioProfileType.audioProfileMusicStandard,
        scenario: AudioScenarioType.audioScenarioGameStreaming,
      );

      // Volume indication for active speaking mic animations
      await _engine!.enableAudioVolumeIndication(interval: 200, smooth: 3, reportVad: true);

      if (enableVideo) {
        await _setupVideo();
      }

      _isInitialized = true;
    } catch (e) {
      debugPrint('[AgoraRtcService] Engine initialization failed: $e');
    }
  }

  Future<void> _setupVideo() async {
    if (_engine == null) return;
    try {
      await _engine!.enableVideo();
      await _engine!.setVideoEncoderConfiguration(
        const VideoEncoderConfiguration(
          dimensions: VideoDimensions(width: 720, height: 1280),
          frameRate: 30,
          bitrate: 1710,
          orientationMode: OrientationMode.orientationModeAdaptive,
          degradationPreference: DegradationPreference.maintainQuality,
        ),
      );
      _isVideoEnabled = true;
    } catch (e) {
      debugPrint('[AgoraRtcService] Video setup error: $e');
    }
  }

  Future<void> startPreview() async {
    try {
      if (_engine != null && _isVideoEnabled) {
        await _engine!.startPreview();
      }
    } catch (e) {
      debugPrint('[AgoraRtcService] startPreview error: $e');
    }
  }

  Future<void> stopPreview() async {
    try {
      if (_engine != null) {
        await _engine!.stopPreview();
      }
    } catch (_) {}
  }

  Future<void> switchCamera() async {
    try {
      if (_engine != null) {
        await _engine!.switchCamera();
      }
    } catch (e) {
      debugPrint('[AgoraRtcService] switchCamera error: $e');
    }
  }

  Future<void> joinChannel(
    String token,
    String channelName,
    int uid, {
    bool isHost = false,
    bool isVideo = true,
    String? appId,
  }) async {
    if (!_isInitialized || _engine == null) {
      await initialize(appId: appId, enableVideo: isVideo);
    }
    if (_engine == null) return;

    _remoteUids.clear();
    _currentChannel = channelName;
    _currentUid = uid;

    try {
      // Set Ultra-Low Latency for audience
      await _engine!.setClientRole(
        role: isHost ? ClientRoleType.clientRoleBroadcaster : ClientRoleType.clientRoleAudience,
        options: ClientRoleOptions(
          audienceLatencyLevel: AudienceLatencyLevelType.audienceLatencyLevelUltraLowLatency,
        ),
      );

      if (isVideo && isHost) {
        await _engine!.startPreview();
      }

      await _engine!.joinChannel(
        token: token,
        channelId: channelName,
        uid: uid,
        options: ChannelMediaOptions(
          autoSubscribeAudio: true,
          autoSubscribeVideo: isVideo,
          publishCameraTrack: isHost && isVideo,
          publishMicrophoneTrack: isHost,
          clientRoleType: isHost ? ClientRoleType.clientRoleBroadcaster : ClientRoleType.clientRoleAudience,
          audienceLatencyLevel: AudienceLatencyLevelType.audienceLatencyLevelUltraLowLatency,
        ),
      );
    } catch (e) {
      debugPrint('[AgoraRtcService] Join channel error: $e');
    }
  }

  Future<void> switchRole({required bool isHost, bool isVideo = false}) async {
    try {
      await _engine?.setClientRole(
        role: isHost ? ClientRoleType.clientRoleBroadcaster : ClientRoleType.clientRoleAudience,
        options: ClientRoleOptions(
          audienceLatencyLevel: AudienceLatencyLevelType.audienceLatencyLevelUltraLowLatency,
        ),
      );
      await _engine?.updateChannelMediaOptions(
        ChannelMediaOptions(
          publishCameraTrack: isHost && isVideo,
          publishMicrophoneTrack: isHost,
          clientRoleType: isHost ? ClientRoleType.clientRoleBroadcaster : ClientRoleType.clientRoleAudience,
          audienceLatencyLevel: AudienceLatencyLevelType.audienceLatencyLevelUltraLowLatency,
        ),
      );
    } catch (e) {
      debugPrint('[AgoraRtcService] switchRole error: $e');
    }
  }

  Future<void> leaveChannel() async {
    try {
      _remoteUids.clear();
      _remoteUsersController.add(Set.from(_remoteUids));
      await _engine?.stopPreview();
      await _engine?.leaveChannel();
    } catch (_) {}
    _currentChannel = null;
  }

  Future<void> muteLocalAudio(bool muted) async {
    try {
      await _engine?.muteLocalAudioStream(muted);
    } catch (_) {}
  }

  Future<void> muteLocalVideo(bool muted) async {
    try {
      await _engine?.muteLocalVideoStream(muted);
    } catch (_) {}
  }

  Future<void> dispose() async {
    try {
      _remoteUids.clear();
      await _engine?.stopPreview();
      await _engine?.leaveChannel();
      await _engine?.release();
    } catch (_) {}
    _engine = null;
    _isInitialized = false;
    _isVideoEnabled = false;
    _currentChannel = null;
    _currentUid = null;
  }
}
