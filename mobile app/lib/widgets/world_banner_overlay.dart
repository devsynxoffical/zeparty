import 'dart:async';
import 'dart:collection';
import 'package:flutter/material.dart';
import '../core/services/socket_service.dart';
import '../models/live_room_model.dart';
import '../models/user_model.dart';
import '../features/party_room/live_party_room_screen.dart';

class WorldBannerItem {
  final String id;
  final String type; // 'gift' or 'rocket'
  final String? title;
  final String? senderName;
  final String? senderId;
  final String? senderAvatar;
  final String? receiverName;
  final String? receiverAvatar;
  final String? giftName;
  final String? giftIcon;
  final int? coinValue;
  final int? rocketLevel;
  final int? rewardCoins;
  final String roomId;
  final String roomName;

  WorldBannerItem({
    required this.id,
    required this.type,
    this.title,
    this.senderName,
    this.senderId,
    this.senderAvatar,
    this.receiverName,
    this.receiverAvatar,
    this.giftName,
    this.giftIcon,
    this.coinValue,
    this.rocketLevel,
    this.rewardCoins,
    required this.roomId,
    required this.roomName,
  });

  factory WorldBannerItem.fromGift(Map<String, dynamic> data) {
    final sender = data['sender'] as Map<String, dynamic>?;
    final recipient = data['recipient'] as Map<String, dynamic>?;
    final gift = data['gift'] as Map<String, dynamic>?;

    final coins = data['coinValue'] ?? data['amount'] ?? data['totalCoins'] ?? 0;
    final parsedCoins = coins is int ? coins : int.tryParse(coins.toString()) ?? 0;

    return WorldBannerItem(
      id: data['transactionId']?.toString() ?? 'gift_${DateTime.now().millisecondsSinceEpoch}',
      type: 'gift',
      senderName: data['senderName'] ?? sender?['displayName'] ?? sender?['username'] ?? 'User',
      senderId: data['senderId']?.toString() ?? sender?['id']?.toString() ?? '',
      senderAvatar: data['senderAvatar'] ?? sender?['avatarUrl'],
      receiverName: data['receiverName'] ?? recipient?['displayName'] ?? recipient?['username'] ?? 'Host',
      receiverAvatar: data['receiverAvatar'] ?? recipient?['avatarUrl'],
      giftName: data['giftName'] ?? gift?['name'] ?? 'Gift',
      giftIcon: data['giftIcon'] ?? gift?['iconUrl'],
      coinValue: parsedCoins,
      roomId: data['roomId']?.toString() ?? '',
      roomName: data['roomName']?.toString() ?? "Party Room",
    );
  }

  factory WorldBannerItem.fromRocket(Map<String, dynamic> data) {
    return WorldBannerItem(
      id: 'rocket_${data['rocketLevel']}_${DateTime.now().millisecondsSinceEpoch}',
      type: 'rocket',
      title: data['title'] ?? 'WORLD | ROCKET ${data['rocketLevel']} UNLOCKED',
      rocketLevel: data['rocketLevel'] is int ? data['rocketLevel'] : int.tryParse(data['rocketLevel']?.toString() ?? '1') ?? 1,
      rewardCoins: data['reward'] is int ? data['reward'] : int.tryParse(data['reward']?.toString() ?? '5000') ?? 5000,
      senderName: data['topSenderName'] ?? 'Top Sender',
      roomId: data['roomId']?.toString() ?? '',
      roomName: data['roomName']?.toString() ?? "Party Room",
    );
  }
}

class WorldBannerOverlay extends StatefulWidget {
  final String? currentRoomId;
  const WorldBannerOverlay({super.key, this.currentRoomId});

  @override
  State<WorldBannerOverlay> createState() => _WorldBannerOverlayState();
}

