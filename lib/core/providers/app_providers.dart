import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/local/app_database.dart';
import '../../data/local/preferences_service.dart';
import '../../data/native/native_sms_gateway.dart';
import '../../data/transports/sms_forwarding_transport.dart';
import '../../domain/entities/forwarding_job.dart';
import '../../domain/entities/forwarding_rule.dart';
import '../../domain/services/forwarding_counter.dart';
import '../../domain/services/forwarding_queue.dart';
import '../../domain/services/sms_processor.dart';
import '../../domain/transports/forwarding_transport.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Initialize sharedPreferencesProvider in main() override');
});

final preferencesServiceProvider = Provider<PreferencesService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return PreferencesService(prefs);
});

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase();
});

final nativeSmsGatewayProvider = Provider<NativeSmsGateway>((ref) {
  return MethodChannelNativeSmsGateway();
});

final forwardingTransportProvider = Provider<ForwardingTransport>((ref) {
  final gateway = ref.watch(nativeSmsGatewayProvider);
  return SmsForwardingTransport(gateway);
});

final forwardingCounterProvider = Provider<ForwardingCounter>((ref) {
  final prefs = ref.watch(preferencesServiceProvider);
  return ForwardingCounter(prefs);
});

final forwardingQueueProvider = Provider<ForwardingQueue>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return ForwardingQueue(db);
});

final smsProcessorProvider = Provider<SmsProcessor>((ref) {
  final prefs = ref.watch(preferencesServiceProvider);
  final db = ref.watch(appDatabaseProvider);
  final counter = ref.watch(forwardingCounterProvider);
  final queue = ref.watch(forwardingQueueProvider);
  final transport = ref.watch(forwardingTransportProvider);

  return SmsProcessor(
    prefs,
    db,
    counter,
    queue,
    transport,
  );
});

class AppSettingsState {
  final bool forwardingEnabled;
  final int successfulForwardCount;
  final int smsForwardingLimit;
  final String destinationNumber;
  final bool senderFilterEnabled;
  final List<String> allowedSenders;
  final int? outgoingSubscriptionId;
  final List<ForwardingRule> activeRules;
  final List<String> globalExcludeKeywords;
  final bool onboardingCompleted;

  AppSettingsState({
    required this.forwardingEnabled,
    required this.successfulForwardCount,
    required this.smsForwardingLimit,
    required this.destinationNumber,
    required this.senderFilterEnabled,
    required this.allowedSenders,
    required this.outgoingSubscriptionId,
    required this.activeRules,
    required this.globalExcludeKeywords,
    required this.onboardingCompleted,
  });

  bool get isLimitReached => successfulForwardCount >= smsForwardingLimit;
  int get remainingCount => (smsForwardingLimit - successfulForwardCount).clamp(0, smsForwardingLimit);
}

class AppSettingsNotifier extends StateNotifier<AppSettingsState> {
  final PreferencesService _prefs;

  AppSettingsNotifier(this._prefs) : super(_loadState(_prefs));

  static AppSettingsState _loadState(PreferencesService prefs) {
    return AppSettingsState(
      forwardingEnabled: prefs.forwardingEnabled,
      successfulForwardCount: prefs.successfulForwardCount,
      smsForwardingLimit: prefs.smsForwardingLimit,
      destinationNumber: prefs.destinationNumber,
      senderFilterEnabled: prefs.senderFilterEnabled,
      allowedSenders: prefs.allowedSenders,
      outgoingSubscriptionId: prefs.outgoingSubscriptionId,
      activeRules: prefs.activeRules,
      globalExcludeKeywords: prefs.globalExcludeKeywords,
      onboardingCompleted: prefs.onboardingCompleted,
    );
  }

  void refresh() {
    state = _loadState(_prefs);
  }

  Future<void> toggleForwarding(bool enabled) async {
    if (state.isLimitReached && enabled) return;
    await _prefs.setForwardingEnabled(enabled);
    refresh();
  }

  Future<void> setDestinationNumber(String number) async {
    await _prefs.setDestinationNumber(number);
    refresh();
  }

  Future<void> setSenderFilterEnabled(bool enabled) async {
    await _prefs.setSenderFilterEnabled(enabled);
    refresh();
  }

  Future<void> setAllowedSenders(List<String> senders) async {
    await _prefs.setAllowedSenders(senders);
    refresh();
  }

  Future<void> setOutgoingSubscriptionId(int? subId) async {
    await _prefs.setOutgoingSubscriptionId(subId);
    refresh();
  }

  Future<void> setActiveRules(List<ForwardingRule> rules) async {
    await _prefs.setActiveRules(rules);
    refresh();
  }

  Future<void> setGlobalExcludeKeywords(List<String> keywords) async {
    await _prefs.setGlobalExcludeKeywords(keywords);
    refresh();
  }

  Future<void> completeOnboarding() async {
    await _prefs.setOnboardingCompleted(true);
    refresh();
  }
}

final appSettingsProvider = StateNotifierProvider<AppSettingsNotifier, AppSettingsState>((ref) {
  final prefs = ref.watch(preferencesServiceProvider);
  return AppSettingsNotifier(prefs);
});

final historyListProvider = FutureProvider<List<ForwardingJob>>((ref) async {
  final queue = ref.watch(forwardingQueueProvider);
  return await queue.getHistory();
});
