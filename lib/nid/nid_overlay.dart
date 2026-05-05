import 'dart:io';

import 'package:flutter/material.dart';

class NidOverlay extends StatelessWidget {
  final String step; // e.g., "1/2"
  final String instruction; // e.g., "Take photo of the Front side"
  final Widget bottomAction;
  final String? imagePath;
  final VoidCallback onBack;
  final VoidCallback onFlashToggle;
  final bool isFlashOn;

  const NidOverlay({
    super.key,
    required this.step,
    required this.instruction,
    required this.bottomAction,
    required this.onBack,
    required this.onFlashToggle,
    required this.isFlashOn,
    this.imagePath,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (imagePath != null)
          Align(
            alignment: Alignment.center,
            child: Container(
              height: 220,
              width: MediaQuery.of(context).size.width * 0.85,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(0),
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.file(File(imagePath!), fit: BoxFit.cover),
            ),
          ),
        // The Dark Cutout Background
        Positioned.fill(
          child: ColorFiltered(
            colorFilter: ColorFilter.mode(
              Colors.black.withAlpha(179),
              BlendMode.srcOut,
            ),
            child: Stack(
              children: [
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    backgroundBlendMode: BlendMode.dstOut,
                  ),
                ),
                Align(
                  alignment: Alignment.center,
                  child: Container(
                    height: 220, // Aspect ratio for ID card
                    width: MediaQuery.of(context).size.width * 0.85,
                    decoration: BoxDecoration(
                      color: Colors.white
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Green Corner Markers
        Center(
          child: SizedBox(
            height: 220,
            width: MediaQuery.of(context).size.width * 0.85,
            child: CustomPaint(painter: CornerPainter()),
          ),
        ),
        // UI Text Elements
        SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                      onPressed: onBack,
                    ),
                    Text(
                      step,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    GestureDetector(
                      onTap: onFlashToggle,
                      child: Container(
                        height: 40,
                        width: 40,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFF176), // Yellow circle
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isFlashOn ? Icons.flash_on : Icons.flash_off,
                          color: Colors.black,
                          size: 24,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              Text(
                instruction,
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(bottom: 40),
                child: bottomAction,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class CornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.greenAccent
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;

    double len = 20; // Length of corner lines
    // Top Left
    canvas.drawPath(Path()..moveTo(0, len)..lineTo(0, 0)..lineTo(len, 0), paint);
    // Top Right
    canvas.drawPath(Path()..moveTo(size.width - len, 0)..lineTo(size.width, 0)..lineTo(size.width, len), paint);
    // Bottom Left
    canvas.drawPath(Path()..moveTo(0, size.height - len)..lineTo(0, size.height)..lineTo(len, size.height), paint);
    // Bottom Right
    canvas.drawPath(Path()..moveTo(size.width - len, size.height)..lineTo(size.width, size.height)..lineTo(size.width, size.height - len), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
