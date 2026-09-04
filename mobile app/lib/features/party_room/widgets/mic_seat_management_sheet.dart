import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/party_participant_model.dart';
import '../../../models/user_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/live_party_provider.dart';
import '../../../widgets/user_avatar.dart';

class MicSeatManagementSheet extends StatefulWidget {
  final int micIndex;
  final PartyParticipantModel? occupant;
  final bool isLocked;
  final bool isMuted;

  const MicSeatManagementSheet({
    super.key,
    required this.micIndex,
    this.occupant,
    required this.isLocked,
    required this.isMuted,
  });

  static void show(
    BuildContext context, {
    required int micIndex,
    PartyParticipantModel? occupant,
    required bool isLocked,
    required bool isMuted,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => MicSeatManagementSheet(
        micIndex: micIndex,
        occupant: occupant,
        isLocked: isLocked,
        isMuted: isMuted,
      ),
    );
  }

  @override
  State<MicSeatManagementSheet> createState() => _MicSeatManagementSheetState();
}

class _MicSeatManagementSheetState extends State<MicSeatManagementSheet> {
  bool _showVolumeSlider = false;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LivePartyProvider>();
    final authUser = context.watch<AuthProvider>().currentUser;

    final micIndex = widget.micIndex;
    final occupant = widget.occupant ?? provider.participants.where((p) => p.seatNumber == micIndex).firstOrNull;
    final isOccupied = occupant != null;
    final isLocked = provider.isSeatLocked(micIndex);
    final isMuted = provider.isSeatMuted(micIndex);
    final volume = provider.getSeatVolume(micIndex);

