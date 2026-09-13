import 'incoming_sms.dart';

class ForwardableSms {
  final IncomingSms incomingSms;
  final String destinationNumber;
  final int? outgoingSubscriptionId;

  ForwardableSms({
    required this.incomingSms,
    required this.destinationNumber,
    this.outgoingSubscriptionId,
  });

  /// Formats the message with metadata while retaining the exact full original body intact.
  String formatFormattedBody() {
    final dateStr = _formatTimestamp(incomingSms.receivedAt);
    return '📩 Parent SMS\n\nFrom: ${incomingSms.sender}\nTime: $dateStr\n\n${incomingSms.body}';
  }

  static String _formatTimestamp(DateTime dt) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final day = dt.day.toString().padLeft(2, '0');
    final month = months[dt.month - 1];
    final year = dt.year;
    
    final hourInt = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final hour = hourInt.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    final amPm = dt.hour >= 12 ? 'PM' : 'AM';

    return '$day-$month-$year $hour:$minute $amPm';
  }
}
