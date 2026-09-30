import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/repositories/backend_repository.dart';
import '../../core/services/media_upload_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_provider.dart';
import '../../models/live_room_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/live_party_provider.dart';

class RoomSettingsScreen extends StatefulWidget {
  final LiveRoomModel room;
  const RoomSettingsScreen({super.key, required this.room});

  @override
  State<RoomSettingsScreen> createState() => _RoomSettingsScreenState();
}

class _RoomSettingsScreenState extends State<RoomSettingsScreen> {
  late TextEditingController _nameController;
  late TextEditingController _announcementController;
  late TextEditingController _feeController;

  late String _selectedCoverUrl;
  late String _roomMode;
  late int _seatCapacity;
  late String _closeRoomEffect;
  late String _roomTheme;

  // Behavior Toggles (CR 30)
  late bool _allowGuestMic;
  late bool _allowHistoryMessages;
  late bool _allowUnderMicEmoji;
  late bool _allowUnderMicDice;
  late bool _allowAdminEditSettings;
  late bool _allowAdminChangeMode;

  late List<String> _bannedUserIds;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final r = widget.room;
    _nameController = TextEditingController(text: r.title);
    _announcementController = TextEditingController(text: r.announcement);
    _feeController = TextEditingController(text: r.membershipFee.toString());

    _selectedCoverUrl = r.coverUrl;
    _roomMode = r.roomMode;
    _seatCapacity = r.seatCapacity;
    _closeRoomEffect = r.closeRoomEffect;
    _roomTheme = r.nobleTitle.isNotEmpty ? r.nobleTitle : 'Default Dark';

