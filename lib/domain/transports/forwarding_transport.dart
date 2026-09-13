import '../entities/forwardable_sms.dart';
import '../entities/forwarding_result.dart';

/// Abstract transport interface for SMS delivery.
/// 
/// Rest of the application components (Rule Engine, Duplicate Detector,
/// Forwarding Counter, Queue, and Dashboard) depend ONLY on this abstraction.
/// In future versions, an `InternetForwardingTransport` can be added without
/// modifying domain logic or UI.
abstract class ForwardingTransport {
  Future<ForwardResult> forward(ForwardableSms sms);
}