class _WorldBannerOverlayState extends State<WorldBannerOverlay> with SingleTickerProviderStateMixin {
  final Queue<WorldBannerItem> _queue = Queue<WorldBannerItem>();
  WorldBannerItem? _activeItem;
  late AnimationController _animController;
  late Animation<Offset> _slideAnimation;
  Timer? _displayTimer;
  StreamSubscription? _giftBannerSub;
  StreamSubscription? _rocketBannerSub;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1.4),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    ));

    _initSocketListeners();
  }

  void _initSocketListeners() {
    final socket = SocketService.instance;
    _giftBannerSub = socket.onEvent('world:gift_banner').listen((data) {
      if (data is Map<String, dynamic>) {
        _enqueue(WorldBannerItem.fromGift(data));
      }
    });

    _rocketBannerSub = socket.onEvent('world:rocket_unlocked').listen((data) {
      if (data is Map<String, dynamic>) {
        _enqueue(WorldBannerItem.fromRocket(data));
      }
    });
  }

  void _enqueue(WorldBannerItem item) {
    if (!mounted) return;
    _queue.add(item);
    if (_activeItem == null) {
      _showNext();
    }
  }

  void _showNext() {
    if (_queue.isEmpty || !mounted) {
      setState(() => _activeItem = null);
      return;
    }

    final next = _queue.removeFirst();
    setState(() => _activeItem = next);
    _animController.forward(from: 0.0);

    // Visible for 4.5 seconds
    _displayTimer?.cancel();
    _displayTimer = Timer(const Duration(milliseconds: 4500), () {
      if (mounted) {
        _animController.reverse().then((_) {
          if (mounted) {
            _showNext();
          }
        });
      }
    });
  }

  void _onBannerTap() {
    if (_activeItem == null) return;
    final targetRoomId = _activeItem!.roomId;
    if (targetRoomId.isEmpty) return;

    // If already in target room, do nothing
    if (widget.currentRoomId != null &&
        (widget.currentRoomId == targetRoomId || widget.currentRoomId!.startsWith(targetRoomId) || targetRoomId.startsWith(widget.currentRoomId!))) {
      return;
    }

    _displayTimer?.cancel();
    _animController.reverse();

    // Deep link navigate to originating room
    final targetRoom = LiveRoomModel(
      id: targetRoomId,
      title: _activeItem!.roomName,
      host: UserModel(
        id: 'host_$targetRoomId',
        name: _activeItem!.roomName,
        username: 'host',
        avatarUrl: '',
      ),
      coverUrl: '',
      viewerCount: 0,
      category: 'Chat',
      isPrivate: false,
      announcement: '',
      startTime: DateTime.now(),
      roomType: 'AUDIO_PARTY',
      seatCapacity: 8,
      nobleTitle: '',
      status: 'LIVE',
      isPinnedTop: false,
      isPkActive: false,
      isMuted: false,
      membershipFee: 0,
      roomMode: 'Public mode',
      allowGuestMic: true,
      allowHistoryMessages: true,
      allowUnderMicEmoji: true,
      allowUnderMicDice: true,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LivePartyRoomScreen(room: targetRoom),
      ),
    );
  }

  @override
  void dispose() {
    _displayTimer?.cancel();
    _giftBannerSub?.cancel();
    _rocketBannerSub?.cancel();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_activeItem == null) return const SizedBox.shrink();

    final item = _activeItem!;
    final isRocket = item.type == 'rocket';

    return SlideTransition(
      position: _slideAnimation,
      child: Center(
        child: GestureDetector(
          onTap: _onBannerTap,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400, minWidth: 320),
            margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: isRocket
                  ? const LinearGradient(
                      colors: [Color(0xFF5C3810), Color(0xFF2C1E0A), Color(0xFF140D04)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : const LinearGradient(
                      colors: [Color(0xFF38144C), Color(0xFF200B2D), Color(0xFF0F0417)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isRocket ? const Color(0xFFFFB800) : const Color(0xFFFF77C6),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: (isRocket ? Colors.amber : Colors.purpleAccent).withValues(alpha: 0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: isRocket ? _buildRocketBanner(item) : _buildGiftBanner(item),
          ),
        ),
      ),
    );
  }

  Widget _buildRocketBanner(WorldBannerItem item) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('🚀', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            Text(
              item.title ?? 'WORLD | ROCKET ${item.rocketLevel} UNLOCKED',
              style: const TextStyle(
                color: Color(0xFFFFD56B),
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${item.rewardCoins ?? 5000} Coins',
                style: const TextStyle(color: Color(0xFFFFD56B), fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Text(
                '${item.roomName} • Tap to join this room >',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 11),
          ],
        ),
      ],
    );
  }

  Widget _buildGiftBanner(WorldBannerItem item) {
    return Row(
      children: [
        // Sender Avatar
        CircleAvatar(
          radius: 16,
          backgroundColor: Colors.white24,
          backgroundImage: (item.senderAvatar != null && item.senderAvatar!.isNotEmpty)
              ? NetworkImage(item.senderAvatar!)
              : null,
          child: (item.senderAvatar == null || item.senderAvatar!.isEmpty)
              ? Text(
                  item.senderName?.isNotEmpty == true ? item.senderName![0].toUpperCase() : 'U',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                )
              : null,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: '${item.senderName} ',
                      style: const TextStyle(color: Color(0xFFFFB3E6), fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                    const TextSpan(
                      text: 'sent ',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                    TextSpan(
                      text: '${item.giftName} ',
                      style: const TextStyle(color: Color(0xFFFFD56B), fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                    const TextSpan(
                      text: 'to ',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                    TextSpan(
                      text: '${item.receiverName}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: Colors.pinkAccent.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${item.coinValue?.toString() ?? '0'} Coins',
                      style: const TextStyle(color: Color(0xFFFF85D0), fontSize: 9.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${item.roomName} • Tap to view >',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white60, fontSize: 10),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        // Gift Icon
        if (item.giftIcon != null && item.giftIcon!.isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: item.giftIcon!.startsWith('http')
                ? Image.network(item.giftIcon!, width: 32, height: 32, fit: BoxFit.contain)
                : Image.asset(item.giftIcon!, width: 32, height: 32, fit: BoxFit.contain),
          )
        else
          const Text('🎁', style: TextStyle(fontSize: 22)),
      ],
    );
  }
}
