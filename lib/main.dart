import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:selfie_capture/selfie_capture.dart';

late List<CameraDescription> cameras;

void main() async {
  cameras = await availableCameras();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    final frontCamera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );
    return MaterialApp(
      title: 'Flutter Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorScheme: .fromSeed(seedColor: Colors.deepPurple)),
      home: HomeScreen(camera: frontCamera),
    );
  }
}

class HomeScreen extends StatelessWidget {
  final CameraDescription camera;

  const HomeScreen({super.key, required this.camera});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Camera Dashboard'), centerTitle: true),
      body: Center(
        child: TextButton.icon(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SelfieCapture(camera: camera),
            ),
          ),
          label: Text('Capture Photo'),
          icon: Icon(Icons.camera_alt_outlined),
        ),
      ),
    );
  }
}
