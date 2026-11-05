import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../models/gift_model.dart';
import '../core/services/socket_service.dart';

class GiftAnimationOverlay extends StatefulWidget {
  final String? roomId;
  final Set<String>? alternativeIds;

  const GiftAnimationOverlay({
    super.key,
    this.roomId,
    this.alternativeIds,
  });

  @override
  State<GiftAnimationOverlay> createState() => GiftAnimationOverlayState();
}

class _QueuedVideoGift {
  final GiftModel gift;
  final String senderName;
  final int quantity;

  const _QueuedVideoGift({
    required this.gift,
    required this.senderName,
    required this.quantity,
  });
}

class GiftAnimationOverlayState extends State<GiftAnimationOverlay>
    with SingleTickerProviderStateMixin {
  GiftModel? _currentGift;
  String _giftSenderName = '';
  int _giftQuantity = 1;
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  StreamSubscription? _giftSub;
  StreamSubscription? _clearFeedSub;

  VideoPlayerController? _videoController;
  Timer? _videoTimer;
  bool _isVideoPlaying = false;
  final List<_QueuedVideoGift> _videoQueue = [];

  /// Skia ColorMatrix that eliminates black video backgrounds via Luma-keying:
  /// Black and dark compression artifacts (R+G+B <= 15) -> Alpha = 0 (transparent).
  /// Colored gift graphics and effects -> Alpha ramps quickly to 255 (fully visible).
  static const List<double> _blackBackgroundFilterMatrix = <double>[
    1.0, 0.0, 0.0, 0.0, 0.0,
    0.0, 1.0, 0.0, 0.0, 0.0,
    0.0, 0.0, 1.0, 0.0, 0.0,
    3.0, 3.0, 3.0, 0.0, -45.0,
  ];

  final Set<String> _processedTxIds = {};

  bool _matchesRoom(String inRoomId, [String? inClientRoomId]) {
    if (widget.roomId == null || widget.roomId!.isEmpty) return true;
    String norm(String s) => s.toLowerCase().replaceAll('room:', '').replaceAll('room_', '').trim();
    final inNorm = norm(inRoomId);
    final inClientNorm = inClientRoomId != null ? norm(inClientRoomId) : '';
    final targetNorm = norm(widget.roomId!);

    if (inNorm.isEmpty && inClientNorm.isEmpty) return true;

    final validIds = <String>{
      targetNorm,
      if (widget.alternativeIds != null) ...widget.alternativeIds!.map(norm),
    };

    return validIds.contains(inNorm) ||
        (inClientNorm.isNotEmpty && validIds.contains(inClientNorm)) ||
        validIds.any((id) =>
            (inNorm.isNotEmpty && (inNorm.contains(id) || id.contains(inNorm))) ||
            (inClientNorm.isNotEmpty && (inClientNorm.contains(id) || id.contains(inClientNorm))));
  }

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.2), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 1.0), weight: 10),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.4), weight: 20),
    ]).animate(_animController);

    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 15),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 65),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 20),
    ]).animate(_animController);

    _giftSub = SocketService.instance.onGiftSent.listen((data) {
      if (!mounted) return;
      final inRoomId = (data['roomId'] ?? data['room'] ?? '').toString();
      final inClientRoomId = (data['clientRoomId'] ?? '').toString();
      if (!_matchesRoom(inRoomId, inClientRoomId)) {
        return;
      }
      try {
        final txId = (data['transactionId'] ?? data['id'] ?? data['eventId'] ?? '').toString();
        if (txId.isNotEmpty && _processedTxIds.contains(txId)) {
          // Already played for this client (e.g. sender triggered local animation immediately)
          return;
        }

        final giftMap = data['gift'] is Map ? Map<String, dynamic>.from(data['gift']) : Map<String, dynamic>.from(data);
        final senderMap = data['sender'] is Map ? Map<String, dynamic>.from(data['sender']) : {};
        final senderName = senderMap['displayName'] ?? senderMap['username'] ?? data['senderName'] ?? 'Someone';
        final qty = data['quantity'] is int ? data['quantity'] as int : (int.tryParse(data['quantity']?.toString() ?? '1') ?? 1);

        final rawGiftId = giftMap['id']?.toString() ?? data['giftId']?.toString() ?? '';
        final rawGiftName = giftMap['name']?.toString() ?? data['giftName']?.toString() ?? '';

        // Authoritatively map raw code or name to local catalog item (e.g. 'cg11' -> 'Birthday Cake', 'cg23' -> 'Private Jet')
        final catalogGift = GiftModel.findById(rawGiftId) ?? GiftModel.findById(rawGiftName);

        final model = catalogGift ?? GiftModel(
          id: rawGiftId,
          name: rawGiftName.isNotEmpty ? rawGiftName : 'Gift',
          icon: giftMap['icon']?.toString() ?? '🎁',
          iconUrl: giftMap['iconUrl']?.toString(),
          svgaAssetUrl: giftMap['svgaAssetUrl']?.toString() ?? giftMap['animationUrl']?.toString(),
          diamondPrice: giftMap['diamondPrice'] is int ? giftMap['diamondPrice'] as int : 100,
          priceCoins: giftMap['priceCoins'] is int ? giftMap['priceCoins'] as int : 100,
          category: giftMap['category']?.toString() ?? 'Classic',
        );

        playGiftAnimation(model, senderName: senderName.toString(), quantity: qty, transactionId: txId);
      } catch (e) {
        debugPrint('[GiftAnimationOverlay] Error parsing gift event: $e');
      }
    });

    _clearFeedSub = SocketService.instance.onRoomFeedCleared.listen((_) {
      clearAnimation();
    });
  }

  void clearAnimation() {
    if (!mounted) return;
    _animController.stop();
    _videoTimer?.cancel();
    _videoController?.pause();
    _videoController?.dispose();
    _videoController = null;
    _isVideoPlaying = false;
    setState(() {
      _currentGift = null;
      _giftSenderName = '';
      _giftQuantity = 1;
    });

    if (_videoQueue.isNotEmpty) {
      final next = _videoQueue.removeAt(0);
      _playMp4Gift(next.gift, senderName: next.senderName, quantity: next.quantity);
    }
  }

  void playGiftAnimation(GiftModel gift, {String senderName = '', int quantity = 1, String? transactionId}) {
    if (!mounted) return;

    if (transactionId != null && transactionId.trim().isNotEmpty) {
      final cleanTxId = transactionId.trim();
      if (_processedTxIds.contains(cleanTxId)) {
        return; // Prevent duplicate execution of the exact same gift transaction
      }
      _processedTxIds.add(cleanTxId);
      if (_processedTxIds.length > 500) {
        _processedTxIds.remove(_processedTxIds.first);
      }
    }

    // Resolve authoritative catalog record if the passed model is missing the animation asset
    final catalogGift = GiftModel.findById(gift.id) ?? GiftModel.findById(gift.name);
    final effectiveGift = catalogGift ?? gift;

    final isMp4 = effectiveGift.svgaAssetUrl != null && effectiveGift.svgaAssetUrl!.toLowerCase().endsWith('.mp4');

    // Video gifts are owned by GiftAnimationOverlay; non-video gifts are owned exclusively by TikTokGiftOverlay
    if (!isMp4) {
      return;
    }

    if (_isVideoPlaying) {
      if (_videoQueue.length < 15) {
        _videoQueue.add(_QueuedVideoGift(
          gift: effectiveGift,
          senderName: senderName,
          quantity: quantity,
        ));
      }
      return;
    }

    _playMp4Gift(effectiveGift, senderName: senderName, quantity: quantity);
  }

  void _playMp4Gift(GiftModel gift, {String senderName = '', int quantity = 1}) async {
    final assetPath = gift.svgaAssetUrl ?? '';
    if (assetPath.isEmpty) {
      clearAnimation();
      return;
    }

    VideoPlayerController controller;
    try {
      if (assetPath.startsWith('http://') || assetPath.startsWith('https://')) {
        controller = VideoPlayerController.networkUrl(Uri.parse(assetPath));
      } else {
        controller = VideoPlayerController.asset(assetPath);
      }
      _videoController = controller;
    } catch (e) {
      debugPrint('[GiftAnimationOverlay] Video controller creation error ($assetPath): $e');
      clearAnimation();
      return;
    }

    setState(() {
      _currentGift = gift;
      _giftSenderName = senderName;
      _giftQuantity = quantity;
      _isVideoPlaying = true;
    });

    try {
      await controller.initialize();
      if (!mounted || _videoController != controller) {
        controller.dispose();
        return;
      }
      controller.setVolume(1.0);
      controller.play();
      setState(() {});

      final dur = controller.value.duration;
      final playDuration = (dur != Duration.zero) ? dur : const Duration(seconds: 4);

      _videoTimer?.cancel();
      _videoTimer = Timer(playDuration, () {
        if (mounted && _videoController == controller) {
          clearAnimation();
        }
      });
    } catch (e) {
      debugPrint('[GiftAnimationOverlay] Video playback init failed ($assetPath): $e');
      if (mounted) {
        _isVideoPlaying = false;
        _animController.forward(from: 0.0).then((_) {
          if (mounted) clearAnimation();
        });
      }
    }
  }

  @override
  void dispose() {
    _giftSub?.cancel();
    _clearFeedSub?.cancel();
    _animController.dispose();
    _videoTimer?.cancel();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_currentGift == null) return const SizedBox.shrink();

    if (_isVideoPlaying && _videoController != null && _videoController!.value.isInitialized) {
      final totalCoins = (_currentGift!.priceCoins > 0 ? _currentGift!.priceCoins : _currentGift!.diamondPrice) * _giftQuantity;
      return IgnorePointer(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Centered Animated Video Frame
            Center(
              child: SizedBox(
                width: MediaQuery.of(context).size.width * 0.95,
                height: MediaQuery.of(context).size.height * 0.58,
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: SizedBox(
                    width: _videoController!.value.size.width > 0 ? _videoController!.value.size.width : 400,
                    height: _videoController!.value.size.height > 0 ? _videoController!.value.size.height : 400,
                    child: ColorFiltered(
                      colorFilter: const ColorFilter.matrix(_blackBackgroundFilterMatrix),
                      child: VideoPlayer(_videoController!),
                    ),
                  ),
                ),
              ),
            ),

            // Top-Floating Luxury Gift Banner
            Positioned(
              top: MediaQuery.of(context).padding.top + 75,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8E24AA), Color(0xFFFF1744), Color(0xFFFF8F00)],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFFFD700), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF1744).withValues(alpha: 0.6),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.8), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: ColorFiltered(
                          colorFilter: const ColorFilter.matrix(_blackBackgroundFilterMatrix),
                          child: _currentGift!.icon.startsWith('assets/')
                              ? Image.asset(
                                  _currentGift!.icon,
                                  width: 38,
                                  height: 38,
                                  fit: BoxFit.contain,
                                )
                              : (_currentGift!.icon.startsWith('http')
                                  ? Image.network(
                                      _currentGift!.icon,
                                      width: 38,
                                      height: 38,
                                      fit: BoxFit.contain,
                                    )
                                  : Center(child: Text(_currentGift!.icon, style: const TextStyle(fontSize: 20)))),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _giftSenderName.isNotEmpty
                              ? '$_giftSenderName sent $_giftQuantity × ${_currentGift!.name}'
                              : 'SPECIAL GIFT: ${_currentGift!.name}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                            letterSpacing: 0.8,
                          ),
                        ),
                        Text(
                          '$totalCoins Coins 🪙',
                          style: const TextStyle(
                            color: Color(0xFFFFD700),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return IgnorePointer(
      child: Center(
        child: AnimatedBuilder(
          animation: _animController,
          builder: (context, child) {
            String iconPath = _currentGift!.icon;
            if (!iconPath.startsWith('assets/') &&
                !iconPath.startsWith('http') &&
                _currentGift!.svgaAssetUrl != null &&
                _currentGift!.svgaAssetUrl!.endsWith('.mp4')) {
              iconPath = _currentGift!.svgaAssetUrl!.replaceAll('.mp4', '.png');
            }

            return Opacity(
              opacity: _opacityAnimation.value.clamp(0.0, 1.0),
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: _buildPureGiftDisplay(iconPath),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPureGiftDisplay(String iconPath) {
    Widget giftImage;
    if (iconPath.startsWith('assets/')) {
      giftImage = Image.asset(
        iconPath,
        width: 180,
        height: 180,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => Text(
          _currentGift!.icon.length < 4 ? _currentGift!.icon : '🎁',
          style: const TextStyle(fontSize: 100),
        ),
      );
    } else if (iconPath.startsWith('http')) {
      giftImage = Image.network(
        iconPath,
        width: 180,
        height: 180,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => const Text('🎁', style: TextStyle(fontSize: 100)),
      );
    } else {
      giftImage = Text(_currentGift!.icon, style: const TextStyle(fontSize: 100));
    }

    if (_giftQuantity > 1) {
      return Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          giftImage,
          Positioned(
            right: -10,
            bottom: -10,
            child: Text(
              '×$_giftQuantity',
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w900,
                color: Color(0xFFFFD700),
                shadows: [
                  Shadow(color: Colors.black87, blurRadius: 10, offset: Offset(2, 2)),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return giftImage;
  }
}

