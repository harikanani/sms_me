import 'package:flutter/services.dart';
import '../../domain/entities/forwarding_result.dart';

abstract class NativeSmsGateway {
  Future<void> initialize();
  Future<ForwardResult> sendSms({
    required String destinationNumber,
    required String body,
    int? subscriptionId,
  });
  Future<Map<String, dynamic>> getSimInfo();
  Future<bool> requestBatteryOptimizationExemption();
  Future<bool> isBatteryOptimizationIgnored();
}

class MethodChannelNativeSmsGateway implements NativeSmsGateway {
  static const MethodChannel _channel = MethodChannel('com.example.sms_me/sms_channel');

  Function(Map<String, dynamic>)? _onSmsReceivedCallback;

  void setOnSmsReceivedCallback(Function(Map<String, dynamic>) callback) {
    _onSmsReceivedCallback = callback;
  }

  @override
  Future<void> initialize() async {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onSmsReceived') {
        final Map<dynamic, dynamic> args = call.arguments as Map<dynamic, dynamic>;
        final Map<String, dynamic> smsMap = Map<String, dynamic>.from(args);
        _onSmsReceivedCallback?.call(smsMap);
      }
    });
  }

  @override
  Future<ForwardResult> sendSms({
    required String destinationNumber,
    required String body,
    int? subscriptionId,
  }) async {
    try {
      final Map<String, dynamic> args = {
        'destinationNumber': destinationNumber,
        'body': body,
        'subscriptionId': subscriptionId,
      };

      final Map<dynamic, dynamic>? result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'sendSms',
        args,
      );

      if (result != null && result['status'] == 'SUCCESS') {
        return ForwardResult(status: ForwardStatus.success);
      } else {
        final error = result?['error'] as String? ?? 'Unknown native SMS send error';
        return ForwardResult(
          status: ForwardStatus.failed,
          errorMessage: error,
        );
      }
    } on PlatformException catch (e) {
      return ForwardResult(
        status: ForwardStatus.failed,
        errorMessage: '${e.code}: ${e.message}',
      );
    } catch (e) {
      return ForwardResult(
        status: ForwardStatus.failed,
        errorMessage: e.toString(),
      );
    }
  }

  @override
  Future<Map<String, dynamic>> getSimInfo() async {
    try {
      final Map<dynamic, dynamic>? result = await _channel.invokeMethod<Map<dynamic, dynamic>>('getSimInfo');
      if (result != null) {
        return Map<String, dynamic>.from(result);
      }
    } catch (_) {}
    return {'sims': []};
  }

  @override
  Future<bool> requestBatteryOptimizationExemption() async {
    try {
      final bool? result = await _channel.invokeMethod<bool>('requestBatteryOptimizationExemption');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> isBatteryOptimizationIgnored() async {
    try {
      final bool? result = await _channel.invokeMethod<bool>('isBatteryOptimizationIgnored');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }
}
