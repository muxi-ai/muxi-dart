import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:test/test.dart';
import 'package:muxi/src/webhook.dart';

String createSignature(String payload, String secret, {int? timestamp}) {
  final ts = timestamp ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000);
  final message = '$ts.$payload';
  final hmac = Hmac(sha256, utf8.encode(secret));
  final digest = hmac.convert(utf8.encode(message));
  final signature = digest.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return 't=$ts,v1=$signature';
}

void main() {
  const secret = 'test_webhook_secret';
  const payload = '{"id":"req123","status":"completed","response":[{"type":"text","text":"Hello"}]}';

  group('Webhook.verifySignature', () {
    test('returns true for valid signature', () {
      final sigHeader = createSignature(payload, secret);
      expect(Webhook.verifySignature(payload, sigHeader, secret), isTrue);
    });

    test('returns false for invalid signature', () {
      final ts = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final sigHeader = 't=$ts,v1=invalidsignature';
      expect(Webhook.verifySignature(payload, sigHeader, secret), isFalse);
    });

    test('returns false for null header', () {
      expect(Webhook.verifySignature(payload, null, secret), isFalse);
    });

    test('returns false for empty header', () {
      expect(Webhook.verifySignature(payload, '', secret), isFalse);
    });

    test('returns false for expired timestamp', () {
      final oldTimestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000 - 600;
      final sigHeader = createSignature(payload, secret, timestamp: oldTimestamp);
      expect(Webhook.verifySignature(payload, sigHeader, secret), isFalse);
    });

    test('throws for missing secret', () {
      expect(
        () => Webhook.verifySignature(payload, 't=123,v1=abc', ''),
        throwsA(isA<WebhookVerificationException>()),
      );
    });
  });

  group('Webhook.parse', () {
    test('parses completed payload', () {
      final event = Webhook.parse(payload);
      
      expect(event.requestId, equals('req123'));
      expect(event.status, equals('completed'));
      expect(event.content.length, equals(1));
      expect(event.content[0].type, equals('text'));
      expect(event.content[0].text, equals('Hello'));
    });

    test('parses failed payload', () {
      const failedPayload = '{"id":"req456","status":"failed","error":{"code":"TIMEOUT","message":"Request timed out"}}';
      final event = Webhook.parse(failedPayload);
      
      expect(event.status, equals('failed'));
      expect(event.error, isNotNull);
      expect(event.error!.code, equals('TIMEOUT'));
      expect(event.error!.message, equals('Request timed out'));
    });

    test('parses clarification payload', () {
      const clarificationPayload = '{"id":"req789","status":"awaiting_clarification","clarification_question":"Which file do you mean?"}';
      final event = Webhook.parse(clarificationPayload);
      
      expect(event.status, equals('awaiting_clarification'));
      expect(event.clarification, isNotNull);
      expect(event.clarification!.question, equals('Which file do you mean?'));
    });

    test('throws for invalid json', () {
      expect(
        () => Webhook.parse('not json'),
        throwsA(isA<WebhookVerificationException>()),
      );
    });
  });
}
