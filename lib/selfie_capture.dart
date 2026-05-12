import 'dart:convert';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart' as fd;
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import 'action_button.dart';
import 'display_image.dart';
import 'liveness/liveness_orchestrator.dart';
import 'liveness/liveness_provider.dart';
import 'liveness/liveness_types.dart';
import 'liveness/mlkit_precheck_engine.dart';

class SelfieCapture extends StatefulWidget {
  const SelfieCapture({
    super.key,
    required this.camera,
    this.livenessProvider,
    this.enableDebugBypass = false,
  });

  final CameraDescription camera;
  final LivenessProvider? livenessProvider;
  final bool enableDebugBypass;

  @override
  State<SelfieCapture> createState() => _SelfieCaptureState();
}

class _SelfieCaptureState extends State<SelfieCapture> {
  late CameraController _controller;
  bool _isDetecting = false;
  bool _isCapturing = false;
  bool _cameraStopped = false;
  bool _cameraStreaming = false;
  String _status = 'Initializing camera...';

  String? _firstBlinkPhotoPath;
  String? _thirdBlinkPhotoPath;
  String? _leftTurnPhotoPath;
  String? _rightTurnPhotoPath;
  String? _headTurnPhotoPath;
  String? _finalImageBase64;

  fd.FaceDetector? _faceDetector;
  late final ImageLabeler _imageLabeler;
  late final LivenessOrchestrator _orchestrator;
  bool _isSunglassesDetected = false;
  bool _isScreenDetected = false;
  bool _isHeadCapDetected = false;
  bool _isMaskDetected = false;

  LivenessPayload? _payload;
  bool _providerInProgress = false;

  @override
  void initState() {
    super.initState();
    _faceDetector = fd.FaceDetector(
      options: fd.FaceDetectorOptions(
        performanceMode: fd.FaceDetectorMode.fast,
        enableLandmarks: false,
        enableContours: false,
        enableClassification: true,
        enableTracking: true,
        minFaceSize: 0.15,
      ),
    );
    _imageLabeler = ImageLabeler(
      options: ImageLabelerOptions(confidenceThreshold: 0.55),
    );

    _orchestrator = LivenessOrchestrator(
      precheckEngine: MLKitPrecheckEngine(requiredStableFrames: 1),
      provider: widget.livenessProvider ?? MockLivenessProvider(),
      debugBypass: LivenessSecurity.isDebugBypassEnabled(
        bypassRequested: widget.enableDebugBypass,
      ),
    );

    _setupCamera();
  }

  Future<void> _setupCamera() async {
    _controller = CameraController(
      widget.camera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.bgra8888,
    );
    await _controller.initialize();
    await _orchestrator.start();
    if (!mounted) return;
    setState(() {
      _status = 'Center your face with both eyes visible';
    });
    _startImageStream();
  }

  void _startImageStream() {
    _controller.startImageStream((CameraImage image) {
      if (_isDetecting || _cameraStopped || _providerInProgress) return;
      _isDetecting = true;
      _processCameraImage(image).whenComplete(() => _isDetecting = false);
    });
    _cameraStreaming = true;
  }

  Future<void> _processCameraImage(CameraImage image) async {
    final bytes = _collectBytes(image);
    final faceInputImage = fd.InputImage.fromBytes(
      bytes: bytes,
      metadata: fd.InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: _rotationIntToFaceRotation(widget.camera.sensorOrientation),
        format: fd.InputImageFormatValue.fromRawValue(image.format.raw) ??
            fd.InputImageFormat.nv21,
        bytesPerRow: image.planes[0].bytesPerRow,
      ),
    );

    final faces = await (_faceDetector?.processImage(faceInputImage) ??
        Future.value(<fd.Face>[]));
    if (!mounted || _cameraStopped) return;

