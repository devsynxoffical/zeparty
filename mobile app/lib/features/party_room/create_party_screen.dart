import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/repositories/backend_repository.dart';
import '../../core/repositories/room_repository.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/live_room_model.dart';
import 'live_party_room_screen.dart';

class CreatePartyScreen extends StatefulWidget {
  const CreatePartyScreen({super.key});

  @override
  State<CreatePartyScreen> createState() => _CreatePartyScreenState();
}

class _CreatePartyScreenState extends State<CreatePartyScreen> {
  final _nameController = TextEditingController();
  String _selectedCategory = 'Music';
  String _roomType = 'AUDIO_PARTY';
  int _capacity = 10;
  String _privacy = 'Public';
  String? _selectedCoverUrl;
  bool _isCreating = false;
  
  final List<String> _dummyCovers = [
    'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?auto=format&fit=crop&w=600&q=80',
    'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?auto=format&fit=crop&w=600&q=80',
    'https://images.unsplash.com/photo-1492684223066-81342ee5ff30?auto=format&fit=crop&w=600&q=80',
    'https://images.unsplash.com/photo-1542751371-adc38448a05e?auto=format&fit=crop&w=600&q=80',
  ];
  int _coverIndex = 0;

  Future<void> _createParty() async {
    if (_isCreating) return;
    setState(() => _isCreating = true);

    final currentUser = Provider.of<AuthProvider>(context, listen: false).currentUser;
    final title = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()
        : '${currentUser.name}\'s Party';
    final coverUrl = _selectedCoverUrl ?? (currentUser.avatarUrl.isNotEmpty ? currentUser.avatarUrl : _dummyCovers[0]);

    LiveRoomModel roomToJoin;

    try {
      roomToJoin = await RoomRepository.instance.createRoom(
        title: title,
        coverImageUrl: coverUrl,
        roomType: 'AUDIO_PARTY',
        category: _selectedCategory,
        isPrivate: _privacy != 'Public',
      );
    } catch (e) {
      debugPrint('[CreateParty] Backend createRoom error: $e, using local fallback');
      roomToJoin = LiveRoomModel(
        id: 'party_${DateTime.now().millisecondsSinceEpoch}',
        title: title,
        host: currentUser,
        coverUrl: coverUrl,
        viewerCount: 1,
        category: _selectedCategory,
        isPrivate: _privacy != 'Public',
        startTime: DateTime.now(),
        roomType: 'AUDIO_PARTY',
        seatCapacity: _capacity,
      );
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }

    BackendRepository.instance.addLiveRoom(roomToJoin);

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => LivePartyRoomScreen(room: roomToJoin)),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    return Scaffold(
      backgroundColor: AppColors.getBackground(isDark),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Create Live Party', style: TextStyle(color: AppColors.getTextPrimary(isDark))),
        iconTheme: IconThemeData(color: AppColors.getTextPrimary(isDark)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover Image
            Center(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedCoverUrl = _dummyCovers[_coverIndex % _dummyCovers.length];
                    _coverIndex++;
                  });
                },
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppColors.getCard(isDark),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.getBorder(isDark), width: 2),
                    image: _selectedCoverUrl != null
                        ? DecorationImage(
                            image: NetworkImage(_selectedCoverUrl!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: _selectedCoverUrl == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.add_a_photo, size: 32, color: Colors.grey),
                            const SizedBox(height: 8),
                            Text('Add Cover', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                          ],
                        )
                      : Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            color: Colors.black.withValues(alpha: 0.3),
                          ),
                          child: const Icon(Icons.edit, color: Colors.white, size: 28),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Party Name
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Party Name',
                filled: true,
                fillColor: AppColors.getCard(isDark),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),

            // Category
            DropdownButtonFormField<String>(
              initialValue: _selectedCategory,
              items: ['Music', 'Chat', 'Games', 'PK Battle', 'Entertainment', 'Friends', 'Other']
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (val) => setState(() => _selectedCategory = val!),
              decoration: InputDecoration(
                labelText: 'Category',
                filled: true,
                fillColor: AppColors.getCard(isDark),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),

            // Room Type
            DropdownButtonFormField<String>(
              initialValue: _roomType,
              items: ['Voice Room', 'Video Room']
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (val) => setState(() => _roomType = val!),
              decoration: InputDecoration(
                labelText: 'Room Type',
                filled: true,
                fillColor: AppColors.getCard(isDark),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),

            // Capacity
            DropdownButtonFormField<int>(
              initialValue: _capacity,
              items: [10, 15, 20, 30].map((c) => DropdownMenuItem(value: c, child: Text('$c Seats'))).toList(),
              onChanged: (val) => setState(() => _capacity = val!),
              decoration: InputDecoration(
                labelText: 'Room Seat Capacity',
                filled: true,
                fillColor: AppColors.getCard(isDark),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),

            // Privacy
            DropdownButtonFormField<String>(
              initialValue: _privacy,
              items: ['Public', 'Followers Only', 'Private']
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (val) => setState(() => _privacy = val!),
              decoration: InputDecoration(
                labelText: 'Privacy',
                filled: true,
                fillColor: AppColors.getCard(isDark),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 32),

            // Create Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isCreating ? null : _createParty,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGold,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isCreating
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                    : const Text('Create Party', style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
