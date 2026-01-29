import 'dart:convert';
import 'package:crypto/crypto.dart';

class WebhookVerificationException implements Exception {
  final String message;
  WebhookVerificationException(this.message);
  @override
  String toString() => 'WebhookVerificationException: $message';
}

class ContentItem {
  final String type;
  final String? text;
  final Map<String, dynamic>? file;

  ContentItem({required this.type, this.text, this.file});

  factory ContentItem.fromJson(Map<String, dynamic> json) => ContentItem(
    type: json['type'] ?? 'text',
    text: json['text'],
    file: json['file'],
  );
}

class ErrorDetails {
  final String code;
  final String message;
  final String? trace;

  ErrorDetails({required this.code, required this.message, this.trace});

  factory ErrorDetails.fromJson(Map<String, dynamic> json) => ErrorDetails(
    code: json['code'] ?? 'unknown',
    message: json['message'] ?? 'Unknown error',
    trace: json['trace'],
  );
}

class Clarification {
  final String question;
  final String? clarificationRequestId;
  final String? originalMessage;

  Clarification({required this.question, this.clarificationRequestId, this.originalMessage});

  factory Clarification.fromJson(Map<String, dynamic> json) => Clarification(
    question: json['clarification_question'] ?? '',
    clarificationRequestId: json['clarification_request_id'],
    originalMessage: json['original_message'],
  );
}

class WebhookEvent {
  final String requestId;
  final String status;
  final int timestamp;
  final List<ContentItem> content;
  final ErrorDetails? error;
  final Clarification? clarification;
  final String? formationId;
  final String? userId;
  final double? processingTime;
  final String processingMode;
  final String? webhookUrl;
  final Map<String, dynamic> raw;

  WebhookEvent({
    required this.requestId,
    required this.status,
    required this.timestamp,
    required this.content,
    this.error,
    this.clarification,
    this.formationId,
    this.userId,
    this.processingTime,
    this.processingMode = 'async',
    this.webhookUrl,
    required this.raw,
  });

  factory WebhookEvent.fromJson(Map<String, dynamic> json) {
    final response = json['response'] as List<dynamic>? ?? [];
    final content = response.map((item) => ContentItem.fromJson(item as Map<String, dynamic>)).toList();
    final errorData = json['error'] as Map<String, dynamic>?;
    final status = json['status'] as String? ?? 'unknown';

    return WebhookEvent(
      requestId: json['id'] as String? ?? '',
      status: status,
      timestamp: (json['timestamp'] as num?)?.toInt() ?? 0,
      content: content,
      error: errorData != null ? ErrorDetails.fromJson(errorData) : null,
      clarification: status == 'awaiting_clarification' ? Clarification.fromJson(json) : null,
      formationId: json['formation_id'] as String?,
      userId: json['user_id'] as String?,
      processingTime: (json['processing_time'] as num?)?.toDouble(),
      processingMode: json['processing_mode'] as String? ?? 'async',
      webhookUrl: json['webhook_url'] as String?,
      raw: json,
    );
  }
}

class Webhook {
  static bool verifySignature(String payload, String? signatureHeader, String secret, {int toleranceSeconds = 300}) {
    if (signatureHeader == null || signatureHeader.isEmpty) return false;
    if (secret.isEmpty) throw WebhookVerificationException('Webhook secret is required');

    final parts = <String, String>{};
    try {
      for (final part in signatureHeader.split(',')) {
        final kv = part.split('=');
        if (kv.length == 2) parts[kv[0]] = kv[1];
      }
    } catch (_) {
      return false;
    }

    final timestampStr = parts['t'];
    final signature = parts['v1'];
    if (timestampStr == null || signature == null) return false;

    final timestamp = int.tryParse(timestampStr);
    if (timestamp == null) return false;

    final currentTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if ((currentTime - timestamp).abs() > toleranceSeconds) return false;

    final message = '$timestamp.$payload';
    final hmac = Hmac(sha256, utf8.encode(secret));
    final digest = hmac.convert(utf8.encode(message));
    final expected = digest.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

    return expected == signature;
  }

  static WebhookEvent parse(String payload) {
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      return WebhookEvent.fromJson(data);
    } catch (e) {
      throw WebhookVerificationException('Invalid JSON payload: $e');
    }
  }

  static WebhookEvent parseJson(Map<String, dynamic> data) => WebhookEvent.fromJson(data);
}
