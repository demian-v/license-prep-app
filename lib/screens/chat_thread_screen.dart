import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../localization/app_localizations.dart';
import '../models/chat.dart';
import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';
import '../providers/state_provider.dart';
import '../providers/subscription_provider.dart';
import '../services/analytics_service.dart';
import '../services/chat_service.dart';
import '../services/instructor_service.dart';
import '../services/push_service.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import '../theme/bento_tokens.dart';
import '../theme/solar_icons.dart';
import '../widgets/bento_question_parts.dart';
import '../widgets/instructor_card.dart';
import '../widgets/report_sheet.dart';
import 'booking_screen.dart';
import 'instructor_detail_screen.dart';

/// Who the thread is with, before the conversation exists: a student opening
/// «Написать» on a profile (instructors plan v2 §10).
class ChatPartner {
  const ChatPartner(
      {required this.instructorUid, required this.name, this.photoPath});

  final String instructorUid;
  final String name;
  final String? photoPath;
}

/// One conversation (plan v2 §10, P6). Messages stream live; sending goes
/// through `sendMessage`, which masks contacts until the first booking.
///
/// A student opening «Написать» passes [partner]: until their first message
/// creates the thread there is nothing to listen to (the rules refuse a
/// missing conversation), so the page shows only the composer.
class ChatThreadScreen extends StatefulWidget {
  const ChatThreadScreen(
      {super.key, required this.conversationId, this.partner, this.service});

  final String conversationId;
  final ChatPartner? partner;
  final ChatService? service;

  @override
  State<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends State<ChatThreadScreen> {
  late final ChatService _service = widget.service ?? ChatService();
  final _input = TextEditingController();
  final _scroll = ScrollController();

  /// Null while a new-thread page checks whether the thread exists already.
  bool? _exists;
  Stream<ChatConversation>? _conversation;
  Stream<List<ChatMessage>>? _messages;
  StreamSubscription<ChatConversation>? _readSub;
  int _limit = 50;
  bool _sending = false;
  bool _marking = false;
  Future<({String phone, String email})>? _contacts;

  String get _uid =>
      Provider.of<AuthProvider>(context, listen: false).user?.id ?? '';

  @override
  void initState() {
    super.initState();
    PushService.openConversation.value = widget.conversationId;
    _scroll.addListener(_onScroll);
    if (widget.partner == null) {
      _listen();
    } else {
      _service.exists(widget.conversationId).then((exists) {
        if (!mounted) return;
        if (exists) {
          _listen();
        } else {
          setState(() => _exists = false);
        }
      }, onError: (_) {
        if (mounted) setState(() => _exists = false);
      });
    }
  }

  void _listen() {
    setState(() {
      _exists = true;
      _conversation =
          _service.conversation(widget.conversationId).asBroadcastStream();
      _messages = _service.messages(widget.conversationId, limit: _limit);
    });
    // Opening the thread, and every message arriving while it is open,
    // reads it: the caller's unread count goes back to zero.
    _readSub = _conversation!.listen((c) {
      if (c.unreadFor(_uid) > 0 && !_marking) {
        _marking = true;
        _service
            .markRead(widget.conversationId)
            .catchError((_) {})
            .whenComplete(() => _marking = false);
      }
    }, onError: (_) {});
  }

  /// Older messages, 50 at a time, when the list reaches its top.
  void _onScroll() {
    if (_messages == null || !_scroll.hasClients) return;
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
      _loadMore = true;
    }
  }

  bool _loadMore = false;

