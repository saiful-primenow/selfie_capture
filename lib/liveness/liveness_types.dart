import 'dart:math';

enum LivenessStepType { blink, smile, turnLeft, turnRight }

class FaceSample {
  const FaceSample({
    required this.timestamp,
    required this.faceCount,
    required this.centered,
    required this.yaw,
    required this.leftEyeOpen,
    required this.rightEyeOpen,
    required this.smile,
    required this.mouthOpen,
    required this.faceWidthRatio,
    required this.centerX,
    required this.centerY,
  });

  final DateTime timestamp;
  final int faceCount;
  final bool centered;
  final double yaw;
  final double leftEyeOpen;
  final double rightEyeOpen;
  final double smile;
  final double mouthOpen;
  final double faceWidthRatio;
  final double centerX;
  final double centerY;
}

class LivenessResult {
  const LivenessResult({
    required this.passed,
    this.confidence,
    this.reasonCode,
    this.vendorSessionId,
    this.meta = const <String, dynamic>{},
  });

  final bool passed;
  final double? confidence;
  final String? reasonCode;
  final String? vendorSessionId;
  final Map<String, dynamic> meta;
}

class LivenessSession {
  const LivenessSession({required this.sessionId, this.meta = const <String, dynamic>{}});

  final String sessionId;
  final Map<String, dynamic> meta;
}

class LivenessPayload {
  const LivenessPayload({
    required this.precheckPassed,
    required this.providerPassed,
    required this.providerMeta,
  });

  final bool precheckPassed;
  final bool providerPassed;
  final Map<String, dynamic> providerMeta;
}

class LivenessStatus {
  const LivenessStatus({
    required this.precheckPassed,
    required this.finished,
    required this.failed,
    required this.message,
    this.activeStep,
    this.progress = 0,
  });

  final bool precheckPassed;
  final bool finished;
  final bool failed;
  final String message;
  final LivenessStepType? activeStep;
  final int progress;
}

List<LivenessStepType> defaultChallengeSteps(Random random) {
  final steps = <LivenessStepType>[
    LivenessStepType.blink,
    LivenessStepType.smile,
    LivenessStepType.turnLeft,
    LivenessStepType.turnRight,
  ];
  steps.shuffle(random);
  return steps;
}
