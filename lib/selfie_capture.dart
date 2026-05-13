import 'dart:convert';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
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

  final _imageLabeler = ImageLabeler(
    options: ImageLabelerOptions(confidenceThreshold: 0.5),
  );
  bool _isGlassesDetected = false;
  bool _isScreenDetected = false;
  bool _isHeadCapDetected = false;
  bool _isMaskDetected = false;

  // Liveness Flow Variables
  final List<String> _steps = [];
  int _currentStepIndex = 0;

  static const int REQUIRED_STABLE_FRAMES = 1;
  String message = "Blink Your Eyes";

  final _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.fast,
      enableLandmarks: true,
      enableContours: true,
      enableClassification: true,
      enableTracking: true,
      //minFaceSize: 0.15,
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
      _setupRandomSteps();
      setState(() {});
      _startImageStream();
    });
    _initializeControllerFuture;
  }

  void _setupRandomSteps() {
    _steps.clear();
    final allSteps = ['left', 'right', 'smile', 'blink'];
    allSteps.shuffle();
    _steps.addAll(allSteps);
    _currentStepIndex = 0;
    debugPrint("Steps initialized: $_steps");
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

    // Check for glasses/sunglasses and screens (potential video/spoof)
    if (faces.length == 1) {
      final face = faces.first;
      final labels = await _imageLabeler.processImage(inputImage);

      _isGlassesDetected = labels.any((label) {
        final l = label.label.toLowerCase();
        return (l.contains('glasses') || l.contains('sunglasses')) &&
            label.confidence > 0.8;
      });

      _isScreenDetected = labels.any((label) {
        final l = label.label.toLowerCase();
        return (l.contains('monitor') ||
                l.contains('screen') ||
                l.contains('television') ||
                l.contains('display') ||
                l.contains('phone') ||
                l.contains('tablet') ||
                l.contains('laptop') ||
                l.contains('electronics')) &&
            label.confidence >= 0.60;
      });

      _isHeadCapDetected = labels.any((label) {
        final value = label.label.toLowerCase();
        return (value.contains('cap') ||
                value.contains('hat') ||
                value.contains('headwear') ||
                value.contains('helmet') ||
                value.contains('beanie') ||
                value.contains('head covering')) &&
            label.confidence >= 0.50;
      });

      _isMaskDetected = labels.any((label) {
        final value = label.label.toLowerCase();
        return (value.contains('mask') ||
                value.contains('face mask') ||
                value.contains('medical mask') ||
                value.contains('respirator')) &&
            label.confidence >= 0.60;
      });

      // Heuristic: If face is too close (occupies > 80% of frame),
      // it's often a sign of spoofing or bad framing where screen edges are hidden.
      final double faceWidth = face.boundingBox.width;
      final double frameWidth = image.width.toDouble();
      if ((faceWidth / frameWidth) > 0.80) {
        _isScreenDetected = true;
      }
    } else {
      _isGlassesDetected = false;
      _isScreenDetected = false;
      _isHeadCapDetected = false;
      _isMaskDetected = false;
    }

    setState(() {
      if (faces.length == 1) {
        if (_isGlassesDetected) {
          message = "Please remove your glasses";
          _currentFace == null;
        } else if (_isHeadCapDetected) {
          message = "Please remove your hat/cap";
          _currentFace == null;
        } else if (_isMaskDetected) {
          message = "Please remove your mask";
          _currentFace == null;
        } else if (_isScreenDetected) {
          message = "Digital screen detected. Use a real face.";
          _currentFace == null;
        } else {
          _currentFace = faces.first;
          _processCurrentStep();
        }
      } else {
        _currentFace = null;
        if (faces.length > 1) {
          message = "Multiple faces detected!";
        }
      }
    });
  }

  void _processCurrentStep() {
    if (_currentStepIndex >= _steps.length || _cameraStopped) return;

    final step = _steps[_currentStepIndex];
    switch (step) {
      case 'left':
        _checkHeadTurn(isLeft: true);
        break;
      case 'right':
        _checkHeadTurn(isLeft: false);
        break;
      case 'smile':
        _checkSmile();
        break;
      case 'blink':
        _checkBlink();
        break;
    }
  }

  void _checkHeadTurn({required bool isLeft}) {
    double yAngle = _currentFace?.headEulerAngleY ?? 0;
    if (Platform.isIOS) yAngle = -yAngle;

    if (isLeft ? yAngle > 18 : yAngle < -18) {
      if (isLeft) {
        _rightStableCount++;
        if (_rightStableCount >= REQUIRED_STABLE_FRAMES) {
          _completeStep('left');
        }
      } else {
        _leftStableCount++;
        if (_leftStableCount >= REQUIRED_STABLE_FRAMES) {
          _completeStep('right');
        }
      }
    } else {
      isLeft ? _rightStableCount = 0 : _leftStableCount = 0;
    }
  }

  void _checkSmile() {
    final smileProb = _currentFace?.smilingProbability ?? 0;
    if (smileProb >= 0.85) {
      _completeStep('smile');
    }
  }

  void _checkBlink() {
    final leftEye = _currentFace!.leftEyeOpenProbability ?? 1.0;
    final rightEye = _currentFace!.rightEyeOpenProbability ?? 1.0;

    bool currentlyClosed = leftEye < 0.15 && rightEye < 0.15;
    bool currentlyOpen = leftEye > 0.85 && rightEye > 0.85;

    if (currentlyClosed && !_eyesWereClosed && !_isCapturing) {
      _eyesWereClosed = true;
      _blinkCount++;
      if (_blinkCount == 1) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) _capturePhoto(type: 'blink1');
        });
      }
      if (_blinkCount >= 3) {
        _completeStep('blink');
      }
      setState(() {});
    } else if (currentlyOpen && _eyesWereClosed) {
      _eyesWereClosed = false;
      setState(() {});
    }
  }

  void _completeStep(String type) {
    setState(() {
      _currentStepIndex++;

      String captureType = type;
      if (type == 'blink') {
        captureType = 'blink3';
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) _capturePhoto(type: 'blink3');
        });
      } else {
        if (type == 'smile') {
          hasSmiled = true;
          captureType = 'head';
        }
        _capturePhoto(type: captureType);
      }
    });
  }

  // Capturing photo
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
        } else if (type == 'blink3') {
          _thirdBlinkPhotoPath = fileName;
        } else if (type == 'head') {
          _headTurnPhotoPath = fileName;
        } else if (type == 'left') {
          _leftTurnPhotoPath = fileName;
        } else if (type == 'right') {
          _rightTurnPhotoPath = fileName;
        }

        if (_currentStepIndex == _steps.length) {
          _cameraStopped = true;
        }
      });

      // Stop camera properly if all steps completed
      if (_currentStepIndex == _steps.length) {
        message = "Success! All steps complete";
        _stopCamera();

        final lastPath = fileName;
        convertImageToBase64(lastPath, (base64) {
          convertedImage = base64;
          debugPrint("Final image conversion complete");
        });
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
      hasSmiled = false;
      _blinkCount = 0;
      _firstBlinkPhotoPath = null;
      _thirdBlinkPhotoPath = null;
      _headTurnPhotoPath = null;
      _leftTurnPhotoPath = null;
      _rightTurnPhotoPath = null;
      _setupRandomSteps();
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
    _imageLabeler.close();
    super.dispose();
  }

  Widget _buildStepIndicator() {
    if (_currentStepIndex >= _steps.length || _cameraStopped || _currentFace == null) {
      return const SizedBox.shrink();
    }

    final step = _steps[_currentStepIndex];
    IconData? icon;
    switch (step) {
      case 'left':
        icon = Icons.turn_left;
        break;
      case 'right':
        icon = Icons.turn_right;
        break;
      case 'smile':
        icon = Icons.sentiment_satisfied;
        break;
      case 'blink':
        icon = Icons.remove_red_eye;
        break;
    }

    if (icon == null) {
      return const SizedBox.shrink();
    }

    return Center(child: _stepIcon(icon, false, true));
  }

  Widget _stepIcon(IconData icon, bool completed, bool isCurrent) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: completed
            ? Colors.green
            : (isCurrent ? Colors.blue : Colors.grey.shade300),
        shape: BoxShape.circle,
        border: isCurrent
            ? Border.all(color: Colors.blue.withAlpha(64), width: 4)
            : null,
      ),
      child: Icon(icon, color: Colors.white, size: isCurrent ? 24 : 18),
    );
  }

  Widget _buildStatusPanel() {
    String instruction = "";
    Color statusColor = Colors.blue;

    if (_cameraStopped) {
      instruction = "Success! Capture complete";
      statusColor = Colors.green;
    } else if (_currentFace == null) {
      if (_isGlassesDetected) {
        instruction = message;
      } else if (_isScreenDetected) {
        instruction = message;
      } else if (_isHeadCapDetected) {
        instruction = message;
      } else if (_isMaskDetected) {
        instruction = message;
      } else {
        instruction = "Center your face in the frame";
      }
      statusColor = Colors.red;
    } else if (_currentStepIndex < _steps.length) {
      final step = _steps[_currentStepIndex];
      statusColor = Colors.blue;
      if (step == 'left') {
        instruction = "Turn Head Left";
      } else if (step == 'right') {
        instruction = "Turn Head Right";
      } else if (step == 'smile') {
        instruction = "Now Smile!";
        statusColor = Colors.orange;
      } else if (step == 'blink') {
        instruction = "Blink your eyes ($_blinkCount/3)";
        statusColor = Colors.purple;
      }
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
                    decoration: const BoxDecoration(shape: BoxShape.circle),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: (_cameraStopped)
                              ? (_thirdBlinkPhotoPath != null ||
                                        showImage != null
                                    ? Image.file(
                                        File(
                                          _thirdBlinkPhotoPath ?? showImage!,
                                        ),
                                        fit: BoxFit.cover,
                                      )
                                    : const Center(
                                        child: Text("Processing..."),
                                      ))
                              : (_controller.value.isInitialized)
                              ? FittedBox(
                                  fit: BoxFit.cover,
                                  child: SizedBox(
                                    width:
                                        _controller.value.previewSize!.height,
                                    height:
                                        _controller.value.previewSize!.width,
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
                        if (_controller.value.isInitialized || _cameraStopped)
                          Positioned.fill(
                            child: Padding(
                              padding: const EdgeInsets.all(2.0),
                              child: CircularProgressIndicator(
                                value: _cameraStopped ? 1.0 : (_blinkCount / 3),
                                strokeWidth: 14,
                                backgroundColor: Color(0xFFE5E7EA),
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Color(0xFFFAB0FF),
                                ),
                              ),
                            ),
                          ),
                      ],
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
