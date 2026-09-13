import '../../domain/entities/forwardable_sms.dart';
import '../../domain/entities/forwarding_result.dart';
import '../../domain/transports/forwarding_transport.dart';
import '../native/native_sms_gateway.dart';

/// V1 implementation of [ForwardingTransport] sending messages via Android SMS.
class SmsForwardingTransport implements ForwardingTransport {
  final NativeSmsGateway _nativeSmsGateway;

  SmsForwardingTransport(this._nativeSmsGateway);

  @override
  Future<ForwardResult> forward(ForwardableSms sms) async {
    final formattedBody = sms.formatFormattedBody();
    return await _nativeSmsGateway.sendSms(
      destinationNumber: sms.destinationNumber,
      body: formattedBody,
      subscriptionId: sms.outgoingSubscriptionId,
    );
  }
}
