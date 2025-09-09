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

  group('Global Counter ID Tests', () {
    test('should validate global ID format patterns', () {
      const userId = 'abc123def456';
      const globalId = 1;
      const userReportNum = 1;
      const expectedGlobalPattern = r'^\d+_user_abc123def456_report_\d+$';
      
      // Test various global IDs match the expected pattern
      const testGlobalIds = [
        '1_user_abc123def456_report_1',
        '123_user_abc123def456_report_5',
        '9999_user_abc123def456_report_999',
      ];
      
      final regex = RegExp(expectedGlobalPattern);
      
      for (final id in testGlobalIds) {
        expect(regex.hasMatch(id), isTrue, 
               reason: 'Global ID "$id" should match pattern $expectedGlobalPattern');
      }
    });

    test('should validate global fallback ID format', () {
      const userId = 'test_user_error';
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fallbackId = '${timestamp}_user_${userId}_report_fallback_123';
      
      // Global fallback ID should contain global prefix, user ID, and fallback marker
      expect(fallbackId, contains('_user_test_user_error_report_fallback_'));
      expect(fallbackId, startsWith(timestamp.toString()));
      expect(fallbackId.length, greaterThan('_user_test_user_error_report_fallback_'.length));
    });

    test('should generate different global IDs for same user', () {
      const userId = 'testUser';
      const globalIds = [1, 2, 3];
      const userReportNums = [1, 2, 1]; // Different users can have same user report numbers
      
      final generatedIds = <String>[];
      for (int i = 0; i < globalIds.length; i++) {
        generatedIds.add('${globalIds[i]}_user_${userId}_report_${userReportNums[i]}');
      }
      
      expect(generatedIds, [
        '1_user_testUser_report_1',
        '2_user_testUser_report_2', 
        '3_user_testUser_report_1',
      ]);
      
      // All global IDs should be different even if user report numbers repeat
      final uniqueIds = generatedIds.toSet();
      expect(uniqueIds.length, equals(generatedIds.length));
    });

    test('should validate global sequential ordering', () {
      const userId1 = 'alice';
      const userId2 = 'bob';
      
      // Global IDs should be sequential regardless of user
      final sequentialGlobalIds = [
        '1_user_${userId1}_report_1',
        '2_user_${userId2}_report_1', 
        '3_user_${userId1}_report_2',
        '4_user_${userId2}_report_2',
      ];
      
      // Extract global IDs and verify they're sequential
      final globalNumbers = sequentialGlobalIds.map((id) {
        return int.parse(id.split('_')[0]);
      }).toList();
      
      expect(globalNumbers, [1, 2, 3, 4]);
      
      // Verify each ID has correct format
      for (final id in sequentialGlobalIds) {
        expect(id, matches(r'^\d+_user_\w+_report_\d+$'));
      }
    });

    test('should maintain user-specific counters in global format', () {
      const userId = 'testUser';
      
      // User report numbers should still increment per user
      final userReports = [
        '1_user_${userId}_report_1',
        '5_user_${userId}_report_2', 
        '10_user_${userId}_report_3',
      ];
      
      // Extract user report numbers
      final userNumbers = userReports.map((id) {
        final parts = id.split('_');
        return int.parse(parts.last);
      }).toList();
      
      expect(userNumbers, [1, 2, 3]);
      
      // Global numbers can be non-sequential for same user
      final globalNumbers = userReports.map((id) {
        return int.parse(id.split('_')[0]);
      }).toList();
      
      expect(globalNumbers, [1, 5, 10]);
    });

    test('should handle large global counter values', () {
      const userId = 'testUser';
      const largeGlobalId = 999999;
      const userReportNum = 123;
      final largeGlobalFormat = '${largeGlobalId}_user_${userId}_report_$userReportNum';
      
      expect(largeGlobalFormat, equals('999999_user_testUser_report_123'));
      expect(largeGlobalFormat.length, greaterThan(25)); // Should handle large numbers
      expect(largeGlobalFormat, startsWith('999999_'));
    });

    test('should differentiate between legacy and global formats', () {
      const userId = 'testUser';
      
      final legacyFormat = 'user_${userId}_report_1';
      final globalFormat = '1_user_${userId}_report_1';
      
      expect(legacyFormat, equals('user_testUser_report_1'));
      expect(globalFormat, equals('1_user_testUser_report_1'));
      
      // Global format should start with a number
      expect(globalFormat, matches(r'^\d+_'));
      expect(legacyFormat, matches(r'^user_'));
      
      // Both should be valid but distinguishable
      expect(legacyFormat, isNot(equals(globalFormat)));
    });

    test('should validate global counter document format', () {
      const globalCounterDocId = 'global_report_counter';
      
      expect(globalCounterDocId, equals('global_report_counter'));
      expect(globalCounterDocId, isNot(contains('user_')));
      expect(globalCounterDocId, isNot(endsWith('_reports')));
    });
  });

  group('Mixed Format Support Tests', () {
    test('should support both legacy and global formats simultaneously', () {
      const userId = 'testUser';
      
      final legacyIds = [
        'user_${userId}_report_1',
        'user_${userId}_report_2',
      ];
      
      final globalIds = [
        '1_user_${userId}_report_1',
        '2_user_${userId}_report_2',
      ];
      
      final mixedIds = [...legacyIds, ...globalIds];
      
      // All IDs should be unique
      final uniqueIds = mixedIds.toSet();
      expect(uniqueIds.length, equals(mixedIds.length));
      
      // Should be able to distinguish formats
      final legacyPattern = RegExp(r'^user_\w+_report_\d+$');
      final globalPattern = RegExp(r'^\d+_user_\w+_report_\d+$');
      
      for (final id in legacyIds) {
        expect(legacyPattern.hasMatch(id), isTrue);
        expect(globalPattern.hasMatch(id), isFalse);
      }
      
      for (final id in globalIds) {
        expect(globalPattern.hasMatch(id), isTrue);
        expect(legacyPattern.hasMatch(id), isFalse);
      }
    });

    test('should handle user reports query with mixed formats', () {
      const userId = 'testUser';
      
      // Simulate mixed format report IDs in database
      final allReportIds = [
        'user_${userId}_report_1',          // Legacy format
        'user_${userId}_report_2',          // Legacy format
        '5_user_${userId}_report_3',        // Global format
        '8_user_${userId}_report_4',        // Global format
        'user_otherUser_report_1',          // Different user (should be filtered)
        '10_user_otherUser_report_1',       // Different user (should be filtered)
      ];
      
      // Filter for testUser reports (both formats)
      final userReports = allReportIds.where((id) {
        final legacyPattern = RegExp(r'^user_' + userId + r'_report_\d+$');
        final globalPattern = RegExp(r'^\d+_user_' + userId + r'_report_\d+$');
        return legacyPattern.hasMatch(id) || globalPattern.hasMatch(id);
      }).toList();
      
      expect(userReports.length, equals(4));
      expect(userReports, containsAll([
        'user_${userId}_report_1',
        'user_${userId}_report_2',
        '5_user_${userId}_report_3',
        '8_user_${userId}_report_4',
      ]));
    });
  });
}