    _allowGuestMic = r.allowGuestMic;
    _allowHistoryMessages = r.allowHistoryMessages;
    _allowUnderMicEmoji = r.allowUnderMicEmoji;
    _allowUnderMicDice = r.allowUnderMicDice;
    _allowAdminEditSettings = r.allowAdminEditSettings;
    _allowAdminChangeMode = r.allowAdminChangeMode;
    _bannedUserIds = List<String>.from(r.bannedUserIds);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _announcementController.dispose();
    _feeController.dispose();
    super.dispose();
  }

  // Free Gallery Cover Upload (CR 30 / CR 31 policy)
  Future<void> _changeCoverImage() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 88);
      if (picked != null) {
        String finalUrl = picked.path;
        try {
          final uploadRes = await MediaUploadService.instance.uploadFile(
            filePath: picked.path,
            folder: 'room_covers',
          );
          if (uploadRes.url.isNotEmpty) finalUrl = uploadRes.url;
        } catch (err) {
          debugPrint('[RoomSettings] Cover upload fallback: $err');
        }
        setState(() {
          _selectedCoverUrl = finalUrl;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✨ Room cover updated (Free upload)')),
          );
        }
      }
    } catch (e) {
      debugPrint('[RoomSettings] Pick image error: $e');
    }
  }

  void _saveSettings() async {
    final partyProv = Provider.of<LivePartyProvider>(context, listen: false);
    final authProv = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = authProv.currentUser;

    final isHost = widget.room.host.id == currentUser.id || widget.room.creatorUserId == currentUser.id;
    final isAdmin = partyProv.isAdmin(currentUser.id);
    final canEdit = isHost || (isAdmin && widget.room.allowAdminEditSettings);

    if (!canEdit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ You do not have permission to modify room settings.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final updatedFee = int.tryParse(_feeController.text.trim()) ?? 0;
    final updatedTitle = _nameController.text.trim();
    final updatedNotice = _announcementController.text.trim();

    final updatedRoom = widget.room.copyWith(
      title: updatedTitle.isNotEmpty ? updatedTitle : widget.room.title,
      announcement: updatedNotice.isNotEmpty ? updatedNotice : widget.room.announcement,
      coverUrl: _selectedCoverUrl,
      membershipFee: updatedFee,
      roomMode: _roomMode,
      seatCapacity: _seatCapacity,
      nobleTitle: _roomTheme,
      allowGuestMic: _allowGuestMic,
      allowHistoryMessages: _allowHistoryMessages,
      allowUnderMicEmoji: _allowUnderMicEmoji,
      allowUnderMicDice: _allowUnderMicDice,
      allowAdminEditSettings: _allowAdminEditSettings,
      allowAdminChangeMode: _allowAdminChangeMode,
      closeRoomEffect: _closeRoomEffect,
      bannedUserIds: _bannedUserIds,
    );

    // Update active room provider
    partyProv.updateRoomDetails(
      title: updatedRoom.title,
      coverUrl: updatedRoom.coverUrl,
      capacity: updatedRoom.seatCapacity,
      nobleTitle: updatedRoom.nobleTitle,
    );
    partyProv.sendSystemMessage('⚙️ Room Settings updated by management.');

    // Save in global state store
    BackendRepository.instance.addLiveRoom(updatedRoom);

    await Future.delayed(const Duration(milliseconds: 300));

    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Room settings saved and applied!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context, updatedRoom);
    }
  }

  void _openKickOutList() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1B2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('🚫 Kick-out / Banned List', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_bannedUserIds.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 30),
                  child: Center(
                    child: Text('No users have been kicked out of this room.', style: TextStyle(color: Colors.white54)),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: _bannedUserIds.length,
                    itemBuilder: (context, index) {
                      final userId = _bannedUserIds[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A2640),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Colors.redAccent,
                            child: Icon(Icons.person_off, color: Colors.white, size: 20),
                          ),
                          title: Text('User ID: $userId', style: const TextStyle(color: Colors.white, fontSize: 14)),
                          trailing: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                            ),
                            onPressed: () {
                              setSheetState(() {
                                _bannedUserIds.removeAt(index);
                              });
                              setState(() {});
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Unbanned user $userId')),
                              );
                            },
                            child: const Text('Unban', style: TextStyle(color: Colors.white, fontSize: 12)),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProv = Provider.of<AuthProvider>(context);
    final partyProv = Provider.of<LivePartyProvider>(context);
    final currentUser = authProv.currentUser;

    final isHost = widget.room.host.id == currentUser.id || widget.room.creatorUserId == currentUser.id;
    final isAdmin = partyProv.isAdmin(currentUser.id);
    final canEdit = isHost || (isAdmin && widget.room.allowAdminEditSettings);
    final canChangeMode = isHost || (isAdmin && widget.room.allowAdminChangeMode);

    return Scaffold(
      backgroundColor: const Color(0xFF0D0B18),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1B2E),
        elevation: 0,
        title: const Text('Room Settings', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          if (canEdit)
            TextButton(
              onPressed: _isSaving ? null : _saveSettings,
              child: _isSaving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.pinkAccent, strokeWidth: 2))
                  : const Text('Save', style: TextStyle(color: Colors.pinkAccent, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!canEdit)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.amber, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Read-only view. Only the room owner or authorized admins can edit these settings.',
                        style: TextStyle(color: Colors.amber, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),

            // ── Section 1: Identity & Appearance ──
            _buildSectionHeader('Identity & Appearance', Icons.palette_outlined),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1B2E),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: canEdit ? _changeCoverImage : null,
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Image.network(
                                _selectedCoverUrl,
                                width: 70,
                                height: 70,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 70,
                                  height: 70,
                                  color: Colors.purple.shade900,
                                  child: const Icon(Icons.room, color: Colors.white),
                                ),
                              ),
                            ),
                            if (canEdit)
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.pinkAccent,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.edit, color: Colors.white, size: 12),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Room Cover Photo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(
                              canEdit ? 'Tap thumbnail to change (Free Gallery Upload)' : 'Cover photo',
                              style: const TextStyle(color: Colors.white54, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white10, height: 24),

                  // Room Name
                  TextField(
                    controller: _nameController,
                    enabled: canEdit,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Room Name',
                      labelStyle: TextStyle(color: Colors.white60),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.pinkAccent)),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Room Announcement
                  TextField(
                    controller: _announcementController,
                    enabled: canEdit,
                    maxLines: 2,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Room Announcement / Notice',
                      labelStyle: TextStyle(color: Colors.white60),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.pinkAccent)),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Room Theme / Decoration
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Room Theme', style: TextStyle(color: Colors.white, fontSize: 14)),
                      DropdownButton<String>(
                        value: ['Default Dark', 'Neon Vibes', 'Cyberpunk', 'Luxury Gold', 'Royal Purple'].contains(_roomTheme) ? _roomTheme : 'Default Dark',
                        dropdownColor: const Color(0xFF2A2640),
                        style: const TextStyle(color: Colors.pinkAccent, fontWeight: FontWeight.bold),
                        underline: const SizedBox(),
                        items: ['Default Dark', 'Neon Vibes', 'Cyberpunk', 'Luxury Gold', 'Royal Purple']
                            .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                            .toList(),
                        onChanged: canEdit ? (val) => setState(() => _roomTheme = val!) : null,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Section 2: Membership & Mode ──
            _buildSectionHeader('Membership & Mode', Icons.meeting_room_outlined),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1B2E),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  // Membership Fee
                  Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Membership Fee (Coins)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            Text('Set to 0 for Free entry', style: TextStyle(color: Colors.white54, fontSize: 12)),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 100,
                        child: TextField(
                          controller: _feeController,
                          enabled: canEdit,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            fillColor: const Color(0xFF2A2640),
                            filled: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white10, height: 24),

                  // Room Mode
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Room Mode', style: TextStyle(color: Colors.white, fontSize: 14)),
                      DropdownButton<String>(
                        value: ['Friend mode', 'Public mode', 'Lock mode'].contains(_roomMode) ? _roomMode : 'Friend mode',
                        dropdownColor: const Color(0xFF2A2640),
                        style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold),
                        underline: const SizedBox(),
                        items: ['Friend mode', 'Public mode', 'Lock mode']
                            .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                            .toList(),
                        onChanged: canChangeMode ? (val) => setState(() => _roomMode = val!) : null,
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white10, height: 24),

                  // Mic Seat Capacity
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Number of Mics / Seats', style: TextStyle(color: Colors.white, fontSize: 14)),
                      DropdownButton<int>(
                        value: [8, 10, 12, 15, 20].contains(_seatCapacity) ? _seatCapacity : 10,
                        dropdownColor: const Color(0xFF2A2640),
                        style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
                        underline: const SizedBox(),
                        items: [8, 10, 12, 15, 20]
                            .map((c) => DropdownMenuItem(value: c, child: Text('$c Seats')))
                            .toList(),
                        onChanged: canEdit ? (val) => setState(() => _seatCapacity = val!) : null,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Section 3: Behavior Toggles ──
            _buildSectionHeader('Behavior Toggles', Icons.tune_rounded),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1E1B2E),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _buildToggleRow('Guests taking mic', 'Allow ordinary guests to take open mic seats', _allowGuestMic, (v) => setState(() => _allowGuestMic = v), canEdit),
                  const Divider(color: Colors.white10, height: 1),
                  _buildToggleRow('Historical room messages', 'Allow members to view chat history prior to joining', _allowHistoryMessages, (v) => setState(() => _allowHistoryMessages = v), canEdit),
                  const Divider(color: Colors.white10, height: 1),
                  _buildToggleRow('Under-mic emoji sending', 'Allow seat occupants to trigger floating emojis', _allowUnderMicEmoji, (v) => setState(() => _allowUnderMicEmoji = v), canEdit),
                  const Divider(color: Colors.white10, height: 1),
                  _buildToggleRow('Under-mic dice sending', 'Allow seat occupants to roll game dice', _allowUnderMicDice, (v) => setState(() => _allowUnderMicDice = v), canEdit),
                  const Divider(color: Colors.white10, height: 1),
                  _buildToggleRow('Admins edit room settings', 'Permit appointed admins to change title/announcement', _allowAdminEditSettings, (v) => setState(() => _allowAdminEditSettings = v), isHost),
                  const Divider(color: Colors.white10, height: 1),
                  _buildToggleRow('Admins change room mode', 'Permit appointed admins to switch Public/Friend/Lock mode', _allowAdminChangeMode, (v) => setState(() => _allowAdminChangeMode = v), isHost),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Section 4: Effects & Moderation ──
            _buildSectionHeader('Effects & Moderation', Icons.security_rounded),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1B2E),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  // Close Room Effects
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Close Room Effects', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                            Text('Animation played when host closes the party', style: TextStyle(color: Colors.white54, fontSize: 11)),
                          ],
                        ),
                      ),
                      DropdownButton<String>(
                        value: ['Standard', 'Fade Out', 'Diamond Burst', 'VIP Galaxy Explosion'].contains(_closeRoomEffect) ? _closeRoomEffect : 'Standard',
                        dropdownColor: const Color(0xFF2A2640),
                        style: const TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.bold),
                        underline: const SizedBox(),
                        items: ['Standard', 'Fade Out', 'Diamond Burst', 'VIP Galaxy Explosion']
                            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                            .toList(),
                        onChanged: canEdit ? (val) => setState(() => _closeRoomEffect = val!) : null,
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white10, height: 24),

                  // Kick-out List
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(color: Color(0xFF3D1E2A), shape: BoxShape.circle),
                      child: const Icon(Icons.person_off_rounded, color: Colors.redAccent),
                    ),
                    title: const Text('Kick-out List', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    subtitle: Text('Manage ${_bannedUserIds.length} removed users', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white38, size: 14),
                    onTap: _openKickOutList,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.pinkAccent, size: 18),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleRow(String title, String subtitle, bool value, ValueChanged<bool> onChanged, bool enabled) {
    return SwitchListTile(
      value: value,
      onChanged: enabled ? onChanged : null,
      activeThumbColor: Colors.pinkAccent,
      title: Text(title, style: TextStyle(color: enabled ? Colors.white : Colors.white38, fontSize: 14, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: TextStyle(color: enabled ? Colors.white54 : Colors.white24, fontSize: 11)),
    );
  }
}
