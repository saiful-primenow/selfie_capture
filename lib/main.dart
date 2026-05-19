import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:selfie_capture/account_opening_screen.dart';
import 'package:selfie_capture/selfie_capture.dart';
import 'nid/nid_camera_screen.dart';

late List<CameraDescription> cameras;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorScheme: .fromSeed(seedColor: Colors.deepPurple)),
      home: HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Camera Dashboard'), centerTitle: true),
      body: Center(
        child: Column(
          mainAxisAlignment: .center,
          children: [
            TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SelfieCapture()),
                );
              },
              label: Text('Check Liveness'),
              icon: Icon(Icons.camera_alt_outlined),
            ),

            TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AccountOpeningScreen(),
                  ),
                );
              },
              label: Text('Instruction'),
              icon: Icon(Icons.camera_alt_outlined),
            ),

            TextButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => NidCameraScreen()),
              ),
              label: Text('Capture NID'),
              icon: Icon(Icons.camera_alt_outlined),
            ),
          ],
        ),
      ),
    );
  }
}
