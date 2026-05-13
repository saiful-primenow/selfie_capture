import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
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

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100,
      );
      if (image != null) {
        final croppedFile = await _cropImage(image.path);
        if (croppedFile != null) {
          setState(() {
            if (!_isFrontConfirmed) {
              _frontImage = XFile(croppedFile.path);
            } else {
              _backImage = XFile(croppedFile.path);
            }
          });
        }
      }
    } catch (e) {
      debugPrint("Error picking image: $e");
    }
  }

  /*Future<void> _pickAndCropImage() async {
    try {
      // Pick Image
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100,
      );

      if (pickedFile == null) return;

      // Crop Image
      final CroppedFile? croppedFile = await ImageCropper().cropImage(
        sourcePath: pickedFile.path,
        compressQuality: 100,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Image',
            toolbarColor: Colors.blue,
            toolbarWidgetColor: Colors.white,
            lockAspectRatio: false,
          ),
          IOSUiSettings(
            title: 'Crop Image',
          ),
        ],
      );

      if (croppedFile == null) return;

      if (!mounted) return;

      // Navigate to Preview Screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PreviewImageScreen(
            imagePath: croppedFile.path,
          ),
        ),
      );
    } catch (e) {
      debugPrint("Error: $e");
    }
  }*/

  Future<CroppedFile?> _cropImage(String path) async {
    try {
      return await ImageCropper().cropImage(
        sourcePath: path,
        aspectRatio: const CropAspectRatio(ratioX: 1.58, ratioY: 1.0),
        // Standard ID Card Ratio
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Align NID in Frame',
            toolbarColor: Colors.black,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
            hideBottomControls: false,
          ),
          IOSUiSettings(
            title: 'Align NID in Frame',
            aspectRatioLockEnabled: false,
            resetAspectRatioEnabled: false,
          ),
        ],
      );
    } catch (e) {
      debugPrint("Error cropping image: $e");
      return null;
    }
  }

  Future<void> _takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    try {
      final image = await _controller!.takePicture();
      final croppedFile = await _cropImage(image.path);

      if (croppedFile != null) {
        setState(() {
          if (!_isFrontConfirmed) {
            _frontImage = XFile(croppedFile.path);
          } else {
            _backImage = XFile(croppedFile.path);
          }
        });
      }

      // File size in bytes
      final int fileSize = await _frontImage!.length();
      debugPrint("Front NID Size MB: ${(fileSize / (1024 * 1024)).toStringAsFixed(2)} MB");
      final int fileSize2 = await _backImage!.length();
      debugPrint("Back NID Size MB: ${(fileSize2 / (1024 * 1024)).toStringAsFixed(2)} MB");

    } catch (e) {
      debugPrint("Error taking picture: $e");
    }
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
    });
  }

  Future<void> _confirmBack() async {
    await _controller?.dispose();
    _controller = null;
    setState(() {
      _isInitialized = false;
    });

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NidVerifyScreen(
          frontImage: _frontImage?.path,
          backImage: _backImage?.path,
          onRetake: () {
            _resetAll();
            Navigator.pop(context);
          },
          onConfirm: () {
            Navigator.pop(context); // Pop Verify
            Navigator.pop(context); // Pop Camera
          },
        ),
      ),
    ).then((_) {
      if (mounted && _controller == null) {
        _setupCamera();
      }
    });
  }

  void _resetAll() {
    setState(() {
      _frontImage = null;
      _isFrontConfirmed = false;
      _backImage = null;
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

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Live Feed aligned with overlay cutout
          Align(
            alignment: const Alignment(0, -0.35),
            child: SizedBox(
              height: 220,
              width: MediaQuery.of(context).size.width * 0.85,
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  if (_frontImage == null ||
                      (_isFrontConfirmed && _backImage == null))
                    ClipRRect(
                      child: FittedBox(
                        fit: BoxFit.cover,
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
              onGallery: _pickImage,
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
              onGallery: _pickImage,
              isFlashOn: _isFlashOn,
            ),
        ],
      ),
    );
  }
}
