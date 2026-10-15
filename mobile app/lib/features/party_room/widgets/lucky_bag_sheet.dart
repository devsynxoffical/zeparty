import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/user_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/live_party_provider.dart';
import '../../../providers/wallet_provider.dart';
import '../../../widgets/user_avatar.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Item 06: Normal & World Lucky Bag Module
// ─────────────────────────────────────────────────────────────────────────────

enum LuckyBagMode { normal, world }
enum LuckyBagTask { none, followMe, followRoom }
enum LuckyBagCountdown { none, fiveMins }

class LuckyBagClaimRecord {
  final String userId;
  final String userName;
  final String userAvatar;
  final int coins;
  final DateTime claimedAt;

  LuckyBagClaimRecord({
    required this.userId,
    required this.userName,
    required this.userAvatar,
    required this.coins,
    required this.claimedAt,
  });
}

class LuckyBagModel {
  final String id;
  final LuckyBagMode mode;
  final String senderId;
  final String senderName;
  final String senderAvatar;
  final String sourceRoomId;
  final String sourceRoomTitle;
  final int totalCoins;
  final int totalClaims;
  int claimsRemaining;
  int coinsRemaining;
  final LuckyBagTask task;
  final int countdownSeconds;
  final DateTime createdAt;
  final DateTime opensAt;
  final List<LuckyBagClaimRecord> claims;

  LuckyBagModel({
    required this.id,
    required this.mode,
    required this.senderId,
    required this.senderName,
    required this.senderAvatar,
    required this.sourceRoomId,
    required this.sourceRoomTitle,
    required this.totalCoins,
    required this.totalClaims,
    required this.claimsRemaining,
    required this.coinsRemaining,
    required this.task,
    required this.countdownSeconds,
    required this.createdAt,
    required this.opensAt,
    List<LuckyBagClaimRecord>? claims,
  }) : claims = claims ?? [];

  bool get isOpen => DateTime.now().isAfter(opensAt);
  bool get isFullyClaimed => claimsRemaining <= 0 || coinsRemaining <= 0;
  bool get isExpired => DateTime.now().difference(createdAt).inMinutes > 60;
  bool hasUserClaimed(String userId) => claims.any((c) => c.userId == userId);

