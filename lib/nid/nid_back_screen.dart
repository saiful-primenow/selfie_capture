import 'package:flutter/material.dart';

import 'nid_overlay.dart';

class NidBackUI extends StatelessWidget {
  final VoidCallback onCapture;
  final VoidCallback? onRetake;
  final VoidCallback? onContinue;
  final String? imagePath;
  final VoidCallback onBack;
  final VoidCallback onFlashToggle;
  final bool isFlashOn;

  const NidBackUI({
    super.key,
    required this.onCapture,
    required this.onBack,
    required this.onFlashToggle,
    required this.isFlashOn,
    this.onRetake,
    this.onContinue,
    this.imagePath,
  });

  @override
  Widget build(BuildContext context) {
    return NidOverlay(
      step: "2/2",
      imagePath: imagePath,
      onBack: onBack,
      onFlashToggle: onFlashToggle,
      isFlashOn: isFlashOn,
      instruction: imagePath == null
          ? "Take photo of the Back side of your NID"
          : "Review your Back side photo",
      bottomAction: imagePath == null
          ? GestureDetector(
              onTap: onCapture,
              child: Container(
                height: 80,
                width: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                ),
                child: const Center(
                  child: Icon(Icons.circle, color: Colors.white, size: 60),
                ),
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
