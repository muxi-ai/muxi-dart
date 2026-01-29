import 'package:test/test.dart';
import 'package:muxi/src/errors.dart';

void main() {
  group('Error mapping', () {
    test('mapError returns AuthenticationException for 401', () {
      final error = mapError(401, null, 'Unauthorized');
      expect(error, isA<AuthenticationException>());
      expect(error.statusCode, equals(401));
    });

    test('mapError returns AuthorizationException for 403', () {
      final error = mapError(403, null, 'Forbidden');
      expect(error, isA<AuthorizationException>());
      expect(error.statusCode, equals(403));
    });

    test('mapError returns NotFoundException for 404', () {
      final error = mapError(404, 'NOT_FOUND', 'Not found');
      expect(error, isA<NotFoundException>());
      expect(error.code, equals('NOT_FOUND'));
    });

    test('mapError returns ConflictException for 409', () {
      final error = mapError(409, null, 'Conflict');
      expect(error, isA<ConflictException>());
    });

    test('mapError returns ValidationException for 422', () {
      final error = mapError(422, null, 'Invalid input');
      expect(error, isA<ValidationException>());
    });

    test('mapError returns RateLimitException for 429', () {
      final error = mapError(429, null, 'Too many requests', null, 30);
      expect(error, isA<RateLimitException>());
      expect((error as RateLimitException).retryAfter, equals(30));
    });

    test('mapError returns ServerException for 5xx', () {
      final error = mapError(500, null, 'Internal server error');
      expect(error, isA<ServerException>());
      expect(error.statusCode, equals(500));
    });

    test('MuxiException toString includes code and message', () {
      final error = MuxiException('TEST_ERROR', 'Test message', 400);
      expect(error.toString(), equals('TEST_ERROR: Test message'));
    });

    test('MuxiException toString handles empty code', () {
      final error = MuxiException('', 'Test message', 400);
      expect(error.toString(), equals('Test message'));
    });
  });
}
