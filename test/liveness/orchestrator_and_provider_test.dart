import 'package:flutter_test/flutter_test.dart';
import 'package:selfie_capture/liveness/liveness_orchestrator.dart';
import 'package:selfie_capture/liveness/liveness_provider.dart';
import 'package:selfie_capture/liveness/liveness_types.dart';
import 'package:selfie_capture/liveness/mlkit_precheck_engine.dart';

FaceSample sampleNow() => FaceSample(
      timestamp: DateTime.now(),
      faceCount: 1,
      centered: true,
      yaw: 0,
      leftEyeOpen: 0.95,
      rightEyeOpen: 0.95,
      smile: 0.95,
      mouthOpen: 0.7,
      faceWidthRatio: 0.5,
      centerX: 0.5,
      centerY: 0.5,
    );

void main() {
  test('debug bypass enabled only in debug flag', () {
    expect(
      LivenessSecurity.isDebugBypassEnabled(
        bypassRequested: true,
        debugFlag: true,
      ),
      isTrue,
    );

    expect(
      LivenessSecurity.isDebugBypassEnabled(
        bypassRequested: true,
        debugFlag: false,
      ),
      isFalse,
    );
  });

  test('provider result is mapped into payload', () async {
    final provider = MockLivenessProvider(
      forcedResult: const LivenessResult(
        passed: false,
        confidence: 0.2,
        reasonCode: 'SPOOF_DETECTED',
        vendorSessionId: 'vendor-1',
        meta: <String, dynamic>{'provider': 'mock'},
      ),
    );

    final orchestrator = LivenessOrchestrator(
      precheckEngine: MLKitPrecheckEngine(requiredStableFrames: 1),
      provider: provider,
    );

    await orchestrator.start();
    final payload = await orchestrator.finalize(sessionData: const <String, dynamic>{});

    expect(payload.precheckPassed, isTrue);
    expect(payload.providerPassed, isFalse);
    expect(payload.providerMeta['reasonCode'], 'SPOOF_DETECTED');
  });

  test('orchestrator gives precheck guidance before completion', () async {
    final orchestrator = LivenessOrchestrator(
      precheckEngine: MLKitPrecheckEngine(requiredStableFrames: 1),
      provider: MockLivenessProvider(),
    );

    await orchestrator.start();
    final status = orchestrator.evaluate(sampleNow());
    expect(status.finished, isFalse);
    expect(status.precheckPassed, isTrue);
  });
}
