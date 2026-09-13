import 'package:synchronized/synchronized.dart';
import '../../data/local/preferences_service.dart';

class ForwardingCounter {
  final PreferencesService _prefs;
  final Lock _lock = Lock();

  ForwardingCounter(this._prefs);

  int get currentCount => _prefs.successfulForwardCount;
  int get limit => _prefs.smsForwardingLimit;
  int get remaining => (limit - currentCount).clamp(0, limit);
  bool get isLimitReached => currentCount >= limit;

  /// Thread-safe check to determine whether sending one additional SMS is allowed.
  Future<bool> canForward() async {
    return await _lock.synchronized(() async {
      return _prefs.successfulForwardCount < _prefs.smsForwardingLimit;
    });
  }

  /// Increments the counter atomically ONLY after confirmed successful delivery.
  /// If the new count reaches the limit, updates forwarding state to paused/limitReached.
  Future<int> incrementOnSuccess() async {
    return await _lock.synchronized(() async {
      final current = _prefs.successfulForwardCount;
      final newCount = current + 1;
      await _prefs.setSuccessfulForwardCount(newCount);

      if (newCount >= _prefs.smsForwardingLimit) {
        await _prefs.setForwardingEnabled(false);
      }
      return newCount;
    });
  }
}
