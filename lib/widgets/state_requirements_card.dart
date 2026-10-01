import 'package:flutter/material.dart';

import '../data/state_learner_rules.dart';
import '../localization/app_localizations.dart';
import '../theme/app_theme.dart';
import '../theme/bento_tokens.dart';
import '../theme/solar_icons.dart';

/// «Что требует ваш штат» — what the student's state requires before the road
/// test (instructors plan v2 §14.4), from [stateLearnerRules]. Real value on
/// the Инструкторы tab, including the locked preview: it says why a licensed
/// school may be needed at all. Renders nothing for a state without data.
class StateRequirementsCard extends StatelessWidget {
  const StateRequirementsCard({super.key, required this.stateId});

  final String stateId;

  @override
  Widget build(BuildContext context) {
    final rules = stateLearnerRules[stateId];
    if (rules == null) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);

    String fill(String text, Map<String, int> values) =>
        values.entries.fold(text, (t, e) => t.replaceAll('{${e.key}}', '${e.value}'));

    final teen = switch (rules.teen) {
      TeenBtw(parentHours: final int parent, :final classHours, :final btwHours) =>
        fill(l.translate('sreq_teen_btw_or_parent'), {'class': classHours, 'btw': btwHours, 'parent': parent}),
      TeenBtw(:final classHours, :final btwHours) =>
        fill(l.translate('sreq_teen_btw'), {'class': classHours, 'btw': btwHours}),
      TeenBtwOrParentCourse(:final btwHours) => fill(l.translate('sreq_teen_btw_or_parent_course'), {'btw': btwHours}),
      TeenCourseOnly(:final classHours) => fill(l.translate('sreq_teen_course_only'), {'class': classHours}),
      TeenAge16Btw(:final btwHours) => fill(l.translate('sreq_teen_age16_btw'), {'btw': btwHours}),
      TeenSchoolCourse() => l.translate('sreq_teen_school_course'),
      TeenNone() => l.translate('sreq_teen_none'),
    };
    final adult = switch (rules.adult) {
      AdultAllAgesBtw(:final classHours, :final btwHours) =>
        fill(l.translate('sreq_adult_all_btw'), {'class': classHours, 'btw': btwHours}),
      AdultCourse(:final fromAge, :final toAge, :final classHours) =>
        fill(l.translate('sreq_adult_course'), {'from': fromAge, 'to': toAge, 'class': classHours}),
      AdultCourseAll(:final classHours) => fill(l.translate('sreq_adult_course_all'), {'class': classHours}),
      AdultFullCourseUnder(:final toAge, :final btwHours) =>
        fill(l.translate('sreq_adult_full_under'), {'to': toAge, 'btw': btwHours}),
      AdultNone() => l.translate('sreq_adult_none'),
    };

    Widget line(IconData icon, Color iconColor, String text) => Padding(
          padding: const EdgeInsets.only(top: AppSpacing.x3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const SizedBox(width: AppSpacing.x2),
              Expanded(child: Text(text, style: AppTypography.body.copyWith(color: AppColors.ink))),
            ],
          ),
        );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.x4 + AppSpacing.x1),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(BentoTokens.card),
        boxShadow: AppColors.shadowCard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(SolarIcons.mapPointBold, size: 22, color: AppColors.signal),
              const SizedBox(width: AppSpacing.x2),
              Expanded(
                child: Text(
                  l.translate('sreq_title'),
                  style: AppTypography.heading.copyWith(
                    fontSize: 18,
                    height: 24 / 18,
                    color: AppColors.ink,
                    fontVariations: const [FontVariation('wght', 600)],
                  ),
                ),
              ),
            ],
          ),
          line(SolarIcons.squareAcademicCapBold, AppColors.signal, teen),
          line(SolarIcons.userRoundedLinear, AppColors.signal, adult),
          // Amber = time (palette); the text stays inkSecondary for contrast.
          if (rules.changes2027) line(SolarIcons.clockCircleLinear, AppColors.warn, l.translate('sreq_changes_2027')),
          const SizedBox(height: AppSpacing.x3),
          Text(l.translate('sreq_source'), style: AppTypography.caption.copyWith(color: AppColors.inkSecondary)),
        ],
      ),
    );
  }
}
