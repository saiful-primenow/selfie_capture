import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

Future<String> getBase64Image(
  String imagePath, {
  int quality = 5,
  int maxWidth = 512,
}) async {
  try {
    final File imageFile = File(imagePath);
    final Uint8List imageBytes = await imageFile.readAsBytes();

    // Decode the image
    img.Image? originalImage = img.decodeImage(imageBytes);
    if (originalImage == null) return '';

    // Resize if needed
    if (originalImage.width > maxWidth) {
      originalImage = img.copyResize(originalImage, width: maxWidth);
    }

    // Encode the image to JPEG with reduced quality
    final List<int> compressedBytes = img.encodeJpg(
      originalImage,
      quality: quality,
    );

    // Convert to base64
    final String base64Image = base64Encode(compressedBytes);
    return base64Image;
  } catch (e) {
    print('Error encoding image to base64: $e');
    return '';
  }
}
