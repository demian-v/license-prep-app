import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../localization/app_localizations.dart';
import '../models/chat.dart';
import '../providers/auth_provider.dart';
import '../services/chat_service.dart';
import '../theme/app_theme.dart';
import '../theme/bento_tokens.dart';
import '../theme/solar_icons.dart';
import '../widgets/bento_empty_card.dart';
import '../widgets/bento_result_parts.dart';
import '../widgets/instructor_card.dart';
import '../widgets/unread_badge.dart';
import 'chat_thread_screen.dart';

/// The conversations list (instructors plan v2 §10, P6). For an instructor it
/// is the «Чат» tab; for a student it is the «Сообщения» segment of
/// Инструкторы ([embedded] drops the page scaffold), or a pushed page
/// ([pushed]) when their plan has lapsed and only reading is left (owner,
/// 2026-10-05). Newest first; each row opens the thread.
class ChatListScreen extends StatefulWidget {
  const ChatListScreen(
      {super.key, this.embedded = false, this.pushed = false, this.service});

  final bool embedded;
  final bool pushed;
  final ChatService? service;

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  late final ChatService _service = widget.service ?? ChatService();
  Stream<List<ChatConversation>>? _stream;
  String? _streamUid;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final uid = Provider.of<AuthProvider>(context).user?.id;
    if (uid != null && uid != _streamUid) {
      _streamUid = uid;
      _stream = _service.conversations(uid);
    }
    final empty = BentoEmptyCard(
      icon: SolarIcons.chatRoundLineLinear,
      title: l.translate('chat_empty_title'),
      description: l.translate('chat_empty_desc'),
    );

    final content = StreamBuilder<List<ChatConversation>>(
      stream: _stream,
      builder: (context, snap) {
        final list = snap.data ?? const <ChatConversation>[];
        final tab = !widget.embedded && !widget.pushed;
        if (uid == null || (snap.hasData && list.isEmpty) || snap.hasError) {
          return tab ? _tabPage(l, [empty]) : empty;
        }
        if (!snap.hasData) {
          const spinner = Padding(
            padding: EdgeInsets.only(top: AppSpacing.x6),
            child: Center(child: CircularProgressIndicator()),
          );
          return tab ? _tabPage(l, const [spinner]) : spinner;
        }
        final rows = [
          for (final c in list) ...[
            _ConversationRow(conversation: c, uid: uid, onTap: () => _open(c)),
            const SizedBox(height: AppSpacing.x3),
          ],
        ];
        if (widget.embedded) return Column(children: rows);
        if (tab) return _tabPage(l, rows);
        return ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.x4 + AppSpacing.x1,
              AppSpacing.x2, AppSpacing.x4 + AppSpacing.x1, AppSpacing.x6),
          children: rows,
        );
      },
    );

    if (widget.embedded) return content;
    if (widget.pushed) {
      return Scaffold(
        backgroundColor: AppColors.field,
        appBar: bentoHeadingAppBar(
          title: l.translate('instructors_tab_messages'),
          onBack: () => Navigator.of(context).pop(),
        ),
        body: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.x4 + AppSpacing.x1),
            child: content,
          ),
        ),
      );
    }
    // The instructor's tab: no title (owner rule 1).
    return Scaffold(
        backgroundColor: AppColors.field, body: SafeArea(child: content));
  }

  /// The instructor's tab: a heading and one grey line, as on Календарь,
  /// then the threads or the empty card, top-aligned (owner, 2026-10-05: the
  /// page looked empty with one thread). Not a title bar — the heading
  /// scrolls with the list.
  Widget _tabPage(AppLocalizations l, List<Widget> children) => ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.x4 + AppSpacing.x1,
            AppSpacing.x4, AppSpacing.x4 + AppSpacing.x1, AppSpacing.x6),
        children: [
          Text(
            l.translate('instructors_tab_messages'),
            style: AppTypography.title.copyWith(
              fontSize: 22,
              height: 28 / 22,
              color: AppColors.ink,
              fontVariations: const [FontVariation('wght', 700)],
            ),
          ),
          const SizedBox(height: AppSpacing.x1),
          Text(
            l.translate('chat_tab_desc'),
            style: AppTypography.body.copyWith(color: AppColors.inkSecondary),
          ),
          const SizedBox(height: AppSpacing.x3),
          ...children,
        ],
      );

  void _open(ChatConversation c) {
    Navigator.of(context).push(ForwardPageRoute(
      child: ChatThreadScreen(conversationId: c.id, service: widget.service),
    ));
  }
}

/// One thread: the other person (photo or initial), the last message under
/// the name, the time, and the unread count.
class _ConversationRow extends StatelessWidget {
  const _ConversationRow(
      {required this.conversation, required this.uid, required this.onTap});

  final ChatConversation conversation;
  final String uid;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = conversation;
    final asStudent = c.isStudent(uid);
    final deleted = c.otherDeleted(uid);
    final name = deleted
        ? l.translate('chat_deleted_user')
        : asStudent
            ? c.instructorName
            : (c.studentDisplayName.isEmpty
                ? l.translate('chat_student_fallback')
                : c.studentDisplayName);
    final unread = c.unreadFor(uid);
    final text = c.lastMessageSender == uid
        ? l.translate('chat_you_prefix').replaceAll('{text}', c.lastMessageText)
        : c.lastMessageText;

    return PressScale(
      scale: 0.98,
      duration: BentoTokens.state,
      // Fill and shadow under a transparent Material, so the ink splash
      // shows and the shadow does not grey the white (design patterns).
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.paper,
          borderRadius: BorderRadius.circular(BentoTokens.card),
          boxShadow: AppColors.shadowCard,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(BentoTokens.card),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.x4),
              child: Row(
                children: [
                  asStudent && !deleted
                      ? InstructorAvatar(
                          photoPath: c.instructorPhotoPath, size: 52)
                      : ChatLetterAvatar(name: deleted ? '' : name, size: 52),
                  const SizedBox(width: AppSpacing.x3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.title.copyWith(
                                  fontSize: 17,
                                  height: 22 / 17,
                                  color: deleted
                                      ? AppColors.inkSecondary
                                      : AppColors.ink,
                                  fontVariations: const [
                                    FontVariation('wght', 600)
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.x2),
                            Text(
                              _time(context, c.lastMessageAt),
                              style: AppTypography.caption.copyWith(
                                color: unread > 0
                                    ? AppColors.stop
                                    : AppColors.inkTertiary,
                                fontFeatures: const [
                                  FontFeature.tabularFigures()
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                text,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.label.copyWith(
                                  color: unread > 0
                                      ? AppColors.ink
                                      : AppColors.inkSecondary,
                                ),
                              ),
                            ),
                            if (unread > 0) ...[
                              const SizedBox(width: AppSpacing.x2),
                              UnreadBadge(count: unread, ring: false),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Today: the time; earlier: the date, in the app's language.
  static String _time(BuildContext context, DateTime? at) {
    if (at == null) return '';
    final locale = Localizations.localeOf(context).toString();
    final now = DateTime.now();
    final today =
        at.year == now.year && at.month == now.month && at.day == now.day;
    return today
        ? DateFormat.Hm(locale).format(at)
        : DateFormat.MMMd(locale).format(at);
  }
}
