import 'dart:async';
import 'package:flutter/material.dart';
import '../models/live_room_model.dart';
import '../models/pk_battle_model.dart';
import '../models/gift_model.dart';
import '../models/user_model.dart';

class LiveMessage {
  final String sender;
  final String text;
  final bool isGift;
  final GiftModel? gift;

  LiveMessage({
    required this.sender,
    required this.text,
    this.isGift = false,
    this.gift,
  });
}

class LiveProvider extends ChangeNotifier {
  LiveRoomModel? _activeRoom;
  List<LiveMessage> _messages = [];
  GiftModel? _activeGiftAnimation;
  PKBattleModel? _activePkBattle;
  Timer? _pkTimer;
  Timer? _giftTimer;
  int _pkTimeRemainingSeconds = 180;
  static const int _maxMessageBuffer = 100;

  // ── Room Tool State ──────────────────────────────────────
  bool _isRoomLocked = false;
  String? _currentMusicTrack;
  String? _superWheelWinner;
  int _luckyBagDiamonds = 0;
  bool _luckyBagActive = false;
  String _activeEffect = 'None';

  // ── Getters ─────────────────────────────────────────────
  LiveRoomModel? get activeRoom => _activeRoom;
  List<LiveMessage> get messages => List.unmodifiable(_messages);
  GiftModel? get activeGiftAnimation => _activeGiftAnimation;
  PKBattleModel? get activePkBattle => _activePkBattle;
  int get pkTimeRemainingSeconds => _pkTimeRemainingSeconds;

  bool get isRoomLocked => _isRoomLocked;
  String? get currentMusicTrack => _currentMusicTrack;
  bool get isMusicPlaying => _currentMusicTrack != null;
  String? get superWheelWinner => _superWheelWinner;
  int get luckyBagDiamonds => _luckyBagDiamonds;
  bool get luckyBagActive => _luckyBagActive;
  String get activeEffect => _activeEffect;

  // ── Core Methods ─────────────────────────────────────────

  void joinRoom(LiveRoomModel room) {
    _activeRoom = room;
    _isRoomLocked = false;
    _currentMusicTrack = null;
    _luckyBagActive = false;
    _activeEffect = 'None';
    _messages = [
      LiveMessage(sender: 'System', text: 'Welcome to ${room.title}! Remember to follow community rules.'),
      LiveMessage(sender: 'Sophia', text: 'Hey streamer! Sending love'),
      LiveMessage(sender: 'Alex', text: 'Awesome stream quality today!'),
    ];
    notifyListeners();
  }

  void leaveRoom() {
    _activeRoom = null;
    _messages.clear();
    _activeGiftAnimation = null;
    _pkTimer?.cancel();
    _giftTimer?.cancel();
    _isRoomLocked = false;
    _currentMusicTrack = null;
    _luckyBagActive = false;
    notifyListeners();
  }

  void sendMessage(String text, String sender) {
    _messages.add(LiveMessage(sender: sender, text: text));
    if (_messages.length > _maxMessageBuffer) {
      _messages.removeAt(0);
    }
    notifyListeners();
  }

  void sendGift(GiftModel gift, String sender) {
    _activeGiftAnimation = gift;
    _messages.add(
      LiveMessage(
        sender: sender,
        text: 'sent ${gift.name} ${gift.icon}!',
        isGift: true,
        gift: gift,
      ),
    );
    if (_messages.length > _maxMessageBuffer) {
      _messages.removeAt(0);
    }
    notifyListeners();

    _giftTimer?.cancel();
    _giftTimer = Timer(const Duration(seconds: 3), () {
      _activeGiftAnimation = null;
      notifyListeners();
    });
  }

  void clearMessages() {
    _messages.clear();
    notifyListeners();
  }

  void startPkBattle() {
    _activePkBattle = const PKBattleModel(
      id: 'pk_active_round',
      hostA: UserModel(
        id: 'host_1',
        username: 'host_alpha',
        name: 'Team Blue',
        avatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150',
      ),
      hostB: UserModel(
        id: 'host_2',
        username: 'host_beta',
        name: 'Team Red',
        avatarUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150',
      ),
      scoreA: 0,
      scoreB: 0,
      remainingTime: Duration(minutes: 3),
    );
    _pkTimeRemainingSeconds = 180;
    _pkTimer?.cancel();
    _pkTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_pkTimeRemainingSeconds > 0) {
        _pkTimeRemainingSeconds--;
        notifyListeners();
      } else {
        _pkTimer?.cancel();
      }
    });
    notifyListeners();
  }

  // ── Tool Actions ─────────────────────────────────────────

  void toggleRoomLock() {
    _isRoomLocked = !_isRoomLocked;
    sendMessage(
      _isRoomLocked
          ? 'Room is now LOCKED. No new viewers can join.'
          : 'Room has been UNLOCKED.',
      'System',
    );
  }

  void playMusic(String trackName) {
    _currentMusicTrack = trackName;
    sendMessage('Now playing: $trackName', 'System');
    notifyListeners();
  }

  void stopMusic() {
    _currentMusicTrack = null;
    notifyListeners();
  }

  void spinSuperWheel(List<String> participants) {
    if (participants.isEmpty) return;
    final winner = participants[DateTime.now().millisecondsSinceEpoch % participants.length];
    _superWheelWinner = winner;
    sendMessage('Super Wheel spun! Winner: $winner gets 100 diamonds!', 'System');
    Timer(const Duration(seconds: 5), () {
      _superWheelWinner = null;
      notifyListeners();
    });
  }

  void startLuckyBag(int diamonds) {
    _luckyBagDiamonds = diamonds;
    _luckyBagActive = true;
    sendMessage('Lucky Bag is live! $diamonds diamonds to grab — tap fast!', 'System');
    notifyListeners();
    Timer(const Duration(seconds: 12), () {
      _luckyBagActive = false;
      notifyListeners();
    });
  }

  void setEffect(String effectName) {
    _activeEffect = effectName;
    notifyListeners();
  }

  void addPkScore(bool toHostA, int score) {
    if (_activePkBattle != null) {
      if (toHostA) {
        _activePkBattle = _activePkBattle!.copyWith(
          scoreA: _activePkBattle!.scoreA + score,
        );
      } else {
        _activePkBattle = _activePkBattle!.copyWith(
          scoreB: _activePkBattle!.scoreB + score,
        );
      }
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _pkTimer?.cancel();
    _giftTimer?.cancel();
    super.dispose();
  }
}
