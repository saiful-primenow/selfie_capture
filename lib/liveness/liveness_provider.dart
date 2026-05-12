import 'package:flutter/foundation.dart';

import 'liveness_types.dart';

abstract class LivenessProvider {
  Future<LivenessSession> startSession();
  Future<LivenessResult> verify(Map<String, dynamic> sessionData);
}

class MockLivenessProvider implements LivenessProvider {
  MockLivenessProvider({
    this.forcedResult,
    this.allowMlKitOnlyPass = true,
  });

  final LivenessResult? forcedResult;
  final bool allowMlKitOnlyPass;

  @override
  Future<LivenessSession> startSession() async {
    return LivenessSession(
      sessionId: DateTime.now().microsecondsSinceEpoch.toString(),
      meta: const <String, dynamic>{'provider': 'mock'},
    );
  }

  @override
  Future<LivenessResult> verify(Map<String, dynamic> sessionData) async {
    if (forcedResult != null) return forcedResult!;
    if (allowMlKitOnlyPass) {
      return const LivenessResult(
        passed: true,
        confidence: 0.90,
        reasonCode: 'MLKIT_ONLY_PASS',
        vendorSessionId: 'mock-session',
        meta: <String, dynamic>{'provider': 'mock'},
      );
    }
    return const LivenessResult(
      passed: false,
      confidence: 0.0,
      reasonCode: 'MLKIT_ONLY_REPLAY_RISK',
      vendorSessionId: 'mock-session',
      meta: <String, dynamic>{'provider': 'mock'},
    );
  }
}

class LivenessSecurity {
  static bool isDebugBypassEnabled({
    required bool bypassRequested,
    bool debugFlag = kDebugMode,
  }) {
    return debugFlag && bypassRequested;
  }
}
