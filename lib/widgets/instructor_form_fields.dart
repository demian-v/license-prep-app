import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/bento_tokens.dart';

/// The pieces the instructor wizard and the Профиль edit sheets share
/// (instructors plan v2 §14.2: one set of form widgets).

/// A pill that is the dark `ink` row when chosen (owner rule 10).
class InstructorChoicePill extends StatelessWidget {
  const InstructorChoicePill({super.key, required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppMotion.duration(context, BentoTokens.state),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4, vertical: AppSpacing.x2 + 2),
          decoration: BoxDecoration(
            color: selected ? AppColors.ink : AppColors.field,
            borderRadius: BorderRadius.circular(BentoTokens.chip),
          ),
          child: Text(
            label,
            style: AppTypography.label.copyWith(
              color: selected ? AppColors.onSignal : AppColors.ink,
              fontVariations: const [FontVariation('wght', 600)],
            ),
          ),
        ),
      ),
    );
  }
}

/// The "$" in the price field's icon slot: the font subset has no money
/// glyph, and a "$" says "price" better than the old medal.
class InstructorDollarPrefix extends StatelessWidget {
  const InstructorDollarPrefix({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      child: Center(
        child: Text('\$',
            style: AppTypography.body.copyWith(
              fontSize: 20,
              color: AppColors.inkSecondary,
              fontVariations: const [FontVariation('wght', 600)],
            )),
      ),
    );
  }
}

/// The lesson lengths registerAsInstructor and updateInstructorProfile accept.
const instructorLessonDurations = [60, 90, 120];
