import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../localization/app_localizations.dart';
import '../providers/state_provider.dart';
import '../providers/subscription_provider.dart';
import '../services/instructor_service.dart';
import '../theme/app_theme.dart';
import '../theme/bento_tokens.dart';
import '../theme/solar_icons.dart';
import '../utils/state_display.dart';
import '../widgets/bento_empty_card.dart';
import '../widgets/bento_hero_bars.dart';
import '../widgets/bento_question_parts.dart';
import '../widgets/state_requirements_card.dart';
import '../widgets/trial_status_widget.dart';
import 'chat_list_screen.dart';

/// «Инструкторы» — the marketplace tab for students (instructors plan v2 §3,
/// §13). Three states, decided in this order:
///
///  1. the student's state has not launched → «Скоро в <штат>»;
///  2. launched, but no PAID plan (trial users included — owner decision
///     2026-09-30) → the locked preview: the real listing count, generic
///     blurred cards that carry no instructor data; the trial card on
///     top carries the subscribe action;
///  3. paid → the tab itself: Поиск · Избранное · Сообщения. Поиск and
///     Избранное are filled in Phase 4, Сообщения in Phase 6.
///
/// The server enforces the paywall too (listInstructors →
/// requirePaidSubscriber); this screen only decides what to draw.
/// A tab page, so no title (owner rule 1).
class InstructorsScreen extends StatefulWidget {
  const InstructorsScreen({super.key, this.service});

  final InstructorService? service;

  @override
  State<InstructorsScreen> createState() => _InstructorsScreenState();
}

enum _Segment { search, favorites, messages }

class _InstructorsScreenState extends State<InstructorsScreen> {
  late final InstructorService _service = widget.service ?? InstructorService();
  Future<InstructorTabInfo>? _info;
  String? _infoState;
  _Segment _segment = _Segment.search;

  void _load(String state) {
    _infoState = state;
    _info = _service.tabInfo(state);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final stateId = Provider.of<StateProvider>(context).selectedStateId;
    final paid = Provider.of<SubscriptionProvider>(context)
            .subscription
            ?.isPaidSubscription ??
        false;

    if (stateId != null && stateId != _infoState) _load(stateId);

    return Scaffold(
      backgroundColor: AppColors.field,
      body: SafeArea(
        child: stateId == null
            ? const SizedBox.shrink()
            : FutureBuilder<InstructorTabInfo>(
                future: _info,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final stateName = stateDisplayName(stateId);
                  final List<Widget> blocks;
                  if (snapshot.hasError) {
                    blocks = [
                      BentoEmptyCard(
                        icon: SolarIcons.cloudCrossLinear,
                        title: l.translate('instructors_load_error_title'),
                        description: l.translate('instructors_load_error_desc'),
                      ),
                      const SizedBox(height: AppSpacing.x3),
                      BentoActionButton(
                        text: l.translate('try_again'),
                        ink: true,
                        onTap: () => setState(() => _load(stateId)),
                      ),
                    ];
                  } else if (!snapshot.data!.launched) {
                    blocks = [
                      BentoEmptyCard(
                        icon: SolarIcons.mapPointBold,
                        title: l
                            .translate('instructors_coming_title')
                            .replaceAll('{state}', stateName),
                        description: l.translate('instructors_coming_desc'),
                      ),
                      const SizedBox(height: AppSpacing.x3),
                      StateRequirementsCard(stateId: stateId),
                    ];
                  } else if (!paid) {
                    blocks = _lockedPreview(
                        l, stateName, snapshot.data!.listedCount);
                  } else {
                    blocks = _tab(l, stateName, snapshot.data!.listedCount);
                  }
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.x4 + AppSpacing.x1,
                      AppSpacing.x2,
                      AppSpacing.x4 + AppSpacing.x1,
                      AppSpacing.x6,
                    ),
                    children: [
                      // The trial card at the top, inset like the cards, as
                      // on Тесты and Теория (owner, 2026-09-30). It renders
                      // nothing for a paid subscriber.
                      const TrialStatusWidget(),
                      const SizedBox(height: AppSpacing.x4),
                      for (var i = 0; i < blocks.length; i++)
                        StaggerIn(
                            index: i,
                            count: blocks.length,
                            curve: BentoTokens.curve,
                            child: blocks[i]),
                    ],
                  );
                },
              ),
      ),
    );
  }

  List<Widget> _lockedPreview(AppLocalizations l, String stateName, int count) {
    return [
      _Hero(
        title: l.translate('instructors_hero_title'),
        description: l
            .translate('instructors_locked_desc')
            .replaceAll('{state}', stateName),
        count: count,
      ),
      const SizedBox(height: AppSpacing.x3),
      // Why a licensed school may be needed at all — real value even locked.
      StateRequirementsCard(stateId: _infoState!),
      const SizedBox(height: AppSpacing.x3),
      // Generic shapes only — no instructor data reaches a locked client.
      // No subscribe button here: the trial card above already carries it
      // for every unpaid case (active trial, expired, lapsed, none).
      ExcludeSemantics(
        child: ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Column(
            children: [
              for (var i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(height: AppSpacing.x3),
                const _PlaceholderCard(),
              ],
            ],
          ),
        ),
      ),
    ];
  }

  List<Widget> _tab(AppLocalizations l, String stateName, int count) {
    final Widget body = switch (_segment) {
      _Segment.search => BentoEmptyCard(
          icon: SolarIcons.magniferLinear,
          title: l.translate('instructors_search_soon_title'),
          description: l.translate('instructors_search_soon_desc'),
        ),
      _Segment.favorites => BentoEmptyCard(
          icon: SolarIcons.heartLinear,
          title: l.translate('instructors_favorites_empty_title'),
          description: l.translate('instructors_favorites_empty_desc'),
        ),
      _Segment.messages => const ChatListScreen(embedded: true),
    };
    return [
      _Hero(
        title: l.translate('instructors_hero_title'),
        description: stateName,
        count: count,
      ),
      const SizedBox(height: AppSpacing.x3),
      _SegmentPills(
        labels: [
          l.translate('instructors_tab_search'),
          l.translate('instructors_tab_favorites'),
          l.translate('instructors_tab_messages'),
        ],
        selected: _segment.index,
        onSelect: (i) => setState(() => _segment = _Segment.values[i]),
      ),
      const SizedBox(height: AppSpacing.x3),
      if (_segment == _Segment.search) ...[
        StateRequirementsCard(stateId: _infoState!),
        const SizedBox(height: AppSpacing.x3),
      ],
      body,
    ];
  }
}

