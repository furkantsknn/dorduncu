import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:dorduncu/services/app_update_service.dart';

AppVersionPolicy policy({
  int latest = 31,
  int minimum = 30,
  bool verified = true,
  Uri? url,
}) => AppVersionPolicy(
  platform: 'android',
  target: 'production',
  active: true,
  latestBuild: latest,
  minimumBuild: minimum,
  latestVersion: '1.0.0',
  minimumVersion: '1.0.0',
  messages: const <String, String>{'tr': 'Güncelle'},
  storeUrl: url ?? Uri.parse('https://play.google.com/store/apps/details?id=com.dortapp.dort'),
  storeVersionAvailable: verified,
  revisionId: 'revision-1',
);

void main() {
  test('Android ignores a test define because Play tracks are not runtime identity', () {
    expect(
      resolveDistributionTarget(
        platform: TargetPlatform.android,
        configuredTarget: 'test',
      ),
      'production',
    );
    expect(
      resolveDistributionTarget(
        platform: TargetPlatform.iOS,
        configuredTarget: 'test',
      ),
      'test',
    );
  });

  test('build number determines update despite equal display version', () {
    expect(evaluateUpdatePolicy(policy: policy(), installedBuild: 29, storeReachable: true, trustedLivePolicy: true, deferred: false).urgency, UpdateUrgency.required);
  });

  test('unverified or unreachable store never creates a mandatory lock', () {
    expect(evaluateUpdatePolicy(policy: policy(verified: false), installedBuild: 29, storeReachable: true, trustedLivePolicy: true, deferred: false).urgency, UpdateUrgency.optional);
    expect(evaluateUpdatePolicy(policy: policy(), installedBuild: 29, storeReachable: false, trustedLivePolicy: true, deferred: false).urgency, UpdateUrgency.optional);
  });

  test('offline cached policy is fail-open for minimum build', () {
    expect(evaluateUpdatePolicy(policy: policy(), installedBuild: 29, storeReachable: true, trustedLivePolicy: false, deferred: false).urgency, UpdateUrgency.optional);
  });

  test('deferral is version scoped and suppresses only optional prompt', () {
    expect(evaluateUpdatePolicy(policy: policy(minimum: 0), installedBuild: 30, storeReachable: true, trustedLivePolicy: true, deferred: true).urgency, UpdateUrgency.none);
    expect(evaluateUpdatePolicy(policy: policy(), installedBuild: 29, storeReachable: true, trustedLivePolicy: true, deferred: true).urgency, UpdateUrgency.required);
  });

  test('malformed policy fails closed to no update UI', () {
    expect(AppVersionPolicy.tryParse(<String, dynamic>{'platform': 'android', 'target': 'production', 'latestBuild': 2, 'minimumBuild': 3}), isNull);
  });
}
