import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../models/user_model.dart';
import '../../providers/messaging_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/user_avatar.dart';
import '../../widgets/chat_bubble.dart';
import '../../widgets/gift_dialog.dart';
import '../../widgets/gift_animation_overlay.dart';
import '../../widgets/report_sheet.dart';
import '../profile/user_profile_details_screen.dart';

class ChatScreen extends StatefulWidget {
  final UserModel user;

  const ChatScreen({super.key, required this.user});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _msgController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final GlobalKey<GiftAnimationOverlayState> _giftOverlayKey = GlobalKey<GiftAnimationOverlayState>();
  final ScrollController _scrollController = ScrollController();
  XFile? _selectedImage;
  bool _hasText = false;
  Timer? _typingDebounce;

  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  String _recordDurationText = "00:00";
  Timer? _recordTimer;
  int _recordSeconds = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MessagingProvider>().loadMessagesForUser(widget.user.id);
    });

    _msgController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final hasText = _msgController.text.trim().isNotEmpty;
    if (_hasText != hasText) {
      setState(() => _hasText = hasText);
    }

    if (hasText) {
      context.read<MessagingProvider>().sendTyping(widget.user.id, true);
      _typingDebounce?.cancel();
      _typingDebounce = Timer(const Duration(milliseconds: 2500), () {
        if (mounted) {
          context.read<MessagingProvider>().sendTyping(widget.user.id, false);
        }
      });
    } else {
      _typingDebounce?.cancel();
      context.read<MessagingProvider>().sendTyping(widget.user.id, false);
    }
  }

  @override
  void dispose() {
    _typingDebounce?.cancel();
    _msgController.dispose();
    _scrollController.dispose();
    _recordTimer?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }

  final List<String> _quickReplies = [
    'Hey! 👋',
    'Love your stream! ❤️',
    'See you on ZeParty tonight! 🚀',
    'Let\'s go! 🔥',
  ];

  Future<void> _pickChatImage(ImageSource source) async {
    try {
      final XFile? picked = await _picker.pickImage(source: source, imageQuality: 80);
      if (picked != null) {
        setState(() {
          _selectedImage = picked;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to select image: $e')),
        );
      }
    }
  }

  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: AppColors.primary),
              title: const Text('Photo Library'),
              onTap: () {
                Navigator.pop(ctx);
                _pickChatImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: AppColors.accent),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(ctx);
                _pickChatImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showGiftDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => GiftDialog(
        streamerName: widget.user.name.isNotEmpty ? widget.user.name : widget.user.username,
        targetReceiver: widget.user,
        onGiftSent: (gift) {
          final currentUser = context.read<AuthProvider>().currentUser;
          _giftOverlayKey.currentState?.playGiftAnimation(gift);
          context.read<MessagingProvider>().sendMessage(
            widget.user.id,
            '🎁 Sent ${gift.name}!',
            type: 'gift',
            mediaUrl: gift.icon,
            currentUserId: currentUser.id,
          );
        },
      ),
    );
  }

  Future<void> _startRecording() async {
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Microphone permission required')));
      }
      return;
    }
    
    if (await _audioRecorder.hasPermission()) {
      final tempDir = await getTemporaryDirectory();
      final path = '${tempDir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _audioRecorder.start(const RecordConfig(), path: path);
      
      setState(() {
        _isRecording = true;
        _recordSeconds = 0;
        _recordDurationText = "00:00";
      });
      
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          _recordSeconds++;
          final min = (_recordSeconds ~/ 60).toString().padLeft(2, '0');
          final sec = (_recordSeconds % 60).toString().padLeft(2, '0');
          _recordDurationText = "$min:$sec";
        });
      });
    }
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) return;
    _recordTimer?.cancel();
    final path = await _audioRecorder.stop();
    final durationText = _recordDurationText;
    setState(() {
      _isRecording = false;
      _recordSeconds = 0;
      _recordDurationText = "00:00";
    });
    
    if (path != null && mounted) {
      final currentUser = context.read<AuthProvider>().currentUser;
      context.read<MessagingProvider>().sendMessage(
        widget.user.id,
        '🎤 Voice Note ($durationText)',
        type: 'voice',
        mediaUrl: path,
        currentUserId: currentUser.id,
      );
    }
  }

  void _toggleRecordingState() {
    if (_isRecording) {
      _stopRecording();
    } else {
      _startRecording();
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = AppColors.getPrimary(isDark);
    final currentUser = context.watch<AuthProvider>().currentUser;
    final messaging = context.watch<MessagingProvider>();
    final messages = messaging.getMessagesForUser(widget.user.id);
    final isTargetTyping = messaging.isUserTyping(widget.user.id);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => UserProfileDetailsScreen(userId: widget.user.id)),
            );
          },
          child: Row(
            children: [
              UserAvatar(imageUrl: widget.user.avatarUrl, radius: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.user.name.isNotEmpty ? widget.user.name : widget.user.username,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (isTargetTyping)
                      const Text(
                        'typing...',
                        style: TextStyle(fontSize: 10, color: Color(0xFF00E5FF), fontWeight: FontWeight.bold),
                      )
                    else if (widget.user.isLive)
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(4)),
                            child: const Text('🔴 LIVE', style: TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 4),
                          const Text('Streaming now', style: TextStyle(fontSize: 10, color: Colors.redAccent)),
                        ],
                      )
                    else
                      const Row(
                        children: [
                          Icon(Icons.circle, color: AppColors.success, size: 8),
                          SizedBox(width: 4),
                          Text('Online • ZeParty', style: TextStyle(fontSize: 10, color: AppColors.success)),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline_rounded, color: Colors.blueAccent),
            tooltip: 'View Profile',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => UserProfileDetailsScreen(userId: widget.user.id)),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.card_giftcard_rounded, color: Colors.amber),
            tooltip: 'Send Gift',
            onPressed: _showGiftDialog,
          ),
          PopupMenuButton<String>(
            onSelected: (val) async {
              if (val == 'View Profile') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => UserProfileDetailsScreen(userId: widget.user.id)),
                );
              } else if (val == 'Block User') {
                try {
                  await context.read<AuthProvider>().blockUser(widget.user.id);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('🚫 ${widget.user.name} has been blocked.')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to block: $e')),
                    );
                  }
                }
              } else if (val == 'Report Account') {
                ReportSheet.show(
                  context,
                  targetTitle: widget.user.name,
                  reportedUserId: widget.user.id,
                );
              } else if (val == 'Clear Chat') {
                messaging.deleteThreadLocally(widget.user.id);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chat cleared locally.')));
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(value: 'View Profile', child: Text('View Full Profile')),
              const PopupMenuItem(value: 'Block User', child: Text('Block User')),
              const PopupMenuItem(value: 'Report Account', child: Text('Report Account')),
              const PopupMenuItem(value: 'Clear Chat', child: Text('Clear Chat')),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Chat Messages Feed
              Expanded(
                child: messaging.isLoadingMessages && messages.isEmpty
                    ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                    : messages.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => UserProfileDetailsScreen(userId: widget.user.id)),
                                    );
                                  },
                                  child: UserAvatar(imageUrl: widget.user.avatarUrl, radius: 36),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  widget.user.name.isNotEmpty ? widget.user.name : widget.user.username,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Say hello and start connecting on ZeParty! 👋',
                                  style: TextStyle(color: AppColors.getTextSecondary(isDark), fontSize: 12),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(12),
                            itemCount: messages.length,
                            itemBuilder: (context, index) {
                              final msg = messages[index];
                              final isMe = msg.senderId == currentUser.id ||
                                  (currentUser.id.isNotEmpty && msg.senderId == currentUser.id) ||
                                  msg.receiverId == widget.user.id;
                              return ChatBubble(message: msg, isMe: isMe);
                            },
                          ),
              ),

              // Real-time Typing Bubble
              if (isTargetTyping)
                Padding(
                  padding: const EdgeInsets.only(left: 16, bottom: 6),
                  child: Row(
                    children: [
                      UserAvatar(imageUrl: widget.user.avatarUrl, radius: 12),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.getCard(isDark),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('typing', style: TextStyle(fontSize: 11, color: Colors.white70, fontStyle: FontStyle.italic)),
                            SizedBox(width: 6),
                            SizedBox(
                              width: 10,
                              height: 10,
                              child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFF00E5FF)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              // Quick Replies Bar
              SizedBox(
                height: 36,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: _quickReplies.length,
                  itemBuilder: (context, index) {
                    final reply = _quickReplies[index];
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        label: Text(reply, style: TextStyle(fontSize: 11, color: primaryColor)),
                        backgroundColor: AppColors.getSurface(isDark),
                        side: BorderSide(color: AppColors.getBorderStrong(isDark), width: 1),
                        onPressed: () {
                          messaging.sendMessage(widget.user.id, reply, currentUserId: currentUser.id);
                          _scrollToBottom();
                        },
                      ),
                    );
                  },
                ),
              ),

              // Image preview before sending
              if (_selectedImage != null)
                Container(
                  padding: const EdgeInsets.all(8),
                  color: AppColors.getCard(Theme.of(context).brightness == Brightness.dark),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: File(_selectedImage!.path).existsSync()
                            ? Image.file(File(_selectedImage!.path), width: 60, height: 60, fit: BoxFit.cover)
                            : const SizedBox(width: 60, height: 60),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _selectedImage!.name,
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: AppColors.error, size: 20),
                        onPressed: () => setState(() => _selectedImage = null),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 4),

              // Input Bar with Gift Button, Camera, Gallery & Mic
              Container(
                padding: const EdgeInsets.only(left: 8, right: 8, bottom: 8, top: 4),
                child: SafeArea(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: _isRecording 
                          ? Container(
                              height: 48,
                              decoration: BoxDecoration(
                                color: AppColors.getCard(Theme.of(context).brightness == Brightness.dark),
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.mic, color: Colors.red),
                                  const SizedBox(width: 8),
                                  Text("Recording... $_recordDurationText", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            )
                          : Container(
                              decoration: BoxDecoration(
                                color: AppColors.getCard(Theme.of(context).brightness == Brightness.dark),
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.card_giftcard_rounded, color: Colors.amber),
                                    onPressed: _showGiftDialog,
                                  ),
                                  Expanded(
                                    child: TextField(
                                      controller: _msgController,
                                      style: Theme.of(context).textTheme.bodyLarge,
                                      minLines: 1,
                                      maxLines: 5,
                                      decoration: const InputDecoration(
                                        hintText: 'Message...',
                                        border: InputBorder.none,
                                        enabledBorder: InputBorder.none,
                                        focusedBorder: InputBorder.none,
                                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.attach_file_rounded, color: Colors.grey),
                                    onPressed: _showImagePickerOptions,
                                  ),
                                  if (!_hasText)
                                    IconButton(
                                      icon: const Icon(Icons.camera_alt_rounded, color: Colors.grey),
                                      onPressed: () => _pickChatImage(ImageSource.camera),
                                    ),
                                ],
                              ),
                            ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        margin: const EdgeInsets.only(bottom: 2),
                        child: GestureDetector(
                          onTap: () {
                            if (_hasText || _selectedImage != null) {
                              final text = _msgController.text.trim();
                              if (text.isNotEmpty) {
                                messaging.sendMessage(widget.user.id, text, currentUserId: currentUser.id);
                                _msgController.clear();
                                _scrollToBottom();
                              }
                              if (_selectedImage != null) {
                                messaging.sendMessage(
                                  widget.user.id,
                                  '📷 Photo',
                                  type: 'image',
                                  mediaUrl: _selectedImage!.path,
                                  currentUserId: currentUser.id,
                                );
                                setState(() => _selectedImage = null);
                                _scrollToBottom();
                              }
                            } else {
                              _toggleRecordingState();
                            }
                          },
                          onLongPressStart: (_) {
                            if (!_hasText && _selectedImage == null && !_isRecording) {
                              _startRecording();
                            }
                          },
                          onLongPressEnd: (_) {
                            if (_isRecording) {
                              _stopRecording();
                            }
                          },
                          child: CircleAvatar(
                            radius: 24,
                            backgroundColor: _isRecording ? Colors.red : const Color(0xFF00A884),
                            child: Icon(
                              (_hasText || _selectedImage != null) ? Icons.send_rounded : Icons.mic_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Onscreen 3D Gift Animation Overlay
          GiftAnimationOverlay(key: _giftOverlayKey),
        ],
      ),
    );
  }
}
