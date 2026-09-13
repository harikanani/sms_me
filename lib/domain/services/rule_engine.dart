import '../entities/incoming_sms.dart';
import '../entities/forwarding_rule.dart';

class RuleEngineResult {
  final bool shouldForward;
  final String? matchedRuleName;
  final String? reason;

  RuleEngineResult({
    required this.shouldForward,
    this.matchedRuleName,
    this.reason,
  });

  factory RuleEngineResult.forward(String ruleName) {
    return RuleEngineResult(
      shouldForward: true,
      matchedRuleName: ruleName,
    );
  }

  factory RuleEngineResult.ignore(String reason) {
    return RuleEngineResult(
      shouldForward: false,
      reason: reason,
    );
  }
}

class RuleEngine {
  final bool senderFilterEnabled;
  final List<String> allowedSenders;
  final List<ForwardingRule> activeRules;
  final List<String> globalExcludeKeywords;

  RuleEngine({
    this.senderFilterEnabled = false,
    this.allowedSenders = const [],
    required this.activeRules,
    this.globalExcludeKeywords = const [],
  });

  RuleEngineResult evaluate(IncomingSms sms) {
    final normalizedBody = _normalizeText(sms.body);
    final normalizedSender = sms.sender.trim().toUpperCase();

    // 1. Sender filter evaluation
    if (senderFilterEnabled) {
      final isAllowedSender = allowedSenders.any(
        (allowed) => allowed.trim().toUpperCase() == normalizedSender,
      );
      if (!isAllowedSender) {
        return RuleEngineResult.ignore('Sender not in allowed senders list');
      }
    }

    // 2. Global Exclude rules evaluation
    for (final excludeKw in globalExcludeKeywords) {
      if (excludeKw.trim().isNotEmpty) {
        final normalizedExclude = _normalizeText(excludeKw);
        if (_containsKeyword(normalizedBody, normalizedExclude)) {
          return RuleEngineResult.ignore('Matched global exclude keyword: "$excludeKw"');
        }
      }
    }

    // 3. Evaluate each active rule
    for (final rule in activeRules) {
      if (!rule.isEnabled) continue;

      // Check rule-level exclude keywords first
      bool ruleExcluded = false;
      for (final excludeKw in rule.excludeKeywords) {
        if (excludeKw.trim().isNotEmpty &&
            _containsKeyword(normalizedBody, _normalizeText(excludeKw))) {
          ruleExcluded = true;
          break;
        }
      }
      if (ruleExcluded) continue;

      // Check rule-level include keywords
      for (final includeKw in rule.includeKeywords) {
        if (includeKw.trim().isNotEmpty &&
            _containsKeyword(normalizedBody, _normalizeText(includeKw))) {
          return RuleEngineResult.forward(rule.name);
        }
      }
    }

    return RuleEngineResult.ignore('No matching include rules');
  }

  static String _normalizeText(String text) {
    // Lowercase and collapse multiple whitespace into single space
    return text.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static bool _containsKeyword(String normalizedBody, String normalizedKeyword) {
    if (normalizedKeyword.isEmpty) return false;
    return normalizedBody.contains(normalizedKeyword);
  }
}
