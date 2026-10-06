import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/animations/app_animations.dart';
import '../../core/utils/auth_guard.dart';
import '../../models/pk_battle_model.dart';
import '../../models/user_model.dart';
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
      if (widget.pkBattle != null) {
        liveProv.setPkBattle(widget.pkBattle!);
      } else {
        liveProv.startPkBattle(currentHost: currentUser);
      }
      final activeBattleRoom = widget.pkBattle?.roomAId.isNotEmpty == true
          ? widget.pkBattle!.roomAId
          : (liveProv.activeRoom?.id ?? 'pk_battle');
      context.read<LiveGiftProvider>().setActiveRoom(activeBattleRoom);
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

  void _openGiftSheet(BuildContext context, bool isForHostA, PKBattleModel pk) {
    if (pk.participants.isEmpty) return;
    final participant = isForHostA
        ? pk.participants[0]
        : (pk.participants.length > 1 ? pk.participants[1] : pk.participants[0]);
    _openGiftSheetForParticipant(context, participant);
  }

  void _openGiftSheetForParticipant(BuildContext context, PKParticipantModel participant) {
    final targetUser = UserModel(
      id: participant.userId,
      username: participant.username,
      name: participant.name,
      avatarUrl: participant.avatarUrl,
    );
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.transparent,
      builder: (c) => GiftDialog(
        streamerName: participant.name,
        targetReceiver: targetUser,
        onGiftSent: (gift) {
          final currentUser = context.read<AuthProvider>().currentUser;
          context.read<LiveProvider>().sendGift(gift, currentUser.name);
        },
      ),
    );
  }

  void _sendChatMessage(String text) {
    if (text.trim().isEmpty) return;
    final currentUser = context.read<AuthProvider>().currentUser;
    context.read<LiveProvider>().sendMessage(text.trim(), currentUser.name, user: currentUser);
    _chatTextController.clear();
  }

  void _sendQuickEmojiReaction(String emoji) {
    final currentUser = context.read<AuthProvider>().currentUser;
    context.read<LiveProvider>().sendMessage(emoji, currentUser.name, user: currentUser);
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
                _buildTikTokScoreBar(pk),
                const SizedBox(height: 8),

                // ─── 3. PK ARENA STAGE (Dynamic 2, 3, or 4 Video Feeds) ───
                Expanded(
                  flex: 5,
                  child: _buildArenaStage(pk),
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

  static const List<Color> _participantColors = [
    Color(0xFF00E5FF), // Slot 1: Cyan / Blue
    Color(0xFFFF4081), // Slot 2: Hot Pink / Red
    Color(0xFFFFD700), // Slot 3: Gold
    Color(0xFFB388FF), // Slot 4: Purple
  ];

  static const List<String> _participantTeamLabels = [
    'Team Cyan',
    'Team Pink',
    'Team Gold',
    'Team Violet',
  ];

  /// Top Navigation Bar with Exit Icon, Authoritative Timer, and End Battle Action
  Widget _buildTopNavigationHeader(
    BuildContext context,
    int minutes,
    String remSecs,
    int seconds,
    bool isLeadingA,
    PKBattleModel pk,
  ) {
    final isStarted = pk.isStarted;

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

          // Timer / Status Badge
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              gradient: !isStarted
                  ? const LinearGradient(colors: [Color(0xFF4A148C), Color(0xFF1E1035)])
                  : (seconds < 30
                      ? const LinearGradient(colors: [Color(0xFFFF1744), Color(0xFFD50000)])
                      : LinearGradient(colors: [Colors.black.withValues(alpha: 0.75), const Color(0xFF1E1035)])),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: !isStarted
                    ? Colors.purpleAccent
                    : (seconds < 30 ? const Color(0xFFFF5252) : const Color(0xFFFFD700)),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: (!isStarted
                          ? Colors.purpleAccent
                          : (seconds < 30 ? const Color(0xFFFF1744) : const Color(0xFFFFD700)))
                      .withValues(alpha: 0.5),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  !isStarted ? Icons.hourglass_top_rounded : Icons.timer_outlined,
                  color: !isStarted ? Colors.purpleAccent : const Color(0xFFFFD700),
                  size: 14,
                ),
                const SizedBox(width: 5),
                Text(
                  !isStarted ? 'PK READY' : 'PK $minutes:$remSecs',
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

          // Camera & Mic Hardware Controls Group
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
            onTap: () {
              final highestScoreParticipant = pk.participantList.isNotEmpty
                  ? (pk.participantList..sort((a, b) => b.score.compareTo(a.score))).first
                  : null;
              _declareWinner(
                highestScoreParticipant?.name ?? pk.hostA.name,
                highestScoreParticipant?.score ?? pk.scoreA,
              );
            },
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

  /// Dynamic Multi-Participant Score Header Bar
  Widget _buildTikTokScoreBar(PKBattleModel pk) {
    final participants = pk.participantList;
    final totalScore = participants.fold<int>(0, (sum, p) => sum + p.score);
    final effectiveTotal = totalScore == 0 ? 1 : totalScore;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        children: [
          // Score Pill Text Displays
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(participants.length, (idx) {
              final p = participants[idx];
              final color = _participantColors[idx % _participantColors.length];

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color, width: 1.2),
                ),
                child: Row(
                  children: [
                    const Text('💎 ', style: TextStyle(fontSize: 10)),
                    Text(
                      '${p.score} pts',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 5),

          // Integrated Multi-Segment Split Score Bar
          SizedBox(
            height: 20,
            child: Stack(
              alignment: Alignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Row(
                    children: List.generate(participants.length, (idx) {
                      final p = participants[idx];
                      final ratio = (p.score / effectiveTotal).clamp(0.05, 0.95);
                      final color = _participantColors[idx % _participantColors.length];

                      return Expanded(
                        flex: ((ratio * 100).round()).clamp(1, 100),
                        child: Container(
                          color: color,
                        ),
                      );
                    }),
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

  /// Dynamic 2, 3, or 4 Participant Arena Stage
  Widget _buildArenaStage(PKBattleModel pk) {
    final participants = pk.participantList;
    final count = participants.length;

    if (count <= 2) {
      final p1 = participants.isNotEmpty ? participants[0] : null;
      final p2 = participants.length > 1 ? participants[1] : null;

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            if (p1 != null)
              Expanded(
                child: _buildParticipantVideoCard(
                  participant: p1,
                  slotIndex: 0,
                  sideColor: _participantColors[0],
                  teamLabel: _participantTeamLabels[0],
                  useRealCamera: true,
                  onSupportTap: () => _openGiftSheetForParticipant(context, p1),
                ),
              ),
            const SizedBox(width: 8),
            if (p2 != null)
              Expanded(
                child: _buildParticipantVideoCard(
                  participant: p2,
                  slotIndex: 1,
                  sideColor: _participantColors[1],
                  teamLabel: _participantTeamLabels[1],
                  useRealCamera: false,
                  onSupportTap: () => _openGiftSheetForParticipant(context, p2),
                ),
              ),
          ],
        ),
      );
    } else if (count == 3) {
      final p1 = participants[0];
      final p2 = participants[1];
      final p3 = participants[2];

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          children: [
            Expanded(
              flex: 1,
              child: _buildParticipantVideoCard(
                participant: p1,
                slotIndex: 0,
                sideColor: _participantColors[0],
                teamLabel: _participantTeamLabels[0],
                useRealCamera: true,
                onSupportTap: () => _openGiftSheetForParticipant(context, p1),
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              flex: 1,
              child: Row(
                children: [
                  Expanded(
                    child: _buildParticipantVideoCard(
                      participant: p2,
                      slotIndex: 1,
                      sideColor: _participantColors[1],
                      teamLabel: _participantTeamLabels[1],
                      useRealCamera: false,
                      onSupportTap: () => _openGiftSheetForParticipant(context, p2),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _buildParticipantVideoCard(
                      participant: p3,
                      slotIndex: 2,
                      sideColor: _participantColors[2],
                      teamLabel: _participantTeamLabels[2],
                      useRealCamera: false,
                      onSupportTap: () => _openGiftSheetForParticipant(context, p3),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    } else {
      // 4 Participants (2x2 Grid)
      final p1 = participants[0];
      final p2 = participants[1];
      final p3 = participants[2];
      final p4 = participants[3];

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          children: [
            Expanded(
              flex: 1,
              child: Row(
                children: [
                  Expanded(
                    child: _buildParticipantVideoCard(
                      participant: p1,
                      slotIndex: 0,
                      sideColor: _participantColors[0],
                      teamLabel: _participantTeamLabels[0],
                      useRealCamera: true,
                      onSupportTap: () => _openGiftSheetForParticipant(context, p1),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _buildParticipantVideoCard(
                      participant: p2,
                      slotIndex: 1,
                      sideColor: _participantColors[1],
                      teamLabel: _participantTeamLabels[1],
                      useRealCamera: false,
                      onSupportTap: () => _openGiftSheetForParticipant(context, p2),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              flex: 1,
              child: Row(
                children: [
                  Expanded(
                    child: _buildParticipantVideoCard(
                      participant: p3,
                      slotIndex: 2,
                      sideColor: _participantColors[2],
                      teamLabel: _participantTeamLabels[2],
                      useRealCamera: false,
                      onSupportTap: () => _openGiftSheetForParticipant(context, p3),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _buildParticipantVideoCard(
                      participant: p4,
                      slotIndex: 3,
                      sideColor: _participantColors[3],
                      teamLabel: _participantTeamLabels[3],
                      useRealCamera: false,
                      onSupportTap: () => _openGiftSheetForParticipant(context, p4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
  }

  /// Video Card with Avatar / Camera preview, Host Tag, Leading Badge, and Support Button
  Widget _buildParticipantVideoCard({
    required PKParticipantModel participant,
    required int slotIndex,
    required Color sideColor,
    required String teamLabel,
    required bool useRealCamera,
    required VoidCallback onSupportTap,
  }) {
    final isLeft = slotIndex % 2 == 0;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: sideColor, width: 2.0),
        boxShadow: [
          BoxShadow(
            color: sideColor.withValues(alpha: 0.35),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Camera Preview or Avatar Image
            if (useRealCamera &&
                _isCameraInitialized &&
                _cameraController != null &&
                _cameraController!.value.isInitialized &&
                !_isCameraOff)
              CameraPreview(_cameraController!)
            else
              Image.network(
                participant.avatarUrl,
                fit: BoxFit.cover,
                alignment: Alignment.center,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: const Color(0xFF1E1035),
                  child: const Icon(Icons.person, color: Colors.white54, size: 36),
                ),
              ),

            // Gradient Vignette
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
                top: 36,
                left: 8,
                child: Row(
                  children: [
                    if (_isMuted)
                      Container(
                        padding: const EdgeInsets.all(3),
                        margin: const EdgeInsets.only(right: 4),
                        decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                        child: const Icon(Icons.mic_off, color: Colors.white, size: 10),
                      ),
                    if (_isCameraOff)
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                        child: const Icon(Icons.videocam_off, color: Colors.white, size: 10),
                      ),
                  ],
                ),
              ),

            // Top Participant Tag & Avatar
            Positioned(
              top: 6,
              left: isLeft ? 6 : null,
              right: !isLeft ? 6 : null,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: sideColor.withValues(alpha: 0.8), width: 1.0),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    UserAvatar(imageUrl: participant.avatarUrl, radius: 9),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        participant.isHost ? '${participant.name} (Host)' : participant.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 9,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Support Button
            Positioned(
              bottom: 6,
              left: 6,
              right: 6,
              child: GestureDetector(
                onTap: onSupportTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  decoration: BoxDecoration(
                    color: sideColor,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: sideColor.withValues(alpha: 0.5),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('💎', style: TextStyle(fontSize: 9)),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          'Support ${participant.name.split(' ').first}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w900,
                            fontSize: 9,
                            letterSpacing: 0.3,
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
    final liveProvider = context.watch<LiveProvider>();
    final messages = liveProvider.messages;

    if (messages.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: const Text(
          'Battle is LIVE! Send gifts & chats to support your host 🔥',
          style: TextStyle(color: Colors.white54, fontSize: 11, fontStyle: FontStyle.italic),
        ),
      );
    }

    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.72,
      child: ListView.separated(
        reverse: true,
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 2),
        itemCount: messages.length,
        separatorBuilder: (context, index) => const SizedBox(height: 4),
        itemBuilder: (context, index) {
          final msg = messages[messages.length - 1 - index];
          final isGift = msg.isGift;

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
                      text: '${msg.sender}: ',
                      style: TextStyle(
                        color: isGift ? const Color(0xFFFFD700) : const Color(0xFF00E5FF),
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                    TextSpan(
                      text: msg.text,
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
