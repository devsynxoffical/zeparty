import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/repositories/pk_repository.dart';
import '../../models/user_model.dart';
import '../../models/pk_battle_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/live_provider.dart';
import '../../providers/live_party_provider.dart';
import '../../widgets/user_avatar.dart';

class PkMatchScreen extends StatefulWidget {
  final String? currentRoomId;
  final String roomType; // 'AUDIO' or 'VIDEO'
  const PkMatchScreen({
    super.key,
    this.currentRoomId,
    this.roomType = 'AUDIO',
  });

  @override
  State<PkMatchScreen> createState() => _PkMatchScreenState();
}

class _PkMatchScreenState extends State<PkMatchScreen> {
  final TextEditingController _searchController = TextEditingController();

  // Match Duration Selection (3 min, 5 min default, 10 min)
  int _selectedDuration = 300;
  final List<int> _durations = [180, 300, 600];

  // Search & Discovery State
  bool _isSearching = false;
  PKDiscoveryResult? _discoveredOpponent;
  String? _searchError;

  // Available hosts fallback list
  List<UserModel> _availableHosts = [];
  bool _isLoadingHosts = false;

  // Invitation State
  bool _isSendingInvite = false;
  String? _pendingInvitationId;
  String? _pendingMatchId;
  int _invitationTimerRemaining = 30;
  Timer? _invitationTimer;

  // Readiness & Countdown State
  bool _isConfirmingReady = false;
  bool _isPreparing = false;
  bool _isLocalReady = false;

  @override
  void initState() {
    super.initState();
    _loadAvailableHosts();
  }