  Duration get timeUntilOpen {
    final diff = opensAt.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Singleton LuckyBagService (In-Memory State & Bus)
// ─────────────────────────────────────────────────────────────────────────────

class LuckyBagService extends ChangeNotifier {
  static final LuckyBagService instance = LuckyBagService._internal();
  LuckyBagService._internal();

  final Map<String, LuckyBagModel> _roomBags = {};
  LuckyBagModel? _worldBag;
  final List<LuckyBagModel> _history = [];
  final Set<String> _followedUsers = {};
  final Set<String> _followedRooms = {};

  LuckyBagModel? getRoomBag(String roomId) => _roomBags[roomId];
  LuckyBagModel? get worldBag => _worldBag;
  List<LuckyBagModel> get history => List.unmodifiable(_history);

  bool isFollowingUser(String userId) => _followedUsers.contains(userId);
  bool isFollowingRoom(String roomId) => _followedRooms.contains(roomId);

  void followUser(String userId) {
    _followedUsers.add(userId);
    notifyListeners();
  }

  void followRoom(String roomId) {
    _followedRooms.add(roomId);
    notifyListeners();
  }

  void createLuckyBag(LuckyBagModel bag) {
    if (bag.mode == LuckyBagMode.world) {
      _worldBag = bag;
    }
    _roomBags[bag.sourceRoomId] = bag;
    _history.insert(0, bag);
    notifyListeners();
  }

  Map<String, dynamic> claimBag({
    required LuckyBagModel bag,
    required UserModel claimant,
  }) {
    if (!bag.isOpen) {
      return {'success': false, 'message': 'Bag is not open yet!'};
    }
    if (bag.isFullyClaimed) {
      return {'success': false, 'message': 'Lucky Bag is fully claimed!'};
    }
    if (bag.hasUserClaimed(claimant.id)) {
      final existing = bag.claims.firstWhere((c) => c.userId == claimant.id);
      return {
        'success': false,
        'alreadyClaimed': true,
        'coins': existing.coins,
        'message': 'You already claimed ${existing.coins} coins!',
      };
    }

    // Server-grade randomized reward calculation
    final rand = Random();
    int reward;
    if (bag.claimsRemaining == 1) {
      reward = bag.coinsRemaining;
    } else {
      final maxShare = (bag.coinsRemaining / bag.claimsRemaining * 2.0).round();
      final minShare = max(1, (bag.coinsRemaining / (bag.claimsRemaining * 5)).floor());
      reward = minShare + (maxShare > minShare ? rand.nextInt(maxShare - minShare) : 0);
      reward = reward.clamp(1, bag.coinsRemaining - (bag.claimsRemaining - 1));
    }

    bag.coinsRemaining -= reward;
    bag.claimsRemaining -= 1;

    final record = LuckyBagClaimRecord(
      userId: claimant.id,
      userName: claimant.name.isNotEmpty ? claimant.name : 'User_${claimant.id.substring(0, min(4, claimant.id.length))}',
      userAvatar: claimant.avatarUrl,
      coins: reward,
      claimedAt: DateTime.now(),
    );
    bag.claims.insert(0, record);

    notifyListeners();
    return {
      'success': true,
      'coins': reward,
      'remainingClaims': bag.claimsRemaining,
      'message': 'Claimed $reward coins!',
    };
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Lucky Bag Create Sheet (Matches Screen I & Screen J)
// ─────────────────────────────────────────────────────────────────────────────

class LuckyBagCreateSheet extends StatefulWidget {
  final String roomId;
  final String roomTitle;

  const LuckyBagCreateSheet({
    super.key,
    required this.roomId,
    required this.roomTitle,
  });

  static void show(BuildContext context, {required String roomId, required String roomTitle}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LuckyBagCreateSheet(roomId: roomId, roomTitle: roomTitle),
    );
  }

  @override
  State<LuckyBagCreateSheet> createState() => _LuckyBagCreateSheetState();
}

class _LuckyBagCreateSheetState extends State<LuckyBagCreateSheet> {
  LuckyBagMode _mode = LuckyBagMode.normal;
  LuckyBagTask _task = LuckyBagTask.none;
  LuckyBagCountdown _countdown = LuckyBagCountdown.none;

  late TextEditingController _coinsCtrl;
  late TextEditingController _quantityCtrl;

  // Mode-specific configuration limits
  int get minCoins => _mode == LuckyBagMode.normal ? 500 : 6666;
  int get maxCoins => _mode == LuckyBagMode.normal ? 10000 : 100000;
  int get minQuantity => _mode == LuckyBagMode.normal ? 3 : 50;
  int get maxQuantity => _mode == LuckyBagMode.normal ? 20 : 300;

  @override
  void initState() {
    super.initState();
    _coinsCtrl = TextEditingController(text: '800');
    _quantityCtrl = TextEditingController(text: '20');
  }

  @override
  void dispose() {
    _coinsCtrl.dispose();
    _quantityCtrl.dispose();
    super.dispose();
  }

  void _switchMode(LuckyBagMode newMode) {
    if (_mode == newMode) return;
    setState(() {
      _mode = newMode;
      if (_mode == LuckyBagMode.world) {
        _coinsCtrl.text = '8888';
        _quantityCtrl.text = '100';
      } else {
        _coinsCtrl.text = '800';
        _quantityCtrl.text = '20';
      }
    });
  }

  void _submit() {
    final coins = int.tryParse(_coinsCtrl.text.trim()) ?? 0;
    final quantity = int.tryParse(_quantityCtrl.text.trim()) ?? 0;

    if (coins < minCoins || coins > maxCoins) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Coins must be between $minCoins and $maxCoins'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (quantity < minQuantity || quantity > maxQuantity) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Quantity must be between $minQuantity and $maxQuantity'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final authUser = context.read<AuthProvider>().currentUser;
    final wallet = context.read<WalletProvider>();

    // Deduct coins
    final success = wallet.spendCoins(coins, '${_mode == LuckyBagMode.world ? "World" : "Normal"} Lucky Bag');
    if (!success && wallet.coins < coins) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Insufficient balance! You need $coins coins (You have: ${wallet.coins}).'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final countdownSecs = _countdown == LuckyBagCountdown.fiveMins ? 300 : 0;
    final now = DateTime.now();
    final bag = LuckyBagModel(
      id: 'bag_${now.millisecondsSinceEpoch}',
      mode: _mode,
      senderId: authUser.id,
      senderName: authUser.name.isNotEmpty ? authUser.name : 'Host',
      senderAvatar: authUser.avatarUrl,
      sourceRoomId: widget.roomId,
      sourceRoomTitle: widget.roomTitle,
      totalCoins: coins,
      totalClaims: quantity,
      claimsRemaining: quantity,
      coinsRemaining: coins,
      task: _task,
      countdownSeconds: countdownSecs,
      createdAt: now,
      opensAt: now.add(Duration(seconds: countdownSecs)),
    );

    LuckyBagService.instance.createLuckyBag(bag);

    // Also notify LivePartyProvider
    context.read<LivePartyProvider>().createLuckyBag(
      id: bag.id,
      totalCoins: coins,
      totalClaims: quantity,
    );

    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _mode == LuckyBagMode.world
              ? '🌍 World Lucky Bag launched with $coins Coins for $quantity users across all rooms!'
              : '💰 Normal Lucky Bag launched with $coins Coins for $quantity users in this room!',
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF6F17E3),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Top Bar ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.settings_outlined, color: Colors.white70),
                      onPressed: () {},
                    ),
                    const Spacer(),
                    // Center Art
                    Image.asset(
                      'assets/images/party_tool_luckybag.png',
                      height: 48,
                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.card_giftcard_rounded, color: Colors.amber, size: 40),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.help_outline_rounded, color: Colors.white70),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            backgroundColor: const Color(0xFF1E1B2E),
                            title: const Text('Lucky Bag Rules', style: TextStyle(color: Colors.white)),
                            content: const Text(
                              '• Normal Lucky Bag: Released in current room only.\n'
                              '• World Lucky Bag: Broadcast to all rooms with a global notification.\n'
                              '• Coins are deducted once upon creation.\n'
                              '• Users claim rewards freely when countdown ends.',
                              style: TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
                            ],
                          ),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.receipt_long_rounded, color: Colors.white70),
                      onPressed: () {
                        LuckyBagHistorySheet.show(context);
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // ── Tabs Switcher (Normal / World) ──
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _switchMode(LuckyBagMode.normal),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _mode == LuckyBagMode.normal ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(25),
                          ),
                          child: Center(
                            child: Text(
                              'Normal Lucky Bag',
                              style: TextStyle(
                                color: _mode == LuckyBagMode.normal ? const Color(0xFF6F17E3) : Colors.white70,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _switchMode(LuckyBagMode.world),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _mode == LuckyBagMode.world ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(25),
                          ),
                          child: Center(
                            child: Text(
                              'World Lucky Bag',
                              style: TextStyle(
                                color: _mode == LuckyBagMode.world ? const Color(0xFF6F17E3) : Colors.white70,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // Subtitle
              Text(
                _mode == LuckyBagMode.world
                    ? 'World lucky bag will be sent to all rooms'
                    : 'Normal lucky bag will be sent to this room only',
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),

              const SizedBox(height: 16),

              // ── Coins Input Field ──
              _buildInputField(
                label: 'Coins',
                sublabel: '($minCoins-$maxCoins)',
                controller: _coinsCtrl,
                iconText: '🪙',
                keyboardType: TextInputType.number,
              ),

              const SizedBox(height: 12),

              // ── Quantity Input Field ──
              _buildInputField(
                label: 'Quantity',
                sublabel: '($minQuantity-$maxQuantity)',
                controller: _quantityCtrl,
                iconText: '👤',
                keyboardType: TextInputType.number,
              ),

              const SizedBox(height: 16),

              // ── Tasks Section ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Text('Tasks', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                        SizedBox(width: 6),
                        Text('Set task to grow followers!', style: TextStyle(color: Colors.white60, fontSize: 11)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildTaskPill('None', LuckyBagTask.none),
                        const SizedBox(width: 8),
                        _buildTaskPill('Follow me', LuckyBagTask.followMe),
                        const SizedBox(width: 8),
                        _buildTaskPill('Follow the room', LuckyBagTask.followRoom),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── Countdown Section ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Text('Countdown', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                        SizedBox(width: 6),
                        Text('Set timer, build the excitement!', style: TextStyle(color: Colors.white60, fontSize: 11)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildCountdownPill('None', LuckyBagCountdown.none),
                        const SizedBox(width: 8),
                        _buildCountdownPill('5 mins', LuckyBagCountdown.fiveMins),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── Send Button ──
              Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 20),
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFDD00), Color(0xFFFF9900)],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                  onPressed: _submit,
                  child: const Text(
                    'Send',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // Footer indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Text('🟡 8 >', style: TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Be a noble increase the number of lucky bags sent',
                style: TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required String sublabel,
    required TextEditingController controller,
    required String iconText,
    required TextInputType keyboardType,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              Text(sublabel, style: const TextStyle(color: Colors.white54, fontSize: 10)),
            ],
          ),
          const Spacer(),
          SizedBox(
            width: 100,
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              textAlign: TextAlign.right,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              decoration: InputDecoration(
                suffixText: ' $iconText',
                suffixStyle: const TextStyle(fontSize: 14),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskPill(String title, LuckyBagTask task) {
    final isSelected = _task == task;
    return GestureDetector(
      onTap: () => setState(() => _task = task),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white.withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildCountdownPill(String title, LuckyBagCountdown countdown) {
    final isSelected = _countdown == countdown;
    return GestureDetector(
      onTap: () => setState(() => _countdown = countdown),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white.withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Lucky Bag Claim Sheet
// ─────────────────────────────────────────────────────────────────────────────

class LuckyBagClaimSheet extends StatefulWidget {
  final LuckyBagModel bag;

  const LuckyBagClaimSheet({super.key, required this.bag});

  static void show(BuildContext context, LuckyBagModel bag) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LuckyBagClaimSheet(bag: bag),
    );
  }

  @override
  State<LuckyBagClaimSheet> createState() => _LuckyBagClaimSheetState();
}

class _LuckyBagClaimSheetState extends State<LuckyBagClaimSheet> {
  Timer? _countdownTimer;
  int? _claimedCoins;
  bool _isClaiming = false;

  @override
  void initState() {
    super.initState();
    if (!widget.bag.isOpen) {
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {
            if (widget.bag.isOpen) {
              timer.cancel();
            }
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _onClaimPressed() {
    final authUser = context.read<AuthProvider>().currentUser;
    final bag = widget.bag;

    // Check tasks
    if (bag.task == LuckyBagTask.followMe && !LuckyBagService.instance.isFollowingUser(bag.senderId)) {
      LuckyBagService.instance.followUser(bag.senderId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Followed ${bag.senderName}! Now claiming...'), backgroundColor: Colors.purple),
      );
    } else if (bag.task == LuckyBagTask.followRoom && !LuckyBagService.instance.isFollowingRoom(bag.sourceRoomId)) {
      LuckyBagService.instance.followRoom(bag.sourceRoomId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Followed ${bag.sourceRoomTitle}! Now claiming...'), backgroundColor: Colors.purple),
      );
    }

    setState(() => _isClaiming = true);

    final res = LuckyBagService.instance.claimBag(bag: bag, claimant: authUser);

    setState(() {
      _isClaiming = false;
      if (res['success'] == true) {
        _claimedCoins = res['coins'] as int?;
        context.read<WalletProvider>().earnCoins(_claimedCoins ?? 0, 'Lucky Bag Reward');
      }
    });

    if (res['success'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message'] as String? ?? 'Could not claim'), backgroundColor: Colors.orange),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bag = widget.bag;
    final authUser = context.watch<AuthProvider>().currentUser;
    final hasClaimed = bag.hasUserClaimed(authUser.id);
    final isFollowingUser = LuckyBagService.instance.isFollowingUser(bag.senderId);
    final isFollowingRoom = LuckyBagService.instance.isFollowingRoom(bag.sourceRoomId);

    bool taskPending = false;
    String taskButtonLabel = 'Grab Lucky Bag 🎁';
    if (bag.task == LuckyBagTask.followMe && !isFollowingUser) {
      taskPending = true;
      taskButtonLabel = 'Follow & Claim 🎁';
    } else if (bag.task == LuckyBagTask.followRoom && !isFollowingRoom) {
      taskPending = true;
      taskButtonLabel = 'Follow Room & Claim 🎁';
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.72,
      decoration: const BoxDecoration(
        color: Color(0xFF1E1B2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header Indicator
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // ── Creator & Bag Info Header ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                UserAvatar(imageUrl: bag.senderAvatar, name: bag.senderName, radius: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              bag.senderName,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: bag.mode == LuckyBagMode.world ? Colors.cyan.withValues(alpha: 0.2) : Colors.orange.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              bag.mode == LuckyBagMode.world ? '🌍 World' : '🏠 Room',
                              style: TextStyle(
                                color: bag.mode == LuckyBagMode.world ? Colors.cyanAccent : Colors.orangeAccent,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Total: ${bag.totalCoins} Coins • ${bag.claimsRemaining}/${bag.totalClaims} Claims Remaining',
                        style: const TextStyle(color: Colors.white60, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Status & Action Panel ──
          if (_claimedCoins != null || hasClaimed) ...[
            // Already Claimed State
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
              ),
              child: Column(
                children: [
                  const Text('🎉 YOU CLAIMED', style: TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(
                    '+${_claimedCoins ?? bag.claims.firstWhere((c) => c.userId == authUser.id, orElse: () => LuckyBagClaimRecord(userId: '', userName: '', userAvatar: '', coins: 0, claimedAt: DateTime.now())).coins} 🪙',
                    style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ] else if (!bag.isOpen) ...[
            // Countdown State
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF6F17E3).withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF6F17E3)),
              ),
              child: Column(
                children: [
                  const Text('⏳ OPENS IN', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(
                    _formatDuration(bag.timeUntilOpen),
                    style: const TextStyle(color: Colors.amber, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 2),
                  ),
                  const SizedBox(height: 4),
                  if (taskPending)
                    Text(
                      bag.task == LuckyBagTask.followMe ? 'Task: Follow creator to claim' : 'Task: Follow room to claim',
                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                ],
              ),
            ),
          ] else if (bag.isFullyClaimed) ...[
            // Fully Claimed State
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                'All Lucky Bag claims have been grabbed!',
                style: TextStyle(color: Colors.white60, fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
          ] else ...[
            // Ready to Claim
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                  onPressed: _isClaiming ? null : _onClaimPressed,
                  child: _isClaiming
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                      : Text(
                          taskButtonLabel,
                          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 20),

          // ── Claimants List Header ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Text('Claimants', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                const Spacer(),
                Text('${bag.claims.length} Claimed', style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // ── Claimants List ──
          Expanded(
            child: bag.claims.isEmpty
                ? const Center(
                    child: Text('No claims yet. Be the first!', style: TextStyle(color: Colors.white38, fontSize: 13)),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    itemCount: bag.claims.length,
                    separatorBuilder: (context, index) => const Divider(color: Colors.white10, height: 1),
                    itemBuilder: (ctx, index) {
                      final item = bag.claims[index];
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: UserAvatar(imageUrl: item.userAvatar, name: item.userName, radius: 18),
                        title: Text(item.userName, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          '${item.claimedAt.hour.toString().padLeft(2, '0')}:${item.claimedAt.minute.toString().padLeft(2, '0')}',
                          style: const TextStyle(color: Colors.white38, fontSize: 10),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('+${item.coins}', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 14)),
                            const SizedBox(width: 4),
                            const Text('🪙', style: TextStyle(fontSize: 12)),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Lucky Bag History Sheet
// ─────────────────────────────────────────────────────────────────────────────

class LuckyBagHistorySheet extends StatelessWidget {
  const LuckyBagHistorySheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const LuckyBagHistorySheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final history = LuckyBagService.instance.history;

    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: const BoxDecoration(
        color: Color(0xFF1E1B2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),
          const Text('Lucky Bag History', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          Expanded(
            child: history.isEmpty
                ? const Center(child: Text('No lucky bags launched yet', style: TextStyle(color: Colors.white38)))
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: history.length,
                    separatorBuilder: (context, index) => const Divider(color: Colors.white10),
                    itemBuilder: (ctx, i) {
                      final bag = history[i];
                      return ListTile(
                        leading: Image.asset(
                          'assets/images/party_tool_luckybag.png',
                          width: 36,
                          errorBuilder: (context, error, stackTrace) => const Icon(Icons.card_giftcard, color: Colors.amber),
                        ),
                        title: Text(
                          '${bag.mode == LuckyBagMode.world ? "🌍 World" : "🏠 Room"} • ${bag.totalCoins} Coins',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        subtitle: Text(
                          'Sent by ${bag.senderName} • ${bag.claims.length}/${bag.totalClaims} Claimed',
                          style: const TextStyle(color: Colors.white60, fontSize: 11),
                        ),
                        trailing: Text(
                          bag.isFullyClaimed ? 'Completed' : (bag.isOpen ? 'Active' : 'Counting Down'),
                          style: TextStyle(
                            color: bag.isFullyClaimed ? Colors.grey : Colors.greenAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Floating In-Room Lucky Bag Widget
// ─────────────────────────────────────────────────────────────────────────────

class LuckyBagFloatingWidget extends StatelessWidget {
  final String roomId;
  const LuckyBagFloatingWidget({super.key, required this.roomId});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LuckyBagService.instance,
      builder: (ctx, _) {
        final bag = LuckyBagService.instance.getRoomBag(roomId) ?? LuckyBagService.instance.worldBag;
        if (bag == null || bag.isFullyClaimed || bag.isExpired) {
          return const SizedBox.shrink();
        }

        return GestureDetector(
          onTap: () => LuckyBagClaimSheet.show(context, bag),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: bag.mode == LuckyBagMode.world
                    ? [const Color(0xFF00C6FF), const Color(0xFF0072FF)]
                    : [const Color(0xFFFF512F), const Color(0xFFDD2476)],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Image.asset(
                  'assets/images/party_tool_luckybag.png',
                  width: 36,
                  height: 36,
                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.card_giftcard, color: Colors.white, size: 28),
                ),
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: Colors.amber,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      bag.isOpen ? '${bag.claimsRemaining}' : '⏳',
                      style: const TextStyle(color: Colors.black, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// World Lucky Bag Notification Banner
// ─────────────────────────────────────────────────────────────────────────────

class WorldLuckyBagBanner extends StatelessWidget {
  const WorldLuckyBagBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LuckyBagService.instance,
      builder: (ctx, _) {
        final bag = LuckyBagService.instance.worldBag;
        if (bag == null || bag.isFullyClaimed || bag.isExpired) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF7B2FF7), Color(0xFF9147FF)],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Image.asset(
                'assets/images/party_tool_luckybag.png',
                width: 28,
                height: 28,
                errorBuilder: (context, error, stackTrace) => const Icon(Icons.public_rounded, color: Colors.amber, size: 24),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Text('🌍 World Lucky Bag', style: TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                        const SizedBox(width: 6),
                        Text('• ${bag.totalCoins} 🪙', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Text(
                      '${bag.senderName} in "${bag.sourceRoomTitle}"',
                      style: const TextStyle(color: Colors.white70, fontSize: 10),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => LuckyBagClaimSheet.show(context, bag),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.amber,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text('Claim', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
