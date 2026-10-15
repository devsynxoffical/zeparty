import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/user_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/live_party_provider.dart';
import '../../../widgets/user_avatar.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Elimination Lucky Wheel — Item 05
// All state is local. Backend events are emitted via provider.sendRoomEvent()
// (see backend report for required socket events).
// ─────────────────────────────────────────────────────────────────────────────

enum _WheelPhase { setup, joining, spinning, roundResult, winner }

class EliminationWheelSheet extends StatefulWidget {
  const EliminationWheelSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const EliminationWheelSheet(),
    );
  }

  @override
  State<EliminationWheelSheet> createState() => _EliminationWheelSheetState();
}

class _EliminationWheelSheetState extends State<EliminationWheelSheet>
    with TickerProviderStateMixin {
  // ── Setup fields ──────────────────────────────────────────────────────────
  int _entryCoinFee = 0;
  int _maxParticipants = 10;
  bool _onlySeatedMics = false;

  // ── Game state ────────────────────────────────────────────────────────────
  _WheelPhase _phase = _WheelPhase.setup;
  final List<UserModel> _joined = [];
  final List<UserModel> _eliminated = [];
  UserModel? _lastEliminated;
  UserModel? _winner;
  int _roundNumber = 0;

  // ── Spin animation ────────────────────────────────────────────────────────
  late AnimationController _spinCtrl;
  late Animation<double> _spinAnim;
  double _currentAngle = 0;
  int? _eliminatedIdx;

  // ── Winner celebration ────────────────────────────────────────────────────
  late AnimationController _celebCtrl;
  late Animation<double> _celebAnim;

  // ── Presets ───────────────────────────────────────────────────────────────
  static const List<int> _feeOptions = [0, 50, 100, 200, 500, 1000];
  static const List<int> _capOptions = [5, 8, 10, 15, 20];

  @override
  void initState() {
    super.initState();
    _spinCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 4));
    _celebCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _celebAnim = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _celebCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _spinCtrl.dispose();
    _celebCtrl.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Logic
  // ─────────────────────────────────────────────────────────────────────────

  void _startGame() {
    if (_joined.length < 2) {
      _showMsg('Need at least 2 participants to start!');
      return;
    }
    setState(() {
      _phase = _WheelPhase.spinning;
      _roundNumber = 1;
    });
  }

  void _joinWheel(UserModel user) {
    if (_joined.any((u) => u.id == user.id)) return;
    if (_joined.length >= _maxParticipants) {
      _showMsg('Wheel is full ($_maxParticipants max)');
      return;
    }
    setState(() => _joined.add(user));
  }

  void _spinWheel() {
    if (_spinCtrl.isAnimating) return;
    if (_joined.length < 2) return;

    final rng = Random();
    _eliminatedIdx = rng.nextInt(_joined.length);

    final sliceAngle = (2 * pi) / _joined.length;
    final targetSliceCenter = _eliminatedIdx! * sliceAngle + sliceAngle / 2;
    final totalRotations = 5 + rng.nextInt(3);
    final targetAngle = _currentAngle + totalRotations * 2 * pi + targetSliceCenter;

    _spinAnim = Tween<double>(begin: _currentAngle, end: targetAngle).animate(
      CurvedAnimation(parent: _spinCtrl, curve: Curves.decelerate),
    );

    _spinCtrl.reset();
    _spinCtrl.forward().then((_) {
      _currentAngle = targetAngle % (2 * pi);
      _resolveElimination();
    });
  }

  void _resolveElimination() {
    if (_eliminatedIdx == null || _eliminatedIdx! >= _joined.length) return;
    final victim = _joined[_eliminatedIdx!];
    setState(() {
      _lastEliminated = victim;
      _joined.removeAt(_eliminatedIdx!);
      _eliminated.add(victim);
      _phase = _WheelPhase.roundResult;
    });

    if (_joined.length == 1) {
      Future.delayed(const Duration(seconds: 2), _showWinner);
    }
  }

  void _nextRound() {
    setState(() {
      _roundNumber++;
      _phase = _WheelPhase.spinning;
      _lastEliminated = null;
      _eliminatedIdx = null;
    });
  }

  void _showWinner() {
    if (!mounted) return;
    setState(() {
      _winner = _joined.first;
      _phase = _WheelPhase.winner;
    });
  }

  void _resetGame() {
    _spinCtrl.reset();
    setState(() {
      _phase = _WheelPhase.setup;
      _joined.clear();
      _eliminated.clear();
      _lastEliminated = null;
      _winner = null;
      _roundNumber = 0;
      _currentAngle = 0;
      _eliminatedIdx = null;
      _entryCoinFee = 0;
      _maxParticipants = 10;
      _onlySeatedMics = false;
    });
  }

  void _showMsg(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: const BoxDecoration(
        color: Color(0xFF0D0B1F),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          _buildHandle(),
          _buildHeader(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildHandle() => Center(
        child: Container(
          margin: const EdgeInsets.only(top: 12, bottom: 4),
          width: 44,
          height: 5,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      );

  Widget _buildHeader() {
    final titles = {
      _WheelPhase.setup: '🎯 Elimination Wheel',
      _WheelPhase.joining: '👥 Join the Wheel',
      _WheelPhase.spinning: 'Round $_roundNumber • Spin to Eliminate',
      _WheelPhase.roundResult: '💥 Round $_roundNumber Result',
      _WheelPhase.winner: '🏆 Winner!',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              titles[_phase] ?? '🎯 Elimination Wheel',
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          if (_phase != _WheelPhase.setup && _phase != _WheelPhase.joining)
            TextButton.icon(
              onPressed: _resetGame,
              icon: const Icon(Icons.refresh_rounded, size: 16, color: Colors.white54),
              label: const Text('Reset', style: TextStyle(color: Colors.white54, fontSize: 12)),
            ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white54, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_phase) {
      case _WheelPhase.setup:
        return _buildSetupPhase();
      case _WheelPhase.joining:
        return _buildJoinPhase();
      case _WheelPhase.spinning:
        return _buildSpinPhase();
      case _WheelPhase.roundResult:
        return _buildRoundResultPhase();
      case _WheelPhase.winner:
        return _buildWinnerPhase();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Phase 1: Setup
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildSetupPhase() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 130,
              height: 130,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const SweepGradient(
                  colors: [
                    Color(0xFFFF416C), Color(0xFFFF9B00), Color(0xFFFFE000),
                    Color(0xFF00C6FF), Color(0xFF7B2FF7), Color(0xFFFF416C),
                  ],
                ),
                boxShadow: [
                  BoxShadow(color: const Color(0xFFFF416C).withValues(alpha: 0.5), blurRadius: 30),
                ],
              ),
              child: const Center(child: Icon(Icons.casino_rounded, color: Colors.white, size: 48)),
            ),
          ),

          _sectionLabel('Entry Fee per Player'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _feeOptions.map((fee) {
              final selected = _entryCoinFee == fee;
              return GestureDetector(
                onTap: () => setState(() => _entryCoinFee = fee),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: selected ? const Color(0xFF7B2FF7) : Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: selected ? const Color(0xFF7B2FF7) : Colors.white24),
                    boxShadow: selected
                        ? [BoxShadow(color: const Color(0xFF7B2FF7).withValues(alpha: 0.4), blurRadius: 10)]
                        : [],
                  ),
                  child: Text(
                    fee == 0 ? '🆓 Free' : '🪙 $fee',
                    style: TextStyle(
                      color: selected ? Colors.white : Colors.white70,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 20),
          _sectionLabel('Max Participants'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _capOptions.map((cap) {
              final selected = _maxParticipants == cap;
              return GestureDetector(
                onTap: () => setState(() => _maxParticipants = cap),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: selected ? const Color(0xFF00C6FF).withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: selected ? const Color(0xFF00C6FF) : Colors.white24),
                  ),
                  child: Text(
                    '$cap',
                    style: TextStyle(
                      color: selected ? const Color(0xFF00C6FF) : Colors.white70,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 20),
          _sectionLabel('Participant Filter'),
          const SizedBox(height: 8),
          _buildToggle(
            label: 'Mic Seat Holders Only',
            subtitle: 'Only seated mic users can join',
            value: _onlySeatedMics,
            onChanged: (v) => setState(() => _onlySeatedMics = v),
          ),

          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7B2FF7),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              onPressed: () => setState(() => _phase = _WheelPhase.joining),
              child: const Text('Open Registration 🎟️', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              _entryCoinFee == 0 ? 'Players join for free' : 'Each player pays 🪙 $_entryCoinFee coins to join',
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Phase 2: Join
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildJoinPhase() {
    final provider = context.watch<LivePartyProvider>();
    final authUser = context.read<AuthProvider>().currentUser;
    final isHost = provider.activeRoom?.host.id == authUser.id ||
        provider.activeRoom?.creatorUserId == authUser.id;

    final eligible = _onlySeatedMics
        ? provider.participants.where((p) => p.seatNumber != null).toList()
        : provider.participants;

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF7B2FF7), Color(0xFF00C6FF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Icon(Icons.timer_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${_joined.length} / $_maxParticipants joined',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                    Text(_entryCoinFee == 0 ? 'Free entry • Tap to join!' : 'Entry: 🪙 $_entryCoinFee coins',
                        style: const TextStyle(color: Colors.white70, fontSize: 11)),
                  ],
                ),
              ),
              if (!_joined.any((u) => u.id == authUser.id))
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF7B2FF7),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                  onPressed: () => _joinWheel(authUser),
                  child: const Text('Join', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text('✓ Joined', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
            ],
          ),
        ),

        if (_joined.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Registered Players (${_joined.length})',
                  style: const TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ),
          SizedBox(
            height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _joined.length,
              itemBuilder: (ctx, i) => _buildPlayerChip(_joined[i], eliminated: false),
            ),
          ),
        ],

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Text('Room Members (${eligible.length})',
                  style: const TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.bold)),
              const Spacer(),
              if (isHost)
                TextButton(
                  onPressed: () {
                    for (final p in eligible) {
                      if (_joined.length < _maxParticipants) _joinWheel(p.user);
                    }
                    setState(() {});
                  },
                  child: const Text('Add All', style: TextStyle(color: Color(0xFF00C6FF), fontSize: 12)),
                ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: eligible.length,
            itemBuilder: (ctx, i) {
              final p = eligible[i];
              final alreadyJoined = _joined.any((u) => u.id == p.user.id);
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: alreadyJoined
                        ? const Color(0xFF7B2FF7).withValues(alpha: 0.4)
                        : Colors.white.withValues(alpha: 0.06),
                  ),
                ),
                child: Row(
                  children: [
                    UserAvatar(imageUrl: p.user.avatarUrl, radius: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.user.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                          Text(p.seatNumber != null ? 'Mic Seat ${p.seatNumber}' : 'Audience',
                              style: const TextStyle(color: Colors.white38, fontSize: 11)),
                        ],
                      ),
                    ),
                    if (alreadyJoined)
                      const Icon(Icons.check_circle_rounded, color: Color(0xFF7B2FF7), size: 20)
                    else if (isHost)
                      GestureDetector(
                        onTap: () => _joinWheel(p.user),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF7B2FF7).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF7B2FF7).withValues(alpha: 0.5)),
                          ),
                          child: const Text('Add', style: TextStyle(color: Color(0xFF7B2FF7), fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),

        if (isHost)
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _joined.length >= 2 ? const Color(0xFFFF416C) : Colors.grey,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _joined.length >= 2 ? _startGame : null,
                child: Text(
                  _joined.length >= 2
                      ? '🎯 Start Elimination (${_joined.length} players)'
                      : 'Need at least 2 players',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Phase 3: Spinning
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildSpinPhase() {
    final provider = context.read<LivePartyProvider>();
    final authUser = context.read<AuthProvider>().currentUser;
    final isHost = provider.activeRoom?.host.id == authUser.id ||
        provider.activeRoom?.creatorUserId == authUser.id;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _statChip('Round', '$_roundNumber', const Color(0xFF7B2FF7)),
              _statChip('Remaining', '${_joined.length}', const Color(0xFF00C6FF)),
              _statChip('Eliminated', '${_eliminated.length}', const Color(0xFFFF416C)),
            ],
          ),
        ),

        Expanded(
          child: Center(
            child: AnimatedBuilder(
              animation: _spinCtrl.isAnimating ? _spinAnim : AlwaysStoppedAnimation(_currentAngle),
              builder: (ctx, child) {
                final angle = _spinCtrl.isAnimating ? _spinAnim.value : _currentAngle;
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 270,
                      height: 270,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: const Color(0xFF7B2FF7).withValues(alpha: 0.4), blurRadius: 40, spreadRadius: 10),
                        ],
                      ),
                    ),
                    Transform.rotate(
                      angle: angle,
                      child: CustomPaint(
                        size: const Size(250, 250),
                        painter: _WheelPainter(participants: _joined),
                      ),
                    ),
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF0D0B1F),
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 8)],
                      ),
                      child: const Icon(Icons.stars_rounded, color: Colors.amber, size: 20),
                    ),
                    Positioned(
                      top: 0,
                      child: CustomPaint(
                        size: const Size(24, 32),
                        painter: _PointerPainter(),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),

        if (_eliminated.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Eliminated:', style: TextStyle(color: Colors.white38, fontSize: 11)),
                const SizedBox(height: 6),
                SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: _eliminated
                        .map((u) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: _buildPlayerChip(u, eliminated: true),
                            ))
                        .toList(),
                  ),
                ),
              ],
            ),
          ),

        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: AnimatedBuilder(
              animation: _spinCtrl,
              builder: (ctx, child) {
                final spinning = _spinCtrl.isAnimating;
                return ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: spinning ? Colors.grey.shade800 : const Color(0xFFFF416C),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    elevation: spinning ? 0 : 6,
                  ),
                  onPressed: (spinning || !isHost) ? null : _spinWheel,
                  child: spinning
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                            SizedBox(width: 12),
                            Text('Spinning...', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                          ],
                        )
                      : Text(
                          isHost ? '🎡 Spin Wheel (${_joined.length} players)' : '⏳ Waiting for host to spin...',
                          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Phase 4: Round Result
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildRoundResultPhase() {
    final provider = context.read<LivePartyProvider>();
    final authUser = context.read<AuthProvider>().currentUser;
    final isHost = provider.activeRoom?.host.id == authUser.id ||
        provider.activeRoom?.creatorUserId == authUser.id;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF3D0C15), Color(0xFF1A0008)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFFF416C).withValues(alpha: 0.6), width: 1.5),
                boxShadow: [BoxShadow(color: const Color(0xFFFF416C).withValues(alpha: 0.3), blurRadius: 30)],
              ),
              child: Column(
                children: [
                  const Text('💥 ELIMINATED!',
                      style: TextStyle(color: Color(0xFFFF416C), fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 2)),
                  const SizedBox(height: 16),
                  if (_lastEliminated != null) ...[
                    UserAvatar(imageUrl: _lastEliminated!.avatarUrl, radius: 36),
                    const SizedBox(height: 12),
                    Text(_lastEliminated!.name,
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Text('has been eliminated in Round $_roundNumber',
                        style: const TextStyle(color: Colors.white54, fontSize: 13)),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 24),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Column(
                children: [
                  Text('${_joined.length} players remaining',
                      style: const TextStyle(color: Colors.white60, fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _joined.map((u) => _buildPlayerChip(u, eliminated: false)).toList(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            if (isHost && _joined.length > 1)
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7B2FF7),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _nextRound,
                  child: Text('▶ Next Round (${_joined.length} left)',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Phase 5: Winner
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildWinnerPhase() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: _celebAnim,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    colors: [Color(0xFFFFE000), Color(0xFFFF9B00), Color(0xFFFF416C)],
                  ),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFFFFE000).withValues(alpha: 0.7), blurRadius: 40, spreadRadius: 10),
                  ],
                ),
                child: const Center(child: Text('🏆', style: TextStyle(fontSize: 52))),
              ),
            ),
            const SizedBox(height: 24),
            const Text('WINNER!',
                style: TextStyle(color: Color(0xFFFFE000), fontSize: 36, fontWeight: FontWeight.bold, letterSpacing: 6)),
            const SizedBox(height: 20),
            if (_winner != null) ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2A1A00), Color(0xFF1A1000)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFFFE000).withValues(alpha: 0.5), width: 2),
                  boxShadow: [BoxShadow(color: const Color(0xFFFFE000).withValues(alpha: 0.25), blurRadius: 30)],
                ),
                child: Column(
                  children: [
                    UserAvatar(imageUrl: _winner!.avatarUrl, radius: 48),
                    const SizedBox(height: 12),
                    Text(_winner!.name,
                        style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Text('Last survivor of $_roundNumber rounds',
                        style: const TextStyle(color: Colors.amber, fontSize: 13)),
                    if (_entryCoinFee > 0) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFE000).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFFE000).withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          '🪙 Prize Pool: ${_entryCoinFee * (_joined.length + _eliminated.length)} coins',
                          style: const TextStyle(color: Color(0xFFFFE000), fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Elimination Order',
                        style: TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    ...List.generate(_eliminated.length, (i) {
                      final u = _eliminated[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.08),
                              ),
                              child: Text('${i + 1}',
                                  style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 10),
                            UserAvatar(imageUrl: u.avatarUrl, radius: 12),
                            const SizedBox(width: 8),
                            Text(u.name, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                            const Spacer(),
                            Text('Round ${i + 1}', style: const TextStyle(color: Colors.white30, fontSize: 11)),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white60,
                  side: const BorderSide(color: Colors.white24),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _resetGame,
                child: const Text('Play Again 🔄', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────────────────

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
      );

  Widget _statChip(String label, String value, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
            Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
          ],
        ),
      );

  Widget _buildPlayerChip(UserModel user, {required bool eliminated}) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            children: [
              ColorFiltered(
                colorFilter: eliminated
                    ? const ColorFilter.mode(Colors.grey, BlendMode.saturation)
                    : const ColorFilter.mode(Colors.transparent, BlendMode.multiply),
                child: UserAvatar(imageUrl: user.avatarUrl, radius: 22),
              ),
              if (eliminated)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withValues(alpha: 0.4),
                    ),
                    child: const Center(child: Text('❌', style: TextStyle(fontSize: 12))),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          SizedBox(
            width: 48,
            child: Text(
              user.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(color: eliminated ? Colors.white30 : Colors.white70, fontSize: 9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggle({
    required String label,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 11)),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged, activeThumbColor: const Color(0xFF7B2FF7)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Wheel Painter
// ─────────────────────────────────────────────────────────────────────────────

class _WheelPainter extends CustomPainter {
  final List<UserModel> participants;

  static const List<Color> _sliceColors = [
    Color(0xFFFF416C), Color(0xFFFF9B00), Color(0xFFFFE000),
    Color(0xFF00C6FF), Color(0xFF7B2FF7), Color(0xFF00E676),
    Color(0xFFFF6B6B), Color(0xFF4ECDC4), Color(0xFFFFBE0B),
    Color(0xFF8B5CF6), Color(0xFF06B6D4), Color(0xFFEC4899),
    Color(0xFF10B981), Color(0xFFF59E0B), Color(0xFF6366F1),
    Color(0xFFEF4444), Color(0xFF3B82F6), Color(0xFF22C55E),
    Color(0xFFA855F7), Color(0xFFF97316),
  ];

  const _WheelPainter({required this.participants});

  @override
  void paint(Canvas canvas, Size size) {
    if (participants.isEmpty) return;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final sliceAngle = (2 * pi) / participants.length;

    for (int i = 0; i < participants.length; i++) {
      final startAngle = i * sliceAngle - pi / 2;
      final color = _sliceColors[i % _sliceColors.length];

      final paint = Paint()..color = color;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - 3),
        startAngle, sliceAngle, true, paint,
      );

      final borderPaint = Paint()
        ..color = const Color(0xFF0D0B1F)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - 3),
        startAngle, sliceAngle, true, borderPaint,
      );

      final labelAngle = startAngle + sliceAngle / 2;
      final labelRadius = radius * 0.65;
      final labelX = center.dx + labelRadius * cos(labelAngle);
      final labelY = center.dy + labelRadius * sin(labelAngle);

      canvas.save();
      canvas.translate(labelX, labelY);
      canvas.rotate(labelAngle + pi / 2);

      final name = participants[i].name;
      final displayName = name.length > 7 ? '${name.substring(0, 6)}\u2026' : name;

      final tp = TextPainter(
        text: TextSpan(
          text: displayName,
          style: TextStyle(
            color: Colors.white,
            fontSize: participants.length > 10 ? 8 : 10,
            fontWeight: FontWeight.bold,
            shadows: const [Shadow(color: Colors.black87, blurRadius: 3)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }

    final rimPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, radius - 1, rimPaint);
  }

  @override
  bool shouldRepaint(_WheelPainter old) => old.participants != participants;
}

// ─────────────────────────────────────────────────────────────────────────────
// Pointer Painter
// ─────────────────────────────────────────────────────────────────────────────

class _PointerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;
    final path = Path()
      ..moveTo(size.width / 2, size.height)
      ..lineTo(0, 0)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_PointerPainter old) => false;
}
