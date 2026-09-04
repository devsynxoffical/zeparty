import 'dart:async';
import 'package:flutter/material.dart';
import '../models/gift_model.dart';
import '../models/live_gift_event_model.dart';
import '../models/user_model.dart';
import 'wallet_provider.dart';

class LiveGiftProvider extends ChangeNotifier {
  String? _activeRoomId;
  String? get activeRoomId => _activeRoomId;

  final StreamController<LiveGiftEventModel> _eventStreamController =
      StreamController<LiveGiftEventModel>.broadcast();
  Stream<LiveGiftEventModel> get giftStream => _eventStreamController.stream;

  final List<LiveGiftEventModel> _eventQueue = [];
  LiveGiftEventModel? _currentActiveEvent;
  LiveGiftEventModel? get currentActiveEvent => _currentActiveEvent;

  final Map<String, LiveGiftEventModel> _activeComboMap = {};
  final Map<String, Timer> _comboResetTimers = {};

  void setActiveRoom(String roomId) {
    if (_activeRoomId != roomId) {
      _activeRoomId = roomId;
      _eventQueue.clear();
      _activeComboMap.clear();
      _currentActiveEvent = null;
      notifyListeners();
    }
  }

  void clearRoom() {
    _activeRoomId = null;
    _eventQueue.clear();
    _activeComboMap.clear();
    _currentActiveEvent = null;
    notifyListeners();
  }

  /// Sends a gift with pre-animation wallet validation & deduction,
  /// combo aggregation, and realtime event broadcasting.
  bool sendGift({
    required WalletProvider walletProvider,
    required GiftModel gift,
    required UserModel sender,
    required UserModel receiver,
    required String roomId,
    int quantity = 1,
  }) {
    final totalCost = gift.diamondPrice * quantity;

    // 1. Wallet Validation & Pre-animation Coin Deduction
    final success = walletProvider.spendDiamonds(totalCost, gift.name);
    if (!success) {
      return false; // Insufficient balance
    }

    final comboKey = '${sender.id}_${gift.id}_${receiver.id}';
    final now = DateTime.now();

    LiveGiftEventModel event;

    // 2. Combo Aggregation Check (within 2.5s combo window)
    if (_activeComboMap.containsKey(comboKey)) {
      final existing = _activeComboMap[comboKey]!;
      final newComboCount = existing.comboCount + quantity;

      event = existing.copyWith(
        comboCount: newComboCount,
        timestamp: now,
      );

      _activeComboMap[comboKey] = event;
      _comboResetTimers[comboKey]?.cancel();
    } else {
      final eventId = 'gift_${now.millisecondsSinceEpoch}_${sender.id.hashCode.abs()}';
      event = LiveGiftEventModel(
        eventId: eventId,
        giftId: gift.id,
        giftName: gift.name,
        giftIcon: gift.icon,
        animationLevel: gift.animationLevel,
        giftValue: gift.diamondPrice,
        quantity: quantity,
        comboCount: quantity,
        senderId: sender.id,
        senderName: sender.name,
        senderAvatarUrl: sender.avatarUrl,
        receiverId: receiver.id,
        receiverName: receiver.name,
        receiverAvatarUrl: receiver.avatarUrl,
        roomId: roomId,
        timestamp: now,
      );

      _activeComboMap[comboKey] = event;
    }

    // 3. Set Combo Reset Timer (2.5 seconds)
    _comboResetTimers[comboKey] = Timer(const Duration(milliseconds: 2500), () {
      _activeComboMap.remove(comboKey);
      _comboResetTimers.remove(comboKey);
    });

    // 4. Realtime Stream Broadcast
    _eventStreamController.add(event);

    // 5. Enqueue into Priority Queue
    _enqueueEvent(event);

    notifyListeners();
    return true;
  }

  /// Receive realtime gift event from remote socket/server
  void receiveGiftEvent(LiveGiftEventModel event) {
    if (_activeRoomId != null && event.roomId != _activeRoomId) return;
    _eventStreamController.add(event);
    _enqueueEvent(event);
    notifyListeners();
  }

  void _enqueueEvent(LiveGiftEventModel event) {
    // Insert higher level gifts ahead of lower level gifts
    int insertIndex = _eventQueue.length;
    for (int i = 0; i < _eventQueue.length; i++) {
      if (event.animationLevel.index > _eventQueue[i].animationLevel.index) {
        insertIndex = i;
        break;
      }
    }
    _eventQueue.insert(insertIndex, event);

    if (_currentActiveEvent == null) {
      _playNextEvent();
    }
  }

  void _playNextEvent() {
    if (_eventQueue.isEmpty) {
      _currentActiveEvent = null;
      notifyListeners();
      return;
    }

    _currentActiveEvent = _eventQueue.removeAt(0);
    notifyListeners();
  }

  void onCurrentEventCompleted() {
    _playNextEvent();
  }

  @override
  void dispose() {
    for (final timer in _comboResetTimers.values) {
      timer.cancel();
    }
    _eventStreamController.close();
    super.dispose();
  }
}
