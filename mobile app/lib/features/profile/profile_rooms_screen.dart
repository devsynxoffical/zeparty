import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/repositories/room_repository.dart';
import '../../core/theme/app_colors.dart';
import '../../models/live_room_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../party_room/live_party_room_screen.dart';

class ProfileRoomsScreen extends StatefulWidget {
  final UserModel user;
  const ProfileRoomsScreen({super.key, required this.user});

  @override
  State<ProfileRoomsScreen> createState() => _ProfileRoomsScreenState();
}

class _ProfileRoomsScreenState extends State<ProfileRoomsScreen> {
  final ScrollController _scrollController = ScrollController();
  List<LiveRoomModel> _joinedRooms = [];
  int _totalJoinedRooms = 0;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = false;
  int _page = 1;
  String? _errorMessage;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadJoinedRooms(isRefresh: true);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoading && !_isLoadingMore && _hasMore) {
        _loadJoinedRooms(isRefresh: false);
      }
    }
  }

  Future<void> _loadJoinedRooms({bool isRefresh = false}) async {
    final currentRequestId = ++_requestId;
    if (isRefresh) {
      _page = 1;
      _hasMore = false;
    }

    setState(() {
      if (isRefresh) {
        _isLoading = _joinedRooms.isEmpty;
      } else {
        _isLoadingMore = true;
      }
      _errorMessage = null;
    });

    try {
      final res = await RoomRepository.instance.getJoinedRooms(
        userId: widget.user.effectivePublicId,
        page: _page,
        limit: 20,
      );

      if (_requestId != currentRequestId || !mounted) return;

      final rawList = res['data'] ?? res['rooms'] ?? [];
      final List<LiveRoomModel> loaded = [];

      if (rawList is List) {
        for (final item in rawList) {
          if (item is Map<String, dynamic>) {
            loaded.add(LiveRoomModel.fromJson(item));
          }
        }
      }

      final pagination = res['pagination'] as Map<String, dynamic>?;
      final total = pagination?['total'] ?? res['total'] ?? (loaded.length + (isRefresh ? 0 : _joinedRooms.length));
      final totalParsed = total is int ? total : (int.tryParse(total.toString()) ?? loaded.length);

      setState(() {
        if (isRefresh || _page == 1) {
          _joinedRooms = loaded;
        } else {
          _joinedRooms.addAll(loaded);
        }
        _totalJoinedRooms = totalParsed;
        _isLoading = false;
        _isLoadingMore = false;
        _hasMore = loaded.length >= 20;
        if (_hasMore) _page++;
      });
    } catch (e) {
      if (_requestId != currentRequestId || !mounted) return;
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
        _errorMessage = 'Failed to load joined rooms. Please try again.';
      });
    }
  }

  Future<void> _unjoinRoom(LiveRoomModel room) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unjoin Room'),
        content: Text('Are you sure you want to unjoin "${room.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Unjoin', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      final success = await RoomRepository.instance.unjoinRoom(room.id);
      if (success) {
        if (mounted) {
          setState(() {
            _joinedRooms.removeWhere((r) => r.id == room.id);
            if (_totalJoinedRooms > 0) _totalJoinedRooms--;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Unjoined "${room.title}" successfully')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to unjoin room. Please try again.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error unjoining room: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppColors.getPrimary(isDark);
    final auth = context.watch<AuthProvider>();
    final isMe = auth.currentUser.id == widget.user.id ||
        (auth.currentUser.publicUserId.isNotEmpty && auth.currentUser.publicUserId == widget.user.publicUserId);

    final displayTotal = _totalJoinedRooms > 0 ? _totalJoinedRooms : _joinedRooms.length;

    return Scaffold(
      backgroundColor: AppColors.getBackground(isDark),
      appBar: AppBar(
        title: Text(
          isMe ? 'My Joined Rooms ($displayTotal)' : 'Joined Rooms ($displayTotal)',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.getBackground(isDark),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => _loadJoinedRooms(isRefresh: true),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
            )
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.wifi_off_rounded, size: 52, color: AppColors.getTextSecondary(isDark)),
                        const SizedBox(height: 12),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.getTextSecondary(isDark), fontSize: 14),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => _loadJoinedRooms(isRefresh: true),
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('Try Again'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : _joinedRooms.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.meeting_room_rounded, size: 56, color: AppColors.getTextSecondary(isDark)),
                            const SizedBox(height: 12),
                            Text(
                              'No joined rooms yet',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: AppColors.getTextPrimary(isDark),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              isMe
                                  ? 'Rooms you join will appear here even after leaving live sessions'
                                  : 'This user hasn\'t joined any rooms yet',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.getTextSecondary(isDark),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () => _loadJoinedRooms(isRefresh: true),
                      color: AppColors.primary,
                      child: ListView.separated(
                        controller: _scrollController,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        itemCount: _joinedRooms.length + (_isLoadingMore ? 1 : 0),
                        separatorBuilder: (context, index) => const SizedBox(height: 12),
                        itemBuilder: (context, idx) {
                          if (idx == _joinedRooms.length) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
                              ),
                            );
                          }

                          final room = _joinedRooms[idx];
                          return _buildRoomCard(context, room, isDark, primary, isMe);
                        },
                      ),
                    ),
    );
  }

  Widget _buildRoomCard(
    BuildContext context,
    LiveRoomModel room,
    bool isDark,
    Color primary,
    bool isMe,
  ) {
    final isLive = room.isLive;

    return InkWell(
      onTap: () {
        if (isLive) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => LivePartyRoomScreen(room: room)),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('"${room.title}" is currently offline. You will be notified when live.'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.getCard(isDark),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isLive ? Colors.greenAccent.withValues(alpha: 0.3) : AppColors.getBorder(isDark),
          ),
          boxShadow: isLive
              ? [
                  BoxShadow(
                    color: Colors.greenAccent.withValues(alpha: 0.08),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    room.coverUrl,
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 64,
                      height: 64,
                      color: Colors.purple.shade900,
                      child: const Icon(Icons.music_note_rounded, color: Colors.amberAccent),
                    ),
                  ),
                ),
                Positioned(
                  top: 4,
                  left: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: isLive ? Colors.redAccent : Colors.black54,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isLive ? 'LIVE' : 'OFFLINE',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
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
                    room.title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppColors.getTextPrimary(isDark),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.person_rounded, size: 12, color: AppColors.getTextSecondary(isDark)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Host: ${room.host.displayName.isNotEmpty ? room.host.displayName : room.host.name}',
                          style: TextStyle(fontSize: 11, color: AppColors.getTextSecondary(isDark)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (isLive) ...[
                        const Icon(Icons.remove_red_eye_rounded, size: 12, color: Colors.greenAccent),
                        const SizedBox(width: 4),
                        Text(
                          '${room.viewerCount} watching',
                          style: const TextStyle(fontSize: 11, color: Colors.greenAccent, fontWeight: FontWeight.bold),
                        ),
                      ] else ...[
                        Text(
                          'Offline',
                          style: TextStyle(fontSize: 11, color: AppColors.getTextSecondary(isDark)),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (isMe)
              IconButton(
                icon: const Icon(Icons.exit_to_app_rounded, color: Colors.redAccent, size: 20),
                tooltip: 'Unjoin Room',
                onPressed: () => _unjoinRoom(room),
              )
            else
              Icon(Icons.chevron_right_rounded, color: AppColors.getTextSecondary(isDark), size: 20),
          ],
        ),
      ),
    );
  }
}
