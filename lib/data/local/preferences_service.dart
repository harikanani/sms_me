import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/forwarding_rule.dart';

class PreferencesService {
  static const String _keyForwardingEnabled = 'forwarding_enabled';
  static const String _keySuccessfulForwardCount = 'successful_forward_count';
  static const String _keySmsForwardingLimit = 'sms_forwarding_limit';
  static const String _keyDestinationNumber = 'destination_number';
  static const String _keySenderFilterEnabled = 'sender_filter_enabled';
  static const String _keyAllowedSenders = 'allowed_senders';
  static const String _keyOutgoingSubscriptionId = 'outgoing_subscription_id';
  static const String _keyActiveRules = 'active_rules_json';
  static const String _keyGlobalExcludeKeywords = 'global_exclude_keywords';
  static const String _keyOnboardingCompleted = 'onboarding_completed';

  final SharedPreferences _prefs;

  PreferencesService(this._prefs);

  static Future<PreferencesService> init() async {
    final prefs = await SharedPreferences.getInstance();
    return PreferencesService(prefs);
  }

  bool get forwardingEnabled => _prefs.getBool(_keyForwardingEnabled) ?? false;
  Future<void> setForwardingEnabled(bool value) async {
    await _prefs.setBool(_keyForwardingEnabled, value);
  }

  int get successfulForwardCount => _prefs.getInt(_keySuccessfulForwardCount) ?? 0;
  Future<void> setSuccessfulForwardCount(int count) async {
    await _prefs.setInt(_keySuccessfulForwardCount, count);
  }

  int get smsForwardingLimit => _prefs.getInt(_keySmsForwardingLimit) ?? 3000;
  Future<void> setSmsForwardingLimit(int limit) async {
    await _prefs.setInt(_keySmsForwardingLimit, limit);
  }

  String get destinationNumber => _prefs.getString(_keyDestinationNumber) ?? '';
  Future<void> setDestinationNumber(String number) async {
    await _prefs.setString(_keyDestinationNumber, number.trim());
  }

  bool get senderFilterEnabled => _prefs.getBool(_keySenderFilterEnabled) ?? false;
  Future<void> setSenderFilterEnabled(bool value) async {
    await _prefs.setBool(_keySenderFilterEnabled, value);
  }

  List<String> get allowedSenders => _prefs.getStringList(_keyAllowedSenders) ?? ['HDFCBK', 'SBIINB', 'ICICIB', 'AXISBK', 'PAYTMB'];
  Future<void> setAllowedSenders(List<String> senders) async {
    await _prefs.setStringList(_keyAllowedSenders, senders.map((e) => e.trim().toUpperCase()).toList());
  }

  int? get outgoingSubscriptionId {
    final val = _prefs.getInt(_keyOutgoingSubscriptionId);
    return val == -1 ? null : val;
  }
  Future<void> setOutgoingSubscriptionId(int? subId) async {
    if (subId == null) {
      await _prefs.setInt(_keyOutgoingSubscriptionId, -1);
    } else {
      await _prefs.setInt(_keyOutgoingSubscriptionId, subId);
    }
  }

  List<ForwardingRule> get activeRules {
    final jsonStr = _prefs.getString(_keyActiveRules);
    if (jsonStr == null || jsonStr.isEmpty) {
      return DefaultRules.allDefaults;
    }
    try {
      final list = jsonDecode(jsonStr) as List;
      return list.map((e) => ForwardingRule.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return DefaultRules.allDefaults;
    }
  }

  Future<void> setActiveRules(List<ForwardingRule> rules) async {
    final list = rules.map((r) => r.toJson()).toList();
    await _prefs.setString(_keyActiveRules, jsonEncode(list));
  }

  List<String> get globalExcludeKeywords => _prefs.getStringList(_keyGlobalExcludeKeywords) ?? ['offer', 'promotion', 'sale'];
  Future<void> setGlobalExcludeKeywords(List<String> keywords) async {
    await _prefs.setStringList(_keyGlobalExcludeKeywords, keywords);
  }

  bool get onboardingCompleted => _prefs.getBool(_keyOnboardingCompleted) ?? false;
  Future<void> setOnboardingCompleted(bool value) async {
    await _prefs.setBool(_keyOnboardingCompleted, value);
  }

  bool get isLimitReached => successfulForwardCount >= smsForwardingLimit;
}
