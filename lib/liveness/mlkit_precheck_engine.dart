import 'liveness_types.dart';

class MLKitPrecheckEngine {
  MLKitPrecheckEngine({
    this.requiredStableFrames = 1,
    this.maxCenterDelta = 0.12,
    this.leftYawThreshold = 18,
    this.rightYawThreshold = -18,
    this.smileThreshold = 0.8,
    this.eyeClosedThreshold = 0.2,
    this.eyeOpenThreshold = 0.8,
  });

  final int requiredStableFrames;
  final double maxCenterDelta;
  final double leftYawThreshold;
  final double rightYawThreshold;
  final double smileThreshold;
  final double eyeClosedThreshold;
  final double eyeOpenThreshold;

  FaceSample? _prev;
  int _stableCounter = 0;
  bool _eyesWereClosed = false;
  int _blinkCycles = 0;

  void resetPerStep() {
    _stableCounter = 0;
    _eyesWereClosed = false;
    _blinkCycles = 0;
  }

  bool isReadyForChallenge(FaceSample sample) {
    final oneFace = sample.faceCount == 1;
    final result = oneFace && sample.centered;
    _prev = sample;
    return result;
  }

  bool validateStep(LivenessStepType step, FaceSample sample) {
    final requiresCentering = step != LivenessStepType.turnLeft && step != LivenessStepType.turnRight;
    if (sample.faceCount != 1 || (requiresCentering && !sample.centered)) {
      _stableCounter = 0;
      _prev = sample;
      return false;
    }

    final smooth = _isSmooth(sample);
    if (!smooth) {
      _stableCounter = 0;
      _prev = sample;
      return false;
    }

    final matched = switch (step) {
      LivenessStepType.blink => _isBlinkCycle(sample),
      LivenessStepType.smile => sample.smile >= smileThreshold,
      LivenessStepType.turnLeft => sample.yaw >= leftYawThreshold,
      LivenessStepType.turnRight => sample.yaw <= rightYawThreshold,
    };

    if (matched) {
      _stableCounter += 1;
    } else {
      _stableCounter = 0;
    }

    _prev = sample;
    return _stableCounter >= requiredStableFrames;
  }

  bool _isSmooth(FaceSample current) {
    if (_prev == null) return true;
    final dx = (current.centerX - _prev!.centerX).abs();
    final dy = (current.centerY - _prev!.centerY).abs();
    return dx <= maxCenterDelta && dy <= maxCenterDelta;
  }

  bool _isBlinkCycle(FaceSample sample) {
    final closed = sample.leftEyeOpen < eyeClosedThreshold && sample.rightEyeOpen < eyeClosedThreshold;
    final open = sample.leftEyeOpen > eyeOpenThreshold && sample.rightEyeOpen > eyeOpenThreshold;

    if (closed && !_eyesWereClosed) {
      _eyesWereClosed = true;
      return false;
    }

    if (open && _eyesWereClosed) {
      _eyesWereClosed = false;
      _blinkCycles += 1;
      return _blinkCycles >= 2;
    }

    return false;
  }
}