  @override
  void dispose() {
    if (PushService.openConversation.value == widget.conversationId) {
      PushService.openConversation.value = null;
    }
    _readSub?.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await _service.send(
        conversationId: _exists == true ? widget.conversationId : null,
        instructorUid: _exists == true ? null : widget.partner?.instructorUid,
        text: text,
      );
      _input.clear();
      if (result.created) {
        analyticsService.logChatStarted();
        // The moment a push makes sense to a student: someone will answer
        // (plan v2 §12). Never blocks the send.
        unawaited(PushService.instance.requestPermissionAndRegister());
      }
      if (_exists != true && mounted) _listen();
    } on FirebaseFunctionsException catch (e) {
      messenger.showSnackBar(SnackBar(
          content: Text(l.translate(_errorKey(e))),
          backgroundColor: AppColors.stop));
    } catch (_) {
      messenger.showSnackBar(SnackBar(
          content: Text(l.translate('chat_send_error')),
          backgroundColor: AppColors.stop));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _errorKey(FirebaseFunctionsException e) {
    if (e.code == 'resource-exhausted') return 'chat_thread_limit';
    if (e.message == 'conversation-closed') return 'chat_closed';
    if (e.message == 'instructor-not-verified') {
      return 'instructor_chat_after_id';
    }
    if (e.code == 'permission-denied') return 'chat_paid_required';
    if (e.code == 'not-found') return 'instructor_unavailable_title';
    return 'chat_send_error';
  }

  void _report(ChatMessage m) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => ReportSheet(
        contentType: 'message',
        contextData: {
          'conversationId': widget.conversationId,
          'messageId': m.id,
          'language':
              Provider.of<LanguageProvider>(context, listen: false).language,
          'state': Provider.of<StateProvider>(context, listen: false)
                  .selectedStateId ??
              '',
        },
      ),
    );
  }

  /// A student taps the header: the instructor's profile, if still listed.
  Future<void> _openProfile(String instructorUid) async {
    final l = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final listing = await InstructorService().detail(instructorUid);
      navigator.push(ForwardPageRoute(
          child: InstructorDetailScreen(instructor: listing, uid: _uid)));
    } catch (_) {
      messenger.showSnackBar(
          SnackBar(content: Text(l.translate('instructor_unavailable_title'))));
    }
  }

  /// «Забронировать» in a school's thread (plan v2 §10): the profile is
  /// fetched first, so a school that can't take bookings yet says why.
  Future<void> _book(String instructorUid) async {
    final l = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final listing = await InstructorService().detail(instructorUid);
      if (listing.bookable) {
        navigator.push(ForwardPageRoute(child: BookingScreen(instructor: listing)));
      } else {
        messenger.showSnackBar(SnackBar(content: Text(l.translate('instructor_book_after_check'))));
      }
    } catch (_) {
      messenger.showSnackBar(
          SnackBar(content: Text(l.translate('instructor_unavailable_title'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (_conversation == null) return _scaffold(l, null);
    return StreamBuilder<ChatConversation>(
      stream: _conversation,
      builder: (context, snap) => _scaffold(l, snap.data),
    );
  }

  Widget _scaffold(AppLocalizations l, ChatConversation? c) {
    final uid = _uid;
    final asStudent = c == null ? true : c.isStudent(uid);
    final otherDeleted = c?.otherDeleted(uid) ?? false;
    final name = otherDeleted
        ? l.translate('chat_deleted_user')
        : asStudent
            ? (c?.instructorName ?? widget.partner?.name ?? '')
            : (c.studentDisplayName.isEmpty
                ? l.translate('chat_student_fallback')
                : c.studentDisplayName);
    final instructorUid = c?.instructorUid ?? widget.partner?.instructorUid;
    final paid = Provider.of<SubscriptionProvider>(context)
            .subscription
            ?.isPaidSubscription ??
        false;
    if (asStudent && c?.contactUnlocked == true && !otherDeleted) {
      _contacts ??= _service.contactInfo(widget.conversationId);
    }

    return Scaffold(
      backgroundColor: AppColors.field,
      appBar: AppBar(
        toolbarHeight: 64,
        centerTitle: false,
        titleSpacing: AppSpacing.x2,
        backgroundColor: AppColors.field,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: AppSpacing.x2),
          child: Center(
            child: IconButton(
              style: bentoRoundIconStyle,
              icon: const Icon(SolarIcons.arrowLeftLinear,
                  color: AppColors.ink, size: 24),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ),
        title: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: asStudent && !otherDeleted && instructorUid != null
              ? () => _openProfile(instructorUid)
              : null,
          child: Row(
            children: [
              // On the field page, so the placeholder disc is white.
              asStudent && !otherDeleted
                  ? InstructorAvatar(
                      photoPath:
                          c?.instructorPhotoPath ?? widget.partner?.photoPath,
                      size: 40,
                      background: AppColors.paper,
                    )
                  : ChatLetterAvatar(
                      name: otherDeleted ? '' : name,
                      size: 40,
                      background: AppColors.paper),
              const SizedBox(width: AppSpacing.x3),
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.title.copyWith(
                    fontSize: 18,
                    height: 24 / 18,
                    color:
                        otherDeleted ? AppColors.inkSecondary : AppColors.ink,
                    fontVariations: const [FontVariation('wght', 600)],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // «Забронировать урок» as a full-width pill under the header
            // (owner, 2026-10-05: an icon alone was unclear, and a pill in
            // the app bar cut the school's name).
            if (asStudent && !otherDeleted && instructorUid != null && c?.instructorKind == 'school')
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.x4 + AppSpacing.x1, 0, AppSpacing.x4 + AppSpacing.x1, AppSpacing.x2),
                child: BentoActionButton(
                  text: l.translate('chat_book_lesson'),
                  // Black, not blue (owner, 2026-10-05): blue is the bubbles'.
                  ink: true,
                  onTap: () => _book(instructorUid),
                ),
              ),
            if (_contacts != null) _ContactsCard(contacts: _contacts!),
            Expanded(child: _messageList(l, uid)),
            _composer(l, c, asStudent: asStudent, paid: paid),
          ],
        ),
      ),
    );
  }

  Widget _messageList(AppLocalizations l, String uid) {
    if (_exists == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_messages == null) {
      // A thread not started yet: what happens to contacts, said up front.
      return ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.x4 + AppSpacing.x1,
            AppSpacing.x2, AppSpacing.x4 + AppSpacing.x1, 0),
        children: [
          _Notice(text: l.translate('chat_new_hint')),
        ],
      );
    }
    return StreamBuilder<List<ChatMessage>>(
      stream: _messages,
      builder: (context, snap) {
        final list = snap.data ?? const <ChatMessage>[];
        if (!snap.hasData && !snap.hasError) {
          return const Center(child: CircularProgressIndicator());
        }
        if (_loadMore && list.length >= _limit) {
          _loadMore = false;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() {
              _limit += 50;
              _messages =
                  _service.messages(widget.conversationId, limit: _limit);
            });
          });
        }
        final locale = Localizations.localeOf(context).toString();
        return ListView.builder(
          controller: _scroll,
          reverse: true,
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.x4, AppSpacing.x2, AppSpacing.x4, AppSpacing.x2),
          itemCount: list.length,
          itemBuilder: (context, i) {
            final m = list[list.length - 1 - i];
            final mine = m.senderUid == uid;
            // Bubbles from the same side sit close; a change of side opens up.
            final next = i > 0 ? list[list.length - i] : null;
            final gap = next == null
                ? 0.0
                : next.senderUid == m.senderUid
                    ? AppSpacing.x1
                    : AppSpacing.x3;
            return Padding(
              padding: EdgeInsets.only(bottom: gap),
              child: _Bubble(
                message: m,
                mine: mine,
                time: m.createdAt == null
                    ? ''
                    : DateFormat.Hm(locale).format(m.createdAt!),
                maskedNote: l.translate('chat_masked_note'),
                onLongPress: mine ? null : () => _report(m),
              ),
            );
          },
        );
      },
    );
  }

  Widget _composer(AppLocalizations l, ChatConversation? c,
      {required bool asStudent, required bool paid}) {
    final String? reason = c?.closed == true
        ? l.translate('chat_closed')
        : asStudent && !paid
            ? l.translate('chat_paid_required')
            : null;
    return Container(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.x4, AppSpacing.x2, AppSpacing.x4, AppSpacing.x3),
      color: AppColors.field,
      child: reason != null
          ? _Notice(text: reason)
          : Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.paper,
                      borderRadius: BorderRadius.circular(BentoTokens.card),
                      boxShadow: AppColors.shadowCard,
                    ),
                    child: TextField(
                      controller: _input,
                      minLines: 1,
                      maxLines: 5,
                      maxLength: 2000,
                      textCapitalization: TextCapitalization.sentences,
                      onChanged: (_) => setState(() {}),
                      style: AppTypography.body.copyWith(color: AppColors.ink),
                      decoration: InputDecoration(
                        hintText: l.translate('chat_input_hint'),
                        hintStyle: AppTypography.body
                            .copyWith(color: AppColors.inkTertiary),
                        border: InputBorder.none,
                        counterText: '',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.x4, vertical: 14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.x2),
                _SendButton(
                  busy: _sending,
                  onTap: _input.text.trim().isEmpty || _sending ? null : _send,
                  label: l.translate('chat_send'),
                ),
              ],
            ),
    );
  }
}

