import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/animations/app_animations.dart';
import '../../core/utils/auth_guard.dart';
import '../../models/pk_battle_model.dart';
import '../../providers/live_provider.dart';
import '../../providers/live_gift_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/gift_dialog.dart';
import '../../widgets/user_avatar.dart';
import '../../widgets/tiktok_gift_overlay.dart';
import '../../widgets/comments_sheet.dart';

class PKBattleScreen extends StatefulWidget {
  final PKBattleModel? pkBattle;

  const PKBattleScreen({super.key, this.pkBattle});

  @override
  State<PKBattleScreen> createState() => _PKBattleScreenState();
}

class _PKBattleScreenState extends State<PKBattleScreen> with TickerProviderStateMixin {
  late AnimationController _vsPulseController;
  late AnimationController _winnerController;
  late Animation<double> _vsScale;
  late Animation<double> _winnerScale;

  final TextEditingController _chatTextController = TextEditingController();
  final List<Map<String, String>> _liveChatMessages = [
    {'sender': 'Danial', 'text': 'sent Rocket 🚀 x999', 'type': 'gift'},
    {'sender': 'Sana Mughal', 'text': 'Let’s go Team Blue! 🔥🔥', 'type': 'text'},
    {'sender': 'Usman Jutt', 'text': 'sent Gem Diamond 💎 x10', 'type': 'gift'},
    {'sender': 'Ayesha Khan', 'text': 'Team Red push karo! 💖', 'type': 'text'},
    {'sender': 'Danial', 'text': 'reacted 👏', 'type': 'reaction'},
  ];

  // ─── Real Camera & Mic Hardware State ───
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  int _selectedCameraIndex = 0;
  bool _isCameraInitialized = false;
  bool _isMuted = false;
  bool _isCameraOff = false;

  bool _showWinner = false;
  String? _winnerName;
  int _winnerScore = 0;
  final List<FloatingHeartAnimation> _floatingHearts = [];

  void _onDoubleTapStage(TapDownDetails details) {
    AuthGuard.require(context, () {
      try {
        context.read<LiveProvider>().sendLike();
      } catch (_) {}

      final pos = details.localPosition;
      setState(() {
        _floatingHearts.add(
          FloatingHeartAnimation(
            position: pos,
            onComplete: () {
              if (mounted && _floatingHearts.isNotEmpty) {
                setState(() => _floatingHearts.removeAt(0));
              }
            },
          ),
        );
      });
    }, reason: 'Sign in to send like hearts');
  }

