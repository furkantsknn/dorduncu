import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

enum AppDistributionTarget { test, production }
enum UpdateUrgency { none, optional, required }

class AppVersionPolicy {
  const AppVersionPolicy({
    required this.platform,
    required this.target,
    required this.active,
    required this.latestBuild,
    required this.minimumBuild,
    required this.latestVersion,
    required this.minimumVersion,
    required this.messages,
    required this.storeUrl,
    required this.storeVersionAvailable,
    required this.revisionId,
  });

  final String platform;
  final String target;
  final bool active;
  final int latestBuild;
  final int minimumBuild;
  final String latestVersion;
  final String minimumVersion;
  final Map<String, String> messages;
  final Uri? storeUrl;
  final bool storeVersionAvailable;
  final String revisionId;

  static AppVersionPolicy? tryParse(Map<String, dynamic> data) {
    try {
      final String platform = _text(data['platform']).toLowerCase();
      final String target = _text(data['target']).toLowerCase();
      final int latest = _build(data['latestBuild']);
      final int minimum = _build(data['minimumBuild']);
      final Uri? url = Uri.tryParse(_text(data['storeUrl']));
      if (!const <String>{'android', 'ios'}.contains(platform) ||
          !const <String>{'test', 'production'}.contains(target) ||
          minimum > latest ||
          latest < 0 ||
          minimum < 0) {
        return null;
      }
      return AppVersionPolicy(
        platform: platform,
        target: target,
        active: data['active'] == true,
        latestBuild: latest,
        minimumBuild: minimum,
        latestVersion: _text(data['latestVersion']),
        minimumVersion: _text(data['minimumVersion']),
        messages: <String, String>{
          'tr': _text(data['messageTr']),
          'en': _text(data['messageEn']),
          'de': _text(data['messageDe']),
        },
        storeUrl: url?.hasScheme == true ? url : null,
        storeVersionAvailable: data['storeVersionAvailable'] == true,
        revisionId: _text(data['revisionId']),
      );
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'platform': platform,
    'target': target,
    'active': active,
    'latestBuild': latestBuild,
    'minimumBuild': minimumBuild,
    'latestVersion': latestVersion,
    'minimumVersion': minimumVersion,
    'messageTr': messages['tr'],
    'messageEn': messages['en'],
    'messageDe': messages['de'],
    'storeUrl': storeUrl?.toString() ?? '',
    'storeVersionAvailable': storeVersionAvailable,
    'revisionId': revisionId,
  };

  static int _build(dynamic value) {
    final int? result = int.tryParse(value?.toString() ?? '');
    if (result == null) throw const FormatException();
    return result;
  }

  static String _text(dynamic value) => value?.toString().trim() ?? '';
}

class UpdateDecision {
  const UpdateDecision(this.urgency, this.policy);
  final UpdateUrgency urgency;
  final AppVersionPolicy? policy;
  static const UpdateDecision none = UpdateDecision(UpdateUrgency.none, null);
}

String resolveDistributionTarget({
  required TargetPlatform platform,
  required String configuredTarget,
}) {
  if (platform == TargetPlatform.android) return 'production';
  return configuredTarget == 'test' ? 'test' : 'production';
}

UpdateDecision evaluateUpdatePolicy({
  required AppVersionPolicy? policy,
  required int installedBuild,
  required bool storeReachable,
  required bool trustedLivePolicy,
  required bool deferred,
}) {
  if (policy == null || !policy.active || installedBuild >= policy.latestBuild) {
    return UpdateDecision.none;
  }
  final bool required = trustedLivePolicy &&
      storeReachable &&
      policy.storeVersionAvailable &&
      policy.storeUrl != null &&
      installedBuild < policy.minimumBuild;
  if (required) return UpdateDecision(UpdateUrgency.required, policy);
  if (deferred) return UpdateDecision.none;
  return UpdateDecision(UpdateUrgency.optional, policy);
}

class AppUpdateService {
  AppUpdateService._();
  static const MethodChannel _android = MethodChannel('com.dortapp.dort/app_update');
  static const String _target = String.fromEnvironment(
    'DISTRIBUTION_TARGET',
    defaultValue: 'production',
  );
  static DateTime? _lastCheck;
  static UpdateDecision _lastDecision = UpdateDecision.none;

