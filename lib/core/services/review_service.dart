import 'package:in_app_review/in_app_review.dart';
import '../storage/local_storage.dart';

class ReviewService {
  static const int _minOpensBeforePrompt = 5;
  static const int _daysBetweenPrompts = 30;

  static Future<void> maybeRequestReview() async {
    final count = LocalStorage.getAppOpenCount();
    final lastRequest = LocalStorage.getLastReviewRequestDate();

    if (count < _minOpensBeforePrompt) return;

    if (lastRequest != null) {
      try {
        final last = DateTime.parse(lastRequest);
        if (DateTime.now().difference(last).inDays < _daysBetweenPrompts) return;
      } catch (_) {
        return;
      }
    }

    final inAppReview = InAppReview.instance;
    final available = await inAppReview.isAvailable();
    if (!available) return;

    await inAppReview.requestReview();
    LocalStorage.setLastReviewRequestDate(DateTime.now().toIso8601String());
  }

  static void recordAppOpen() {
    LocalStorage.incrementAppOpenCount();
  }
}
