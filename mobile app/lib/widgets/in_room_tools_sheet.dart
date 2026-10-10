import 'package:flutter/material.dart';
import '../core/services/api_client.dart';

class InRoomToolsSheet extends StatefulWidget {
  final String roomId;
  const InRoomToolsSheet({super.key, required this.roomId});

  static void show(BuildContext context, {required String roomId}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => InRoomToolsSheet(roomId: roomId),
    );
  }

  @override
  State<InRoomToolsSheet> createState() => _InRoomToolsSheetState();
}

class _InRoomToolsSheetState extends State<InRoomToolsSheet> {
  final TextEditingController _youtubeController = TextEditingController();
  final TextEditingController _luckyBagCoinsController = TextEditingController(text: '1000');
  bool _isProcessing = false;

  @override
  void dispose() {
    _youtubeController.dispose();
    _luckyBagCoinsController.dispose();
    super.dispose();
  }

  Future<void> _controlYouTube(String action) async {
    final url = _youtubeController.text.trim();
    if (action == 'PLAY' && url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid YouTube video URL')),
      );
      return;
    }

    setState(() => _isProcessing = true);
    try {
      final response = await ApiClient.instance.post('/v1/rooms/${widget.roomId}/youtube', data: {
        'videoUrl': url,
        'action': action,
      });

      if (mounted) {
        final msg = response.data?['message']?.toString() ?? 'YouTube player updated';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.purple));
        if (action == 'PLAY') _youtubeController.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('YouTube control notice: $e')));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _launchSuperWheel() async {
    setState(() => _isProcessing = true);
    try {
      final response = await ApiClient.instance.post('/v1/rooms/${widget.roomId}/super-wheel', data: {
        'action': 'LAUNCH',
        'stakeAmount': 100,
      });

      if (mounted) {
        final msg = response.data?['message']?.toString() ?? 'Super Wheel launched in room!';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.amber.shade900));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Super Wheel notice: $e')));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _dropLuckyBag() async {
    final coins = int.tryParse(_luckyBagCoinsController.text.trim()) ?? 1000;
    setState(() => _isProcessing = true);
    try {
      final response = await ApiClient.instance.post('/v1/rooms/${widget.roomId}/lucky-bag', data: {
        'totalCoins': coins,
        'claimersLimit': 10,
      });

      if (mounted) {
        final msg = response.data?['message']?.toString() ?? 'Lucky Red Bag dropped into live room!';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.redAccent));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lucky Bag notice: $e')));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xFF1B162B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white30,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '🎛️ Live Room Interactive Tools',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),

              // 1. YouTube Player Control Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.play_circle_fill_rounded, color: Colors.redAccent, size: 22),
                        SizedBox(width: 8),
                        Text(
                          'YouTube Sync Video Streaming',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _youtubeController,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Paste YouTube Video URL...',
                        hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                        isDense: true,
                        filled: true,
                        fillColor: Colors.black26,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isProcessing ? null : () => _controlYouTube('PLAY'),
                            icon: const Icon(Icons.play_arrow_rounded, size: 18),
                            label: const Text('Play Sync'),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: _isProcessing ? null : () => _controlYouTube('PAUSE'),
                          style: OutlinedButton.styleFrom(foregroundColor: Colors.white70),
                          child: const Text('Pause'),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: _isProcessing ? null : () => _controlYouTube('STOP'),
                          style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent),
                          child: const Text('Stop'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 2. Super Wheel Game Launch Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.stars_rounded, color: Colors.amber, size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Super Wheel Party Game',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          Text(
                            'Spin for multipliers & diamond jackpots',
                            style: TextStyle(color: Colors.white54, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: _isProcessing ? null : _launchSuperWheel,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
                      child: const Text('Launch Wheel'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 3. Lucky Bag Drop Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.deepOrangeAccent.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.card_giftcard_rounded, color: Colors.deepOrangeAccent, size: 22),
                        SizedBox(width: 8),
                        Text(
                          'Lucky Red Bag Drop',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _luckyBagCoinsController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            decoration: InputDecoration(
                              labelText: 'Total Coin Drop',
                              labelStyle: const TextStyle(color: Colors.white60, fontSize: 12),
                              isDense: true,
                              filled: true,
                              fillColor: Colors.black26,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: _isProcessing ? null : _dropLuckyBag,
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrangeAccent, foregroundColor: Colors.white),
                          child: const Text('Drop Bag'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