  static String get platformName => defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';
  // A Play track is not an app runtime property: the same signed AAB can be
  // promoted from internal testing to production. Android therefore always
  // consumes the production policy. The explicit target remains useful for
  // iOS, where TestFlight and App Store links are separate artifacts.
  static String get targetName => resolveDistributionTarget(
    platform: defaultTargetPlatform,
    configuredTarget: _target,
  );
  static String get policyId => '${platformName}_$targetName';

  static Future<UpdateDecision> check({bool force = false}) async {
    if (kIsWeb || !<TargetPlatform>{TargetPlatform.android, TargetPlatform.iOS}.contains(defaultTargetPlatform)) {
      return UpdateDecision.none;
    }
    final DateTime now = DateTime.now();
    if (!force && _lastCheck != null && now.difference(_lastCheck!) < const Duration(minutes: 15)) {
      return _lastDecision;
    }
    _lastCheck = now;
    final PackageInfo package = await PackageInfo.fromPlatform();
    final int installedBuild = int.tryParse(package.buildNumber) ?? 0;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    AppVersionPolicy? policy;
    bool trustedLive = false;
    try {
      final snapshot = await FirebaseFirestore.instance.collection('public_app_versions').doc(policyId).get();
      policy = AppVersionPolicy.tryParse(snapshot.data() ?? const <String, dynamic>{});
      if (policy != null && policy.platform == platformName && policy.target == targetName) {
        trustedLive = true;
        await prefs.setString('app_update_policy_$policyId', jsonEncode(policy.toJson()));
      } else {
        policy = null;
      }
    } catch (_) {
      final String? cached = prefs.getString('app_update_policy_$policyId');
      if (cached != null) {
        try {
          policy = AppVersionPolicy.tryParse(jsonDecode(cached) as Map<String, dynamic>);
        } catch (_) {
          policy = null;
        }
      }
    }
    bool storeReachable = policy?.storeVersionAvailable == true && policy?.storeUrl != null;
    if (defaultTargetPlatform == TargetPlatform.android && trustedLive && storeReachable) {
      try {
        final Map<Object?, Object?> result =
            (await _android.invokeMapMethod<Object?, Object?>('checkAvailability')) ?? const {};
        final int availableBuild =
            int.tryParse(result['availableVersionCode']?.toString() ?? '') ?? 0;
        storeReachable = result['available'] == true &&
            availableBuild >= (policy?.minimumBuild ?? 0);
      } catch (_) {
        storeReachable = false;
      }
    }
    final String deferKey = 'app_update_deferred_${policy?.revisionId}_${policy?.latestBuild}';
    _lastDecision = evaluateUpdatePolicy(
      policy: policy,
      installedBuild: installedBuild,
      storeReachable: storeReachable,
      trustedLivePolicy: trustedLive,
      deferred: prefs.getBool(deferKey) == true,
    );
    return _lastDecision;
  }

  static Future<void> defer(AppVersionPolicy policy) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('app_update_deferred_${policy.revisionId}_${policy.latestBuild}', true);
    _lastDecision = UpdateDecision.none;
  }

  static Future<bool> openUpdate(AppVersionPolicy policy, {required bool immediate}) async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        final bool started = await _android.invokeMethod<bool>(
              'startUpdate',
              <String, dynamic>{'immediate': immediate},
            ) ?? false;
        if (started) return true;
      } catch (_) {}
    }
    final Uri? url = policy.storeUrl;
    if (url == null) return false;
    return launchUrl(url, mode: LaunchMode.externalApplication);
  }
}