  @override
  void initState() {
    super.initState();

    _initCameraAndMic();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentUser = context.read<AuthProvider>().currentUser;
      final liveProv = context.read<LiveProvider>();
      liveProv.startPkBattle(currentHost: currentUser);
      context.read<LiveGiftProvider>().setActiveRoom('pk_battle');
    });

    _vsPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _vsScale = Tween<double>(begin: 0.92, end: 1.12).animate(
      CurvedAnimation(parent: _vsPulseController, curve: Curves.easeInOut),
    );

    _winnerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _winnerScale = Tween<double>(begin: 0.2, end: 1.0).animate(
      CurvedAnimation(parent: _winnerController, curve: Curves.elasticOut),
    );
  }

  Future<void> _initCameraAndMic() async {
    try {
      await [Permission.camera, Permission.microphone].request();
      _cameras = await availableCameras();
      if (_cameras.isNotEmpty) {
        // Prefer front camera for streamer
        final frontCameraIndex = _cameras.indexWhere(
          (c) => c.lensDirection == CameraLensDirection.front,
        );
        _selectedCameraIndex = frontCameraIndex != -1 ? frontCameraIndex : 0;
        await _setupCameraController(_cameras[_selectedCameraIndex]);
      }
    } catch (_) {}
  }

  Future<void> _setupCameraController(CameraDescription cameraDescription) async {
    if (_cameraController != null) {
      await _cameraController!.dispose();
    }

    final controller = CameraController(
      cameraDescription,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    _cameraController = controller;

    try {
      await controller.initialize();
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } catch (_) {}
  }

  Future<void> _toggleCameraDirection() async {
    if (_cameras.length < 2) return;
    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
    await _setupCameraController(_cameras[_selectedCameraIndex]);
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
    });
  }

  void _toggleCameraPower() {
    setState(() {
      _isCameraOff = !_isCameraOff;
    });
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _chatTextController.dispose();
    _vsPulseController.dispose();
    _winnerController.dispose();
    super.dispose();
  }

  void _declareWinner(String name, int score) {
    setState(() {
      _winnerName = name;
      _winnerScore = score;
      _showWinner = true;
    });
    _winnerController.forward(from: 0.0);
  }

  void _openGiftSheet(BuildContext context, bool forHostA, PKBattleModel pk) {
    final targetHost = forHostA ? pk.hostA : pk.hostB;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.transparent,
      builder: (c) => GiftDialog(
        streamerName: targetHost.name,
        targetReceiver: targetHost,
        onGiftSent: (gift) {
          context.read<LiveProvider>().addPkScore(forHostA, gift.diamondPrice);
          setState(() {
            _liveChatMessages.add({
              'sender': context.read<AuthProvider>().currentUser.name,
              'text': 'sent ${gift.name} ${gift.icon} to ${targetHost.name}!',
              'type': 'gift',
            });
            if (_liveChatMessages.length > 25) _liveChatMessages.removeAt(0);
          });
        },
      ),
    );
  }

  void _sendChatMessage(String text) {
    if (text.trim().isEmpty) return;
    final currentUser = context.read<AuthProvider>().currentUser;
    setState(() {
      _liveChatMessages.add({
        'sender': currentUser.name,
        'text': text.trim(),
        'type': 'text',
      });
      if (_liveChatMessages.length > 25) _liveChatMessages.removeAt(0);
    });
    _chatTextController.clear();
  }

  void _sendQuickEmojiReaction(String emoji) {
    final currentUser = context.read<AuthProvider>().currentUser;
    setState(() {
      _liveChatMessages.add({
        'sender': currentUser.name,
        'text': 'reacted $emoji',
        'type': 'reaction',
      });
      if (_liveChatMessages.length > 25) _liveChatMessages.removeAt(0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final liveProvider = context.watch<LiveProvider>();
    final pk = liveProvider.activePkBattle;
    final seconds = liveProvider.pkTimeRemainingSeconds;
    final minutes = (seconds / 60).floor();
    final remSecs = (seconds % 60).toString().padLeft(2, '0');

    if (pk == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A071B),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF00E5FF)),
        ),
      );
    }

    final scoreA = pk.scoreA;
    final scoreB = pk.scoreB;
    final totalScore = (scoreA + scoreB) == 0 ? 1 : (scoreA + scoreB);
    final ratioA = (scoreA / totalScore).clamp(0.08, 0.92);
    final isLeadingA = scoreA >= scoreB;

    if (seconds == 0 && !_showWinner) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _declareWinner(
            isLeadingA ? pk.hostA.name : pk.hostB.name,
            isLeadingA ? scoreA : scoreB,
          );
        }
      });
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A071B),
      resizeToAvoidBottomInset: false, // Prevents yellow/black bottom overflow when keyboard opens
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background Gradient Glow
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.0, -0.3),
                radius: 1.2,
                colors: [
                  Color(0xFF23143E),
                  Color(0xFF0A071B),
                ],
              ),
            ),
          ),

          // Double-tap to like gesture detector layer
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onDoubleTapDown: _onDoubleTapStage,
              onDoubleTap: () {},
            ),
          ),

          // Main Layout Column
          SafeArea(
            child: Column(
              children: [
                // ─── 1. TOP HEADER (Exit Button + Timer Pill + End Battle) ───
                _buildTopNavigationHeader(context, minutes, remSecs, seconds, isLeadingA, pk),
                const SizedBox(height: 4),

                // ─── 2. TIKTOK SCORE BAR & VS BADGE ───
                _buildTikTokScoreBar(scoreA, scoreB, ratioA),
                const SizedBox(height: 8),

                // ─── 3. PK ARENA STAGE (Side-by-Side Host Video Cards with Live Camera Support) ───
                Expanded(
                  flex: 5,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        // Host A Box (Left / Blue Team - Real Camera Enabled)
                        Expanded(
                          child: _buildHostVideoCard(
                            host: pk.hostA,
                            score: scoreA,
                            isLeading: isLeadingA,
                            sideColor: const Color(0xFF00E5FF),
                            teamLabel: 'Team Blue',
                            isLeft: true,
                            useRealCamera: true,
                            onSupportTap: () => _openGiftSheet(context, true, pk),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Host B Box (Right / Red Team)
                        Expanded(
                          child: _buildHostVideoCard(
                            host: pk.hostB,
                            score: scoreB,
                            isLeading: !isLeadingA,
                            sideColor: const Color(0xFFFF4081),
                            teamLabel: 'Team Red',
                            isLeft: false,
                            useRealCamera: false,
                            onSupportTap: () => _openGiftSheet(context, false, pk),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),

                // ─── 4. LOWER SECTION: CHAT FEED & BOTTOM ACTION DOCK ───
                Expanded(
                  flex: 4,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Floating Chat List (Occupies middle region cleanly without UI overlaps)
                        Expanded(
                          child: _buildFloatingChatPanel(),
                        ),
                        const SizedBox(height: 6),

                        // Bottom Control Dock (Chat input + Emoji Bar + Camera/Mic Tools + Main Gift Button)
                        _buildBottomActionDock(context, pk),
                        const SizedBox(height: 4),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Double Tap Floating Animated Hearts Layer
          ..._floatingHearts,

          // ─── 5. TIKTOK LIVE GIFT ANIMATION OVERLAY LAYER ───
          const TikTokGiftOverlay(roomId: 'pk_battle'),

          // ─── 6. WINNER VICTORY CELEBRATION OVERLAY ───
          if (_showWinner) _buildVictoryOverlay(isDark),
        ],
      ),
    );
  }

  /// Top Navigation Bar with Exit Icon, Pulsating Timer, and End Battle Action
  Widget _buildTopNavigationHeader(
    BuildContext context,
    int minutes,
    String remSecs,
    int seconds,
    bool isLeadingA,
    PKBattleModel pk,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Close Screen Button
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              ),
              child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
            ),
          ),

          // Pulsating Timer Badge ("PK 02:50")
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              gradient: seconds < 30
                  ? const LinearGradient(colors: [Color(0xFFFF1744), Color(0xFFD50000)])
                  : LinearGradient(colors: [Colors.black.withValues(alpha: 0.75), const Color(0xFF1E1035)]),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: seconds < 30 ? const Color(0xFFFF5252) : const Color(0xFFFFD700),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: (seconds < 30 ? const Color(0xFFFF1744) : const Color(0xFFFFD700)).withValues(alpha: 0.5),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.timer_outlined, color: Color(0xFFFFD700), size: 14),
                const SizedBox(width: 5),
                Text(
                  'PK $minutes:$remSecs',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),

          // Camera & Mic Hardware Controls Group (Relocated to Top Header for a clean bottom dock)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Mic Mute Toggle
              GestureDetector(
                onTap: _toggleMute,
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: _isMuted ? Colors.redAccent.withValues(alpha: 0.85) : Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  child: Icon(
                    _isMuted ? Icons.mic_off : Icons.mic,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ),
              const SizedBox(width: 5),

              // Camera Power Toggle
              GestureDetector(
                onTap: _toggleCameraPower,
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: _isCameraOff ? Colors.redAccent.withValues(alpha: 0.85) : Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  child: Icon(
                    _isCameraOff ? Icons.videocam_off : Icons.videocam,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ),
              const SizedBox(width: 5),

              // Camera Flip
              GestureDetector(
                onTap: _toggleCameraDirection,
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  child: const Icon(
                    Icons.flip_camera_ios,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ),
            ],
          ),

          // End PK Action
          GestureDetector(
            onTap: () => _declareWinner(
              isLeadingA ? pk.hostA.name : pk.hostB.name,
              isLeadingA ? pk.scoreA : pk.scoreB,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              ),
              child: const Text(
                'End PK',
                style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 11),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// TikTok-Style Score Header Bar (Clean score indicators and animated progress bar)
  Widget _buildTikTokScoreBar(int scoreA, int scoreB, double ratioA) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        children: [
          // Score Pill Text Displays
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Blue Side Points
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF00E5FF), width: 1.2),
                ),
                child: Row(
                  children: [
                    const Text('💎 ', style: TextStyle(fontSize: 11)),
                    Text(
                      '$scoreA pts',
                      style: const TextStyle(
                        color: Color(0xFF00E5FF),
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              // Red Side Points
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF4081).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFF4081), width: 1.2),
                ),
                child: Row(
                  children: [
                    Text(
                      '$scoreB pts',
                      style: const TextStyle(
                        color: Color(0xFFFF4081),
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                    const Text(' 💎', style: TextStyle(fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),

          // Integrated Split Score Bar with 3D VS Emblem
          SizedBox(
            height: 22,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Animated Split Bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Row(
                    children: [
                      // Blue Team Fraction
                      AnimatedExpandedBar(
                        widthRatio: ratioA,
                        color: const Color(0xFF00E5FF),
                        gradientColors: const [Color(0xFF00B0FF), Color(0xFF00E5FF)],
                      ),
                      // Red Team Fraction
                      AnimatedExpandedBar(
                        widthRatio: 1 - ratioA,
                        color: const Color(0xFFFF4081),
                        gradientColors: const [Color(0xFFFF4081), Color(0xFFD81B60)],
                      ),
                    ],
                  ),
                ),

                // Central Pulsating VS Emblem
                ScaleTransition(
                  scale: _vsScale,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFD700), Color(0xFFFFAB00)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFD700).withValues(alpha: 0.8),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
                      border: Border.all(color: Colors.white, width: 1.2),
                    ),
                    child: const Text(
                      'VS',
                      style: TextStyle(
                        color: Color(0xFF0A071B),
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Clean Host Video Card with Real Camera Preview for Host A & Mic Toggle Controls
  Widget _buildHostVideoCard({
    required dynamic host,
    required int score,
    required bool isLeading,
    required Color sideColor,
    required String teamLabel,
    required bool isLeft,
    required bool useRealCamera,
    required VoidCallback onSupportTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: sideColor, width: 2.0),
        boxShadow: [
          BoxShadow(
            color: sideColor.withValues(alpha: 0.35),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Video Feed: Real Camera Preview if available & enabled, else Network Image
            if (useRealCamera && _isCameraInitialized && _cameraController != null && _cameraController!.value.isInitialized && !_isCameraOff)
              CameraPreview(_cameraController!)
            else
              Image.network(
                host.avatarUrl,
                fit: BoxFit.cover,
                alignment: Alignment.center,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: const Color(0xFF1E1035),
                  child: const Icon(Icons.person, color: Colors.white54, size: 48),
                ),
              ),

            // Subtle Gradient Vignette
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.6),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.75),
                  ],
                  stops: const [0.0, 0.4, 1.0],
                ),
              ),
            ),

            // Muted Mic / Camera Off Overlay Indicator
            if (useRealCamera && (_isMuted || _isCameraOff))
              Positioned(
                top: 40, left: 10,
                child: Row(
                  children: [
                    if (_isMuted)
                      Container(
                        padding: const EdgeInsets.all(4),
                        margin: const EdgeInsets.only(right: 4),
                        decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                        child: const Icon(Icons.mic_off, color: Colors.white, size: 12),
                      ),
                    if (_isCameraOff)
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                        child: const Icon(Icons.videocam_off, color: Colors.white, size: 12),
                      ),
                  ],
                ),
              ),

            // TOP-LEFT / TOP-RIGHT: Host Name & Avatar Tag
            Positioned(
              top: 10,
              left: isLeft ? 10 : null,
              right: !isLeft ? 10 : null,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: sideColor.withValues(alpha: 0.8), width: 1.0),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    UserAvatar(imageUrl: host.avatarUrl, radius: 11),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        host.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Consumer<AuthProvider>(
                      builder: (context, auth, _) {
                        final isFollowing = auth.isFollowing(host.id);
                        final isMe = auth.currentUser.id == host.id;
                        if (isMe) return const SizedBox.shrink();

                        return GestureDetector(
                          onTap: () {
                            auth.toggleFollow(host.id);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(isFollowing ? 'Unfollowed ${host.name}' : 'Followed ${host.name} ❤️'),
                                duration: const Duration(seconds: 1),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: isFollowing ? Colors.grey : const Color(0xFF00E5FF),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isFollowing ? Icons.check : Icons.add,
                              color: Colors.black,
                              size: 10,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            // TOP-RIGHT / TOP-LEFT: LEADING 🔥 Badge
            if (isLeading)
              Positioned(
                top: 10,
                right: isLeft ? 10 : null,
                left: !isLeft ? 10 : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFFAB00)]),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(color: const Color(0xFFFFD700).withValues(alpha: 0.6), blurRadius: 6),
                    ],
                  ),
                  child: const Text(
                    '🔥 LEADING',
                    style: TextStyle(
                      color: Color(0xFF0A071B),
                      fontWeight: FontWeight.w900,
                      fontSize: 9,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),

            // BOTTOM: Dedicated Support Button for this Host
            Positioned(
              bottom: 8,
              left: 8,
              right: 8,
              child: GestureDetector(
                onTap: onSupportTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isLeft
                          ? const [Color(0xFF00B0FF), Color(0xFF00E5FF)]
                          : const [Color(0xFFD81B60), Color(0xFFFF4081)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: sideColor.withValues(alpha: 0.6),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(isLeft ? '💙' : '❤️', style: const TextStyle(fontSize: 11)),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          'Support ${host.name.split(' ').first}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 10,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Clean Floating Chat Feed Panel
  Widget _buildFloatingChatPanel() {
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.72,
      child: ListView.separated(
        reverse: true,
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 2),
        itemCount: _liveChatMessages.length,
        separatorBuilder: (context, index) => const SizedBox(height: 4),
        itemBuilder: (context, index) {
          final msg = _liveChatMessages[_liveChatMessages.length - 1 - index];
          final isGift = msg['type'] == 'gift';

          return Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isGift
                    ? const Color(0xFF8E24AA).withValues(alpha: 0.85)
                    : Colors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(14),
                border: isGift ? Border.all(color: const Color(0xFFFFD700), width: 1.0) : null,
              ),
              child: RichText(
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: '${msg['sender']}: ',
                      style: TextStyle(
                        color: isGift ? const Color(0xFFFFD700) : const Color(0xFF00E5FF),
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                    TextSpan(
                      text: msg['text'],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Clean Minimalist Bottom Dock (TextField with Embedded Emojis + Main Gift Button)
  Widget _buildBottomActionDock(BuildContext context, PKBattleModel pk) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Row(
        children: [
          // Glassmorphism Chat TextField Container with Embedded Quick Emojis
          Expanded(
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.5), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00E5FF).withValues(alpha: 0.2),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      CommentsSheet.show(
                        context,
                        targetId: 'pk_battle',
                        title: 'Arena Comments',
                        isPost: false,
                        onCommentSubmitted: _sendChatMessage,
                      );
                    },
                    child: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF00E5FF), size: 18),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _chatTextController,
                      onSubmitted: _sendChatMessage,
                      cursorColor: const Color(0xFF00E5FF),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Say something...',
                        hintStyle: TextStyle(color: Colors.white54, fontSize: 12),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 4),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Embedded Quick Emojis inside TextField (🔥, 💖, 👏)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: ['🔥', '💖', '👏'].map((emoji) {
                      return GestureDetector(
                        onTap: () => _sendQuickEmojiReaction(emoji),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: Text(emoji, style: const TextStyle(fontSize: 16)),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Main Gift Modal Button
          GestureDetector(
            onTap: () => _openGiftSheet(context, true, pk),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFE040FB), Color(0xFFFF4081)],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF4081).withValues(alpha: 0.6),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: const Text('🎁', style: TextStyle(fontSize: 18)),
            ),
          ),
        ],
      ),
    );
  }

  /// Victory Overlay when Battle Ends
  Widget _buildVictoryOverlay(bool isDark) {
    return Container(
      color: Colors.black.withValues(alpha: 0.8),
      child: Center(
        child: ScaleTransition(
          scale: _winnerScale,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 28),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4A148C), Color(0xFF8E24AA), Color(0xFFD81B60)],
              ),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: const Color(0xFFFFD700), width: 2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.6),
                  blurRadius: 30,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('👑', style: TextStyle(fontSize: 72)),
                const SizedBox(height: 12),
                const Text(
                  'PK VICTORY!',
                  style: TextStyle(
                    color: Color(0xFFFFD700),
                    fontWeight: FontWeight.w900,
                    fontSize: 28,
                    letterSpacing: 2.0,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _winnerName ?? 'Streamer',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Won with $_winnerScore 💎 diamonds!',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFD700),
                    foregroundColor: const Color(0xFF0A071B),
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close Arena', style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AnimatedExpandedBar extends StatelessWidget {
  final double widthRatio;
  final Color color;
  final List<Color> gradientColors;

  const AnimatedExpandedBar({
    super.key,
    required this.widthRatio,
    required this.color,
    required this.gradientColors,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: (widthRatio * 1000).toInt().clamp(1, 999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradientColors),
        ),
      ),
    );
  }
}
