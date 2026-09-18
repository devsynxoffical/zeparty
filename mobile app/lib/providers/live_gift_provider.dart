import 'dart:async';
import 'package:flutter/material.dart';
import '../models/gift_model.dart';
import '../models/live_gift_event_model.dart';
import '../models/user_model.dart';
import '../core/repositories/gift_repository.dart';
import '../core/services/socket_service.dart';
import '../core/utils/performance_utils.dart';
import 'wallet_provider.dart';

class LiveGiftProvider extends ChangeNotifier {
  final GiftRepository _giftRepository = GiftRepository.instance;
  final SocketService _socketService = SocketService.instance;

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

  final Set<String> _processedTransactionIds = {};
  final Set<String> _activeSendingIdempotencyKeys = {};

  List<GiftModel> _catalogGifts = [];
  List<GiftModel> get catalogGifts =>
      _catalogGifts.isNotEmpty ? List.unmodifiable(_catalogGifts) : GiftModel.defaultCatalog;

  bool _isLoadingCatalog = false;
  bool get isLoadingCatalog => _isLoadingCatalog;

  bool _isSending = false;
  bool get isSending => _isSending;

  String? _lastError;
  String? get lastError => _lastError;

  StreamSubscription<Map<String, dynamic>>? _socketGiftSubscription;

  LiveGiftProvider() {
    _initSocketListener();
    fetchCatalog();
  }

  void _initSocketListener() {
    _socketGiftSubscription?.cancel();
    _socketGiftSubscription = _socketService.onGiftSent.listen((data) {
      final txId = data['transactionId']?.toString() ?? '';
      if (txId.isNotEmpty && _processedTransactionIds.contains(txId)) {
        // Already processed locally (e.g. sender triggered local animation on REST response)
        return;
      }
      if (txId.isNotEmpty) {
        _processedTransactionIds.add(txId);
      }

      try {
        final event = LiveGiftEventModel.fromSocketJson(data);
        receiveGiftEvent(event);
      } catch (e) {
        debugPrint('[LiveGiftProvider] Error parsing socket gift event: $e');
      }
    });
  }

  /// Fetch live gift catalog from backend API
  Future<void> fetchCatalog({String? category, bool refresh = false}) async {
    if (_isLoadingCatalog) return;
    _isLoadingCatalog = true;
    _lastError = null;
    if (refresh) notifyListeners();

    try {
      final gifts = await _giftRepository.fetchGifts(category: category);
      if (gifts.isNotEmpty) {
        _catalogGifts = gifts;
      }
      _isLoadingCatalog = false;
      notifyListeners();
    } catch (e) {
      _isLoadingCatalog = false;
      _lastError = 'Failed to load gift catalog';
      debugPrint('[LiveGiftProvider] Catalog fetch error: $e');
      notifyListeners();
    }
  }

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

  /// Send gift to backend atomically, with server-side validation, ledger posting,
  /// host diamond reward, Socket.IO emission, and wallet reconciliation.
  Future<bool> sendGift({
    required WalletProvider walletProvider,
    required GiftModel gift,
    required UserModel sender,
    required UserModel receiver,
    required String roomId,
    int quantity = 1,
  }) async {
    final unitPrice = gift.priceCoins > 0 ? gift.priceCoins : gift.diamondPrice;
    final totalCost = unitPrice * quantity;

    // Quick client-side check to prevent needless network roundtrips if balance is clearly low
    if (walletProvider.coins < totalCost) {
      _lastError = 'Insufficient coin balance ($totalCost required, ${walletProvider.coins} available)';
      notifyListeners();
      return false;
    }

    final idempotencyKey = PerformanceUtils.generateIdempotencyKey('gift_${gift.id}');
    if (_activeSendingIdempotencyKeys.contains(idempotencyKey)) {
      return false; // Prevent double taps
    }
    _activeSendingIdempotencyKeys.add(idempotencyKey);
    _isSending = true;
    _lastError = null;
    notifyListeners();

    try {
      final response = await _giftRepository.sendGift(
        giftId: gift.id,
        recipientUserId: receiver.id,
        quantity: quantity,
        roomId: roomId,
        idempotencyKey: idempotencyKey,
      );

      _isSending = false;
      _activeSendingIdempotencyKeys.remove(idempotencyKey);

      final txId = response['transactionId']?.toString() ?? '';
      if (txId.isNotEmpty) {
        _processedTransactionIds.add(txId);
      }

      // Authoritative server balance reconciliation
      walletProvider.fetchWallet();

      // Trigger local animation & combo aggregation
      _enqueueLocalComboEvent(
        txId: txId.isNotEmpty ? txId : idempotencyKey,
        gift: gift,
        sender: sender,
        receiver: receiver,
        roomId: roomId,
        quantity: quantity,
      );

      notifyListeners();
      return true;
    } catch (e) {
      _isSending = false;
      _activeSendingIdempotencyKeys.remove(idempotencyKey);
      _lastError = e.toString();
      debugPrint('[LiveGiftProvider] sendGift error: $e');

      // Reconcile wallet just in case
      walletProvider.fetchWallet();
      notifyListeners();
      return false;
    }
  }

  void _enqueueLocalComboEvent({
    required String txId,
    required GiftModel gift,
    required UserModel sender,
    required UserModel receiver,
    required String roomId,
    required int quantity,
  }) {
    final comboKey = '${sender.id}_${gift.id}_${receiver.id}';
    final now = DateTime.now();

    LiveGiftEventModel event;

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
      event = LiveGiftEventModel(
        eventId: txId,
        giftId: gift.id,
        giftName: gift.name,
        giftIcon: gift.icon,
        iconUrl: gift.iconUrl,
        animationUrl: gift.svgaAssetUrl,
        animationLevel: gift.animationLevel,
        giftValue: gift.priceCoins > 0 ? gift.priceCoins : gift.diamondPrice,
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

    _comboResetTimers[comboKey] = Timer(const Duration(milliseconds: 2500), () {
      _activeComboMap.remove(comboKey);
      _comboResetTimers.remove(comboKey);
    });

    _eventStreamController.add(event);
    _enqueueEvent(event);
  }

  /// Receive realtime gift event from remote socket/server
  void receiveGiftEvent(LiveGiftEventModel event) {
    if (_activeRoomId != null && event.roomId.isNotEmpty && event.roomId != _activeRoomId) return;
    _eventStreamController.add(event);
    _enqueueEvent(event);
    notifyListeners();
  }

  void _enqueueEvent(LiveGiftEventModel event) {
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
    _socketGiftSubscription?.cancel();
    for (final timer in _comboResetTimers.values) {
      timer.cancel();
    }
    _eventStreamController.close();
    super.dispose();
  }
}