/// A message bubble: mine on the right in `signal`, theirs on the left on
/// white. A masked message says why, quietly, under the bubble.
class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.message,
    required this.mine,
    required this.time,
    required this.maskedNote,
    this.onLongPress,
  });

  final ChatMessage message;
  final bool mine;
  final String time;
  final String maskedNote;

  /// Report: only the other side's messages.
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final fg = mine ? AppColors.onSignal : AppColors.ink;
    const r = Radius.circular(20);
    const tail = Radius.circular(6);
    return Column(
      crossAxisAlignment:
          mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onLongPress: onLongPress,
          child: ConstrainedBox(
            constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.78),
            child: Container(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.x3 + 2, AppSpacing.x2, AppSpacing.x3 + 2, 6),
              decoration: BoxDecoration(
                color: mine ? AppColors.signal : AppColors.paper,
                borderRadius: BorderRadius.only(
                  topLeft: r,
                  topRight: r,
                  bottomLeft: mine ? r : tail,
                  bottomRight: mine ? tail : r,
                ),
                boxShadow: mine ? null : AppColors.shadowCard,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    widthFactor: 1,
                    child: Text(message.text,
                        style: AppTypography.body.copyWith(color: fg)),
                  ),
                  Text(
                    time,
                    style: AppTypography.caption.copyWith(
                      fontSize: 11,
                      color: mine
                          ? AppColors.onSignal.withValues(alpha: 0.7)
                          : AppColors.inkTertiary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (message.masked)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(SolarIcons.lockKeyholeMinimalisticLinear,
                    size: 13, color: AppColors.inkTertiary),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    maskedNote,
                    style: AppTypography.caption
                        .copyWith(fontSize: 12, color: AppColors.inkTertiary),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// The round black send disc, 48pt: the `ink` action, like Сохранить —
/// blue stays for the bubbles (owner, 2026-10-05).
class _SendButton extends StatelessWidget {
  const _SendButton(
      {required this.busy, required this.onTap, required this.label});

  final bool busy;
  final VoidCallback? onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Semantics(
      button: true,
      label: label,
      child: PressScale(
        enabled: enabled,
        scale: 0.94,
        duration: BentoTokens.state,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: AppMotion.duration(context, BentoTokens.state),
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: enabled || busy ? AppColors.ink : AppColors.border,
              shape: BoxShape.circle,
              boxShadow: enabled ? AppColors.shadowRaised : null,
            ),
            child: Center(
              child: busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.onSignal),
                    )
                  : Icon(SolarIcons.plainBold,
                      size: 22,
                      color:
                          enabled ? AppColors.onSignal : AppColors.inkTertiary),
            ),
          ),
        ),
      ),
    );
  }
}

