import 'package:flutter/material.dart';

class App3DIcon extends StatelessWidget {
  final String iconPath;
  final double size;
  final Color? color;

  const App3DIcon({
    super.key,
    required this.iconPath,
    this.size = 24.0,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      iconPath,
      width: size,
      height: size,
      fit: BoxFit.contain,
      color: color,
    );
  }
}
