import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'nid_front_screen.dart';
import 'nid_back_screen.dart';
import 'nid_verify_screen.dart';

class NidCameraScreen extends StatefulWidget {
  const NidCameraScreen({super.key});

  @override
  State<NidCameraScreen> createState() => _NidCameraScreenState();
}

class _NidCameraScreenState extends State<NidCameraScreen> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  bool _isFlashOn = false;

  XFile? _frontImage;
  bool _isFrontConfirmed = false;

  XFile? _backImage;
  bool _isBackConfirmed = false;

  @override
  void initState() {
    super.initState();
    _setupCamera();
  }

  Future<void> _setupCamera() async {
    _cameras = await availableCameras();
    if (_cameras != null && _cameras!.isNotEmpty) {
      _controller = CameraController(
        _cameras![0],
        ResolutionPreset.high,
        enableAudio: false,
      );
      await _controller!.initialize();
      if (!mounted) return;
      setState(() => _isInitialized = true);
    }
  }

  Future<void> _toggleFlash() async {
    if (_controller == null) return;
    setState(() {
      _isFlashOn = !_isFlashOn;
    });
    await _controller!.setFlashMode(
      _isFlashOn ? FlashMode.torch : FlashMode.off,
    );
  }

  Future<void> _takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    final image = await _controller!.takePicture();
    setState(() {
      if (!_isFrontConfirmed) {
        _frontImage = image;
      } else {
        _backImage = image;
      }
    });
  }

  void _resetFront() {
    setState(() {
      _frontImage = null;
      _isFrontConfirmed = false;
    });
  }

  void _confirmFront() {
    setState(() {
      _isFrontConfirmed = true;
    });
  }

  void _resetBack() {
    setState(() {
      _backImage = null;
      _isBackConfirmed = false;
    });
  }

  void _confirmBack() {
    setState(() {
      _isBackConfirmed = true;
    });
  }

  void _resetAll() {
    setState(() {
      _frontImage = null;
      _isFrontConfirmed = false;
      _backImage = null;
      _isBackConfirmed = false;
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_isBackConfirmed) {
      return NidVerifyScreen(
        frontImage: _frontImage?.path,
        backImage: _backImage?.path,
        onRetake: _resetAll,
        onConfirm: () {
          // Final action
          Navigator.pop(context);
        },
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // The Live Feed (Only show if not in review mode)
          /*Positioned.fill(
            child:
                (_frontImage == null ||
                    (_isFrontConfirmed && _backImage == null))
                ? FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                      width: _controller!.value.previewSize!.height,
                      height: _controller!.value.previewSize!.width,
                      child: CameraPreview(_controller!),
                    ),
                )
                : Container(color: Colors.black),
          ),*/
          Center(
            child: SizedBox(
              height: 220,
              width: MediaQuery.of(context).size.width * 0.85,
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  if (_frontImage == null ||
                      (_isFrontConfirmed && _backImage == null))
                    ClipRRect(
                      // borderRadius: BorderRadius.circular(12), // same as 1st
                      child: FittedBox(
                        fit: BoxFit.cover,
                        // Maintain zoom & quality like 1st camera
                        child: SizedBox(
                          width: _controller!.value.previewSize!.height,
                          height: _controller!.value.previewSize!.width,
                          child: CameraPreview(_controller!),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Logic to switch between Front and Back UI
          if (!_isFrontConfirmed)
            NidFrontUI(
              onCapture: _takePicture,
              imagePath: _frontImage?.path,
              onRetake: _resetFront,
              onContinue: _confirmFront,
              onBack: () => Navigator.pop(context),
              onFlashToggle: _toggleFlash,
              isFlashOn: _isFlashOn,
            )
          else
            NidBackUI(
              onCapture: _takePicture,
              imagePath: _backImage?.path,
              onRetake: _resetBack,
              onContinue: _confirmBack,
              onBack: _resetFront,
              onFlashToggle: _toggleFlash,
              isFlashOn: _isFlashOn,
            ),
        ],
      ),
    );
  }
}
