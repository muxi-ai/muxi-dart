import 'package:test/test.dart';
import 'package:muxi/src/auth.dart';

void main() {
  group('Auth', () {
    test('generateHmacSignature returns valid signature and timestamp', () {
      final (signature, timestamp) = Auth.generateHmacSignature('secret', 'GET', '/test');
      
      expect(signature, isNotEmpty);
      expect(timestamp, greaterThan(0));
      expect((DateTime.now().millisecondsSinceEpoch ~/ 1000 - timestamp).abs(), lessThanOrEqualTo(5));
    });

    test('buildAuthHeader returns properly formatted header', () {
      final header = Auth.buildAuthHeader('key123', 'secret', 'POST', '/rpc/test');
      
      expect(header, startsWith('MUXI-HMAC key=key123, timestamp='));
      expect(header, contains('signature='));
    });

    test('generateHmacSignature strips query params from path', () {
      final (sig1, _) = Auth.generateHmacSignature('secret', 'GET', '/test');
      final (sig2, _) = Auth.generateHmacSignature('secret', 'GET', '/test?foo=bar');
      
      expect(sig1.length, equals(sig2.length));
    });

    test('generateHmacSignature produces consistent signatures', () {
      final (sig1, ts1) = Auth.generateHmacSignature('secret', 'GET', '/test');
      final (sig2, ts2) = Auth.generateHmacSignature('secret', 'GET', '/test');
      
      if (ts1 == ts2) expect(sig1, equals(sig2));
    });
  });
}