    final primaryFaceCount = faces.length;
    if (primaryFaceCount == 1) {
      final labels = await _imageLabeler.processImage(faceInputImage);
      _isSunglassesDetected = labels.any((label) {
        final value = label.label.toLowerCase();
        return (value.contains('sunglasses') || value.contains('glasses')) &&
            label.confidence >= 0.75;
      });

      _isScreenDetected = labels.any((label) {
        final value = label.label.toLowerCase();
        return (value.contains('screen') ||
                value.contains('monitor') ||
                value.contains('display') ||
                value.contains('television') ||
                value.contains('laptop') ||
                value.contains('tablet') ||
                value.contains('phone')) &&
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
    } else {
      _isSunglassesDetected = false;
      _isScreenDetected = false;
      _isHeadCapDetected = false;
      _isMaskDetected = false;
    }

    final hasBlockingPolicyIssue =
        _isSunglassesDetected || _isScreenDetected || _isHeadCapDetected || _isMaskDetected;

    if (!mounted) return;
    setState(() {
      if (_isSunglassesDetected) {
        _status = 'Sunglasses detected. Please remove glasses.';
      } else if (_isScreenDetected) {
        _status = 'Screen-like object detected. Use live face only.';
      } else if (_isHeadCapDetected) {
        _status = 'Head cap detected. Please remove cap/hat.';
      } else if (_isMaskDetected) {
        _status = 'Mask detected. Please remove mask.';
      }
    });

    if (hasBlockingPolicyIssue) {
      if (_providerInProgress) {
        setState(() {
          _providerInProgress = false;
        });
      }
      return;
    }

    final sample = _toFaceSample(
      faces: faces,
      frameWidth: image.width.toDouble(),
      frameHeight: image.height.toDouble(),
    );
    final status = _orchestrator.evaluate(sample);

    if (!mounted) return;
    setState(() {
      _status = status.message;
    });

    if (status.finished && !status.failed && !_providerInProgress) {
      await _captureFinalAndVerify();
      return;
    }

    if (status.failed) {
      setState(() {
        _status = status.message;
      });
    }

  }

  Uint8List _collectBytes(CameraImage image) {
    final WriteBuffer allBytes = WriteBuffer();
    for (final plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    return allBytes.done().buffer.asUint8List();
  }

  FaceSample _toFaceSample({
    required List<fd.Face> faces,
    required double frameWidth,
    required double frameHeight,
  }) {
    if (faces.length != 1) {
      return FaceSample(
        timestamp: DateTime.now(),
        faceCount: faces.length,
        centered: false,
        yaw: 0,
        leftEyeOpen: 0,
        rightEyeOpen: 0,
        smile: 0,
        mouthOpen: 0,
        faceWidthRatio: 0,
        centerX: 0,
        centerY: 0,
      );
    }

    final face = faces.first;
    final box = face.boundingBox;
    final centerX = (box.left + box.width / 2) / frameWidth;
    final centerY = (box.top + box.height / 2) / frameHeight;
    final centered = (centerX - 0.5).abs() < 0.32 && (centerY - 0.5).abs() < 0.32;

    final yaw = Platform.isIOS
        ? -(face.headEulerAngleY ?? 0)
        : (face.headEulerAngleY ?? 0);

    return FaceSample(
      timestamp: DateTime.now(),
      faceCount: 1,
      centered: centered,
      yaw: yaw,
      leftEyeOpen: face.leftEyeOpenProbability ?? 0.5,
      rightEyeOpen: face.rightEyeOpenProbability ?? 0.5,
      smile: face.smilingProbability ?? 0,
      mouthOpen: 0,
      faceWidthRatio: box.width / frameWidth,
      centerX: centerX,
      centerY: centerY,
    );
  }

  Future<void> _captureFinalAndVerify() async {
    final hasBlockingPolicyIssue =
        _isSunglassesDetected || _isScreenDetected || _isHeadCapDetected || _isMaskDetected;
    if (hasBlockingPolicyIssue) {
      setState(() {
        _providerInProgress = false;
        if (_isSunglassesDetected) {
          _status = 'Sunglasses detected. Please remove glasses.';
        } else if (_isScreenDetected) {
          _status = 'Screen-like object detected. Use live face only.';
        } else if (_isHeadCapDetected) {
          _status = 'Head cap detected. Please remove cap/hat.';
        } else if (_isMaskDetected) {
          _status = 'Mask detected. Please remove mask.';
        }
      });
      return;
    }

    setState(() {
      _providerInProgress = true;
      _status = 'Precheck done. Verifying liveness...';
    });

    if (_cameraStreaming) {
      await _controller.stopImageStream();
      _cameraStreaming = false;
    }

    final finalPath = await _capturePhoto(type: 'blink3', returnPathOnly: true);
    if (finalPath != null) {
      _finalImageBase64 = await _convertImageToBase64(finalPath);
    }

    final payload = await _orchestrator.finalize(
      sessionData: <String, dynamic>{
        'finalImageBase64Length': _finalImageBase64?.length ?? 0,
      },
    );

    if (!mounted) return;
    setState(() {
      _payload = payload;
      _providerInProgress = false;
    });

    if (!payload.providerPassed) {
      final reason = payload.providerMeta['reasonCode']?.toString() ?? '';
      setState(() {
        if (reason == 'MLKIT_ONLY_REPLAY_RISK') {
          _status =
              'Replay/video risk detected. ML Kit only mode cannot verify real liveness.';
        } else {
          _status = 'Liveness provider rejected. Please retry.';
        }
      });
      return;
    }

    await _stopCamera();
    setState(() {
      _status = 'Liveness verified successfully';
    });
  }

  Future<String?> _capturePhoto({required String type, bool returnPathOnly = false}) async {
    if (_isCapturing || _cameraStopped) return null;
    _isCapturing = true;
    try {
      await _controller.setFlashMode(FlashMode.off);
      final image = await _controller.takePicture();
      final directory = await getApplicationDocumentsDirectory();
      final fileName = path.join(
        directory.path,
        '${type}_photo_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await File(image.path).copy(fileName);
      await _normalizeFrontCameraImage(fileName);

      if (!mounted) return fileName;
      setState(() {
        if (type == 'blink1') {
          _firstBlinkPhotoPath ??= fileName;
        } else if (type == 'blink3') {
          _thirdBlinkPhotoPath = fileName;
        } else if (type == 'head') {
          _headTurnPhotoPath = fileName;
        } else if (type == 'left') {
          _leftTurnPhotoPath ??= fileName;
        } else if (type == 'right') {
          _rightTurnPhotoPath ??= fileName;
        }
      });

      if (returnPathOnly) return fileName;
      return fileName;
    } catch (_) {
      return null;
    } finally {
      _isCapturing = false;
    }
  }

  Future<void> _normalizeFrontCameraImage(String imagePath) async {
    if (widget.camera.lensDirection != CameraLensDirection.front) {
      return;
    }

    final file = File(imagePath);
    final bytes = await file.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return;

    // Front camera captures are often mirrored; store as non-mirrored.
    final corrected = img.flipHorizontal(decoded);
    await file.writeAsBytes(img.encodeJpg(corrected, quality: 95), flush: true);
  }

  Future<String> _convertImageToBase64(String imagePath) async {
    final bytes = await File(imagePath).readAsBytes();
    return base64Encode(bytes);
  }

  Future<String> compressBase64Image(String base64Image, {int quality = 20}) async {
    final imageBytes = base64Decode(base64Image);
    final image = img.decodeImage(imageBytes);
    if (image == null) {
      throw Exception('Failed to decode image');
    }
    final compressedBytes = img.encodeJpg(image, quality: quality);
    return base64Encode(compressedBytes);
  }

  Future<void> _stopCamera() async {
    if (_cameraStopped) return;
    if (_cameraStreaming) {
      await _controller.stopImageStream();
      _cameraStreaming = false;
    }
    _cameraStopped = true;
    await _controller.dispose();
  }

  Future<void> _restartCamera() async {
    if (!_cameraStopped) {
      await _stopCamera();
    }

    setState(() {
      _cameraStopped = false;
      _providerInProgress = false;
      _payload = null;
      _status = 'Restarted. Center your face with both eyes visible';
      _firstBlinkPhotoPath = null;
      _thirdBlinkPhotoPath = null;
      _leftTurnPhotoPath = null;
      _rightTurnPhotoPath = null;
      _headTurnPhotoPath = null;
      _finalImageBase64 = null;
    });

    _orchestrator.restart();
    await _setupCamera();
  }

  fd.InputImageRotation _rotationIntToFaceRotation(int rotation) {
    switch (rotation) {
      case 90:
        return fd.InputImageRotation.rotation90deg;
      case 180:
        return fd.InputImageRotation.rotation180deg;
      case 270:
        return fd.InputImageRotation.rotation270deg;
      default:
        return fd.InputImageRotation.rotation0deg;
    }
  }

  @override
  void dispose() {
    if (!_cameraStopped) {
      _controller.dispose();
    }
    _faceDetector?.close();
    _imageLabeler.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showImage = _thirdBlinkPhotoPath ?? _firstBlinkPhotoPath ?? _headTurnPhotoPath;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Self Live Photo'),
        centerTitle: true,
        actions: [
          if (LivenessSecurity.isDebugBypassEnabled(bypassRequested: widget.enableDebugBypass))
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Center(
                child: Text(
                  'TEST MODE',
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.blue.withAlpha(25),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.blue.withAlpha(80)),
              ),
              child: Text(
                _status,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 34),
            Container(
              width: 250,
              height: 250,
              decoration: const BoxDecoration(shape: BoxShape.circle),
              clipBehavior: Clip.antiAlias,
              child: (_cameraStopped)
                  ? (showImage != null
                        ? Image.file(File(showImage), fit: BoxFit.cover)
                        : const Center(child: Text('No image captured')))
                  : (_controller.value.isInitialized
                        ? FittedBox(
                            fit: BoxFit.cover,
                            child: SizedBox(
                              width: _controller.value.previewSize!.height,
                              height: _controller.value.previewSize!.width,
                              child: CameraPreview(_controller),
                            ),
                          )
                        : const Center(child: CircularProgressIndicator())),
            ),
            const SizedBox(height: 50),
            if (_payload != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Text(
                  'precheckPassed=${_payload!.precheckPassed}, providerPassed=${_payload!.providerPassed}, providerMeta=${_payload!.providerMeta}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ActionButton(
                customPadding: 16,
                parentContext: context,
                topButtonText: 'Continue',
                isTopButtonDisabled: !_cameraStopped || _payload?.providerPassed != true,
                useActiveBackground: _cameraStopped && _payload?.providerPassed == true,
                activeBackgroundImage: 'assets/button_background_2.png',
                disabledBackgroundImage: 'assets/button_background_grey.png',
                showBackButton: true,
                backButtonText: 'Restart',
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
