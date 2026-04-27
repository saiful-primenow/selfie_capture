import 'dart:convert';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:path/path.dart' as path;
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import 'action_button.dart';
import 'camera_helper.dart';
import 'display_image.dart';

class SelfieCapture extends StatefulWidget {
  final CameraDescription camera;

  const SelfieCapture({super.key, required this.camera});

  @override
  State<SelfieCapture> createState() => _SelfieCaptureState();
}

class _SelfieCaptureState extends State<SelfieCapture> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  bool _isDetecting = false;
  bool _isCapturing = false;
  bool _cameraStopped = false;
  bool _cameraStreaming = false;
  bool hasSmiled = false;
  Face? _currentFace;
  String _headPosition = 'Center';
  String _eyeStatus = 'Eyes Open';
  bool _leftTurnCaptured = false;
  bool _rightTurnCaptured = false;
  bool _headTurnCaptured = false;
  bool loading = false;
  int _blinkCount = 0;
  String? _firstBlinkPhotoPath;
  String? _thirdBlinkPhotoPath;
  String? _headTurnPhotoPath;
  String? showImage;
  String? convertedImage = "";
  String ekyc_id = "";
  String name = "";

  // bool videoDetected = false;
  String message = "Blink Your Eyes";

  final _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableTracking: true,
      enableContours: true,
      enableLandmarks: true,
      enableClassification: true,
      performanceMode:
          FaceDetectorMode.accurate, // matches ML Kit default behavior
    ),
  );

  String frontNID = "";

  List<List<Offset>> _landmarkHistory = [];
  int maxHistoryLength = 15;

  @override
  void initState() {
    super.initState();
    _controller = CameraController(
      widget.camera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup
                .nv21 // for Android
          : ImageFormatGroup.bgra8888,
    );
    _initializeControllerFuture = _controller.initialize().then((_) async {
      if (!mounted) return;
      // await _controller.setZoomLevel(zoomLevel);
      setState(() {});
      _startImageStream();
    });
    _initializeControllerFuture;

    // frontNID = widget.frontNID;
    // ekyc_id = widget.ekyc_id;
    // debugPrint("Name from selfie is: ${widget.name}");
    // name = widget.name;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {

    // App state changed before we got the chance to initialize.
    if (_controller == null || !_controller.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      _controller.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeControllerFuture;
    }
  }

  void _startImageStream() {
    _controller.startImageStream((CameraImage image) {
      if (_isDetecting || _cameraStopped) return;
      _isDetecting = true;

      debugPrint("Image format: ${image.format.group.toString()}");

      _processCameraImage(image).then((_) {
        _isDetecting = false;
      });
    });
    _cameraStreaming = true;
  }

  List<double> brightnessHistory = [];

  Future<void> _processCameraImage(CameraImage image) async {
    if (_cameraStopped) return;

    final WriteBuffer allBytes = WriteBuffer();
    for (Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }

    final bytes = allBytes.done().buffer.asUint8List();

    final inputImage = InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: _rotationIntToImageRotation(widget.camera.sensorOrientation),
        format:
            InputImageFormatValue.fromRawValue(image.format.raw) ??
            InputImageFormat.nv21,
        bytesPerRow: image.planes[0].bytesPerRow,
      ),
    );

    final faces = await _faceDetector.processImage(inputImage);

    if (!mounted) return;

    setState(() {
      if (faces.isNotEmpty) {
        _currentFace = faces.first;
        _updateHeadPosition();
        _checkSmileThenProceed();
        _updateEyeStatus();
        // _trackMicroJitter(faces.first);
      } else {
        _currentFace = null;
        _headPosition = 'No Face';
        _eyeStatus = 'No Face';
      }
    });
  }

  void _updateHeadPosition() {
    if (_currentFace == null) return;

    final yAngle = _currentFace!.headEulerAngleY ?? 0;

    if (yAngle > 15 && !_rightTurnCaptured) {
      setState(() {
        _headPosition = 'Right';
        _rightTurnCaptured = true;
      });
    } else if (yAngle < -15 && !_leftTurnCaptured) {
      setState(() {
        _headPosition = 'Left';
        _leftTurnCaptured = true;
      });
    } else {
      _headPosition = 'Center';
    }

    if (_leftTurnCaptured && _rightTurnCaptured && !_headTurnCaptured) {
      _headTurnCaptured = true;
      _capturePhoto(type: 'head');
    }
  }

  void _checkSmileThenProceed() {
    final smileProb = _currentFace?.smilingProbability ?? 0;
    if (smileProb >= 0.85 && _headTurnCaptured) {
      hasSmiled = true;
    }
  }

  void _updateEyeStatus() {
    if (_currentFace == null ||
        _cameraStopped ||
        !hasSmiled ||
        !_headTurnCaptured)
      return;

    final leftEye = _currentFace!.leftEyeOpenProbability ?? 1;
    final rightEye = _currentFace!.rightEyeOpenProbability ?? 1;

    if (leftEye < 0.15 && rightEye < 0.15) {
      _eyeStatus = 'Eyes Closed';

      if (!_isCapturing && hasSmiled) {
        _blinkCount++;

        if (_blinkCount == 1) {
          _capturePhoto(type: 'blink1');
        } else if (_blinkCount == 2) {
          debugPrint("Second Blink Detected.");
        } else if (_blinkCount == 3) {
          _capturePhoto(type: 'blink3');
        }

        if (_blinkCount >= 3 && _headTurnCaptured && !_cameraStopped) {
          _stopCamera();
        }
      }
    } else if (leftEye > 0.85 && rightEye > 0.85) {
      _eyeStatus = 'Eyes Open';
    } else {
      _eyeStatus = 'One Eye Closed';
    }
  }

  Future<void> _capturePhoto({required String type}) async {
    if (_isCapturing || _currentFace == null || _cameraStopped) return;
    setState(() {
      _isCapturing = true;
    });
    try {
      await _controller.setFlashMode(FlashMode.off);

      final image = await _controller.takePicture();
      final directory = await getApplicationDocumentsDirectory();
      final fileName = path.join(
        directory.path,
        '${type}_photo_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await File(image.path).copy(fileName);
      setState(() {
        if (type == 'blink1') {
          _firstBlinkPhotoPath = fileName;
          _thirdBlinkPhotoPath = fileName;
        } else if (type == 'blink2') {
          _thirdBlinkPhotoPath = fileName;
          debugPrint("Blink 2 captured.");
        } else if (type == 'blink3') {
          _thirdBlinkPhotoPath = fileName;
        } else if (type == 'head') {
          _headTurnPhotoPath = fileName;
          _thirdBlinkPhotoPath = fileName;
        }

        if (_firstBlinkPhotoPath != null &&
            _thirdBlinkPhotoPath != null &&
            _headTurnPhotoPath != null) {
          message = "Almost Done";
          _stopCamera();

          convertImageToBase64(showImage!, (base64) {
            convertedImage = base64;
            print("Base64 result: $base64");
          });
        }
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error capturing $type photo: $e');
      }
    } finally {
      setState(() {
        _isCapturing = false;
      });
    }
  }

  Future<void> _stopCamera() async {
    try {
      if (_cameraStreaming) {
        await _controller.stopImageStream();
        _cameraStreaming = false;
      }
      setState(() {
        _cameraStopped = true;
      });
    } catch (e) {
      debugPrint('Error stopping camera: $e');
    }
  }

  void _restartCamera() async {
    setState(() {
      _cameraStopped = false;
      _isCapturing = false;
      _leftTurnCaptured = false;
      _rightTurnCaptured = false;
      _headTurnCaptured = false;
      hasSmiled = false;
      _blinkCount = 0;
      _firstBlinkPhotoPath = null;
      _thirdBlinkPhotoPath = null;
      _headTurnPhotoPath = null;
      message = "Blink Your Eyes";
    });

    if (!_controller.value.isInitialized) {
      await _controller.initialize();
    }
    _startImageStream();
  }

  InputImageRotation _rotationIntToImageRotation(int rotation) {
    switch (rotation) {
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
        return InputImageRotation.rotation270deg;
      default:
        return InputImageRotation.rotation0deg;
    }
  }

  // image conversion
  void convertImageToBase64(
    String image,
    void Function(String base64) onComplete,
  ) {
    final File imageFile = File(image);
    imageFile.readAsBytes().then((bytes) {
      final base64 = base64Encode(bytes);
      onComplete(base64);
    });
  }

  Future<String> compressBase64Image(
    String base64Image, {
    int quality = 20,
  }) async {
    Uint8List imageBytes = base64Decode(base64Image);

    img.Image? image = img.decodeImage(imageBytes);
    if (image == null) {
      throw Exception('Failed to decode image');
    }

    List<int> compressedBytes = img.encodeJpg(image, quality: quality);

    String compressedBase64 = base64Encode(compressedBytes);
    return compressedBase64;
  }

  @override
  void dispose() {
    _controller.dispose();
    _faceDetector.close();
    super.dispose();
  }

  Widget _buildStatusPanel() {
    return Container(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_leftTurnCaptured && !_rightTurnCaptured)
            const Text(
              "Turn Head Right",
              style: TextStyle(color: Colors.black, fontSize: 20),
            ),

          if (!_leftTurnCaptured)
            const Text(
              "Turn Head Left",
              style: TextStyle(color: Colors.black, fontSize: 20),
            ),

          if (_headTurnCaptured && !hasSmiled && _blinkCount < 3)
            const Text(
              "Please Smile",
              style: TextStyle(color: Colors.black, fontSize: 20),
            ),
          if (hasSmiled && _blinkCount < 3)
            Text(message, style: TextStyle(color: Colors.black, fontSize: 20)),
          if (_blinkCount > 1 && _cameraStopped)
            const Text(
              "Almost Done",
              style: TextStyle(color: Colors.black, fontSize: 20),
            ),

          // if (showImage != null && videoDetected) Text("Video Detected - Take Live Selfies", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    showImage =
        _thirdBlinkPhotoPath ?? _firstBlinkPhotoPath ?? _headTurnPhotoPath;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: Text("Self Live Photo"), centerTitle: true,),
      body: loading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
              ),
            )
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildStatusPanel(),
                  const SizedBox(height: 47),

                  Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      // border: Border.all(color: Colors.grey.shade300, width: 5),
                    ),
                    clipBehavior: Clip.hardEdge,
                    child: (_controller.value.isInitialized)
                        ? (_cameraStopped
                              ? (showImage != null
                                    ? Image.file(
                                        File(
                                          _thirdBlinkPhotoPath ?? showImage!,
                                        ),
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        height: double.infinity,
                                      )
                                    : const Center(child: Text("")))
                              : FittedBox(
                                  fit: BoxFit.cover,
                                  child: SizedBox(
                                    width:
                                        _controller.value.previewSize!.height,
                                    height:
                                        _controller.value.previewSize!.width,
                                    child: CameraPreview(_controller),
                                  ),
                                ))
                        : const Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.red,
                              ),
                            ),
                          ),
                  ),

                  const SizedBox(height: 111),

                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: ActionButton(
                      customPadding: 16,
                      parentContext: context,
                      topButtonText: "Continue",
                      isTopButtonDisabled: !_cameraStopped,
                      useActiveBackground: _cameraStopped,
                      activeBackgroundImage: 'assets/button_background_2.png',
                      disabledBackgroundImage:
                          'assets/button_background_grey.png',
                      showBackButton: _cameraStopped,
                      backButtonText: "Restart",
                      onBackButtonTap: _restartCamera,
                      onTopButtonTap: () async {
                        if (showImage != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DisplayImageScreen(
                                imagePath: showImage!,
                              ),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