/// A quiet grey line on the field page: why the composer is closed, or what
/// happens to contacts in a new thread.
class _Notice extends StatelessWidget {
  const _Notice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x4, vertical: AppSpacing.x3),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(BentoTokens.card),
        boxShadow: AppColors.shadowCard,
      ),
      child: Row(
        children: [
          const Icon(SolarIcons.infoCircleLinear,
              size: 20, color: AppColors.inkSecondary),
          const SizedBox(width: AppSpacing.x2),
          Expanded(
              child: Text(text,
                  style: AppTypography.label
                      .copyWith(color: AppColors.inkSecondary))),
        ],
      ),
    );
  }
}

/// The instructor's phone and email, once a booking unlocked the thread
/// (plan v2 §10). Selectable, so they can be copied.
class _ContactsCard extends StatelessWidget {
  const _ContactsCard({required this.contacts});

  final Future<({String phone, String email})> contacts;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return FutureBuilder<({String phone, String email})>(
      future: contacts,
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        Widget row(IconData icon, String value) => Padding(
              padding: const EdgeInsets.only(top: AppSpacing.x1),
              child: Row(
                children: [
                  Icon(icon, size: 18, color: AppColors.signal),
                  const SizedBox(width: AppSpacing.x2),
                  Expanded(
                      child: SelectableText(value,
                          style: AppTypography.body
                              .copyWith(color: AppColors.ink))),
                  // One tap copies it (owner, 2026-10-05).
                  IconButton(
                    tooltip: l.translate('chat_copy'),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.field,
                      minimumSize: const Size(36, 36),
                      fixedSize: const Size(36, 36),
                      padding: EdgeInsets.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: AppIcons.icon(AppIcons.copy, size: 18, color: AppColors.signal),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: value));
                      HapticFeedback.selectionClick();
                      ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(SnackBar(
                          content: Text(l.translate('chat_copied')),
                          backgroundColor: AppColors.guide,
                          duration: const Duration(seconds: 2),
                        ));
                    },
                  ),
                ],
              ),
            );
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(AppSpacing.x4 + AppSpacing.x1, 0,
              AppSpacing.x4 + AppSpacing.x1, AppSpacing.x2),
          padding: const EdgeInsets.all(AppSpacing.x4),
          decoration: BoxDecoration(
            color: AppColors.paper,
            borderRadius: BorderRadius.circular(BentoTokens.card),
            boxShadow: AppColors.shadowCard,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.translate('chat_contacts_title'),
                style: AppTypography.label.copyWith(
                    color: AppColors.ink,
                    fontVariations: const [FontVariation('wght', 700)]),
              ),
              if (snap.data!.phone.isNotEmpty)
                row(SolarIcons.phoneLinear, snap.data!.phone),
              if (snap.data!.email.isNotEmpty)
                row(SolarIcons.letterLinear, snap.data!.email),
            ],
          ),
        );
      },
    );
  }
}

/// A student has no photo: the initial on a `signal50` disc; an empty name
/// (a deleted account) gets the placeholder figure. Shared with the list.
class ChatLetterAvatar extends StatelessWidget {
  const ChatLetterAvatar(
      {super.key,
      required this.name,
      required this.size,
      this.background = AppColors.field});

  final String name;
  final double size;

  /// The placeholder disc for an empty name, as [InstructorAvatar.background].
  final Color background;

  @override
  Widget build(BuildContext context) {
    final letter =
        name.trim().isEmpty ? null : name.trim().characters.first.toUpperCase();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
          color: letter == null ? background : AppColors.signal50,
          shape: BoxShape.circle),
      child: letter == null
          ? Icon(SolarIcons.userRoundedBold,
              size: size * 0.45, color: AppColors.inkTertiary)
          : Text(
              letter,
              style: AppTypography.title.copyWith(
                fontSize: size * 0.42,
                height: 1,
                color: AppColors.signal,
                fontVariations: const [FontVariation('wght', 600)],
              ),
            ),
    );
  }
}
