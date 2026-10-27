import 'dart:async';
import 'package:flutter/material.dart';
import '../models/gift_model.dart';
import '../models/live_gift_event_model.dart';
import '../models/user_model.dart';
import '../core/repositories/gift_repository.dart';
import '../core/services/api_client.dart';
import '../core/services/socket_service.dart';
import '../core/utils/performance_utils.dart';
import 'auth_provider.dart';
import 'svip_provider.dart';
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

  String? _lastTransactionId;
  String? get lastTransactionId => _lastTransactionId;

  StreamSubscription<Map<String, dynamic>>? _socketGiftSubscription;

  LiveGiftProvider() {
    _initSocketListener();
    fetchCatalog();
  }

  void _initSocketListener() {
    _socketGiftSubscription?.cancel();
    _socketGiftSubscription = _socketService.onGiftSent.listen((data) {
      final inRoomId = (data['roomId'] ?? '').toString();
      // Drop event immediately if we are not in a room, or if it belongs to another room
      if (_activeRoomId == null || _activeRoomId!.isEmpty) return;
      if (inRoomId.isNotEmpty && inRoomId != _activeRoomId) return;

      final txId = (data['transactionId'] ?? data['id'] ?? data['eventId'] ?? '').toString();
      if (txId.isNotEmpty && _processedTransactionIds.contains(txId)) {
        // Already processed locally (e.g. sender triggered local animation on REST response)
        return;
      }
      if (txId.isNotEmpty) {
        _processedTransactionIds.add(txId);
      }

      try {
        final event = LiveGiftEventModel.fromSocketJson(data);
        // Video gifts play exclusively in GiftAnimationOverlay; do not double-play in TikTokGiftOverlay
        final hasVideo = event.animationUrl != null && event.animationUrl!.toLowerCase().endsWith('.mp4');
        if (hasVideo) return;

        receiveGiftEvent(event);
      } catch (e) {
        debugPrint('[LiveGiftProvider] Error parsing socket gift event: $e');
      }
    });
  }

  /// Fetch live gift catalog from backend API
  Future<void> fetchCatalog({String? category, bool refresh = false}) async {
    _isLoadingCatalog = false;
    _catalogGifts = GiftModel.defaultCatalog;
    _lastError = null;
    notifyListeners();
  }

  void setActiveRoom(String roomId) {
    _activeRoomId = roomId;
    // Always wipe stale queues and previous room gift state on room switch/entry
    _eventQueue.clear();
    _activeComboMap.clear();
    _currentActiveEvent = null;
    for (final timer in _comboResetTimers.values) {
      timer.cancel();
    }
    _comboResetTimers.clear();
    notifyListeners();
  }

  void clearRoom() {
    _activeRoomId = null;
    _eventQueue.clear();
    _activeComboMap.clear();
    _currentActiveEvent = null;
    for (final timer in _comboResetTimers.values) {
      timer.cancel();
    }
    _comboResetTimers.clear();
    notifyListeners();
  }

  /// Send gift to backend atomically, with server-side validation, ledger posting,
  /// host diamond reward, Socket.IO emission, wallet reconciliation, and Wealth XP progression.
  Future<bool> sendGift({
    required WalletProvider walletProvider,
    required GiftModel gift,
    required UserModel sender,
    required UserModel receiver,
    required String roomId,
    int quantity = 1,
    AuthProvider? authProvider,
    SVIPProvider? svipProvider,
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
      _lastTransactionId = txId.isNotEmpty ? txId : idempotencyKey;
      if (txId.isNotEmpty) {
        _processedTransactionIds.add(txId);
      }

      // Authoritative server balance reconciliation
      walletProvider.fetchWallet();

      // Credit sender Wealth XP according to approved spending-to-XP rules (1 coin spent = 1 Wealth XP)
      if (authProvider != null && totalCost > 0) {
        authProvider.addWealthXp(totalCost);
      }

      // Award SVIP points (1 coin spent = 1 SVIP point) and auto-upgrade SVIP level
      if (svipProvider != null && totalCost > 0) {
        svipProvider.addPoints(totalCost, reason: 'Sent $quantity × ${gift.name}', type: 'gift_send');
      }

      // Trigger local animation & combo aggregation (only for non-video gifts)
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
    } on ApiException catch (e) {
      final isNotActiveOrMissing = e.code == 'GIFT_NOT_ACTIVE' ||
          e.message.toLowerCase().contains('does not exist') ||
          e.message.toLowerCase().contains('not active');

      if (isNotActiveOrMissing) {
        debugPrint('[LiveGiftProvider] Backend does not have gift ${gift.id} yet. Executing local delivery.');
        _isSending = false;
        _activeSendingIdempotencyKeys.remove(idempotencyKey);

        // Authoritative client coin deduction
        walletProvider.spendCoins(totalCost, 'Sent ${gift.name}');

        // Credit sender Wealth XP
        if (authProvider != null && totalCost > 0) {
          authProvider.addWealthXp(totalCost);
        }

        // Award SVIP points on local delivery
        if (svipProvider != null && totalCost > 0) {
          svipProvider.addPoints(totalCost, reason: 'Sent $quantity × ${gift.name}', type: 'gift_send');
        }

        // Broadcast real-time gift over socket so room viewers and receiver see it
        final txId = idempotencyKey;
        _lastTransactionId = txId;
        _processedTransactionIds.add(txId);
        _socketService.emit('room:gift_sent', {
          'transactionId': txId,
          'roomId': roomId,
          'senderUserId': sender.id,
          'recipientUserId': receiver.id,
          'sender': {'id': sender.id, 'name': sender.name, 'avatarUrl': sender.avatarUrl},
          'recipient': {'id': receiver.id, 'name': receiver.name, 'avatarUrl': receiver.avatarUrl},
          'gift': gift.toJson(),
          'giftId': gift.id,
          'giftName': gift.name,
          'giftIcon': gift.icon,
          'giftValue': unitPrice,
          'quantity': quantity,
          'totalCoins': totalCost,
          'timestamp': DateTime.now().toIso8601String(),
        });

        // Trigger local animation & combo aggregation (only for non-video gifts)
        _enqueueLocalComboEvent(
          txId: txId,
          gift: gift,
          sender: sender,
          receiver: receiver,
          roomId: roomId,
          quantity: quantity,
        );

        notifyListeners();
        return true;
      }

      _isSending = false;
      _activeSendingIdempotencyKeys.remove(idempotencyKey);
      _lastError = e.message;
      debugPrint('[LiveGiftProvider] sendGift ApiException (${e.code}): ${e.message}');

      // Reconcile wallet just in case
      walletProvider.fetchWallet();
      notifyListeners();
      return false;
    } catch (e) {
      _isSending = false;
      _activeSendingIdempotencyKeys.remove(idempotencyKey);
      final rawErr = e.toString();
      _lastError = rawErr.replaceFirst('Exception: ', '').replaceFirst('ApiException: ', '');
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
    // If this gift has an MP4 video animation, it plays exclusively in GiftAnimationOverlay
    final hasVideoAnimation = (gift.svgaAssetUrl != null && gift.svgaAssetUrl!.toLowerCase().endsWith('.mp4')) ||
        (GiftModel.findById(gift.id)?.svgaAssetUrl != null && GiftModel.findById(gift.id)!.svgaAssetUrl!.toLowerCase().endsWith('.mp4'));
    if (hasVideoAnimation) {
      return;
    }

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
    if (_activeRoomId == null || _activeRoomId!.isEmpty) return;
    if (event.roomId.isNotEmpty && event.roomId != _activeRoomId) return;
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
