import 'dart:io';
import 'package:flutter/material.dart';

class DisplayImageScreen extends StatelessWidget {
  final String? blink1Path;
  final String? blink3Path;
  final String? leftTurnPath;
  final String? rightTurnPath;

  const DisplayImageScreen({
    super.key,
    this.blink1Path,
    this.blink3Path,
    this.leftTurnPath,
    this.rightTurnPath,
  });

  @override
  Widget build(BuildContext context) {
    final List<Map<String, String>> photos = [
      if (blink3Path != null) {"title": "Final Photo", "path": blink3Path!},
      if (blink1Path != null) {"title": "1st Blink", "path": blink1Path!},
      if (rightTurnPath != null) {"title": "Right Turn", "path": rightTurnPath!},
      if (leftTurnPath != null) {"title": "Left Turn", "path": leftTurnPath!},
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text("Captured Photos"), centerTitle: true),
      body: Column(
        children: [
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.8,
              ),
              itemCount: photos.length,
              itemBuilder: (context, index) {
                return _buildGridItem(photos[index]["title"]!, photos[index]["path"]!);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFED1B2E),
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text(
                "Go Back",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildGridItem(String title, String path) {
    return Column(
      children: [
        Container(
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.grey.shade300, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(20),
                blurRadius: 5,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.file(File(path), fit: BoxFit.cover),
        ),
        SizedBox(height: 5),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
