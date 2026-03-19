import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../storage/local_storage.dart';

/// Remote JSON: { "latest_version": "1.0.0", "store_url_android": "https://play.google.com/store/apps/details?id=...", "store_url_ios": "https://apps.apple.com/..." }
/// Set [versionCheckUrl] to your JSON endpoint to show "Update available" popup when a new version exists.
class UpdateCheckService {
  static const String versionCheckUrl = String.fromEnvironment(
    'VERSION_CHECK_URL',
    defaultValue: '',
  ); // e.g. --dart-define=VERSION_CHECK_URL=https://yourserver.com/version.json

  static String? get _resolvedVersionCheckUrl {
    if (versionCheckUrl.trim().isEmpty) return null;
    return versionCheckUrl.trim();
  }

  static bool _parseBool(dynamic value) {
    if (value is bool) return value;
    if (value is String) {
      final v = value.toLowerCase().trim();
      return v == 'true' || v == '1' || v == 'yes';
    }
    if (value is num) return value != 0;
    return false;
  }

  static Future<bool> isUpdateAvailable() async {
    final checkUrl = _resolvedVersionCheckUrl;
    if (checkUrl == null) return false;

    try {
      final info = await PackageInfo.fromPlatform();
      final current = info.version;
      final response = await http.get(Uri.parse(checkUrl)).timeout(
        const Duration(seconds: 5),
      );
      if (response.statusCode != 200) return false;

      final map = json.decode(response.body) as Map<String, dynamic>?;
      final latest = map?['latest_version'] as String?;
      if (latest == null || latest.isEmpty) return false;

      final minSupported = map?['min_supported_version'] as String?;
      final force = _parseBool(map?['force_update']) || _parseBool(map?['mandatory']);
      final hasNormalUpdate = isVersionNewer(latest, current);
      final hasForceUpdate = isForceUpdate(
        currentVersion: current,
        latestVersion: latest,
        minSupportedVersion: minSupported,
        forceFlag: force,
      );

      if (hasNormalUpdate || hasForceUpdate) {
        final dismissed = LocalStorage.getLastDismissedUpdateVersion();
        if (dismissed == latest && !hasForceUpdate) return false;
        return true;
      }
    } catch (_) {}
    return false;
  }

  static bool isVersionNewer(String latest, String current) {
    try {
      final l = _parseVersion(latest);
      final c = _parseVersion(current);
      for (int i = 0; i < 3; i++) {
        final a = l[i];
        final b = c[i];
        if (a > b) return true;
        if (a < b) return false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  static List<int> _parseVersion(String v) {
    final parts = v.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    while (parts.length < 3) parts.add(0);
    return parts.take(3).toList();
  }

  static Future<String?> getStoreUrl() async {
    final checkUrl = _resolvedVersionCheckUrl;
    if (checkUrl == null) return null;
    try {
      final response = await http.get(Uri.parse(checkUrl)).timeout(
        const Duration(seconds: 5),
      );
      if (response.statusCode != 200) return null;
      final map = json.decode(response.body) as Map<String, dynamic>?;
      // Prefer platform-specific URL
      final android = map?['store_url_android'] as String?;
      final ios = map?['store_url_ios'] as String?;
      final generic = map?['store_url'] as String?;
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        return ios ?? generic ?? android;
      }
      return android ?? generic ?? ios;
    } catch (_) {}
    return null;
  }

  static Future<void> openStore(String? url) async {
    String toOpen = url ?? '';
    if (toOpen.isEmpty) {
      final info = await PackageInfo.fromPlatform();
      toOpen = 'https://play.google.com/store/apps/details?id=${info.packageName}';
    }
    final uri = Uri.parse(toOpen);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  static Future<Map<String, String>?> fetchVersionInfo() async {
    final checkUrl = _resolvedVersionCheckUrl;
    if (checkUrl == null) return null;
    try {
      final response = await http.get(Uri.parse(checkUrl)).timeout(
        const Duration(seconds: 5),
      );
      if (response.statusCode != 200) return null;
      final map = json.decode(response.body) as Map<String, dynamic>?;
      final latest = map?['latest_version'] as String?;
      final force = _parseBool(map?['force_update']) || _parseBool(map?['mandatory']);
      final minSupported = map?['min_supported_version'] as String? ?? '';
      final storeUrl = (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS)
          ? (map?['store_url_ios'] as String? ??
                map?['store_url'] as String? ??
                map?['store_url_android'] as String?)
          : (map?['store_url_android'] as String? ??
                map?['store_url'] as String? ??
                map?['store_url_ios'] as String?);
      if (latest != null) {
        return {
          'latest_version': latest,
          'store_url': storeUrl ?? '',
          'force_update': force ? 'true' : 'false',
          'min_supported_version': minSupported,
        };
      }
    } catch (_) {}
    return null;
  }

  static bool isForceUpdate({
    required String currentVersion,
    required String latestVersion,
    String? minSupportedVersion,
    bool forceFlag = false,
  }) {
    final belowMinSupported = (minSupportedVersion != null && minSupportedVersion.isNotEmpty)
        ? isVersionNewer(minSupportedVersion, currentVersion)
        : false;
    final behindLatest = isVersionNewer(latestVersion, currentVersion);
    return belowMinSupported || (forceFlag && behindLatest);
  }

  static void markUpdateDialogDismissed(String version) {
    LocalStorage.setLastDismissedUpdateVersion(version);
  }
}