  @override
  void dispose() {
    _invitationTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  String get _effectiveRoomId {
    if (widget.currentRoomId != null && widget.currentRoomId!.isNotEmpty) {
      return widget.currentRoomId!;
    }
    final partyProv = context.read<LivePartyProvider>();
    if (partyProv.activeRoom != null) return partyProv.activeRoom!.id;
    final liveProv = context.read<LiveProvider>();
    if (liveProv.activeRoom != null) return liveProv.activeRoom!.id;
    return '';
  }

  String get _effectiveRoomType {
    if (widget.roomType.isNotEmpty) return widget.roomType;
    final partyProv = context.read<LivePartyProvider>();
    if (partyProv.activeRoom != null) return 'AUDIO';
    return 'VIDEO';
  }

  Future<void> _loadAvailableHosts() async {
    setState(() => _isLoadingHosts = true);
    try {
      final hosts = await PKRepository.instance.getAvailableLiveHosts();
      final authUserId = context.read<AuthProvider>().currentUser.id;
      if (mounted) {
        setState(() {
          _availableHosts = hosts.where((h) => h.id != authUserId).toList();
          _isLoadingHosts = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingHosts = false);
    }
  }

  Future<void> _performDiscovery() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isSearching = true;
      _searchError = null;
      _discoveredOpponent = null;
    });

    try {
      final result = await PKRepository.instance.discoverOpponent(
        query: query,
        roomType: _effectiveRoomType,
      );

      if (mounted) {
        if (result == null) {
          setState(() {
            _searchError = 'No online ${widget.roomType} room found matching "$query".';
            _isSearching = false;
          });
        } else {
          setState(() {
            _discoveredOpponent = result;
            _isSearching = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _searchError = 'Search failed: $e';
          _isSearching = false;
        });
      }
    }
  }

  Future<void> _sendInvitation({
    required String targetRoomId,
    required String targetHostUserId,
    required String targetName,
  }) async {
    final fromRoomId = _effectiveRoomId;
    if (fromRoomId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Active room ID not found.')),
      );
      return;
    }

    setState(() => _isSendingInvite = true);
    try {
      final res = await PKRepository.instance.sendInvitation(
        fromRoomId: fromRoomId,
        targetRoomId: targetRoomId,
        targetHostUserId: targetHostUserId,
        durationSeconds: _selectedDuration,
      );

      final invId = res['invitationId']?.toString();
      final matchId = res['matchId']?.toString();

      if (mounted) {
        setState(() {
          _pendingInvitationId = invId;
          _pendingMatchId = matchId;
          _invitationTimerRemaining = 30;
          _isSendingInvite = false;
        });

        _startInvitationCountdown();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚔️ PK invitation sent to $targetName (Expires in 30s)'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSendingInvite = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send PK invitation: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _startInvitationCountdown() {
    _invitationTimer?.cancel();
    _invitationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_invitationTimerRemaining <= 1) {
        timer.cancel();
        setState(() {
          _pendingInvitationId = null;
          _invitationTimerRemaining = 0;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('⏱️ PK invitation expired.')),
        );
      } else {
        setState(() => _invitationTimerRemaining--);
      }
    });
  }

  Future<void> _cancelPendingInvitation() async {
    if (_pendingInvitationId == null) return;
    try {
      await PKRepository.instance.cancelInvitation(_pendingInvitationId!);
      _invitationTimer?.cancel();
      if (mounted) {
        setState(() {
          _pendingInvitationId = null;
          _pendingMatchId = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PK invitation cancelled.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cancelling invitation: $e')),
        );
      }
    }
  }

  Future<void> _confirmOperatorReady() async {
    if (_pendingMatchId == null) return;
    setState(() => _isConfirmingReady = true);
    try {
      await PKRepository.instance.setOperatorReady(
        matchId: _pendingMatchId!,
        mediaPrepared: true,
      );
      if (mounted) {
        setState(() {
          _isLocalReady = true;
          _isConfirmingReady = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Ready confirmed! Waiting for countdown...'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isConfirmingReady = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error confirming ready: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAudio = _effectiveRoomType == 'AUDIO';

    return Scaffold(
      backgroundColor: const Color(0xFF0A071B),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          children: [
            Text(
              '${isAudio ? 'Audio' : 'Video'} PK Match',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
            ),
            const Text(
              '1v1 Host Competition • 1 Coin = 1 Point',
              style: TextStyle(color: Color(0xFF00E5FF), fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topCenter,
                radius: 1.2,
                colors: [Color(0xFF2E124D), Color(0xFF0A071B)],
              ),
            ),
          ),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                // 1. Duration Selector Section
                _buildDurationSelector(),
                const SizedBox(height: 16),

                // 2. Pending Invitation Banner (if active)
                if (_pendingInvitationId != null) ...[
                  _buildPendingInviteBanner(),
                  const SizedBox(height: 16),
                ],

                // 3. Preparation / Readiness Check (if in prep)
                if (_isPreparing) ...[
                  _buildPreparationBanner(),
                  const SizedBox(height: 16),
                ],

                // 4. Opponent Search Section
                _buildSearchSection(),
                const SizedBox(height: 14),

                // 5. Search Result (Discovered Opponent)
                if (_isSearching)
                  const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: Color(0xFF00E5FF))))
                else if (_discoveredOpponent != null)
                  _buildDiscoveredCard(_discoveredOpponent!)
                else if (_searchError != null)
                  _buildErrorCard(_searchError!),

                const SizedBox(height: 20),

                // 6. Available Live Hosts Recommendation List
                _buildAvailableHostsSection(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDurationSelector() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.timer_outlined, color: Color(0xFF00E5FF), size: 18),
              SizedBox(width: 8),
              Text(
                'Match Duration',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
              Spacer(),
              Text(
                'Admin Configurable',
                style: TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: _durations.map((seconds) {
              final minutes = seconds ~/ 60;
              final isSelected = _selectedDuration == seconds;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: InkWell(
                    onTap: _pendingInvitationId == null
                        ? () => setState(() => _selectedDuration = seconds)
                        : null,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        gradient: isSelected
                            ? const LinearGradient(
                                colors: [Color(0xFFE91E63), Color(0xFFFF6090)],
                              )
                            : null,
                        color: isSelected ? null : Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? Colors.pinkAccent : Colors.white.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '$minutes Minutes',
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.white70,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          if (seconds == 300)
                            Text(
                              'Standard',
                              style: TextStyle(
                                color: isSelected ? Colors.white.withValues(alpha: 0.8) : const Color(0xFF00E5FF),
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Discover Opponent',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 4),
          const Text(
            'Search by Room ID or public Numeric Host ID (Same room type & region)',
            style: TextStyle(color: Colors.white54, fontSize: 11),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: const InputDecoration(
                      hintText: 'Enter Room ID or Host Numeric ID...',
                      hintStyle: TextStyle(color: Colors.white38, fontSize: 12),
                      prefixIcon: Icon(Icons.search_rounded, color: Colors.white54, size: 20),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    onSubmitted: (_) => _performDiscovery(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: _isSearching ? null : _performDiscovery,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 46,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00E5FF), Color(0xFF0091EA)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'Search',
                    style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDiscoveredCard(PKDiscoveryResult result) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1035),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Stack(
                children: [
                  UserAvatar(
                    imageUrl: result.hostAvatarUrl,
                    radius: 24,
                  ),
                  if (result.isOnline)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.greenAccent,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.black, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.hostDisplayName,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'ID: ${result.numericId ?? result.hostId} • Room: ${result.roomId}',
                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${result.roomType} Room • ${result.region}',
                        style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _isSendingInvite
                    ? null
                    : () => _sendInvitation(
                          targetRoomId: result.roomId,
                          targetHostUserId: result.hostId,
                          targetName: result.hostDisplayName,
                        ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE91E63),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                child: _isSendingInvite
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Invite', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(String error) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.redAccent, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(error, style: const TextStyle(color: Colors.white70, fontSize: 12))),
        ],
      ),
    );
  }

  Widget _buildPendingInviteBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFFE91E63).withValues(alpha: 0.25), const Color(0xFF0A071B)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE91E63)),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(color: Color(0xFFE91E63), strokeWidth: 2.5),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Waiting for Opponent Acceptance...',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                Text(
                  'Expires in ${_invitationTimerRemaining}s (30s window)',
                  style: const TextStyle(color: Colors.amberAccent, fontSize: 11),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _cancelPendingInvitation,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white70,
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Cancel', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildPreparationBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.greenAccent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.greenAccent),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Both Rooms Preparing Media (15s Window)',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 6),
          const Text(
            'Confirm camera/microphone readiness before 3s countdown begins.',
            style: TextStyle(color: Colors.white70, fontSize: 11),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.check_circle_rounded, size: 18),
              label: Text(_isConfirmingReady ? 'Confirming...' : (_isLocalReady ? 'Ready Confirmed' : 'I Am Ready')),
              onPressed: (_isConfirmingReady || _isLocalReady) ? null : _confirmOperatorReady,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvailableHostsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Active Broadcasters (Same Region)',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 8),
        if (_isLoadingHosts)
          const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: Colors.white24)))
        else if (_availableHosts.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: const Text(
              'No other hosts online right now. Search by Room ID above.',
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _availableHosts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final host = _availableHosts[index];
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Row(
                  children: [
                    UserAvatar(imageUrl: host.avatarUrl, radius: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            host.name,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'User ID: ${host.id.substring(0, host.id.length > 8 ? 8 : host.id.length)}',
                            style: const TextStyle(color: Colors.white38, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.send_rounded, color: Color(0xFF00E5FF), size: 20),
                      onPressed: () {
                        _searchController.text = host.id;
                        _performDiscovery();
                      },
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}
