import 'dart:math';

import 'liveness_provider.dart';
import 'liveness_types.dart';
import 'mlkit_precheck_engine.dart';

class LivenessOrchestrator {
  LivenessOrchestrator({
    required this.precheckEngine,
    required this.provider,
    Random? random,
    this.precheckTimeout = const Duration(seconds: 20),
    this.sessionTimeout = const Duration(seconds: 90),
    this.stepTimeout = const Duration(seconds: 12),
    this.debugBypass = false,
  }) : _random = random ?? Random() {
    _steps = defaultChallengeSteps(_random);
  }

  final MLKitPrecheckEngine precheckEngine;
  final LivenessProvider provider;
  final Random _random;
  final Duration precheckTimeout;
  final Duration sessionTimeout;
  final Duration stepTimeout;
  final bool debugBypass;

  late List<LivenessStepType> _steps;
  int _index = 0;
  DateTime? _startedAt;
  DateTime? _stepStartedAt;
  LivenessSession? _providerSession;

  Future<void> start() async {
    _startedAt = DateTime.now();
    _stepStartedAt = _startedAt;
    _providerSession = await provider.startSession();
  }

  void restart() {
    _index = 0;
    _steps = defaultChallengeSteps(_random);
    precheckEngine.resetPerStep();
    _startedAt = DateTime.now();
    _stepStartedAt = _startedAt;
  }

  LivenessStatus evaluate(FaceSample sample) {
    final now = sample.timestamp;
    if (_startedAt == null) {
      _startedAt = now;
      _stepStartedAt = now;
    }

    if (now.difference(_startedAt!) > sessionTimeout) {
      return const LivenessStatus(
        precheckPassed: false,
        finished: true,
        failed: true,
        message: 'Liveness session timed out',
      );
    }

    final ready = precheckEngine.isReadyForChallenge(sample);
    if (!ready && now.difference(_startedAt!) <= precheckTimeout) {
      return const LivenessStatus(
        precheckPassed: false,
        finished: false,
        failed: false,
        message: 'Center your face with both eyes visible',
      );
    }

    if (!ready && now.difference(_startedAt!) > precheckTimeout) {
      return const LivenessStatus(
        precheckPassed: false,
        finished: true,
        failed: true,
        message: 'Precheck timeout. Please retry.',
      );
    }

    final current = _steps[_index];
    if (now.difference(_stepStartedAt!) > stepTimeout) {
      return LivenessStatus(
        precheckPassed: true,
        finished: true,
        failed: true,
        message: '${_label(current)} step timeout',
        activeStep: current,
        progress: _index,
      );
    }

    final ok = precheckEngine.validateStep(current, sample);
    if (!ok) {
      return LivenessStatus(
        precheckPassed: true,
        finished: false,
        failed: false,
        message: _instruction(current),
        activeStep: current,
        progress: _index,
      );
    }

    _index += 1;
    precheckEngine.resetPerStep();
    _stepStartedAt = now;

    if (_index >= _steps.length) {
      return const LivenessStatus(
        precheckPassed: true,
        finished: true,
        failed: false,
        message: 'Precheck complete',
        progress: 4,
      );
    }

    final next = _steps[_index];
    return LivenessStatus(
      precheckPassed: true,
      finished: false,
      failed: false,
      message: _instruction(next),
      activeStep: next,
      progress: _index,
    );
  }

  Future<LivenessPayload> finalize({required Map<String, dynamic> sessionData}) async {
    if (LivenessSecurity.isDebugBypassEnabled(bypassRequested: debugBypass)) {
      return const LivenessPayload(
        precheckPassed: true,
        providerPassed: true,
        providerMeta: <String, dynamic>{'bypass': true, 'reasonCode': 'DEBUG_BYPASS'},
      );
    }

    final merged = <String, dynamic>{
      'providerSessionId': _providerSession?.sessionId,
      ...sessionData,
    };
    final result = await provider.verify(merged);
    return LivenessPayload(
      precheckPassed: true,
      providerPassed: result.passed,
      providerMeta: <String, dynamic>{
        'confidence': result.confidence,
        'reasonCode': result.reasonCode,
        'vendorSessionId': result.vendorSessionId,
        ...result.meta,
      },
    );
  }

  String _instruction(LivenessStepType step) {
    return switch (step) {
      LivenessStepType.blink => 'Blink twice',
      LivenessStepType.smile => 'Smile naturally',
      LivenessStepType.turnLeft => 'Turn head left',
      LivenessStepType.turnRight => 'Turn head right',
    };
  }

  String _label(LivenessStepType step) {
    return switch (step) {
      LivenessStepType.blink => 'Blink',
      LivenessStepType.smile => 'Smile',
      LivenessStepType.turnLeft => 'Turn left',
      LivenessStepType.turnRight => 'Turn right',
    };
  }
}
