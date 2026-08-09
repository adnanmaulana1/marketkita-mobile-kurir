import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  final double size;
  const AppLogo({super.key, this.size = 72});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF171717),
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Icon(Icons.two_wheeler, size: size * 0.55, color: Colors.amber.shade400),
    );
  }
}
