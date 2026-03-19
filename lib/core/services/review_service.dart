import 'package:in_app_review/in_app_review.dart';
import '../storage/local_storage.dart';

class ReviewService {
  static const int _minOpensBeforePrompt = 3;
  static const int _daysBetweenPrompts = 21;

  /// Returns true if the app should show the rate-us dialog (e.g. after 3+ opens, 21+ days since last prompt).
  static Future<bool> shouldShowReviewDialog() async {
    final count = LocalStorage.getAppOpenCount();
    final lastRequest = LocalStorage.getLastReviewRequestDate();

    if (count < _minOpensBeforePrompt) return false;

    if (lastRequest != null) {
      try {
        final last = DateTime.parse(lastRequest);
        if (DateTime.now().difference(last).inDays < _daysBetweenPrompts) return false;
      } catch (_) {
        // Ignore invalid stored date and allow showing dialog.
      }
    }
    return true;
  }

  /// Calls the native in-app review (Play Store / App Store) and records the request date.
  static Future<bool> requestReview() async {
    try {
      // Reliable behavior: always open app store listing for rating.
      await InAppReview.instance.openStoreListing();
      LocalStorage.setLastReviewRequestDate(DateTime.now().toIso8601String());
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Records that the user chose "Later" so we don't show the dialog again for a while.
  static void recordReviewLater() {
    LocalStorage.setLastReviewRequestDate(DateTime.now().toIso8601String());
  }

  static void recordAppOpen() {
    LocalStorage.incrementAppOpenCount();
  }
}
