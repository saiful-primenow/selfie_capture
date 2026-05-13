import 'package:flutter/material.dart';

import 'nid_overlay.dart';

class NidFrontUI extends StatelessWidget {
  final VoidCallback onCapture;
  final VoidCallback? onRetake;
  final VoidCallback? onContinue;
  final String? imagePath;
  final VoidCallback onBack;
  final VoidCallback onFlashToggle;
  final VoidCallback onGallery;
  final bool isFlashOn;

  const NidFrontUI({
    super.key,
    required this.onCapture,
    required this.onBack,
    required this.onFlashToggle,
    required this.onGallery,
    required this.isFlashOn,
    this.onRetake,
    this.onContinue,
    this.imagePath,
  });

  @override
  Widget build(BuildContext context) {
    return NidOverlay(
      step: "1/2",
      imagePath: imagePath,
      onBack: onBack,
      instruction: imagePath == null
          ? "Take photo of the Front side of your NID"
          : "Review your Front side photo",
      bottomAction: imagePath == null
          ? Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
              decoration: BoxDecoration(
                color: const Color(0xFF181818), // Dark background for controls
                borderRadius: BorderRadius.circular(40),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Gallery Button
                  IconButton(
                    icon: const Icon(Icons.image_outlined, color: Colors.white, size: 30),
                    onPressed: onGallery,
                  ),
                  // Capture Button
                  GestureDetector(
                    onTap: onCapture,
                    child: Container(
                      height: 66,
                      width: 66,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                      ),
                      child: const Center(
                        child: Icon(Icons.circle, color: Colors.white, size: 56),
                      ),
                    ),
                  ),
                  // Flash Button
                  GestureDetector(
                    onTap: onFlashToggle,
                    child: Container(
                      height: 44,
                      width: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFD4AF37), width: 1.5),
                      ),
                      child: Icon(
                        isFlashOn ? Icons.flash_on : Icons.flash_off,
                        color: const Color(0xFFD4AF37),
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),
            )
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        minimumSize: const Size(0, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: onRetake,
                      child: const Text("Retake Photo"),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6200EE),
                        minimumSize: const Size(0, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: onContinue,
                      child: const Text("Continue",
                          style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
