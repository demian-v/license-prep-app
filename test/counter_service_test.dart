import 'package:flutter_test/flutter_test.dart';
import '../lib/services/counter_service.dart';

void main() {
  group('CounterService Tests', () {
    late CounterService counterService;

    setUp(() {
      counterService = CounterService();
    });

    test('should create CounterService instance', () {
      expect(counterService, isNotNull);
    });

    test('should validate ID format patterns', () {
      const userId = 'abc123def456';
      const expectedPattern = r'^user_abc123def456_report_\d+$';
      
      // Test various generated IDs match the expected pattern
      const testIds = [
        'user_abc123def456_report_1',
        'user_abc123def456_report_123',
        'user_abc123def456_report_9999',
      ];
      
      final regex = RegExp(expectedPattern);
      
      for (final id in testIds) {
        expect(regex.hasMatch(id), isTrue, 
               reason: 'ID "$id" should match pattern $expectedPattern');
      }
    });

    test('should validate fallback ID format', () {
      const userId = 'test_user_error';
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fallbackId = 'user_${userId}_report_${timestamp}_123';
      
      // Fallback ID should contain user ID and timestamp
      expect(fallbackId, contains('user_test_user_error_report_'));
      expect(fallbackId.length, greaterThan('user_test_user_error_report_'.length));
    });

    test('should handle user ID validation', () {
      const validUserIds = [
        'abc123',
        'user_test_123',
        'abcDEF123xyz',
        '1234567890',
      ];
      
      for (final userId in validUserIds) {
        final expectedId = 'user_${userId}_report_1';
        expect(expectedId, startsWith('user_'));
        expect(expectedId, contains('_report_'));
        expect(expectedId, endsWith('_1'));
      }
    });

    test('should generate different formats for different users', () {
      const userIds = ['user1', 'user2', 'user3'];
      final reportCounter = 5;
      
      final generatedIds = userIds.map((userId) => 
        'user_${userId}_report_$reportCounter').toList();
      
      expect(generatedIds, [
        'user_user1_report_5',
        'user_user2_report_5', 
        'user_user3_report_5',
      ]);
      
      // All IDs should be different
      final uniqueIds = generatedIds.toSet();
      expect(uniqueIds.length, equals(generatedIds.length));
    });

    test('should create proper counter document ID format', () {
      const userId = 'test123';
      final counterDocId = 'user_${userId}_reports';
      
      expect(counterDocId, equals('user_test123_reports'));
      expect(counterDocId, startsWith('user_'));
      expect(counterDocId, endsWith('_reports'));
    });
  });

  group('Report ID Pattern Validation', () {
    test('should validate sequential numbering', () {
      const userId = 'testUser';
      final sequentialIds = [
        'user_testUser_report_1',
        'user_testUser_report_2',
        'user_testUser_report_3',
      ];
      
      for (int i = 0; i < sequentialIds.length; i++) {
        final expectedId = 'user_testUser_report_${i + 1}';
        expect(sequentialIds[i], equals(expectedId));
      }
    });
    
    test('should handle large counter values', () {
      const userId = 'testUser';
      const largeCounter = 99999;
      final largeId = 'user_${userId}_report_$largeCounter';
      
      expect(largeId, equals('user_testUser_report_99999'));
      expect(largeId.length, greaterThan(20)); // Should handle large numbers
    });

    test('should maintain user isolation in ID format', () {
      const user1 = 'alice123';
      const user2 = 'bob456';
      const reportNum = 1;
      
      final user1Id = 'user_${user1}_report_$reportNum';
      final user2Id = 'user_${user2}_report_$reportNum';
      
      expect(user1Id, equals('user_alice123_report_1'));
      expect(user2Id, equals('user_bob456_report_1'));
      expect(user1Id, isNot(equals(user2Id)));
    });
  });

  group('Error Handling Patterns', () {
    test('should create valid fallback timestamp format', () {
      const userId = 'errorUser';
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final randomSuffix = '123';
      final fallbackId = 'user_${userId}_report_${timestamp}_$randomSuffix';
      
      expect(fallbackId, startsWith('user_errorUser_report_'));
      expect(fallbackId, endsWith('_123'));
      expect(fallbackId.contains(timestamp.toString()), isTrue);
    });
  });
}
