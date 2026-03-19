import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';

class PlayStoreUpdateService {
  static bool get _isSupported => !kIsWeb && Platform.isAndroid;

  static Future<AppUpdateInfo?> checkForUpdate() async {
    if (!_isSupported) return null;
    try {
      return await InAppUpdate.checkForUpdate();
    } catch (_) {
      return null;
    }
  }

  static bool isUpdateAvailable(AppUpdateInfo info) {
    return info.updateAvailability == UpdateAvailability.updateAvailable;
  }

  static bool isImmediateAllowed(AppUpdateInfo info) {
    return info.immediateUpdateAllowed;
  }

  static bool isFlexibleAllowed(AppUpdateInfo info) {
    return info.flexibleUpdateAllowed;
  }

  static Future<bool> performImmediateUpdate() async {
    if (!_isSupported) return false;
    try {
      await InAppUpdate.performImmediateUpdate();
      return true;
    } catch (_) {
      return false;
    }
  }
}

