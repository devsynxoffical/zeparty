import 'dart:async';
import 'package:flutter/material.dart';
import '../models/user_model.dart';

class CallProvider extends ChangeNotifier {
  bool _isInCall = false;
  bool _isVideoCall = true;
  UserModel? _peerUser;
  bool _isMuted = false;
  bool _isSpeakerOn = true;
  bool _isFrontCamera = true;
  int _callDurationSeconds = 0;
  Timer? _timer;

  bool get isInCall => _isInCall;
  bool get isVideoCall => _isVideoCall;
  UserModel? get peerUser => _peerUser;
  bool get isMuted => _isMuted;
  bool get isSpeakerOn => _isSpeakerOn;
  bool get isFrontCamera => _isFrontCamera;
  int get callDurationSeconds => _callDurationSeconds;

  void startCall(UserModel user, {bool isVideo = true}) {
    _isInCall = true;
    _isVideoCall = isVideo;
    _peerUser = user;
    _isMuted = false;
    _isSpeakerOn = true;
    _isFrontCamera = true;
    _callDurationSeconds = 0;

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _callDurationSeconds++;
      notifyListeners();
    });
    notifyListeners();
  }

  void endCall() {
    _isInCall = false;
    _peerUser = null;
    _timer?.cancel();
    _callDurationSeconds = 0;
    notifyListeners();
  }

  void toggleMute() {
    _isMuted = !_isMuted;
    notifyListeners();
  }

  void toggleSpeaker() {
    _isSpeakerOn = !_isSpeakerOn;
    notifyListeners();
  }

  void switchCamera() {
    _isFrontCamera = !_isFrontCamera;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
