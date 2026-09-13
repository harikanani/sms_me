enum ForwardStatus {
  success,
  failed,
  limitReached,
}

class ForwardResult {
  final ForwardStatus status;
  final String? errorMessage;
  final DateTime timestamp;

  ForwardResult({
    required this.status,
    this.errorMessage,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  bool get isSuccess => status == ForwardStatus.success;
}
