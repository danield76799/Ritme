import 'package:flutter_test/flutter_test.dart';
import 'package:ritme/utils/bool_helper.dart';

void main() {
  group('BoolHelper.parse', () {
    test('should return true for bool true', () {
      expect(BoolHelper.parse(true), isTrue);
    });

    test('should return false for bool false', () {
      expect(BoolHelper.parse(false), isFalse);
    });

    test('should return true for int 1', () {
      expect(BoolHelper.parse(1), isTrue);
    });

    test('should return false for int 0', () {
      expect(BoolHelper.parse(0), isFalse);
    });

    test('should return true for String "true"', () {
      expect(BoolHelper.parse('true'), isTrue);
    });

    test('should return true for String "1"', () {
      expect(BoolHelper.parse('1'), isTrue);
    });

    test('should return true for String "yes"', () {
      expect(BoolHelper.parse('yes'), isTrue);
    });

    test('should return true for String "ja"', () {
      expect(BoolHelper.parse('ja'), isTrue);
    });

    test('should return false for String "false"', () {
      expect(BoolHelper.parse('false'), isFalse);
    });

    test('should return false for String "0"', () {
      expect(BoolHelper.parse('0'), isFalse);
    });

    test('should return defaultValue for null', () {
      expect(BoolHelper.parse(null), isFalse);
      expect(BoolHelper.parse(null, defaultValue: true), isTrue);
    });

    test('should be case insensitive', () {
      expect(BoolHelper.parse('TRUE'), isTrue);
      expect(BoolHelper.parse('True'), isTrue);
      expect(BoolHelper.parse('FALSE'), isFalse);
    });
  });

  group('BoolHelper.toInt', () {
    test('should return 1 for true', () {
      expect(BoolHelper.toInt(true), equals(1));
    });

    test('should return 0 for false', () {
      expect(BoolHelper.toInt(false), equals(0));
    });
  });

  group('BoolHelper.toString', () {
    test('should return "true" for true', () {
      expect(BoolHelper.toString(true), equals('true'));
    });

    test('should return "false" for false', () {
      expect(BoolHelper.toString(false), equals('false'));
    });
  });
}
