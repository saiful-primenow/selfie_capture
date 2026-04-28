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
  bool _leftTurnCaptured = false;
  bool _rightTurnCaptured = false;
  bool _headTurnCaptured = false;
  bool loading = false;
  int _blinkCount = 0;
  bool _eyesWereClosed = false; // Added for robust blink detection
  String? _firstBlinkPhotoPath;
  String? _thirdBlinkPhotoPath;
  String? _headTurnPhotoPath;
  String? _leftTurnPhotoPath;
  String? _rightTurnPhotoPath;
  String? showImage;
  String? convertedImage = "";
  int _leftStableCount = 0;
  int _rightStableCount = 0;

  static const int REQUIRED_STABLE_FRAMES = 5;

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
      setState(() {});
      _startImageStream();
    });
    _initializeControllerFuture;
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
      } else {
        _currentFace = null;
      }
    });
  }

  void _updateHeadPosition() {
    if (_currentFace == null) return;

    final yAngle = _currentFace!.headEulerAngleY ?? 0;

    // RIGHT TURN
    if (yAngle > 25) {
      _rightStableCount++;
      _leftStableCount = 0;

      if (_rightStableCount >= REQUIRED_STABLE_FRAMES && !_rightTurnCaptured) {
        setState(() {
          _rightTurnCaptured = true;
        });
        _capturePhoto(type: 'right');
      }
    }
    // LEFT TURN
    else if (yAngle < -25) {
      _leftStableCount++;
      _rightStableCount = 0;

      if (_leftStableCount >= REQUIRED_STABLE_FRAMES && !_leftTurnCaptured) {
        setState(() {
          _leftTurnCaptured = true;
        });
        _capturePhoto(type: 'left');
      }
    }
    // CENTER
    else {
      _leftStableCount = 0;
      _rightStableCount = 0;
    }

    // AFTER BOTH CAPTURED
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

    final leftEye = _currentFace!.leftEyeOpenProbability ?? 1.0;
    final rightEye = _currentFace!.rightEyeOpenProbability ?? 1.0;

    bool currentlyClosed = leftEye < 0.15 && rightEye < 0.15;
    bool currentlyOpen = leftEye > 0.80 && rightEye > 0.80;

    if (currentlyClosed && !_eyesWereClosed && !_isCapturing) {
      // Transition from Open to Closed
      _eyesWereClosed = true;
      _blinkCount++;

      if (_blinkCount == 1) {
        _capturePhoto(type: 'blink1');
        debugPrint("Blink 1 triggered");
      } else if (_blinkCount == 3) {
        _capturePhoto(type: 'blink3');
        debugPrint("Blink 3 triggered");
      }

      setState(() {});
    } else if (currentlyOpen && _eyesWereClosed) {
      // Transition from Closed to Open
      _eyesWereClosed = false;
      setState(() {});
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
          debugPrint("Blink 1 path set: $_firstBlinkPhotoPath");
        } else if (type == 'blink3') {
          _thirdBlinkPhotoPath = fileName;
          _cameraStopped = true; // Immediately update UI to show the image
          debugPrint("Blink 3 path set: $_thirdBlinkPhotoPath");
        } else if (type == 'head') {
          _headTurnPhotoPath = fileName;
        } else if (type == 'left') {
          _leftTurnPhotoPath = fileName;
        } else if (type == 'right') {
          _rightTurnPhotoPath = fileName;
        }
      });

      // Stop camera properly in the background
      if (type == 'blink3') {
        message = "Almost Done";
        _stopCamera(); // No need to await here as we already set _cameraStopped

        if (_thirdBlinkPhotoPath != null) {
          convertImageToBase64(_thirdBlinkPhotoPath!, (base64) {
            convertedImage = base64;
            debugPrint("Base64 conversion complete for Blink 3");
          });
        }
      }
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

      await _controller.dispose();
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
      _leftTurnPhotoPath = null;
      _rightTurnPhotoPath = null;
      message = "Blink Your Eyes";
    });

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
      setState(() {});
      _startImageStream();
    });
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

  Widget _buildStepIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _stepIcon(Icons.turn_right, _leftTurnCaptured),
        _stepLine(_leftTurnCaptured),
        _stepIcon(Icons.turn_left, _rightTurnCaptured),
        _stepLine(_rightTurnCaptured),
        _stepIcon(Icons.sentiment_satisfied, hasSmiled),
        _stepLine(hasSmiled),
        _stepIcon(Icons.remove_red_eye, _blinkCount >= 3),
      ],
    );
  }

  Widget _stepIcon(IconData icon, bool completed) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: completed ? Colors.green : Colors.grey.shade300,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: Colors.white, size: 18),
    );
  }

  Widget _stepLine(bool completed) {
    return Container(
      width: 30,
      height: 2,
      color: completed ? Colors.green : Colors.grey.shade300,
    );
  }

  Widget _buildStatusPanel() {
    String instruction = "";
    Color statusColor = Colors.blue;

    if (_cameraStopped) {
      instruction = "Success! Capture complete";
      statusColor = Colors.green;
    } else if (_currentFace == null && !_leftTurnCaptured) {
      // Only force centering at the very beginning
      instruction = "Center your face in the frame";
      statusColor = Colors.red;
    } else if (!_leftTurnCaptured) {
      instruction = "Turn Head Right";
    } else if (!_rightTurnCaptured) {
      instruction = "Turn Head Left";
    } else if (!hasSmiled) {
      instruction = "Now Smile!";
      statusColor = Colors.orange;
    } else if (_blinkCount < 3) {
      instruction = "Blink your eyes ($_blinkCount/3)";
      statusColor = Colors.purple;
    } else {
      instruction = "Success! Capture complete";
      statusColor = Colors.green;
    }

    return Column(
      children: [
        _buildStepIndicator(),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: statusColor.withAlpha(26),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: statusColor.withAlpha(128)),
          ),
          child: Text(
            instruction,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: statusColor,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    showImage =
        _thirdBlinkPhotoPath ?? _firstBlinkPhotoPath ?? _headTurnPhotoPath;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: Text("Self Live Photo"), centerTitle: true),
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
                      // border: Border.all(
                      //   color: _cameraStopped ? Colors.green : Colors.blue.withAlpha(126),
                      //   width: 4,
                      // ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: (_cameraStopped)
                        ? (_thirdBlinkPhotoPath != null || showImage != null
                              ? Image.file(
                                  File(_thirdBlinkPhotoPath ?? showImage!),
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: double.infinity,
                                )
                              : const Center(child: Text("Processing...")))
                        : (_controller.value.isInitialized)
                        ? FittedBox(
                            fit: BoxFit.cover,
                            child: SizedBox(
                              width: _controller.value.previewSize!.height,
                              height: _controller.value.previewSize!.width,
                              child: CameraPreview(_controller),
                            ),
                          )
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
                      showBackButton: true,
                      backButtonText: "Restart",
                      onBackButtonTap: _restartCamera,
                      onTopButtonTap: () async {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DisplayImageScreen(
                              blink1Path: _firstBlinkPhotoPath,
                              blink3Path: _thirdBlinkPhotoPath,
                              headTurnPath: _headTurnPhotoPath,
                              leftTurnPath: _leftTurnPhotoPath,
                              rightTurnPath: _rightTurnPhotoPath,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
