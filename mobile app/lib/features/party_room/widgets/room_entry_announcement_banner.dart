import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../providers/game_provider.dart';
import '../../../../providers/auth_provider.dart';

/// Room Entry Announcement Banner (Module 03)
/// Placed directly beneath the mic section and above chat feed.
/// Features Reconnect Protection via session tracking, auto-hide timer,
/// prohibited word filter, character limit, and persistent view capability.
class RoomEntryAnnouncementBanner extends StatefulWidget {
  final String roomId;
  final String roomEntrySessionId;
  final bool isDark;

  const RoomEntryAnnouncementBanner({
    super.key,
    required this.roomId,
    required this.roomEntrySessionId,
    this.isDark = true,
  });

  // Track shown sessions statically to prevent duplicate triggers on socket/firebase reconnects
  static final Set<String> _displayedSessions = {};

  static bool isSessionDisplayed(String sessionId) {
    return _displayedSessions.contains(sessionId);
  }

  static void clearSession(String sessionId) {
    _displayedSessions.remove(sessionId);
  }

  @override
  State<RoomEntryAnnouncementBanner> createState() => _RoomEntryAnnouncementBannerState();
}

class _RoomEntryAnnouncementBannerState extends State<RoomEntryAnnouncementBanner> {
  bool _isVisible = false;
  Timer? _autoHideTimer;

  @override
  void initState() {
    super.initState();
    _checkAndShowAnnouncement();
  }

  @override
  void didUpdateWidget(covariant RoomEntryAnnouncementBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.roomEntrySessionId != widget.roomEntrySessionId) {
      _checkAndShowAnnouncement();
    }
  }

  void _checkAndShowAnnouncement() {
    // Reconnect Protection: Trigger only ONCE per genuine room session ID
    if (!RoomEntryAnnouncementBanner._displayedSessions.contains(widget.roomEntrySessionId)) {
      RoomEntryAnnouncementBanner._displayedSessions.add(widget.roomEntrySessionId);
      setState(() {
        _isVisible = true;
      });

      _autoHideTimer?.cancel();
      _autoHideTimer = Timer(const Duration(seconds: 9), () {
        if (mounted) {
          setState(() {
            _isVisible = false;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _autoHideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVisible) return const SizedBox.shrink();

    final gameProvider = Provider.of<GameProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userCountry = authProvider.currentUser.region.isNotEmpty ? authProvider.currentUser.region : 'Global';

    final announcement = gameProvider.getResolvedAnnouncement(widget.roomId, userCountry);
    final title = announcement['title'] ?? '📢 Room Announcement';
    final text = announcement['text'] ?? 'Welcome to ZeParty!';
    final source = announcement['source'] ?? 'ZeParty Notice';
    final isMandatory = announcement['isMandatory'] == true;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1A30),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isMandatory ? Colors.amber.withValues(alpha: 0.6) : Colors.purpleAccent.withValues(alpha: 0.4),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: (isMandatory ? Colors.amber : Colors.purple).withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    isMandatory ? Icons.campaign_rounded : Icons.info_outline_rounded,
                    color: isMandatory ? Colors.amber : Colors.cyanAccent,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isMandatory ? Colors.amber.withValues(alpha: 0.2) : Colors.cyan.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      source,
                      style: TextStyle(
                        color: isMandatory ? Colors.amber : Colors.cyanAccent,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isVisible = false;
                  });
                },
                child: const Icon(Icons.close_rounded, color: Colors.white60, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            text,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

/// Announcement Management Dialog for Room Owner & Authorized Admin
class RoomAnnouncementEditDialog extends StatefulWidget {
  final String roomId;
  final bool isHost;
  final bool isAdmin;

  const RoomAnnouncementEditDialog({
    super.key,
    required this.roomId,
    required this.isHost,
    required this.isAdmin,
  });

  static Future<void> show(BuildContext context, {required String roomId, required bool isHost, required bool isAdmin}) {
    return showDialog(
      context: context,
      builder: (_) => RoomAnnouncementEditDialog(roomId: roomId, isHost: isHost, isAdmin: isAdmin),
    );
  }

  @override
  State<RoomAnnouncementEditDialog> createState() => _RoomAnnouncementEditDialogState();
}

class _RoomAnnouncementEditDialogState extends State<RoomAnnouncementEditDialog> {
  late TextEditingController _textController;
  late TextEditingController _titleController;
  bool _enabled = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final gameProvider = Provider.of<GameProvider>(context, listen: false);
    final authUser = Provider.of<AuthProvider>(context, listen: false).currentUser;
    final currentAnn = gameProvider.getResolvedAnnouncement(widget.roomId, authUser.region);

    _titleController = TextEditingController(text: currentAnn['title'] ?? '📢 Room Announcement');
    _textController = TextEditingController(text: currentAnn['text'] ?? '');
    _enabled = currentAnn['status'] != 'Disabled';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gameProvider = Provider.of<GameProvider>(context);
    final authUser = Provider.of<AuthProvider>(context, listen: false).currentUser;

    return AlertDialog(
      backgroundColor: const Color(0xFF1E1B2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.campaign_rounded, color: Colors.amber),
          SizedBox(width: 8),
          Text('Room Announcement', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Announcement Title',
                labelStyle: const TextStyle(color: Colors.white70),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _textController,
              maxLines: 4,
              maxLength: 200,
              decoration: InputDecoration(
                labelText: 'Announcement Body (Max 200 chars)',
                labelStyle: const TextStyle(color: Colors.white70),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                counterStyle: const TextStyle(color: Colors.white60),
              ),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Enable Announcement', style: TextStyle(color: Colors.white, fontSize: 14)),
                Switch(
                  value: _enabled,
                  activeThumbColor: Colors.amber,
                  onChanged: (val) {
                    setState(() {
                      _enabled = val;
                    });
                  },
                ),
              ],
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent),
          onPressed: () async {
            final nav = Navigator.of(context);
            final messenger = ScaffoldMessenger.of(context);
            final err = await gameProvider.setRoomAnnouncement(
              roomId: widget.roomId,
              editorUserId: authUser.id,
              title: _titleController.text.trim().isEmpty ? '📢 Room Announcement' : _titleController.text.trim(),
              text: _textController.text,
              enabled: _enabled,
              status: _enabled ? 'Active' : 'Disabled',
              isAdmin: widget.isAdmin,
            );

            if (!mounted) return;
            if (err != null) {
              setState(() {
                _errorMessage = err;
              });
            } else {
              nav.pop();
              messenger.showSnackBar(
                const SnackBar(content: Text('🎉 Announcement updated successfully!'), backgroundColor: Colors.green),
              );
            }
          },
          child: const Text('Save & Publish', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
