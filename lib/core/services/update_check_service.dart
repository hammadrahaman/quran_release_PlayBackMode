import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../storage/local_storage.dart';

/// Remote JSON should be: { "latest_version": "1.0.0", "store_url_android": "https://...", "store_url_ios": "https://..." }
/// Set [versionCheckUrl] to your endpoint, or null to skip update check.
class UpdateCheckService {
  static const String? versionCheckUrl = null; // Set e.g. 'https://yourserver.com/app-version.json'

  static Future<bool> isUpdateAvailable() async {
    if (versionCheckUrl == null || versionCheckUrl!.isEmpty) return false;

    try {
      final info = await PackageInfo.fromPlatform();
      final current = info.version;
      final response = await http.get(Uri.parse(versionCheckUrl!)).timeout(
        const Duration(seconds: 5),
      );
      if (response.statusCode != 200) return false;

      final map = json.decode(response.body) as Map<String, dynamic>?;
      final latest = map?['latest_version'] as String?;
      if (latest == null || latest.isEmpty) return false;

      if (isVersionNewer(latest, current)) {
        final dismissed = LocalStorage.getLastDismissedUpdateVersion();
        if (dismissed == latest) return false;
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
    if (versionCheckUrl == null || versionCheckUrl!.isEmpty) return null;
    try {
      final response = await http.get(Uri.parse(versionCheckUrl!)).timeout(
        const Duration(seconds: 5),
      );
      if (response.statusCode != 200) return null;
      final map = json.decode(response.body) as Map<String, dynamic>?;
      // Prefer platform-specific URL
      final android = map?['store_url_android'] as String?;
      final ios = map?['store_url_ios'] as String?;
      final generic = map?['store_url'] as String?;
      // Return generic or platform URL; caller can use default store links if needed
      return generic ?? android ?? ios;
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
    if (versionCheckUrl == null || versionCheckUrl!.isEmpty) return null;
    try {
      final response = await http.get(Uri.parse(versionCheckUrl!)).timeout(
        const Duration(seconds: 5),
      );
      if (response.statusCode != 200) return null;
      final map = json.decode(response.body) as Map<String, dynamic>?;
      final latest = map?['latest_version'] as String?;
      final storeUrl = map?['store_url'] as String? ??
          map?['store_url_android'] as String? ??
          map?['store_url_ios'] as String?;
      if (latest != null) {
        return {'latest_version': latest, 'store_url': storeUrl ?? ''};
      }
    } catch (_) {}
    return null;
  }

  static void markUpdateDialogDismissed(String version) {
    LocalStorage.setLastDismissedUpdateVersion(version);
  }
}