    final micLabel = micIndex == 0 ? 'Host Mic' : 'Mic ${micIndex + 1}';

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF141124),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Color(0x99000000),
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top Drag Handle
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Header Section with glowing icon and mic state
              Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: isLocked
                            ? [const Color(0xFFE53935), const Color(0xFF8E0000)]
                            : (isMuted
                                ? [const Color(0xFFFF9800), const Color(0xFFE65100)]
                                : [const Color(0xFFAB47BC), const Color(0xFF4A148C)]),
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (isLocked
                                  ? Colors.redAccent
                                  : (isMuted ? Colors.orangeAccent : Colors.purpleAccent))
                              .withValues(alpha: 0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        isLocked
                            ? Icons.lock_rounded
                            : (isMuted ? Icons.mic_off_rounded : Icons.mic_rounded),
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          micLabel,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isLocked
                                    ? Colors.redAccent
                                    : (isMuted
                                        ? Colors.orangeAccent
                                        : (isOccupied ? Colors.greenAccent : Colors.blueAccent)),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                isOccupied
                                    ? 'Occupied by ${occupant.user.name}'
                                    : (isLocked ? 'Locked Seat' : 'Available Seat'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (isOccupied)
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.purpleAccent, width: 2),
                      ),
                      child: UserAvatar(imageUrl: occupant.user.avatarUrl, radius: 22),
                    ),
                ],
              ),

              const SizedBox(height: 20),
              Container(height: 1, color: Colors.white.withValues(alpha: 0.1)),
              const SizedBox(height: 12),

              // Volume Slider Toggle Bar (Optional Expandable)
              if (_showVolumeSlider)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.volume_up_rounded, color: Colors.purpleAccent, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        '${(volume * 100).toInt()}%',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: Colors.purpleAccent,
                            inactiveTrackColor: Colors.white24,
                            thumbColor: Colors.amber,
                            trackHeight: 4,
                          ),
                          child: Slider(
                            value: volume,
                            onChanged: (v) {
                              provider.setSeatVolume(micIndex, v);
                              setState(() {});
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Action List Items

              // 1. Take the Mic
              _buildActionTile(
                context,
                icon: Icons.airline_seat_recline_normal_rounded,
                iconBg: const Color(0xFF1B4D3E),
                iconColor: const Color(0xFF00E676),
                title: 'Take the Mic',
                subtitle: 'Move to or occupy this mic seat',
                onTap: () {
                  Navigator.pop(context);
                  final err = provider.takeMicSeat(micIndex, authUser);
                  if (err == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('🎉 You are now on $micLabel!'), backgroundColor: Colors.green),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('❌ $err'), backgroundColor: Colors.redAccent),
                    );
                  }
                },
              ),

              // 2. Invite User to Take the Mic
              _buildActionTile(
                context,
                icon: Icons.person_add_alt_1_rounded,
                iconBg: const Color(0xFF15294A),
                iconColor: const Color(0xFF2979FF),
                title: 'Invite User to Take the Mic',
                subtitle: 'Send a time-limited mic invitation',
                onTap: () {
                  Navigator.pop(context);
                  _showUserSelectorDialog(context, provider, authUser);
                },
              ),

              // 3. Mute / Unmute the Mic (Available for ALL seats!)
              _buildActionTile(
                context,
                icon: isMuted ? Icons.mic_rounded : Icons.mic_off_rounded,
                iconBg: isMuted ? const Color(0xFF1B4D3E) : const Color(0xFF4A2B10),
                iconColor: isMuted ? const Color(0xFF00E676) : const Color(0xFFFF9100),
                title: isMuted ? 'Unmute the Mic' : 'Mute the Mic',
                subtitle: isMuted
                    ? 'Allow speakers on $micLabel to talk'
                    : 'Mute audio output for $micLabel',
                onTap: () {
                  Navigator.pop(context);
                  provider.muteMicSeat(micIndex, !isMuted, actor: authUser);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isMuted ? '🔊 $micLabel unmuted' : '🔇 $micLabel muted'),
                      backgroundColor: isMuted ? Colors.green : Colors.orange,
                    ),
                  );
                },
              ),

              // 4. Lock / Unlock the Mic
              _buildActionTile(
                context,
                icon: isLocked ? Icons.lock_open_rounded : Icons.lock_rounded,
                iconBg: isLocked ? const Color(0xFF103A4A) : const Color(0xFF4A151B),
                iconColor: isLocked ? const Color(0xFF00E5FF) : const Color(0xFFFF1744),
                title: isLocked ? 'Unlock the Mic' : 'Lock the Mic',
                subtitle: isLocked ? 'Allow users to take this seat' : 'Prevent regular users from taking this seat',
                onTap: () {
                  Navigator.pop(context);
                  provider.lockMicSeat(micIndex, !isLocked, actor: authUser);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isLocked ? '🔓 $micLabel unlocked' : '🔒 $micLabel locked'),
                      backgroundColor: isLocked ? Colors.green : Colors.orange,
                    ),
                  );
                },
              ),

              // 5. Clear Seat / Remove User (Shown when occupied)
              if (isOccupied)
                _buildActionTile(
                  context,
                  icon: Icons.person_remove_rounded,
                  iconBg: const Color(0xFF3D0C15),
                  iconColor: const Color(0xFFFF5252),
                  title: 'Clear Seat',
                  subtitle: 'Move ${occupant.user.name} off the mic back to audience',
                  onTap: () {
                    Navigator.pop(context);
                    provider.clearMicSeat(micIndex, actor: authUser);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('🚫 ${occupant.user.name} was moved to audience'),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                  },
                ),

              // 6. Mic Seat Volume Adjustment
              _buildActionTile(
                context,
                icon: Icons.tune_rounded,
                iconBg: const Color(0xFF281540),
                iconColor: const Color(0xFFD500F9),
                title: 'Mic Seat Volume',
                subtitle: 'Adjust audio output gain level (${(volume * 100).toInt()}%)',
                onTap: () {
                  setState(() {
                    _showVolumeSlider = !_showVolumeSlider;
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionTile(
    BuildContext context, {
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: iconBg,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 11.5,
          ),
        ),
      ),
    );
  }

  void _showUserSelectorDialog(BuildContext context, LivePartyProvider provider, UserModel inviter) {
    final participants = provider.participants.where((p) => p.seatNumber == null).toList();

    showDialog(
      context: context,
      builder: (d) => AlertDialog(
        backgroundColor: const Color(0xFF18142A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(Icons.person_add_alt_1_rounded, color: Colors.blueAccent),
            const SizedBox(width: 8),
            Text('Invite to Mic ${widget.micIndex + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: participants.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No unseated audience members found in room.', style: TextStyle(color: Colors.white70)),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: participants.length,
                  itemBuilder: (ctx, idx) {
                    final p = participants[idx];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        leading: UserAvatar(imageUrl: p.user.avatarUrl, radius: 18),
                        title: Text(p.user.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: Text('@${p.user.username}', style: const TextStyle(color: Colors.white60, fontSize: 11)),
                        trailing: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () {
                            Navigator.pop(d);
                            final inviteId = provider.inviteUserToMic(widget.micIndex, inviter, p.user);
                            if (inviteId != null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('📩 Invitation sent to ${p.user.name} for Mic ${widget.micIndex + 1}!'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          },
                          child: const Text('Invite', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d),
            child: const Text('Close', style: TextStyle(color: Colors.white60)),
          ),
        ],
      ),
    );
  }
}
