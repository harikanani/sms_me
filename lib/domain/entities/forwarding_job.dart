import 'incoming_sms.dart';

enum ForwardingJobStatus {
  pending,
  processing,
  success,
  failed,
  ignored,
  duplicate,
}

class ForwardingJob {
  final String id;
  final IncomingSms sms;
  final ForwardingJobStatus status;
  final String? matchedRuleName;
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime? processedAt;

  ForwardingJob({
    required this.id,
    required this.sms,
    required this.status,
    this.matchedRuleName,
    this.errorMessage,
    required this.createdAt,
    this.processedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sms_id': sms.id,
      'sender': sms.sender,
      'body': sms.body,
      'received_at': sms.receivedAt.toIso8601String(),
      'subscription_id': sms.subscriptionId,
      'status': status.name,
      'matched_rule_name': matchedRuleName,
      'error_message': errorMessage,
      'created_at': createdAt.toIso8601String(),
      'processed_at': processedAt?.toIso8601String(),
    };
  }

  factory ForwardingJob.fromMap(Map<String, dynamic> map) {
    final sms = IncomingSms(
      id: map['sms_id'] as String,
      sender: map['sender'] as String,
      body: map['body'] as String? ?? '',
      receivedAt: DateTime.parse(map['received_at'] as String),
      subscriptionId: map['subscription_id'] as int?,
    );

    return ForwardingJob(
      id: map['id'] as String,
      sms: sms,
      status: ForwardingJobStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => ForwardingJobStatus.pending,
      ),
      matchedRuleName: map['matched_rule_name'] as String?,
      errorMessage: map['error_message'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      processedAt: map['processed_at'] != null
          ? DateTime.parse(map['processed_at'] as String)
          : null,
    );
  }

  ForwardingJob copyWith({
    ForwardingJobStatus? status,
    String? matchedRuleName,
    String? errorMessage,
    DateTime? processedAt,
  }) {
    return ForwardingJob(
      id: id,
      sms: sms,
      status: status ?? this.status,
      matchedRuleName: matchedRuleName ?? this.matchedRuleName,
      errorMessage: errorMessage ?? this.errorMessage,
      createdAt: createdAt,
      processedAt: processedAt ?? this.processedAt,
    );
  }
}
