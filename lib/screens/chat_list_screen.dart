import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import '../theme/app_theme.dart';
import '../theme/solar_icons.dart';
import '../widgets/bento_empty_card.dart';

/// The conversations list (instructors plan v2 §10). For an instructor it is
/// the «Чат» tab; for a student it is the «Сообщения» segment of Инструкторы
/// ([embedded] drops the page scaffold). Phase 6 fills it; until then the
/// empty state.
class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final card = BentoEmptyCard(
      icon: SolarIcons.chatRoundLineLinear,
      title: l.translate('chat_empty_title'),
      description: l.translate('chat_empty_desc'),
    );
    if (embedded) return card;
    return Scaffold(
      backgroundColor: AppColors.field,
      // Centred on the page, like Календарь (owner, 2026-09-30).
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4 + AppSpacing.x1),
            child: card,
          ),
        ),
      ),
    );
  }
}
