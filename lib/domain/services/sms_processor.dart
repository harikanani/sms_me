import '../../data/local/app_database.dart';
import '../../data/local/preferences_service.dart';
import '../entities/forwardable_sms.dart';
import '../entities/forwarding_job.dart';
import '../entities/incoming_sms.dart';
import '../transports/forwarding_transport.dart';
import 'duplicate_detector.dart';
import 'forwarding_counter.dart';
import 'forwarding_queue.dart';
import 'rule_engine.dart';

class SmsProcessor {
  final PreferencesService _prefs;
  final AppDatabase _db;
  final ForwardingCounter _counter;
  final ForwardingQueue _queue;
  final ForwardingTransport _transport;

  SmsProcessor(
    this._prefs,
    this._db,
    this._counter,
    this._queue,
    this._transport,
  );

  Future<ForwardingJob> processIncomingSms(IncomingSms sms) async {
    final jobId = '${sms.id}_${DateTime.now().millisecondsSinceEpoch}';

    // 1. Check duplicate fingerprint
    final fingerprint = DuplicateDetector.generateFingerprint(sms);
    final isDuplicate = await _db.isDuplicateFingerprint(fingerprint);

    if (isDuplicate) {
      final duplicateJob = ForwardingJob(
        id: jobId,
        sms: sms,
        status: ForwardingJobStatus.duplicate,
        createdAt: DateTime.now(),
        processedAt: DateTime.now(),
      );
      await _queue.addJob(duplicateJob);
      return duplicateJob;
    }

    // Save fingerprint immediately to prevent race conditions
    await _db.saveFingerprint(fingerprint);

    // 2. Check if forwarding is enabled
    if (!_prefs.forwardingEnabled) {
      final ignoredJob = ForwardingJob(
        id: jobId,
        sms: sms,
        status: ForwardingJobStatus.ignored,
        errorMessage: 'Forwarding is currently paused or disabled',
        createdAt: DateTime.now(),
        processedAt: DateTime.now(),
      );
      await _queue.addJob(ignoredJob);
      return ignoredJob;
    }

    // 3. Rule Engine evaluation
    final ruleEngine = RuleEngine(
      senderFilterEnabled: _prefs.senderFilterEnabled,
      allowedSenders: _prefs.allowedSenders,
      activeRules: _prefs.activeRules,
      globalExcludeKeywords: _prefs.globalExcludeKeywords,
    );

    final ruleResult = ruleEngine.evaluate(sms);

    if (!ruleResult.shouldForward) {
      final ignoredJob = ForwardingJob(
        id: jobId,
        sms: sms,
        status: ForwardingJobStatus.ignored,
        errorMessage: ruleResult.reason,
        createdAt: DateTime.now(),
        processedAt: DateTime.now(),
      );
      await _queue.addJob(ignoredJob);
      return ignoredJob;
    }

    // 4. Counter / Limit check
    final canForward = await _counter.canForward();
    if (!canForward) {
      await _prefs.setForwardingEnabled(false);
      final limitJob = ForwardingJob(
        id: jobId,
        sms: sms,
        status: ForwardingJobStatus.failed,
        matchedRuleName: ruleResult.matchedRuleName,
        errorMessage: 'SMS forwarding limit reached (3000 max). Forwarding paused.',
        createdAt: DateTime.now(),
        processedAt: DateTime.now(),
      );
      await _queue.addJob(limitJob);
      return limitJob;
    }

    // 5. Destination number check
    final destination = _prefs.destinationNumber;
    if (destination.isEmpty) {
      final failedJob = ForwardingJob(
        id: jobId,
        sms: sms,
        status: ForwardingJobStatus.failed,
        matchedRuleName: ruleResult.matchedRuleName,
        errorMessage: 'Destination phone number is not configured',
        createdAt: DateTime.now(),
        processedAt: DateTime.now(),
      );
      await _queue.addJob(failedJob);
      return failedJob;
    }

    // 6. Create job in processing state
    var job = ForwardingJob(
      id: jobId,
      sms: sms,
      status: ForwardingJobStatus.processing,
      matchedRuleName: ruleResult.matchedRuleName,
      createdAt: DateTime.now(),
    );
    await _queue.addJob(job);

    // 7. Perform forwarding via Transport abstraction
    final forwardableSms = ForwardableSms(
      incomingSms: sms,
      destinationNumber: destination,
      outgoingSubscriptionId: _prefs.outgoingSubscriptionId,
    );

    final result = await _transport.forward(forwardableSms);

    if (result.isSuccess) {
      // Increment counter ONLY on confirmed success
      await _counter.incrementOnSuccess();

      job = job.copyWith(
        status: ForwardingJobStatus.success,
        processedAt: DateTime.now(),
      );
      await _queue.updateJobStatus(job.id, ForwardingJobStatus.success);
    } else {
      job = job.copyWith(
        status: ForwardingJobStatus.failed,
        errorMessage: result.errorMessage ?? 'SMS delivery failed',
        processedAt: DateTime.now(),
      );
      await _queue.updateJobStatus(
        job.id,
        ForwardingJobStatus.failed,
        errorMessage: result.errorMessage ?? 'SMS delivery failed',
      );
    }

    return job;
  }
}
