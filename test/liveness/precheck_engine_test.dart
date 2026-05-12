import 'package:flutter_test/flutter_test.dart';
import 'package:selfie_capture/liveness/liveness_types.dart';
import 'package:selfie_capture/liveness/mlkit_precheck_engine.dart';

FaceSample sample({
  int faceCount = 1,
  bool centered = true,
  double yaw = 0,
  double leftEye = 0.95,
  double rightEye = 0.95,
  double smile = 0.1,
  double mouthOpen = 0.1,
  double widthRatio = 0.3,
  double cx = 0.5,
  double cy = 0.5,
}) {
  return FaceSample(
    timestamp: DateTime.now(),
    faceCount: faceCount,
    centered: centered,
    yaw: yaw,
    leftEyeOpen: leftEye,
    rightEyeOpen: rightEye,
    smile: smile,
    mouthOpen: mouthOpen,
    faceWidthRatio: widthRatio,
    centerX: cx,
    centerY: cy,
  );
}

void main() {
  test('precheck ready requires one centered face with visible eyes', () {
    final engine = MLKitPrecheckEngine();
    expect(engine.isReadyForChallenge(sample()), isTrue);
    expect(engine.isReadyForChallenge(sample(faceCount: 2)), isFalse);
    expect(engine.isReadyForChallenge(sample(centered: false)), isFalse);
  });

  test('blink step completes only after open->closed->open x2 cycles', () {
    final engine = MLKitPrecheckEngine(requiredStableFrames: 1);
    engine.isReadyForChallenge(sample());

    expect(engine.validateStep(LivenessStepType.blink, sample(leftEye: 0.9, rightEye: 0.9)), isFalse);
    expect(engine.validateStep(LivenessStepType.blink, sample(leftEye: 0.1, rightEye: 0.1)), isFalse);
    expect(engine.validateStep(LivenessStepType.blink, sample(leftEye: 0.9, rightEye: 0.9)), isFalse);
    expect(engine.validateStep(LivenessStepType.blink, sample(leftEye: 0.1, rightEye: 0.1)), isFalse);
    expect(engine.validateStep(LivenessStepType.blink, sample(leftEye: 0.9, rightEye: 0.9)), isTrue);
  });

  test('turn left requires stable frames by default', () {
    final engine = MLKitPrecheckEngine(requiredStableFrames: 2);
    engine.isReadyForChallenge(sample());

    expect(engine.validateStep(LivenessStepType.turnLeft, sample(yaw: 20)), isFalse);
    expect(engine.validateStep(LivenessStepType.turnLeft, sample(yaw: 21)), isTrue);
  });
}
