import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../entities/incoming_sms.dart';

class DuplicateDetector {
  /// Generates a deterministic SHA-256 fingerprint from stable message properties.
  static String generateFingerprint(IncomingSms sms) {
    final raw = '${sms.sender.toUpperCase()}|${sms.receivedAt.millisecondsSinceEpoch}|${sms.body}|${sms.subscriptionId ?? 0}';
    final bytes = utf8.encode(raw);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}
