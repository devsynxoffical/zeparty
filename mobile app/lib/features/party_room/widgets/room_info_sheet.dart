import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../models/live_room_model.dart';
import '../../../../models/user_model.dart';
import '../../../../models/party_participant_model.dart';
import '../../../../providers/live_party_provider.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/game_provider.dart';
import '../../../../providers/wallet_provider.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/services/room_share_service.dart';
import '../../../../core/services/media_upload_service.dart';
import '../../recharge/recharge_screen.dart';
import '../room_settings_screen.dart';

class RoomInfoSheet extends StatefulWidget {
  final LiveRoomModel room;
  final bool canManage;
  final bool isDark;
  final List<PartyParticipantModel>? participants;

  const RoomInfoSheet({
    super.key,
    required this.room,
    required this.canManage,
    required this.isDark,
    this.participants,
  });

  @override
  State<RoomInfoSheet> createState() => _RoomInfoSheetState();
}

class _RoomInfoSheetState extends State<RoomInfoSheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late String _currentTitle;
  late String _currentCoverUrl;
  String _memberSearchQuery = '';
  final TextEditingController _memberSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _currentTitle = widget.room.title;
    _currentCoverUrl = widget.room.coverUrl;
  }

  @override
  void didUpdateWidget(covariant RoomInfoSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.room.title != oldWidget.room.title) {
      _currentTitle = widget.room.title;
    }
    if (widget.room.coverUrl != oldWidget.room.coverUrl) {
      _currentCoverUrl = widget.room.coverUrl;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _memberSearchController.dispose();
    super.dispose();
  }

  void _copyRoomId() {
    Clipboard.setData(ClipboardData(text: widget.room.id));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Room ID copied to clipboard'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _onChangeCoverPhoto() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1B2E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white30, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              const Text('Change Room Cover', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Builder(
                builder: (cCtx) {
                  final gameP = cCtx.watch<GameProvider>();
                  final authP = cCtx.read<AuthProvider>();
                  final userCountry = authP.currentUser.region.isNotEmpty ? authP.currentUser.region : 'Global';
                  final price = gameP.getCustomRoomThemeUploadPrice(userCountry);
                  final isPaid = price > 0;
                  final labelText = isPaid
                      ? 'Choose from Gallery • ${AppFormatters.formatNumber(price)} Coins'
                      : 'Choose from Gallery';

                  return ListTile(
                    leading: const Icon(Icons.photo_library_rounded, color: Colors.pinkAccent),
                    title: Text(labelText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    onTap: () async {
                      Navigator.pop(ctx);
                      final authUser = context.read<AuthProvider>().currentUser;
                      final isHost = widget.room.host.id == authUser.id;
                      final isAdmin = authUser.role == UserRole.admin || authUser.id == 'admin';
                      final isAuthorized = widget.canManage || isHost || isAdmin;

                      if (!isAuthorized) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("You don't have permission to change this room.")),
                        );
                        return;
                      }
                      final gameProv = context.read<GameProvider>();
                      final walletProv = context.read<WalletProvider>();
                      final authProv = context.read<AuthProvider>();
                      final currentCountry = authProv.currentUser.region.isNotEmpty ? authProv.currentUser.region : 'Global';
                      final currentPrice = gameProv.getCustomRoomThemeUploadPrice(currentCountry);

                      if (currentPrice > 0) {
                        // 1. Confirmation Popup
                        final bool? confirmed = await showDialog<bool>(
                          context: context,
                          builder: (c) => AlertDialog(
                            backgroundColor: const Color(0xFF1E1B2E),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            title: const Text(
                              'Custom Room DP Upload',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                            ),
                            content: Text(
                              'Cost: ${AppFormatters.formatNumber(currentPrice)} Coins\n\nDo you want to proceed with uploading a custom Room DP?',
                              style: const TextStyle(color: Colors.white70, fontSize: 14),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(c, false),
                                child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(c, true),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.pinkAccent),
                                child: const Text('Confirm', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        );

                        if (confirmed != true) return;

                        // 2. Wallet Balance Check
                        if (walletProv.coins < currentPrice) {
                          if (mounted) {
                            showDialog(
                              context: context,
                              builder: (c) => AlertDialog(
                                backgroundColor: const Color(0xFF1E1B2E),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                title: const Text(
                                  'Insufficient Coins',
                                  style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 18),
                                ),
                                content: Text(
                                  'Required: ${AppFormatters.formatNumber(currentPrice)} Coins\nYour Balance: ${AppFormatters.formatNumber(walletProv.coins)} Coins',
                                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(c),
                                    child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                                  ),
                                  ElevatedButton(
                                    onPressed: () {
                                      Navigator.pop(c);
                                      Navigator.push(context, MaterialPageRoute(builder: (_) => const RechargeScreen()));
                                    },
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
                                    child: const Text('Recharge', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            );
                          }
                          return;
                        }

                        // 3. Process Payment safely
                        final payment = await gameProv.processRoomThemePayment(
                          walletProvider: walletProv,
                          userId: authProv.currentUser.id,
                          roomId: widget.room.id,
                          uploadType: 'Room DP',
                          userCountry: currentCountry,
                        );

                        if (payment['success'] != true) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Payment could not be completed. No coins were deducted.')),
                            );
                          }
                          return;
                        }

                        final String txId = payment['transactionId'] as String;

                        // 4. Open Image Picker
                        try {
                          final picker = ImagePicker();
                          final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
                          if (picked != null) {
                            String publicUrl = picked.path;
                            try {
                              final uploadRes = await MediaUploadService.instance.uploadFile(
                                filePath: picked.path,
                                folder: 'banners',
                              );
                              if (uploadRes.url.isNotEmpty) {
                                publicUrl = uploadRes.url;
                              }
                            } catch (uploadErr) {
                              debugPrint('[RoomInfoSheet] Upload error: $uploadErr');
                            }

                            setState(() {
                              _currentCoverUrl = publicUrl;
                            });
                            gameProv.completeRoomThemeUpload(txId);
                            if (mounted) {
                              Provider.of<LivePartyProvider>(context, listen: false).updateRoomDetails(coverUrl: publicUrl);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('✨ Room cover updated successfully!'),
                                  backgroundColor: Colors.pinkAccent,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          } else {
                            // User cancelled image selection -> Automatic refund!
                            await gameProv.refundRoomThemePayment(
                              walletProvider: walletProv,
                              transactionId: txId,
                              reason: 'Room DP gallery picker cancelled',
                            );
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Upload cancelled. Your ${AppFormatters.formatNumber(currentPrice)} Coins have been refunded.'),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                            }
                          }
                        } catch (e) {
                          // Upload failure -> Automatic refund!
                          await gameProv.refundRoomThemePayment(
                            walletProvider: walletProv,
                            transactionId: txId,
                            reason: 'Room DP upload error: $e',
                          );
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Upload failed. Your ${AppFormatters.formatNumber(currentPrice)} Coins have been refunded.')),
                            );
                          }
                        }
                      } else {
                        // Free upload
                        try {
                          final picker = ImagePicker();
                          final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
                          if (picked != null) {
                            setState(() {
                              _currentCoverUrl = picked.path;
                            });
                            if (mounted) {
                              Provider.of<LivePartyProvider>(context, listen: false).updateRoomDetails(coverUrl: picked.path);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('✨ Room cover updated successfully!'),
                                  backgroundColor: Colors.pinkAccent,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error selecting cover image: $e')),
                            );
                          }
                        }
                      }
                    },
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded, color: Colors.purpleAccent),
                title: const Text('Take Photo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    final picker = ImagePicker();
                    final picked = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
                    if (picked != null) {
                      setState(() {
                        _currentCoverUrl = picked.path;
                      });
                      if (mounted) {
                        Provider.of<LivePartyProvider>(context, listen: false).updateRoomDetails(coverUrl: picked.path);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('✨ Room cover updated successfully!'),
                            backgroundColor: Colors.pinkAccent,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error taking photo: $e')),
                      );
                    }
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.auto_awesome_rounded, color: Colors.amber),
                title: const Text('Choose Curated Room Avatar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showPresetAvatarsDialog();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPresetAvatarsDialog() {
    final presets = [
      'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=300',
      'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=300',
      'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=300',
      'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=300',
      'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=300',
      'https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?w=300',
    ];

    showDialog(
      context: context,
      builder: (pCtx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1B2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Select Preset Room Cover', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: double.maxFinite,
          child: GridView.builder(
            shrinkWrap: true,
            physics: const BouncingScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: presets.length,
            itemBuilder: (context, idx) {
              final url = presets[idx];
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _currentCoverUrl = url;
                  });
                  Provider.of<LivePartyProvider>(context, listen: false).updateRoomDetails(coverUrl: url);
                  Navigator.pop(pCtx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✨ Room cover updated!'),
                      backgroundColor: Colors.pinkAccent,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(url, fit: BoxFit.cover),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _onEditRoomName() {
    final nameController = TextEditingController(text: _currentTitle);

    showDialog(
      context: context,
      builder: (eCtx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1B2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Edit Room Name', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter a catchy title for your room:', style: TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 10),
            TextField(
              controller: nameController,
              autofocus: true,
              maxLength: 35,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Room Name',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.08),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                counterStyle: const TextStyle(color: Colors.white38, fontSize: 10),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(eCtx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.getPrimary(widget.isDark),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              final newName = nameController.text.trim();
              if (newName.isNotEmpty) {
                setState(() {
                  _currentTitle = newName;
                });
                Provider.of<LivePartyProvider>(context, listen: false).updateRoomDetails(title: newName);
                Navigator.pop(eCtx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('✨ Room name updated to "$newName"!'),
                    backgroundColor: Colors.purpleAccent,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('Save Changes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildCoverImage(Color primaryColor) {
    if (_currentCoverUrl.startsWith('http')) {
      return Image.network(
        _currentCoverUrl,
        width: 90,
        height: 90,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _coverFallback(primaryColor),
      );
    } else if (_currentCoverUrl.startsWith('assets')) {
      return Image.asset(
        _currentCoverUrl,
        width: 90,
        height: 90,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _coverFallback(primaryColor),
      );
    } else {
      final file = File(_currentCoverUrl);
      if (file.existsSync()) {
        return Image.file(
          file,
          width: 90,
          height: 90,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _coverFallback(primaryColor),
        );
      }
      return _coverFallback(primaryColor);
    }
  }

  Widget _coverFallback(Color primaryColor) {
    return Container(
      width: 90,
      height: 90,
      color: primaryColor.withValues(alpha: 0.2),
      child: Icon(Icons.music_note, color: primaryColor, size: 40),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textColor = AppColors.getTextPrimary(widget.isDark);
    final secondaryColor = AppColors.getTextSecondary(widget.isDark);
    final primaryColor = AppColors.getPrimary(widget.isDark);
    final cardColor = AppColors.getCard(widget.isDark);

    return Container(
      decoration: BoxDecoration(
        color: widget.isDark ? AppColors.getCard(true) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.70,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 5,
            decoration: BoxDecoration(
              color: secondaryColor.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(width: 24),
                Text(
                  'Room Information',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                    letterSpacing: 0.5,
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: secondaryColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.close_rounded, color: secondaryColor, size: 20),
                  ),
                ),
              ],
            ),
          ),
          
          // Tabs
          TabBar(
            controller: _tabController,
            indicatorColor: primaryColor,
            labelColor: textColor,
            unselectedLabelColor: secondaryColor,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            tabs: const [
              Tab(text: 'Profile'),
              Tab(text: 'Member'),
            ],
          ),
          
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildProfileTab(textColor, secondaryColor, primaryColor, cardColor),
                _buildMemberTab(textColor, secondaryColor),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileTab(Color textColor, Color secondaryColor, Color primaryColor, Color cardColor) {
    final memberCount = widget.participants?.length ?? 1;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Cover & Icons
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              GestureDetector(
                onTap: widget.canManage ? _onChangeCoverPhoto : null,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withValues(alpha: 0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: _buildCoverImage(primaryColor),
                  ),
                ),
              ),
              if (widget.canManage)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: _onChangeCoverPhoto,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: primaryColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.getCard(widget.isDark), width: 2),
                      ),
                      child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 14),
                    ),
                  ),
                ),
              Positioned(
                right: -45,
                top: 5,
                child: Column(
                  children: [
                    if (widget.canManage)
                      _buildActionIcon(Icons.settings_outlined, secondaryColor, () async {
                        final updated = await Navigator.push<LiveRoomModel>(
                          context,
                          MaterialPageRoute(builder: (_) => RoomSettingsScreen(room: widget.room)),
                        );
                        if (updated != null && mounted) {
                          setState(() {
                            _currentTitle = updated.title;
                            _currentCoverUrl = updated.coverUrl;
                          });
                        }
                      }),
                    if (widget.canManage) const SizedBox(height: 12),
                    _buildActionIcon(Icons.star_border_rounded, secondaryColor, () {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Added to Favorites')));
                    }),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Room Name
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  _currentTitle,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                    letterSpacing: 0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.diamond_outlined, color: primaryColor, size: 18),
              if (widget.canManage) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _onEditRoomName,
                  child: Icon(Icons.edit_rounded, color: secondaryColor, size: 16),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          
          // Room ID
          GestureDetector(
            onTap: _copyRoomId,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Room ID: ${widget.room.id.length > 8 ? widget.room.id.substring(0, 8) : widget.room.id}',
                  style: TextStyle(fontSize: 13, color: secondaryColor, fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 4),
                Icon(Icons.copy_rounded, color: secondaryColor, size: 13),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Details List wrapped in a neat card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: primaryColor.withValues(alpha: 0.1)),
            ),
            child: Column(
              children: [
                _buildDetailRow('Country', 'Pakistan', textColor, secondaryColor),
                const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(height: 1, thickness: 0.5)),
                _buildLevelRow(textColor, secondaryColor, primaryColor),
                const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(height: 1, thickness: 0.5)),
                _buildDetailRow('Member', '$memberCount/200', textColor, secondaryColor, highlightValue: '$memberCount', highlightColor: primaryColor),
                const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(height: 1, thickness: 0.5)),
                _buildDetailRow('Room mode', widget.room.roomMode.isNotEmpty ? widget.room.roomMode : 'Friend mode', textColor, secondaryColor, showArrow: widget.canManage),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Share Section
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryColor.withValues(alpha: 0.1), Colors.transparent],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    'Share & Win Coins!',
                    style: TextStyle(color: textColor, fontWeight: FontWeight.w800, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('3 Chances', style: TextStyle(color: primaryColor, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildShareAction(Icons.phone_android, 'Feedback', textColor, secondaryColor),
              _buildShareAction(Icons.chat_bubble_outline_rounded, 'Message', textColor, secondaryColor),
              _buildShareAction(Icons.save_alt_rounded, 'Save', textColor, secondaryColor),
              _buildShareNetworkGroup(),
            ],
          ),
          const SizedBox(height: 24),

          // CR 36 Side-by-Side Follow & Join Bottom Actions
          _buildFollowAndJoinSection(textColor, primaryColor),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildActionIcon(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 24),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, Color textColor, Color secondaryColor, {String? highlightValue, Color? highlightColor, bool showArrow = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: secondaryColor,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        Row(
          children: [
            if (highlightValue != null && highlightColor != null) ...[
              Text(
                highlightValue,
                style: TextStyle(
                  color: highlightColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                value.replaceAll(highlightValue, ''),
                style: TextStyle(
                  color: textColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ] else ...[
              Text(
                value,
                style: TextStyle(
                  color: textColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            if (showArrow) ...[
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, color: secondaryColor, size: 16),
            ]
          ],
        ),
      ],
    );
  }

  Widget _buildLevelRow(Color textColor, Color secondaryColor, Color primaryColor) {
    return Row(
      children: [
        Text(
          'Level',
          style: TextStyle(
            color: secondaryColor,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 16),
        Text(
          'LV.8',
          style: TextStyle(
            color: primaryColor,
            fontSize: 14,
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: 0.54,
                  minHeight: 4,
                  backgroundColor: secondaryColor.withValues(alpha: 0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '5422/10k',
                style: TextStyle(color: secondaryColor, fontSize: 9, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'LV.9',
          style: TextStyle(
            color: secondaryColor.withValues(alpha: 0.4),
            fontSize: 14,
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _buildShareAction(IconData icon, String label, Color textColor, Color secondaryColor) {
    return GestureDetector(
      onTap: () => RoomShareService.shareRoom(context, roomId: widget.room.id, roomTitle: widget.room.title),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: secondaryColor.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: textColor, size: 22),
          ),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(color: textColor, fontSize: 10, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildShareNetworkGroup() {
    return GestureDetector(
      onTap: () => RoomShareService.shareRoom(context, roomId: widget.room.id, roomTitle: widget.room.title),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Row(
                children: [
                  _buildSocialIcon(Colors.blue, Icons.facebook),
                  _buildSocialIcon(Colors.green, Icons.wechat),
                  _buildSocialIcon(Colors.pink, Icons.camera_alt),
                ],
              ),
              Positioned(
                top: -12,
                right: -10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.amber,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.monetization_on, color: Colors.white, size: 12),
                      SizedBox(width: 2),
                      Text('X100', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('Click to Share', style: TextStyle(color: Colors.redAccent.withValues(alpha: 0.8), fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildSocialIcon(Color color, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: Colors.white, size: 16),
    );
  }

  Widget _buildMemberTab(Color textColor, Color secondaryColor) {
    final livePartyProv = Provider.of<LivePartyProvider>(context);
    final authProv = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = authProv.currentUser;

    final roomHostId = widget.room.host.id;
    final isOwner = currentUser.id == roomHostId || widget.room.creatorUserId == currentUser.id;

    // Check if viewer is an admin
    final isViewerAdmin = livePartyProv.participants.any(
      (p) => p.user.id == currentUser.id && p.role == ParticipantRole.moderator,
    );
    final canManageRoles = isOwner || isViewerAdmin;

    final allMembers = livePartyProv.participants.isNotEmpty
        ? livePartyProv.participants
        : (widget.participants ?? []);

    final filteredMembers = allMembers.where((p) {
      if (_memberSearchQuery.trim().isEmpty) return true;
      final q = _memberSearchQuery.trim().toLowerCase();
      final name = p.user.name.toLowerCase();
      final username = p.user.username.toLowerCase();
      final userId = p.user.id.toLowerCase();
      return name.contains(q) || username.contains(q) || userId.contains(q);
    }).toList();

    return Column(
      children: [
        // Search & Counter Header Bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Member: ${allMembers.length}',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Icon(Icons.info_outline, color: secondaryColor, size: 16),
                ],
              ),
              const SizedBox(height: 8),
              // Search Field matching reference
              Container(
                decoration: BoxDecoration(
                  color: widget.isDark ? const Color(0xFF252136) : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: AppColors.getPrimary(widget.isDark).withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 12),
                    Icon(Icons.search_rounded, color: secondaryColor, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _memberSearchController,
                        style: TextStyle(color: textColor, fontSize: 14),
                        onChanged: (val) {
                          setState(() {
                            _memberSearchQuery = val;
                          });
                        },
                        decoration: InputDecoration(
                          hintText: 'User ID',
                          hintStyle: TextStyle(color: secondaryColor.withValues(alpha: 0.6), fontSize: 14),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                    if (_memberSearchQuery.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          _memberSearchController.clear();
                          setState(() {
                            _memberSearchQuery = '';
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Icon(Icons.clear_rounded, color: secondaryColor, size: 18),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: TextButton(
                        onPressed: () {
                          FocusScope.of(context).unfocus();
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Search',
                          style: TextStyle(
                            color: Color(0xFFB524E4),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // List of Members
        Expanded(
          child: filteredMembers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off_rounded, color: secondaryColor.withValues(alpha: 0.5), size: 48),
                      const SizedBox(height: 8),
                      Text(
                        'No room members match your search.',
                        style: TextStyle(color: secondaryColor, fontSize: 13),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: filteredMembers.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, thickness: 0.3, color: Colors.white10),
                  itemBuilder: (context, index) {
                    final participant = filteredMembers[index];
                    final targetUser = participant.user;

                    final isTargetHost = targetUser.id == roomHostId || participant.role == ParticipantRole.host;
                    final isTargetAdmin = participant.role == ParticipantRole.moderator;

                    String roleLabel = 'Member';
                    Color roleColor = secondaryColor;
                    if (isTargetHost) {
                      roleLabel = 'Host';
                      roleColor = Colors.amber;
                    } else if (isTargetAdmin) {
                      roleLabel = 'Admin';
                      roleColor = Colors.cyanAccent;
                    }

                    final canPerformAction = canManageRoles &&
                        !isTargetHost &&
                        targetUser.id != currentUser.id &&
                        (isOwner || (!isTargetAdmin));

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      leading: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: AppColors.getPrimary(widget.isDark).withValues(alpha: 0.2),
                            backgroundImage: targetUser.avatarUrl.isNotEmpty ? NetworkImage(targetUser.avatarUrl) : null,
                            child: targetUser.avatarUrl.isEmpty
                                ? Text(
                                    targetUser.name.isNotEmpty ? targetUser.name[0].toUpperCase() : 'U',
                                    style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                                  )
                                : null,
                          ),
                          if (isTargetHost)
                            const Positioned(
                              top: -4,
                              right: -4,
                              child: Text('👑', style: TextStyle(fontSize: 12)),
                            )
                          else if (isTargetAdmin)
                            const Positioned(
                              top: -4,
                              right: -4,
                              child: Text('🛡️', style: TextStyle(fontSize: 12)),
                            ),
                        ],
                      ),
                      title: Row(
                        children: [
                          Flexible(
                            child: Text(
                              targetUser.name.isNotEmpty ? targetUser.name : targetUser.username,
                              style: TextStyle(
                                color: textColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Role Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: roleColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: roleColor.withValues(alpha: 0.4), width: 0.5),
                            ),
                            child: Text(
                              roleLabel,
                              style: TextStyle(
                                color: roleColor,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      subtitle: Row(
                        children: [
                          Flexible(
                            child: Text(
                              'ID: ${targetUser.id.length > 8 ? targetUser.id.substring(0, 8) : targetUser.id}',
                              style: TextStyle(color: secondaryColor, fontSize: 11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(width: 3, height: 3, decoration: BoxDecoration(color: secondaryColor, shape: BoxShape.circle)),
                          const SizedBox(width: 8),
                          Text(
                            'active today',
                            style: TextStyle(color: secondaryColor, fontSize: 11),
                          ),
                        ],
                      ),
                      trailing: canPerformAction
                          ? PopupMenuButton<String>(
                              icon: Icon(Icons.more_vert_rounded, color: secondaryColor, size: 20),
                              color: const Color(0xFF1E1B2E),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              onSelected: (action) async {
                                if (action == 'appoint_admin') {
                                  _showAdminRoleConfirmDialog(context, livePartyProv, targetUser, 'ADMIN');
                                } else if (action == 'remove_admin') {
                                  _showAdminRoleConfirmDialog(context, livePartyProv, targetUser, 'MEMBER');
                                } else if (action == 'kick') {
                                  _showKickConfirmDialog(context, livePartyProv, targetUser);
                                }
                              },
                              itemBuilder: (ctx) => [
                                if (!isTargetAdmin)
                                  const PopupMenuItem(
                                    value: 'appoint_admin',
                                    child: Row(
                                      children: [
                                        Icon(Icons.shield_outlined, color: Colors.cyanAccent, size: 18),
                                        SizedBox(width: 10),
                                        Text('Appoint as Admin', style: TextStyle(color: Colors.white, fontSize: 13)),
                                      ],
                                    ),
                                  )
                                else
                                  const PopupMenuItem(
                                    value: 'remove_admin',
                                    child: Row(
                                      children: [
                                        Icon(Icons.remove_moderator_outlined, color: Colors.amber, size: 18),
                                        SizedBox(width: 10),
                                        Text('Remove Admin Role', style: TextStyle(color: Colors.white, fontSize: 13)),
                                      ],
                                    ),
                                  ),
                                const PopupMenuItem(
                                  value: 'kick',
                                  child: Row(
                                    children: [
                                      Icon(Icons.person_remove_rounded, color: Colors.redAccent, size: 18),
                                      SizedBox(width: 10),
                                      Text('Remove from Room', style: TextStyle(color: Colors.redAccent, fontSize: 13)),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          : null,
                    );
                  },
                ),
        ),

        // Leave / Unjoin Room Button Footer
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: widget.isDark ? const Color(0xFF191627) : const Color(0xFFF9FAFB),
            border: Border(top: BorderSide(color: secondaryColor.withValues(alpha: 0.1))),
          ),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent.withValues(alpha: 0.15),
                foregroundColor: Colors.redAccent,
                elevation: 0,
                side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.4)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              icon: const Icon(Icons.exit_to_app_rounded, size: 20),
              label: const Text(
                'Leave / Unjoin Room',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              onPressed: () => _showUnjoinConfirmDialog(context, livePartyProv),
            ),
          ),
        ),
      ],
    );
  }

  void _showAdminRoleConfirmDialog(BuildContext context, LivePartyProvider provider, UserModel targetUser, String newRole) {
    final isAppoint = newRole == 'ADMIN';
    showDialog(
      context: context,
      builder: (d) => AlertDialog(
        backgroundColor: const Color(0xFF1E1B2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          isAppoint ? 'Appoint Room Admin' : 'Remove Admin Role',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          isAppoint
              ? 'Are you sure you want to appoint ${targetUser.name} as a Room Admin?'
              : 'Are you sure you want to remove the Admin role from ${targetUser.name}?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isAppoint ? Colors.cyan : Colors.amber,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Navigator.pop(d);
              try {
                await provider.updateMemberRoleOnBackend(targetUser.id, newRole);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isAppoint ? '✨ Appointed ${targetUser.name} as Admin!' : 'ℹ️ Removed Admin role from ${targetUser.name}'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to update role: $e'), backgroundColor: Colors.redAccent),
                  );
                }
              }
            },
            child: Text(isAppoint ? 'Appoint' : 'Remove Role', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showKickConfirmDialog(BuildContext context, LivePartyProvider provider, UserModel targetUser) {
    showDialog(
      context: context,
      builder: (d) => AlertDialog(
        backgroundColor: const Color(0xFF1E1B2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Remove from Room', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to remove ${targetUser.name} from this party room?', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel', style: TextStyle(color: Colors.white60))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () {
              Navigator.pop(d);
              provider.removeParticipant(targetUser.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('🚫 Removed ${targetUser.name} from room.')),
                );
              }
            },
            child: const Text('Remove User'),
          ),
        ],
      ),
    );
  }

  void _showUnjoinConfirmDialog(BuildContext context, LivePartyProvider provider) {
    showDialog(
      context: context,
      builder: (d) => AlertDialog(
        backgroundColor: const Color(0xFF1E1B2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Unjoin Party Room?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
          'Leaving will remove your membership from this room and release any occupied mic seat.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('Stay', style: TextStyle(color: Colors.white60))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () async {
              Navigator.pop(d);
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              }
              await provider.unjoinCurrentRoom();
            },
            child: const Text('Leave Room'),
          ),
        ],
      ),
    );
  }

  // CR 36 Side-by-Side Follow & Join Action Bar
  Widget _buildFollowAndJoinSection(Color textColor, Color primaryColor) {
    final authProv = Provider.of<AuthProvider>(context);
    final walletProv = Provider.of<WalletProvider>(context);
    final currentUser = authProv.currentUser;
    final isOwner = widget.canManage || currentUser.id == widget.room.host.id;

    if (isOwner) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.stars_rounded, color: Colors.amber, size: 20),
            SizedBox(width: 8),
            Text('Room Owner', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
      );
    }

    final isFollowing = authProv.isFollowing(widget.room.host.id);
    final fee = widget.room.membershipFee;
    final isJoined = widget.participants?.any((p) => p.user.id == currentUser.id) ?? false;

    return Row(
      children: [
        // Follow / Following Button (Left Side)
        Expanded(
          child: GestureDetector(
            onTap: () {
              authProv.toggleFollow(widget.room.host.id);
              final newStatus = authProv.isFollowing(widget.room.host.id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(newStatus ? '💖 Following ${widget.room.host.name}!' : 'Unfollowed ${widget.room.host.name}.'),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isFollowing
                      ? [const Color(0xFF4A4458), const Color(0xFF332D42)]
                      : [const Color(0xFFFF4081), const Color(0xFFE91E63)],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: isFollowing
                    ? []
                    : [BoxShadow(color: Colors.pinkAccent.withValues(alpha: 0.4), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isFollowing ? Icons.check_rounded : Icons.favorite_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isFollowing ? 'Following' : 'Follow',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),

        // Join / Joined Button (Right Side)
        Expanded(
          child: GestureDetector(
            onTap: () async {
              if (isJoined) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('✓ You are already a member of this party room.')),
                );
                return;
              }

              if (fee > 0) {
                // Paid Membership Join Confirmation Flow
                final confirmJoin = await showDialog<bool>(
                  context: context,
                  builder: (d) => AlertDialog(
                    backgroundColor: const Color(0xFF1E1B2E),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    title: const Text('Join Room Membership', style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Membership Fee: $fee Coins', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 8),
                        Text('Your Coin Balance: ${walletProv.coins} Coins', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                        const SizedBox(height: 12),
                        const Text(
                          'Joining gives you full access to member chat, mic priority, and exclusive room perks.',
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black),
                        onPressed: () => Navigator.pop(d, true),
                        child: const Text('Confirm & Pay', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                );

                if (confirmJoin != true) return;

                if (walletProv.coins < fee) {
                  if (mounted) {
                    showDialog(
                      context: context,
                      builder: (d) => AlertDialog(
                        backgroundColor: const Color(0xFF1E1B2E),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        title: const Text('Insufficient Coins', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                        content: Text('Required: $fee Coins\nYour Balance: ${walletProv.coins} Coins'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
                            onPressed: () {
                              Navigator.pop(d);
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const RechargeScreen()));
                            },
                            child: const Text('Recharge Now', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    );
                  }
                  return;
                }

                // Deduct fee exactly once
                walletProv.spendCoins(fee);
              }

              // Update room membership state
              if (mounted) {
                final partyProv = Provider.of<LivePartyProvider>(context, listen: false);
                partyProv.joinParty(widget.room, currentUser);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(fee > 0 ? '🎉 Paid $fee coins & joined room membership!' : '🎉 Joined party room!'),
                    backgroundColor: Colors.cyan,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                setState(() {});
              }
            },
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isJoined
                      ? [const Color(0xFF00B0FF), const Color(0xFF00838F)]
                      : [const Color(0xFF00E5FF), const Color(0xFF00B0FF)],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(color: Colors.cyanAccent.withValues(alpha: 0.4), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      isJoined
                          ? 'Joined'
                          : (fee > 0 ? 'Join ($fee 🪙)' : 'Join'),
                      style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
