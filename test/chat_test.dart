import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:license_prep_app/localization/app_localizations.dart';
import 'package:license_prep_app/models/chat.dart';
import 'package:license_prep_app/models/instructor_listing.dart';
import 'package:license_prep_app/providers/language_provider.dart';
import 'package:license_prep_app/screens/instructor_detail_screen.dart';
import 'package:license_prep_app/services/instructor_service.dart';
import 'package:license_prep_app/widgets/bento_question_parts.dart';
import 'package:license_prep_app/widgets/super_enhanced_footer.dart';
import 'package:license_prep_app/widgets/unread_badge.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Instructors P6 — chat (plan v2 §10). The server half (masking, limits,
/// paywall) is tested in functions/src/__tests__/chat.test.ts; here: what
/// the app decides — unread counts, the badge, «Написать» from stage 1, and
/// where the code opens threads, asks for push permission and hides banners.

ChatConversation _conv({
  int studentUnread = 0,
  int instructorUnread = 0,
  bool studentDeleted = false,
  bool instructorDeleted = false,
}) =>
    ChatConversation(
      id: 's1_i1',
      studentUid: 's1',
      instructorUid: 'i1',
      instructorName: 'Maria',
      studentDisplayName: 'Anna K.',
      contactUnlocked: false,
      lastMessageText: 'Hi',
      studentUnread: studentUnread,
      instructorUnread: instructorUnread,
      studentDeleted: studentDeleted,
      instructorDeleted: instructorDeleted,
    );

class _StageService extends InstructorService {
  _StageService(this.stage);

  final int stage;

  @override
  Future<InstructorListing> detail(String id) async => _listing(stage);

  @override
  Future<List<InstructorReview>> reviews(String id) async => const [];

  @override
  Stream<Set<String>> favorites(String uid) => const Stream.empty();
}

InstructorListing _listing(int stage) => InstructorListing.fromMap({
      'id': 'i1', 'kind': 'schoolInstructor', 'name': 'Maria Lopez', 'city': 'Chicago', 'state': 'IL',
      'languages': ['en'], 'stage': stage, 'ratingAvg': 0, 'ratingCount': 0, 'lessonDurations': [60],
      'priceHidden': true, 'payoutsEnabled': false,
    });

Map<String, dynamic> _locale(String lang) =>
    jsonDecode(File('lib/localization/l10n/$lang.json').readAsStringSync()) as Map<String, dynamic>;

void main() {
  group('a conversation, from each side', () {
    test('each side has its own unread count', () {
      final c = _conv(studentUnread: 2, instructorUnread: 5);
      expect(c.unreadFor('s1'), 2);
      expect(c.unreadFor('i1'), 5);
    });

    test('a deleted side closes the thread and is the OTHER side for the one left', () {
      final c = _conv(instructorDeleted: true);
      expect(c.closed, isTrue);
      expect(c.otherDeleted('s1'), isTrue);
      expect(c.otherDeleted('i1'), isFalse);
      expect(_conv().closed, isFalse);
    });
  });

  group('the unread badge', () {
    test('caps at 9+', () {
      expect(UnreadBadge.label(1), '1');
      expect(UnreadBadge.label(9), '9');
      expect(UnreadBadge.label(10), '9+');
    });

    testWidgets('draws nothing for zero', (tester) async {
      await tester.pumpWidget(const Directionality(textDirection: TextDirection.ltr, child: UnreadBadge(count: 0)));
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('sits on the Чат tab of the instructor bar', (tester) async {
      final bytes = File('assets/fonts/Rubik.ttf').readAsBytesSync();
      await (FontLoader('Rubik')..addFont(Future.value(ByteData.view(Uint8List.fromList(bytes).buffer)))).load();
      SharedPreferences.setMockInitialValues({'language': 'ru', 'app_initialized': true});
      final language = LanguageProvider();
      await tester.runAsync(language.waitForLoad);
      tester.view.physicalSize = const Size(402, 874);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(ChangeNotifierProvider.value(
        value: language,
        child: MaterialApp(
          home: Scaffold(
            bottomNavigationBar: SuperEnhancedFooter(
              currentIndex: 0,
              onTap: (_) {},
              forInstructor: true,
              badges: const [0, 3, 0],
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(UnreadBadge), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      // Its count reaches screen readers through the tab itself.
      expect(find.bySemanticsLabel('Чат'), findsOneWidget);
      final chat = tester.getCenter(find.text('Чат'));
      final badge = tester.getCenter(find.byType(UnreadBadge));
      expect((badge.dx - chat.dx).abs(), lessThan(24));
    });
  });

  group('«Написать» on the detail page', () {
    Future<void> pump(WidgetTester tester, int stage) async {
      await tester.binding.setSurfaceSize(const Size(402, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.runAsync(() async {
        await tester.pumpWidget(MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en')],
          home: InstructorDetailScreen(instructor: _listing(stage), uid: 's1', service: _StageService(stage)),
        ));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
    }

    BentoActionButton message(WidgetTester tester) => tester.widget<BentoActionButton>(
        find.ancestor(of: find.text('Message'), matching: find.byType(BentoActionButton)));

    testWidgets('opens from stage 1 (ID checked), with no reason under it', (tester) async {
      await pump(tester, 1);
      expect(message(tester).onTap, isNotNull);
      expect(find.text('Messages open once the ID is checked.'), findsNothing);
    });

    testWidgets('stays disabled at stage 0, with the reason', (tester) async {
      await pump(tester, 0);
      expect(message(tester).onTap, isNull);
      expect(find.text('Messages open once the ID is checked.'), findsOneWidget);
    });
  });

  group('where the code opens, asks and stays quiet', () {
    String code(String path) => File(path).readAsStringSync();

    test('a chat push opens the thread instead of being dropped', () {
      final home = code('lib/screens/home_screen.dart');
      expect(home, contains("route.name != 'chat'"));
      expect(home, contains('ChatThreadScreen(conversationId: route.id!)'));
    });

    test('no in-app banner for the thread already on screen', () {
      expect(code('lib/main.dart'), contains('route?.id == PushService.openConversation.value'));
      final thread = code('lib/screens/chat_thread_screen.dart');
      expect(thread, contains('PushService.openConversation.value = widget.conversationId'));
    });

    test("a student's first message asks for push permission, without blocking the send", () {
      final thread = code('lib/screens/chat_thread_screen.dart');
      final created = thread.indexOf('if (result.created)');
      expect(created, greaterThan(0));
      expect(thread.indexOf('unawaited(PushService.instance.requestPermissionAndRegister())'), greaterThan(created));
    });

    test('every chat string the code picks at run time exists in all five languages', () {
      // Chosen through _errorKey, so the literal-key coverage test can't see them.
      const keys = [
        'chat_thread_limit', 'chat_closed', 'instructor_chat_after_id', 'chat_paid_required',
        'instructor_unavailable_title', 'chat_send_error',
      ];
      for (final lang in ['en', 'es', 'uk', 'ru', 'pl']) {
        final locale = _locale(lang);
        for (final key in keys) {
          expect(locale[key], isA<String>(), reason: '$key in $lang');
        }
        expect(locale['chat_you_prefix'], contains('{text}'), reason: lang);
      }
    });
  });
}
