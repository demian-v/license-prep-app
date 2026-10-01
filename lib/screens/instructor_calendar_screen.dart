import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import '../theme/app_theme.dart';
import '../theme/solar_icons.dart';
import '../widgets/bento_empty_card.dart';

/// «Календарь» — the instructor's first tab (instructors plan v2 §14.2).
/// An empty shell for now: Phase 3 adds the weekly availability grid, Phase 7
/// the upcoming and past lessons. A tab page, so no title (owner rule 1).
class InstructorCalendarScreen extends StatelessWidget {
  const InstructorCalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.field,
      // Centred on the page (owner, 2026-09-30) until Phase 3 fills the tab.
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4 + AppSpacing.x1),
            child: BentoEmptyCard(
              icon: SolarIcons.clockCircleLinear,
              title: l.translate('instructor_calendar_empty_title'),
              description: l.translate('instructor_calendar_empty_desc'),
            ),
          ),
        ),
      ),
    );
  }
}
