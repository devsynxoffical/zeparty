import 'dart:async';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import 'user_avatar.dart';

class SvipEntryManager {
  static final SvipEntryManager _instance = SvipEntryManager._internal();
  factory SvipEntryManager() => _instance;
  SvipEntryManager._internal();

  final _eventController = StreamController<UserModel>.broadcast();
  Stream<UserModel> get onEntry => _eventController.stream;

  void showEntry(UserModel user) {
    if (user.isVip) {
      _eventController.add(user);
    }
  }
}

class SvipEntryBanner extends StatefulWidget {
  const SvipEntryBanner({super.key});

  @override
  State<SvipEntryBanner> createState() => _SvipEntryBannerState();
}

class _SvipEntryBannerState extends State<SvipEntryBanner> with TickerProviderStateMixin {
  final List<UserModel> _queue = [];
  UserModel? _currentUser;
  bool _isAnimating = false;
  late StreamSubscription _subscription;
  
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _slideAnimation = Tween<Offset>(begin: const Offset(-1.5, 0), end: Offset.zero).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutBack,
    ));

    _subscription = SvipEntryManager().onEntry.listen((user) {
      _queue.add(user);
      _processQueue();
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    _slideController.dispose();
    super.dispose();
  }

  void _processQueue() async {
    if (_isAnimating || _queue.isEmpty) return;

    setState(() {
      _isAnimating = true;
      _currentUser = _queue.removeAt(0);
    });

    await _slideController.forward();
    await Future.delayed(const Duration(seconds: 3));
    await _slideController.reverse();

    setState(() {
      _currentUser = null;
      _isAnimating = false;
    });

    _processQueue();
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) return const SizedBox.shrink();

    return IgnorePointer(
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Colors.amber, Colors.orange, Colors.deepOrange]),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(color: Colors.orange.withValues(alpha: 0.5), blurRadius: 12, spreadRadius: 2),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                child: UserAvatar(imageUrl: _currentUser!.avatarUrl, radius: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Row(
                      children: [
                        Text('SVIP', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10, fontStyle: FontStyle.italic)),
                        SizedBox(width: 4),
                        Icon(Icons.flash_on, color: Colors.white, size: 10),
                      ],
                    ),
                    Text(
                      '${_currentUser!.name} entered!',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.directions_car_filled_rounded, color: Colors.white, size: 24),
            ],
          ),
        ),
      ),
    );
  }
}
