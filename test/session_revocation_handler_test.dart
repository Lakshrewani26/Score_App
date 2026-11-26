import 'package:flutter_test/flutter_test.dart';
import 'package:score_app/core/services/session_revocation_handler.dart';

void main() {
  group('SessionRevocationHandler.isSessionRevokedError', () {
    test('returns true for exact backend error message', () {
      expect(
        SessionRevocationHandler.isSessionRevokedError(
          'Your account was logged in on another device. Please log in again.',
        ),
        isTrue,
      );
    });

    test('returns true for message containing "another device"', () {
      expect(
        SessionRevocationHandler.isSessionRevokedError(
          'Session invalid: another device is active.',
        ),
        isTrue,
      );
    });

    test('returns true for message containing "session expired"', () {
      expect(
        SessionRevocationHandler.isSessionRevokedError('session expired'),
        isTrue,
      );
    });

    test('returns true for message containing "session revoked"', () {
      expect(
        SessionRevocationHandler.isSessionRevokedError('session revoked'),
        isTrue,
      );
    });

    test('returns false for ordinary 401 message', () {
      expect(
        SessionRevocationHandler.isSessionRevokedError('Not authenticated'),
        isFalse,
      );
    });

    test('returns false for null message', () {
      expect(SessionRevocationHandler.isSessionRevokedError(null), isFalse);
    });

    test('returns false for empty string', () {
      expect(SessionRevocationHandler.isSessionRevokedError(''), isFalse);
    });

    test('is case-insensitive — uppercase ANOTHER DEVICE matches', () {
      expect(
        SessionRevocationHandler.isSessionRevokedError('ANOTHER DEVICE'),
        isTrue,
      );
    });
  });

  group('SessionRevocationHandler.sessionRevokedMessage', () {
    test('constant matches the expected UI message', () {
      expect(
        SessionRevocationHandler.sessionRevokedMessage,
        equals(
          'Your account was logged in on another device. Please log in again.',
        ),
      );
    });
  });
}
