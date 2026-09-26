import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/theory_module.dart';
import '../providers/language_provider.dart';
import '../theme/app_theme.dart';
import '../theme/bento_tokens.dart';
import '../theme/solar_icons.dart';

/// A Теория module as a Bento card: its 3D picture, then the title with the
/// count as a pill in the top-right corner, the description under them, and
/// a plain green tick in the bottom-right corner once the module is done. The whole card is the button — no
/// chevron. Presses lift the card rather than shrinking it, as on Тесты.
///
/// The old per-title pastel washes (blue, green, orange, purple…) spent the
/// semantic colours on decoration and are gone.
class ModuleCard extends StatefulWidget {
  final TheoryModule module;
  final bool isCompleted;
  final VoidCallback onSelect;

  const ModuleCard({
    Key? key,
    required this.module,
    required this.isCompleted,
    required this.onSelect,
  }) : super(key: key);

  @override
  _ModuleCardState createState() => _ModuleCardState();
}

class _ModuleCardState extends State<ModuleCard> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  static const double _pictureSize = 64;

  /// The same 3D pictures as the topic list (owner, 2026-09-26): Теория's ten
  /// modules are the same ten topics, and a module id ends in its number
  /// (`traffic_rules_ru_IL_01`), as the quiz topic ids do — see
  /// `_getTopicIconAsset` in `lib/services/api/firebase_content_api.dart`.
  static const List<String> _pictures = [
    '1_general_provision',
    '2_traffic_laws',
    '3_passenger_safety',
    '4_pedestrian_rights',
    '5_bicycles_and_motorcycles',
    '6_special_transportation_vehicles',
    '7_driving_difficult_conditions',
    '8_impaired_driving',
    '9_road_signs_markings',
    '10_insurance_responsibility',
  ];

  Widget _buildPicture() {
    Widget fallback() => Container(
          width: _pictureSize,
          height: _pictureSize,
          decoration: const BoxDecoration(
            color: AppColors.signal50,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: const Icon(
            SolarIcons.book2Linear,
            size: 28,
            color: AppColors.signal,
          ),
        );

    final number = int.tryParse(widget.module.id.split('_').last);
    if (number == null || number < 1 || number > _pictures.length) {
      return fallback();
    }
    return Image.asset(
      'assets/images/topic_icons/${_pictures[number - 1]}.png',
      width: _pictureSize,
      height: _pictureSize,
      fit: BoxFit.contain,
      excludeFromSemantics: true,
      errorBuilder: (context, error, stackTrace) => fallback(),
    );
  }

  /// A short lowercase count for the pill («6 модулей»), with the plural
  /// each language needs. Falls back to the old «Количество модулей: N»
  /// wording if the stored count is not a number.
  String _countLabel(String language, String modulePhrase) {
    final raw = widget.module.theoryModulesCount;
    final n = int.tryParse(raw);
    if (n == null) return '$modulePhrase: $raw';

    final mod10 = n % 10;
    final mod100 = n % 100;
    final isOne = mod10 == 1 && mod100 != 11;
    final isFew = mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14);
    switch (language) {
      case 'ru':
        return '$n ${isOne ? 'модуль' : isFew ? 'модуля' : 'модулей'}';
      case 'uk':
        return '$n ${isOne ? 'модуль' : isFew ? 'модулі' : 'модулів'}';
      case 'pl':
        return '$n ${n == 1 ? 'moduł' : isFew ? 'moduły' : 'modułów'}';
      case 'es':
        return '$n ${n == 1 ? 'módulo' : 'módulos'}';
      default:
        return '$n ${n == 1 ? 'module' : 'modules'}';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get the current language from the LanguageProvider
    final language = Provider.of<LanguageProvider>(context, listen: false).language;

    // Translation map for module count phrases in different languages
    final Map<String, String> moduleCountPhrases = {
      'en': 'Module count',
      'uk': 'Кількість модулів',
      'es': 'Cantidad de módulos',
      'ru': 'Количество модулей',
      'pl': 'Liczba modułów',
    };

    // Get the correct phrase based on the current language
    final modulePhrase = moduleCountPhrases[language] ?? 'Module count';

    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: widget.onSelect,
        child: AnimatedSlide(
          offset: Offset(0, _pressed ? -0.025 : 0),
          duration: AppMotion.duration(context, BentoTokens.state),
          curve: AppMotion.enter,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.x4),
            decoration: BoxDecoration(
              color: AppColors.paper,
              borderRadius: BorderRadius.circular(BentoTokens.card),
              boxShadow: AppColors.shadowCard,
            ),
            child: Row(
              children: [
                _buildPicture(),
                const SizedBox(width: AppSpacing.x4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildTitleWithCount(_countLabel(language, modulePhrase)),
                      const SizedBox(height: AppSpacing.x1),
                      _buildDescription(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static final TextStyle _titleStyle = AppTypography.body.copyWith(
    fontSize: 17,
    height: 22 / 17,
    letterSpacing: -0.2,
    color: AppColors.ink,
    fontVariations: const [FontVariation('wght', 600)],
  );

  static final TextStyle _countStyle = AppTypography.caption.copyWith(
    color: AppColors.signal,
    fontVariations: const [FontVariation('wght', 500)],
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  static const EdgeInsets _pillPadding = EdgeInsets.symmetric(
    horizontal: AppSpacing.x2 + 2,
    vertical: AppSpacing.x1,
  );

  /// The title with the count pill in the top-right corner (owner,
  /// 2026-09-26). Only the title's first line shares its width with the pill;
  /// the rest of a long title runs full width under the pill, so the current
  /// titles all fit in two lines without shrinking the type.
  Widget _buildTitleWithCount(String count) {
    final pill = _buildCountPill(count);
    return LayoutBuilder(
      builder: (context, constraints) {
        final textScaler = MediaQuery.textScalerOf(context);
        final direction = Directionality.of(context);
        final title = widget.module.title;
        final pillWidth = (TextPainter(
              text: TextSpan(text: count, style: _countStyle),
              textDirection: direction,
              textScaler: textScaler,
              maxLines: 1,
            )..layout())
                .width +
            _pillPadding.horizontal;
        final firstLineWidth =
            (constraints.maxWidth - AppSpacing.x2 - pillWidth).clamp(0.0, constraints.maxWidth);
        final painter = TextPainter(
          text: TextSpan(text: title, style: _titleStyle),
          textDirection: direction,
          textScaler: textScaler,
        )..layout(maxWidth: firstLineWidth);
        final firstLineEnd = painter.computeLineMetrics().length < 2
            ? title.length
            : painter.getLineBoundary(const TextPosition(offset: 0)).end;

        final firstRow = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                title.substring(0, firstLineEnd).trimRight(),
                style: _titleStyle,
              ),
            ),
            const SizedBox(width: AppSpacing.x2),
            // Held to the title's 22pt line (the pill is 24pt) so the two
            // title lines stay evenly spaced; the pill is centred on the line.
            SizedBox(
              width: pillWidth,
              height: 22,
              child: OverflowBox(
                maxWidth: pillWidth,
                maxHeight: double.infinity,
                child: pill,
              ),
            ),
          ],
        );
        if (firstLineEnd == title.length) return firstRow;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            firstRow,
            Text(title.substring(firstLineEnd).trimLeft(), style: _titleStyle),
          ],
        );
      },
    );
  }

  /// The description and — once the module is done — a plain green tick in
  /// the bottom-right corner, like a "read" mark in a messenger (owner,
  /// 2026-09-26): green because done = correct, but no filled disc. The tick
  /// sits on the last line when there is room there, so a finished card keeps
  /// its height; otherwise the text keeps a column clear for it.
  Widget _buildDescription() {
    final style = AppTypography.body.copyWith(
      fontSize: 14,
      height: 20 / 14,
      color: AppColors.inkSecondary,
    );
    final description = Text(widget.module.description, style: style);
    if (!widget.isCompleted) return description;

    const tickSize = 20.0;
    const tick = Icon(SolarIcons.checkLinear, size: tickSize, color: AppColors.guide);
    return LayoutBuilder(
      builder: (context, constraints) {
        final lines = (TextPainter(
          text: TextSpan(text: widget.module.description, style: style),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: constraints.maxWidth))
            .computeLineMetrics();
        final lastLineWidth = lines.isEmpty ? 0.0 : lines.last.width;
        if (lastLineWidth + AppSpacing.x2 + tickSize <= constraints.maxWidth) {
          return Stack(
            children: [
              SizedBox(width: double.infinity, child: description),
              const Positioned(right: 0, bottom: 0, child: tick),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: description),
            const SizedBox(width: AppSpacing.x2),
            tick,
          ],
        );
      },
    );
  }

  /// One line always: a long translation shrinks slightly to fit rather than
  /// wrapping the pill.
  Widget _buildCountPill(String text) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Container(
        padding: _pillPadding,
        decoration: BoxDecoration(
          color: AppColors.signal50,
          borderRadius: BorderRadius.circular(BentoTokens.chip),
        ),
        child: Text(
          text,
          maxLines: 1,
          style: _countStyle,
        ),
      ),
    );
  }
}
