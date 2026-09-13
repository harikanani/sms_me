class ForwardingRule {
  final String id;
  final String name;
  final List<String> includeKeywords;
  final List<String> excludeKeywords;
  final bool isEnabled;

  const ForwardingRule({
    required this.id,
    required this.name,
    required this.includeKeywords,
    this.excludeKeywords = const [],
    this.isEnabled = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'includeKeywords': includeKeywords,
      'excludeKeywords': excludeKeywords,
      'isEnabled': isEnabled,
    };
  }

  factory ForwardingRule.fromJson(Map<String, dynamic> json) {
    return ForwardingRule(
      id: json['id'] as String,
      name: json['name'] as String,
      includeKeywords: List<String>.from(json['includeKeywords'] as List),
      excludeKeywords: List<String>.from(json['excludeKeywords'] as List? ?? []),
      isEnabled: json['isEnabled'] as bool? ?? true,
    );
  }

  ForwardingRule copyWith({
    String? id,
    String? name,
    List<String>? includeKeywords,
    List<String>? excludeKeywords,
    bool? isEnabled,
  }) {
    return ForwardingRule(
      id: id ?? this.id,
      name: name ?? this.name,
      includeKeywords: includeKeywords ?? this.includeKeywords,
      excludeKeywords: excludeKeywords ?? this.excludeKeywords,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }
}

/// Default built-in rules for V1 scope
class DefaultRules {
  static const ForwardingRule otp = ForwardingRule(
    id: 'rule_otp',
    name: 'OTP & Verification Codes',
    includeKeywords: [
      'OTP',
      'one time password',
      'verification code',
      'verification OTP',
      'security code',
      'authentication code',
    ],
  );

  static const ForwardingRule debit = ForwardingRule(
    id: 'rule_debit',
    name: 'Debit & Withdrawals',
    includeKeywords: [
      'debited',
      'debit',
      'withdrawn',
      'withdrawal',
    ],
  );

  static const ForwardingRule credit = ForwardingRule(
    id: 'rule_credit',
    name: 'Credit & Deposits',
    includeKeywords: [
      'credited',
      'credit',
      'deposited',
      'deposit',
    ],
  );

  static const ForwardingRule transaction = ForwardingRule(
    id: 'rule_transaction',
    name: 'Transactions',
    includeKeywords: [
      'transaction',
      'txn',
    ],
  );

  static const ForwardingRule upi = ForwardingRule(
    id: 'rule_upi',
    name: 'UPI Payments',
    includeKeywords: [
      'UPI',
      'UPI transaction',
      'UPI payment',
    ],
  );

  static List<ForwardingRule> get allDefaults => [
        otp,
        debit,
        credit,
        transaction,
        upi,
      ];
}
