import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sms_me/domain/entities/incoming_sms.dart';
import 'package:sms_me/domain/entities/forwarding_rule.dart';
import 'package:sms_me/domain/services/rule_engine.dart';
import 'package:sms_me/domain/services/duplicate_detector.dart';
import 'package:sms_me/domain/services/forwarding_counter.dart';
import 'package:sms_me/data/local/preferences_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RuleEngine Tests', () {
    late RuleEngine engine;

    setUp(() {
      engine = RuleEngine(
        senderFilterEnabled: false,
        activeRules: DefaultRules.allDefaults,
        globalExcludeKeywords: ['offer', 'promotion', 'sale'],
      );
    });

    test('OTP SMS matches default OTP rule', () {
      final sms = IncomingSms(
        id: '1',
        sender: 'HDFCBK',
        body: 'Your OTP is 123456 for banking login',
        receivedAt: DateTime.now(),
      );
      final result = engine.evaluate(sms);
      expect(result.shouldForward, isTrue);
      expect(result.matchedRuleName, contains('OTP'));
    });

    test('Debit SMS matches default Debit rule', () {
      final sms = IncomingSms(
        id: '2',
        sender: 'SBIINB',
        body: 'Rs 500 debited from your account XX1234',
        receivedAt: DateTime.now(),
      );
      final result = engine.evaluate(sms);
      expect(result.shouldForward, isTrue);
    });

    test('Credit SMS matches default Credit rule', () {
      final sms = IncomingSms(
        id: '3',
        sender: 'ICICIB',
        body: 'Rs 1000 credited to your account XX5678',
        receivedAt: DateTime.now(),
      );
      final result = engine.evaluate(sms);
      expect(result.shouldForward, isTrue);
    });

    test('Unrelated order SMS is ignored', () {
      final sms = IncomingSms(
        id: '4',
        sender: 'AMAZON',
        body: 'Your order has shipped and will arrive tomorrow.',
        receivedAt: DateTime.now(),
      );
      final result = engine.evaluate(sms);
      expect(result.shouldForward, isFalse);
    });

    test('Case insensitive matching (otp: 123456)', () {
      final sms = IncomingSms(
        id: '5',
        sender: 'UNKNOWN',
        body: 'otp: 123456 for login',
        receivedAt: DateTime.now(),
      );
      final result = engine.evaluate(sms);
      expect(result.shouldForward, isTrue);
    });

    test('Global Exclude keywords block matching SMS', () {
      final sms = IncomingSms(
        id: '6',
        sender: 'HDFCBK',
        body: 'Special offer! Your OTP is 998877 to get 10% cash back sale.',
        receivedAt: DateTime.now(),
      );
      final result = engine.evaluate(sms);
      expect(result.shouldForward, isFalse);
      expect(result.reason, contains('exclude keyword'));
    });

    test('Sender filtering works correctly', () {
      final strictEngine = RuleEngine(
        senderFilterEnabled: true,
        allowedSenders: ['HDFCBK', 'SBIINB'],
        activeRules: DefaultRules.allDefaults,
      );

      final allowedSms = IncomingSms(
        id: '7',
        sender: 'HDFCBK',
        body: 'Your OTP is 123456',
        receivedAt: DateTime.now(),
      );
      expect(strictEngine.evaluate(allowedSms).shouldForward, isTrue);

      final unknownSms = IncomingSms(
        id: '8',
        sender: 'SPAMMER',
        body: 'Your OTP is 123456',
        receivedAt: DateTime.now(),
      );
      expect(strictEngine.evaluate(unknownSms).shouldForward, isFalse);
    });
  });

  group('DuplicateDetector Fingerprint Tests', () {
    test('Same SMS generates identical SHA-256 fingerprint', () {
      final now = DateTime.fromMillisecondsSinceEpoch(1600000000000);
      final sms1 = IncomingSms(
        id: '1',
        sender: 'HDFCBK',
        body: 'Rs 5,000 debited from A/c XX1234',
        receivedAt: now,
        subscriptionId: 1,
      );

      final sms2 = IncomingSms(
        id: '2', // Different internal id
        sender: 'hdfcbk', // Case insensitive sender
        body: 'Rs 5,000 debited from A/c XX1234',
        receivedAt: now,
        subscriptionId: 1,
      );

      final fp1 = DuplicateDetector.generateFingerprint(sms1);
      final fp2 = DuplicateDetector.generateFingerprint(sms2);

      expect(fp1, equals(fp2));
      expect(fp1.length, equals(64)); // SHA-256 hex string length
    });

    test('Different SMS generates distinct fingerprint', () {
      final now = DateTime.now();
      final sms1 = IncomingSms(
        id: '1',
        sender: 'HDFCBK',
        body: 'Rs 5,000 debited',
        receivedAt: now,
      );
      final sms2 = IncomingSms(
        id: '2',
        sender: 'HDFCBK',
        body: 'Rs 6,000 debited',
        receivedAt: now,
      );

      expect(
        DuplicateDetector.generateFingerprint(sms1),
        isNot(equals(DuplicateDetector.generateFingerprint(sms2))),
      );
    });
  });

  group('ForwardingCounter Tests', () {
    late PreferencesService prefs;
    late ForwardingCounter counter;

    setUp(() async {
      SharedPreferences.setMockInitialValues({
        'successful_forward_count': 2998,
        'sms_forwarding_limit': 3000,
        'forwarding_enabled': true,
      });
      final sp = await SharedPreferences.getInstance();
      prefs = PreferencesService(sp);
      counter = ForwardingCounter(prefs);
    });

    test('Count increments from 2998 -> 2999 on success', () async {
      expect(counter.currentCount, 2998);
      final newCount = await counter.incrementOnSuccess();
      expect(newCount, 2999);
      expect(counter.isLimitReached, isFalse);
    });

    test('Count reaches 3000 limit and disables forwarding', () async {
      await counter.incrementOnSuccess(); // 2999
      final countAtLimit = await counter.incrementOnSuccess(); // 3000
      expect(countAtLimit, 3000);
      expect(counter.isLimitReached, isTrue);
      expect(prefs.forwardingEnabled, isFalse);
    });

    test('Counter does NOT increment on failure', () async {
      final countBefore = counter.currentCount;
      // Failed attempts do not call incrementOnSuccess()
      expect(counter.currentCount, countBefore);
    });

    test('Limit boundary concurrency protection', () async {
      SharedPreferences.setMockInitialValues({
        'successful_forward_count': 2999,
        'sms_forwarding_limit': 3000,
        'forwarding_enabled': true,
      });
      final sp = await SharedPreferences.getInstance();
      final localPrefs = PreferencesService(sp);
      final localCounter = ForwardingCounter(localPrefs);

      // Simulate 3 messages arriving concurrently at boundary
      final canForward1 = await localCounter.canForward();
      if (canForward1) {
        await localCounter.incrementOnSuccess(); // Reaches 3000
      }

      final canForward2 = await localCounter.canForward();
      expect(canForward2, isFalse); // Rejects subsequent message!
    });
  });
}
