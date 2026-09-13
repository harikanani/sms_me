class IncomingSms {
  final String id;
  final String sender;
  final String body;
  final DateTime receivedAt;
  final int? subscriptionId;

  IncomingSms({
    required this.id,
    required this.sender,
    required this.body,
    required this.receivedAt,
    this.subscriptionId,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender': sender,
      'body': body,
      'receivedAt': receivedAt.toIso8601String(),
      'subscriptionId': subscriptionId,
    };
  }

  factory IncomingSms.fromJson(Map<String, dynamic> json) {
    return IncomingSms(
      id: json['id'] as String,
      sender: json['sender'] as String,
      body: json['body'] as String,
      receivedAt: DateTime.parse(json['receivedAt'] as String),
      subscriptionId: json['subscriptionId'] as int?,
    );
  }

  @override
  String toString() => 'IncomingSms(id: $id, sender: $sender, time: $receivedAt)';
}
