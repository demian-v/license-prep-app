import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import '../models/instructor_listing.dart';
import '../theme/app_theme.dart';
import '../theme/bento_tokens.dart';
import 'bento_question_parts.dart' show BentoActionButton;
import 'instructor_card.dart' show teachingLanguageName;
import 'instructor_form_fields.dart';

/// Поиск's filters (plan v2 §13) as a bottom sheet of pills. Cities and
/// languages are the ones the state's listing actually has, so no choice
/// leads to an empty list on its own. Returns the new filters, or null when
/// the sheet is dismissed.
Future<InstructorFilters?> showInstructorFilters(
  BuildContext context, {
  required InstructorFilters current,
  required List<InstructorListing> all,
}) {
  return showModalBottomSheet<InstructorFilters>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _FiltersSheet(current: current, all: all),
  );
}

/// The hourly price caps offered, in dollars.
const List<int> _priceCaps = [50, 70, 90];

class _FiltersSheet extends StatefulWidget {
  const _FiltersSheet({required this.current, required this.all});

  final InstructorFilters current;
  final List<InstructorListing> all;

  @override
  State<_FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends State<_FiltersSheet> {
  late String? _kind = widget.current.kind;
  late String? _city = widget.current.city;
  late final Set<String> _languages = {...widget.current.languages};
  late int? _maxPrice = widget.current.maxPriceUsd;
  late bool _bookable = widget.current.bookableOnly;
  late bool _rating4 = widget.current.rating4;
  late bool _dual = widget.current.dualControls;

  InstructorFilters get _filters => InstructorFilters(
        kind: _kind,
        city: _city,
        languages: {..._languages},
        maxPriceUsd: _maxPrice,
        bookableOnly: _bookable,
        rating4: _rating4,
        dualControls: _dual,
      );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cities = {for (final i in widget.all) i.city}.toList()..sort();
    final languages = {for (final i in widget.all) ...i.languages}.toList()
      ..sort((a, b) => teachingLanguageName(a).compareTo(teachingLanguageName(b)));
    final count = widget.all.where(_filters.matches).length;

    Widget pill(String label, bool selected, VoidCallback onTap) =>
        InstructorChoicePill(label: label, selected: selected, onTap: () => setState(onTap));
    Widget section(String title, List<Widget> pills) => Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.x4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTypography.label.copyWith(
                  color: AppColors.inkSecondary,
                  fontVariations: const [FontVariation('wght', 600)],
                ),
              ),
              const SizedBox(height: AppSpacing.x2),
              Wrap(spacing: AppSpacing.x2, runSpacing: AppSpacing.x2, children: pills),
            ],
          ),
        );

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      decoration: const BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.vertical(top: Radius.circular(BentoTokens.card)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppSpacing.x3),
            Center(
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.borderStrong,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.x4 + AppSpacing.x1, AppSpacing.x4, AppSpacing.x4 + AppSpacing.x1, AppSpacing.x4),
              child: Text(
                l.translate('instructor_filters'),
                style: AppTypography.title.copyWith(
                  fontSize: 22,
                  height: 28 / 22,
                  color: AppColors.ink,
                  fontVariations: const [FontVariation('wght', 600)],
                ),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4 + AppSpacing.x1),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    section(l.translate('instructor_filter_who'), [
                      pill(l.translate('instructor_filter_all'), _kind == null, () => _kind = null),
                      pill(l.translate('instructor_filter_schools'), _kind == 'school', () => _kind = 'school'),
                      pill(l.translate('instructor_filter_private'), _kind == 'schoolInstructor',
                          () => _kind = 'schoolInstructor'),
                    ]),
                    section(l.translate('instructor_filter_city'), [
                      pill(l.translate('instructor_filter_any'), _city == null, () => _city = null),
                      for (final c in cities) pill(c, _city == c, () => _city = c),
                    ]),
                    section(l.translate('instructor_filter_language'), [
                      for (final code in languages)
                        pill(teachingLanguageName(code), _languages.contains(code),
                            () => _languages.contains(code) ? _languages.remove(code) : _languages.add(code)),
                    ]),
                    section(l.translate('instructor_filter_price'), [
                      pill(l.translate('instructor_filter_any_price'), _maxPrice == null, () => _maxPrice = null),
                      for (final cap in _priceCaps)
                        pill(l.translate('instructor_filter_price_up_to').replaceAll('{price}', '\$$cap'),
                            _maxPrice == cap, () => _maxPrice = cap),
                    ]),
                    section(l.translate('instructor_filter_more'), [
                      pill(l.translate('instructor_filter_bookable'), _bookable, () => _bookable = !_bookable),
                      pill(l.translate('instructor_filter_rating4'), _rating4, () => _rating4 = !_rating4),
                      pill(l.translate('ireg_dual_controls'), _dual, () => _dual = !_dual),
                    ]),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.x4 + AppSpacing.x1, AppSpacing.x2, AppSpacing.x4 + AppSpacing.x1, AppSpacing.x4),
              child: Row(
                children: [
                  Expanded(
                    child: BentoActionButton(
                      text: l.translate('instructor_filter_reset'),
                      primary: false,
                      onCard: true,
                      onTap: () => Navigator.pop(context, const InstructorFilters()),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.x3),
                  Expanded(
                    child: BentoActionButton(
                      text: l.translate('instructor_filter_show').replaceAll('{n}', '$count'),
                      ink: true,
                      onTap: () => Navigator.pop(context, _filters),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
