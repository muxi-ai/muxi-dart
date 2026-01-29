import 'dart:convert';
import 'package:crypto/crypto.dart';

class Auth {
  static (String signature, int timestamp) generateHmacSignature(String secretKey, String method, String path) {
    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final signPath = path.split('?').first;
    final message = '$timestamp;$method;$signPath';
    
    final hmac = Hmac(sha256, utf8.encode(secretKey));
    final digest = hmac.convert(utf8.encode(message));
    final signature = base64Encode(digest.bytes);
    
    return (signature, timestamp);
  }

  static String buildAuthHeader(String keyId, String secretKey, String method, String path) {
    final (signature, timestamp) = generateHmacSignature(secretKey, method, path);
    return 'MUXI-HMAC key=$keyId, timestamp=$timestamp, signature=$signature';
  }
}