/// The page's blue hero: what the tab holds, and the real number of
/// listings in the state as the solid white pill. «Профилей в штате: 9» —
/// a label before the number, like «Дней осталось: 2», so no plural forms
/// are needed in five languages (owner: a bare number was unclear).
class _Hero extends StatelessWidget {
  const _Hero(
      {required this.title, required this.description, required this.count});

  final String title;
  final String description;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(BentoTokens.card),
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [AppColors.signal600, AppColors.signal, AppColors.signal400],
          stops: [0, 0.55, 1],
        ),
        boxShadow: const [
          BoxShadow(
              color: Color(0x290048C3), blurRadius: 24, offset: Offset(0, 10)),
        ],
      ),
      child: Stack(
        children: [
          // The faint bar strip every hero carries (Профиль, Подписка,
          // Поддержка), rising from the bottom edge behind the text.
          const Positioned(
            right: AppSpacing.x4 + AppSpacing.x1,
            bottom: 0,
            child: BentoHeroBars(),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.x4 + AppSpacing.x1),
            child: _content(AppLocalizations.of(context)),
          ),
        ],
      ),
    );
  }

  Widget _content(AppLocalizations l) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTypography.title.copyWith(
            fontSize: 22,
            height: 28 / 22,
            color: AppColors.onSignal,
            fontVariations: const [FontVariation('wght', 700)],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          description,
          style: AppTypography.label.copyWith(
            color: AppColors.signal100,
            fontVariations: const [FontVariation('wght', 400)],
          ),
        ),
        const SizedBox(height: AppSpacing.x4),
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.x3, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.paper,
            borderRadius: BorderRadius.circular(BentoTokens.chip),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(SolarIcons.userRoundedBold,
                  size: 16, color: AppColors.signal),
              const SizedBox(width: AppSpacing.x1),
              Text(
                '${l.translate('instr_count_label')}: $count',
                style: AppTypography.caption.copyWith(
                  color: AppColors.signal,
                  fontVariations: const [FontVariation('wght', 600)],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A listing card's silhouette for the locked preview.
class _PlaceholderCard extends StatelessWidget {
  const _PlaceholderCard();

  @override
  Widget build(BuildContext context) {
    Widget bar(double width, double height) => Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: AppColors.border,
            borderRadius: BorderRadius.circular(BentoTokens.chip),
          ),
        );
    return Container(
      padding: const EdgeInsets.all(AppSpacing.x4),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(BentoTokens.card),
        boxShadow: AppColors.shadowCard,
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
                color: AppColors.field, shape: BoxShape.circle),
          ),
          const SizedBox(width: AppSpacing.x4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                bar(140, 14),
                const SizedBox(height: AppSpacing.x2),
                bar(90, 10),
                const SizedBox(height: AppSpacing.x3),
                Row(children: [
                  bar(56, 20),
                  const SizedBox(width: AppSpacing.x2),
                  bar(48, 20)
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Поиск · Избранное · Сообщения as pills in a white tray; the selected one
/// is the dark `ink` pill (owner rule 10). Labels shrink rather than wrap
/// (rule 5).
class _SegmentPills extends StatelessWidget {
  const _SegmentPills(
      {required this.labels, required this.selected, required this.onSelect});

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.x1),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(BentoTokens.bar),
        boxShadow: AppColors.shadowCard,
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: Semantics(
                button: true,
                selected: i == selected,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onSelect(i),
                  child: AnimatedContainer(
                    duration: AppMotion.duration(context, BentoTokens.state),
                    curve: BentoTokens.curve,
                    height: 40,
                    alignment: Alignment.center,
                    padding:
                        const EdgeInsets.symmetric(horizontal: AppSpacing.x2),
                    decoration: BoxDecoration(
                      color: i == selected ? AppColors.ink : Colors.transparent,
                      borderRadius: BorderRadius.circular(BentoTokens.chip),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        labels[i],
                        maxLines: 1,
                        style: AppTypography.label.copyWith(
                          color: i == selected
                              ? AppColors.onSignal
                              : AppColors.inkSecondary,
                          fontVariations: const [FontVariation('wght', 600)],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
