import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_provider.dart';
import '../../models/party_room_model.dart';
import '../../models/user_model.dart';
import '../../widgets/user_avatar.dart';
import '../../widgets/gift_dialog.dart';

class PartyRoomScreen extends StatefulWidget {
  final PartyRoomModel? partyRoom;
  const PartyRoomScreen({super.key, this.partyRoom});

  @override
  State<PartyRoomScreen> createState() => _PartyRoomScreenState();
}

class _PartyRoomScreenState extends State<PartyRoomScreen> with SingleTickerProviderStateMixin {
  late PartyRoomModel party;
  bool _isMuted = false;
  bool _isSpeakerOn = true;
  int _listenerCount = 0;
  Timer? _listenerTimer;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    party = widget.partyRoom ?? const PartyRoomModel(
      id: 'party_default',
      title: 'Voice Party Room',
      host: UserModel(
        id: 'host_default',
        username: 'host',
        name: 'Party Host',
        avatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150',
      ),
      roomType: 'Open Party',
      seats: [],
      totalListeners: 1,
    );
    _listenerCount = party.totalListeners;

    // Simulate live listener count fluctuation
    _listenerTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) {
        setState(() {
          _listenerCount += (DateTime.now().second % 2 == 0) ? 3 : -1;
          if (_listenerCount < 1) _listenerCount = 1;
        });
      }
    });

    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _listenerTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _showSeatActions(BuildContext context, PartySeatModel seat, bool isDark) {
    final primary = AppColors.getPrimary(isDark);
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.getCard(isDark),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.getBorder(isDark), borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Text(
              seat.user != null ? '${seat.user!.name} — Seat ${seat.seatIndex}' : 'Empty Seat ${seat.seatIndex}',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(isDark)),
            ),
            const SizedBox(height: 20),
            if (seat.user != null) ...[
              _seatAction(ctx, icon: Icons.mic_off_rounded, label: seat.isMuted ? 'Unmute Speaker' : 'Mute Speaker', color: AppColors.liveRed, onTap: () {
                setState(() {
                  final idx = party.seats.indexOf(seat);
                  party.seats[idx] = PartySeatModel(
                    seatIndex: seat.seatIndex,
                    user: seat.user,
                    isMuted: !seat.isMuted,
                    isLocked: seat.isLocked,
                  );
                });
                Navigator.pop(ctx);
              }),
              _seatAction(ctx, icon: Icons.remove_circle_outline_rounded, label: 'Kick from Room', color: AppColors.liveRed, onTap: () {
                setState(() {
                  final idx = party.seats.indexOf(seat);
                  party.seats[idx] = PartySeatModel(seatIndex: seat.seatIndex, isLocked: false);
                });
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${seat.user!.name} removed from room')));
              }),
              _seatAction(ctx, icon: Icons.swap_horiz_rounded, label: 'Swap to Another Seat', color: primary, onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Drag & drop to swap seats')));
              }),
              _seatAction(ctx, icon: Icons.card_giftcard_rounded, label: 'Send Gift', color: primary, onTap: () {
                Navigator.pop(ctx);
                showDialog(context: context, builder: (_) => GiftDialog(streamerName: party.title));
              }),
            ] else ...[
              _seatAction(ctx, icon: Icons.person_add_rounded, label: 'Invite to Seat', color: primary, onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Invitation sent for Seat ${seat.seatIndex}')));
              }),
              _seatAction(ctx, icon: Icons.lock_rounded, label: seat.isLocked ? 'Unlock Seat' : 'Lock Seat', color: primary, onTap: () {
                setState(() {
                  final idx = party.seats.indexOf(seat);
                  party.seats[idx] = PartySeatModel(seatIndex: seat.seatIndex, isLocked: !seat.isLocked);
                });
                Navigator.pop(ctx);
              }),
              _seatAction(ctx, icon: Icons.record_voice_over_rounded, label: 'Promote Viewer to Speaker', color: AppColors.success, onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Viewer promoted to Seat ${seat.seatIndex}')));
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _seatAction(BuildContext ctx, {required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
      onTap: onTap,
    );
  }

  Color get _successColor => AppColors.success;

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final primary = AppColors.getPrimary(isDark);

    return Scaffold(
      backgroundColor: AppColors.getBackground(isDark),
      appBar: AppBar(
        backgroundColor: AppColors.getBackground(isDark),
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              party.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.getTextPrimary(isDark),
              ),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ScaleTransition(
                  scale: _pulseAnim,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: AppColors.liveRed,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    '$_listenerCount Listeners • ${party.roomType}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.getTextSecondary(isDark),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Room type status badge
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: party.roomType == 'Open' ? _successColor.withValues(alpha: 0.15) : primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: party.roomType == 'Open' ? _successColor : primary, width: 1),
              ),
              child: Text(
                party.roomType == 'Open' ? '🌐 Open' : '🔒 Invite',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: party.roomType == 'Open' ? _successColor : primary,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ─── SEATS GRID ───
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: party.seats.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  childAspectRatio: 0.68,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 16,
                ),
                itemBuilder: (context, index) {
                  final seat = party.seats[index];
                  return GestureDetector(
                    onTap: () => _showSeatActions(context, seat, isDark),
                    child: _buildSeat(context, seat, isDark, primary),
                  );
                },
              ),
            ),

            // ─── CONTROL BAR ───
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.getCard(isDark),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border.all(color: AppColors.getBorder(isDark)),
                boxShadow: [BoxShadow(color: AppColors.black.withValues(alpha: isDark ? 0.4 : 0.08), blurRadius: 16, offset: const Offset(0, -4))],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  // Mute
                  _controlBtn(
                    icon: _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                    label: _isMuted ? 'Unmute' : 'Mute',
                    color: _isMuted ? AppColors.liveRed : primary,
                    isDark: isDark,
                    onTap: () => setState(() => _isMuted = !_isMuted),
                  ),
                  // Gift
                  GestureDetector(
                    onTap: () => showDialog(context: context, builder: (_) => GiftDialog(streamerName: party.title)),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: AppColors.getAccentGradient(isDark),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: primary.withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 4))],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('🎁', style: TextStyle(fontSize: 18)),
                          const SizedBox(width: 6),
                          Text('Send Gift', style: TextStyle(
                            color: AppColors.onPrimary(isDark: isDark),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          )),
                        ],
                      ),
                    ),
                  ),
                  // Speaker
                  _controlBtn(
                    icon: _isSpeakerOn ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                    label: 'Speaker',
                    color: _isSpeakerOn ? primary : AppColors.getTextSecondary(isDark),
                    isDark: isDark,
                    onTap: () => setState(() => _isSpeakerOn = !_isSpeakerOn),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeat(BuildContext context, PartySeatModel seat, bool isDark, Color primary) {
    if (seat.user != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomRight,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: primary.withValues(alpha: 0.3), blurRadius: 8, spreadRadius: 2)],
                ),
                child: UserAvatar(imageUrl: seat.user!.avatarUrl, radius: 28, showVipFrame: true),
              ),
              if (seat.isMuted)
                Positioned(
                  right: -2, bottom: -2,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(color: AppColors.liveRed, shape: BoxShape.circle),
                    child: const Icon(Icons.mic_off, size: 11, color: Colors.white),
                  ),
                )
                else
                Positioned(
                  right: -2, bottom: -2,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(color: _successColor, shape: BoxShape.circle),
                    child: const Icon(Icons.mic, size: 11, color: AppColors.black),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            seat.user!.name.split(' ').first,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(isDark)),
            maxLines: 1, overflow: TextOverflow.ellipsis,
          ),
          Text(
            'Seat ${seat.seatIndex}',
            style: TextStyle(fontSize: 9, color: AppColors.getTextSecondary(isDark)),
          ),
        ],
      );
    }

    if (seat.isLocked) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              color: AppColors.getBorder(isDark),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.getBorder(isDark), width: 2),
            ),
            child: Icon(Icons.lock_rounded, color: AppColors.getTextSecondary(isDark), size: 22),
          ),
          const SizedBox(height: 6),
          Text('Locked', style: TextStyle(fontSize: 10, color: AppColors.getTextSecondary(isDark))),
        ],
      );
    }

    // Empty, joinable seat
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 56, height: 56,
          decoration: BoxDecoration(
            color: primary.withValues(alpha: 0.10),
            shape: BoxShape.circle,
            border: Border.all(color: primary.withValues(alpha: 0.35), width: 2, style: BorderStyle.solid),
          ),
          child: Icon(Icons.add_rounded, color: primary, size: 26),
        ),
        const SizedBox(height: 6),
        Text('Seat ${seat.seatIndex}', style: TextStyle(fontSize: 10, color: primary, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _controlBtn({required IconData icon, required String label, required Color color, required bool isDark, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 10, color: AppColors.getTextSecondary(isDark), fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
