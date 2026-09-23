import 'dart:io';
import 'package:flutter/material.dart';

class FullScreenImageViewer extends StatelessWidget {
  final String imageUrl;
  final String? title;

  const FullScreenImageViewer({
    super.key,
    required this.imageUrl,
    this.title,
  });

  static void show(BuildContext context, String imageUrl, {String? title}) {
    if (imageUrl.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => FullScreenImageViewer(imageUrl: imageUrl, title: title),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isLocal = imageUrl.startsWith('/') || imageUrl.startsWith('file:') || imageUrl.contains('\\');
    if (isLocal) {
      try {
        final f = File(imageUrl);
        isLocal = f.existsSync();
      } catch (_) {
        isLocal = false;
      }
    }

    final ImageProvider imageProvider = isLocal
        ? FileImage(File(imageUrl))
        : (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')
            ? NetworkImage(imageUrl)
            : const NetworkImage('https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=500'));

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.7),
        elevation: 0,
        title: Text(
          title ?? 'Profile Photo',
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.8,
          maxScale: 4.0,
          child: Image(
            image: imageProvider,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                      : null,
                  color: Colors.white,
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.broken_image_rounded, color: Colors.white54, size: 64),
                  SizedBox(height: 12),
                  Text('Failed to load image', style: TextStyle(color: Colors.white54)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
