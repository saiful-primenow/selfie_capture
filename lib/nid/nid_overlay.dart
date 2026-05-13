import 'dart:io';

import 'package:flutter/material.dart';

class NidOverlay extends StatelessWidget {
  final String step; // e.g., "1/2"
  final String instruction; // e.g., "Take photo of the Front side"
  final Widget bottomAction;
  final String? imagePath;
  final VoidCallback onBack;
  final String title;

  const NidOverlay({
    super.key,
    required this.step,
    required this.instruction,
    required this.bottomAction,
    required this.onBack,
    this.imagePath,
    this.title = "ID Verification",
  });

  @override
  Widget build(BuildContext context) {
    const cutoutAlignment = Alignment(0, -0.35); // Moved up
    final cutoutWidth = MediaQuery.of(context).size.width * 0.85;
    const cutoutHeight = 220.0;

    return Stack(
      children: [
        if (imagePath != null)
          Align(
            alignment: cutoutAlignment,
            child: Container(
              height: cutoutHeight,
              width: cutoutWidth,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.file(File(imagePath!), fit: BoxFit.cover),
            ),
          ),
        // The Dark Cutout Background
        Positioned.fill(
          child: ColorFiltered(
            colorFilter: ColorFilter.mode(
              Color(0xFF212121),
              BlendMode.srcOut,
            ),
            child: Stack(
              children: [
                Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFF212121), // Dark background for controls
                    backgroundBlendMode: BlendMode.dstOut,
                  ),
                ),
                Align(
                  alignment: cutoutAlignment,
                  child: Container(
                    height: cutoutHeight,
                    width: cutoutWidth,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Green Corner Markers
        Align(
          alignment: cutoutAlignment,
          child: SizedBox(
            height: cutoutHeight,
            width: cutoutWidth,
            child: CustomPaint(painter: CornerPainter()),
          ),
        ),
        // Header
        SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                    onPressed: onBack,
                  ),
                  Expanded(
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 15),
                    child: Text(
                      step,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Instruction Text (Positioned below the cutout)
        Align(
          alignment: const Alignment(0, 0.1), // Below the -0.35 cutout
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: _buildInstructionText(instruction),
          ),
        ),
        // Bottom Actions
        SafeArea(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: bottomAction,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInstructionText(String text) {
    final parts = text.split(RegExp(r'(Front side|Back side)'));
    if (parts.length > 1) {
      String match = RegExp(r'(Front side|Back side)').firstMatch(text)!.group(0)!;
      return RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          style: const TextStyle(color: Colors.white, fontSize: 16),
          children: [
            TextSpan(text: parts[0]),
            TextSpan(
              text: match,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(text: parts[1]),
          ],
        ),
      );
    }
    return Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(color: Colors.white, fontSize: 16),
    );
  }
}

class CornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF2ECC71) // More vibrant green
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    double len = 25; // Slightly longer corner lines
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
