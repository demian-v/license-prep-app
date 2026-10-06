import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../localization/app_localizations.dart';
import '../models/booking.dart';
import '../models/instructor_listing.dart';
import '../services/analytics_service.dart';
import '../services/booking_service.dart';
import '../theme/app_theme.dart';
import '../theme/bento_tokens.dart';
import '../theme/solar_icons.dart';
import '../widgets/bento_empty_card.dart';
import '../widgets/bento_question_parts.dart';
import '../widgets/bento_result_parts.dart' show bentoHeadingAppBar;
import '../widgets/instructor_card.dart' show timezoneLabel;
import 'booking_detail_screen.dart';

/// «Запись на урок» — a paid student books a stage-2 driving school
/// (instructors plan v2 §9). Length → date → start time → the price
/// (lesson + «Сервисный сбор» + total) → «Забронировать» (owner rule 13: the
/// button says only the action). Times are the school's wall clock (owner,
/// 2026-10-05), with the zone named under them. The free half hours and the
/// prices come from getBookingOptions; createBooking checks everything again.
class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key, required this.instructor, this.service});

  final InstructorListing instructor;
  final BookingService? service;

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  late final BookingService _service = widget.service ?? BookingService();
  late Future<BookingOptions> _options = _service.options(widget.instructor.id);

  int? _minutes;
  String? _date;
  BookingSlot? _start;
  bool _busy = false;

  void _reload() => setState(() {
        _options = _service.options(widget.instructor.id);
        _start = null;
      });

  Future<void> _book(BookingQuote quote) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _busy = true);
    try {
      final result = await _service.create(widget.instructor.id, _start!.startAtMs, quote.durationMinutes);
      analyticsService.logBookingCreated(durationMinutes: quote.durationMinutes, feeKind: quote.feeKind);
      if (result.status == 'confirmed') analyticsService.logBookingConfirmed(durationMinutes: quote.durationMinutes);
      navigator.pushReplacement(ForwardPageRoute(child: BookingDetailScreen(bookingId: result.id, asInstructor: false, service: widget.service)));
    } on FirebaseFunctionsException catch (e) {
      final key = e.code == 'already-exists'
          ? 'booking_slot_taken'
          : e.code == 'failed-precondition' && (e.message == 'payments-unavailable' || e.message == 'not-bookable')
              ? 'booking_unavailable'
              : 'booking_error';
      messenger.showSnackBar(SnackBar(content: Text(l.translate(key)), backgroundColor: AppColors.stop));
      if (e.code == 'already-exists') _reload();
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l.translate('booking_error')), backgroundColor: AppColors.stop));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.field,
      appBar: bentoHeadingAppBar(title: l.translate('booking_title'), onBack: () => Navigator.of(context).pop()),
      body: SafeArea(
        top: false,
        child: FutureBuilder<BookingOptions>(
          future: _options,
          builder: (context, snap) {
            if (snap.hasError) {
              return ListView(padding: _padding, children: [
                BentoEmptyCard(
                  icon: SolarIcons.cloudCrossLinear,
                  title: l.translate('instructors_load_error_title'),
                  description: l.translate('instructors_load_error_desc'),
                ),
                const SizedBox(height: AppSpacing.x3),
                BentoActionButton(text: l.translate('try_again'), ink: true, onTap: _reload),
              ]);
            }
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            return _form(l, snap.data!);
          },
        ),
      ),
    );
  }

  Widget _form(AppLocalizations l, BookingOptions o) {
    final i = widget.instructor;
    final quotes = o.quotes.where((q) => o.datesFor(q.durationMinutes).isNotEmpty).toList();
    final header = [
      Text(
        i.name,
        style: AppTypography.title.copyWith(
          fontSize: 22,
          height: 28 / 22,
          color: AppColors.ink,
          fontVariations: const [FontVariation('wght', 700)],
        ),
      ),
      if (i.schoolAddress != null) ...[
        const SizedBox(height: AppSpacing.x1),
        Text(i.schoolAddress!, style: AppTypography.body.copyWith(color: AppColors.inkSecondary)),
      ],
      const SizedBox(height: AppSpacing.x3),
    ];
    if (quotes.isEmpty) {
      return ListView(padding: _padding, children: [
        ...header,
        BentoEmptyCard(
          icon: SolarIcons.clockCircleLinear,
          title: l.translate('booking_no_times_title'),
          description: l.translate('booking_no_times_desc'),
        ),
      ]);
    }

    // Keep the choices valid as the length changes: a date or start that
    // doesn't fit the new length is dropped.
    final quote = quotes.firstWhere((q) => q.durationMinutes == _minutes, orElse: () => quotes.first);
    final dates = o.datesFor(quote.durationMinutes);
    final date = dates.contains(_date) ? _date! : dates.first;
    final starts = o.startsFor(date, quote.durationMinutes);
    final start = starts.any((s) => s.startAtMs == _start?.startAtMs) ? _start : null;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: _padding,
            children: [
              ...header,
              _Card(
                title: l.translate('booking_length'),
                child: Wrap(
                  spacing: AppSpacing.x2,
                  runSpacing: AppSpacing.x2,
                  children: [
                    for (final q in quotes)
                      _Choice(
                        text: l.translate('ireg_minutes').replaceAll('{n}', '${q.durationMinutes}'),
                        selected: q == quote,
                        onTap: () => setState(() => _minutes = q.durationMinutes),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.x3),
              _Card(
                title: l.translate('booking_date'),
                child: _DateStrip(
                  dates: dates,
                  selected: date,
                  onSelect: (d) => setState(() {
                    _date = d;
                    _start = null;
                  }),
                ),
              ),
              const SizedBox(height: AppSpacing.x3),
              _Card(
                title: l.translate('booking_time'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: AppSpacing.x2,
                      runSpacing: AppSpacing.x2,
                      children: [
                        for (final s in starts)
                          _Choice(
                            text: s.time,
                            selected: s.startAtMs == start?.startAtMs,
                            onTap: () => setState(() {
                              _date = date;
                              _start = s;
                            }),
                          ),
                      ],
                    ),
                    if (o.timezone != null) ...[
                      const SizedBox(height: AppSpacing.x3),
                      Row(
                        children: [
                          const Icon(SolarIcons.clockCircleLinear, size: 16, color: AppColors.inkSecondary),
                          const SizedBox(width: AppSpacing.x1 + 2),
                          Expanded(
                            child: Text(
                              timezoneLabel(l, o.timezone!, city: i.city),
                              style: AppTypography.caption.copyWith(color: AppColors.inkSecondary),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.x3),
              _Card(title: l.translate('booking_price'), child: PriceLines(quote: quote)),
              const SizedBox(height: AppSpacing.x3),
              Text(
                l.translate('booking_cancel_rule'),
                textAlign: TextAlign.center,
                style: AppTypography.caption.copyWith(color: AppColors.inkSecondary),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.x4 + AppSpacing.x1, AppSpacing.x2, AppSpacing.x4 + AppSpacing.x1, AppSpacing.x3),
          child: _busy
              ? const SizedBox(height: 56, child: Center(child: CircularProgressIndicator()))
              : BentoActionButton(
                  text: l.translate('instructor_book'),
                  onTap: start == null ? null : () => _book(quote),
                ),
        ),
      ],
    );
  }
}

const EdgeInsets _padding = EdgeInsets.fromLTRB(
  AppSpacing.x4 + AppSpacing.x1,
  AppSpacing.x2,
  AppSpacing.x4 + AppSpacing.x1,
  AppSpacing.x4,
);

/// A white card with its title first (owner rule 2).
class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
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
          Text(
            title,
            style: AppTypography.body.copyWith(
              fontSize: 17,
              color: AppColors.ink,
              fontVariations: const [FontVariation('wght', 600)],
            ),
          ),
          const SizedBox(height: AppSpacing.x3),
          child,
        ],
      ),
    );
  }
}

/// A pill to pick; the chosen one is the dark `ink` pill, no tick (owner
/// rule 10).
class _Choice extends StatelessWidget {
  const _Choice({required this.text, required this.selected, required this.onTap});

  final String text;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppMotion.duration(context, BentoTokens.state),
          curve: BentoTokens.curve,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4, vertical: AppSpacing.x2 + 2),
          decoration: BoxDecoration(
            color: selected ? AppColors.ink : AppColors.field,
            borderRadius: BorderRadius.circular(BentoTokens.chip),
          ),
          child: Text(
            text,
            style: AppTypography.label.copyWith(
              color: selected ? AppColors.onSignal : AppColors.ink,
              fontVariations: const [FontVariation('wght', 600)],
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ),
    );
  }
}

/// The days that have room for the chosen length, as a scrolling row of
/// day tiles, faded at both ends so none touches the card's edge (owner
/// rule 6).
class _DateStrip extends StatefulWidget {
  const _DateStrip({required this.dates, required this.selected, required this.onSelect});

  final List<String> dates;
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  State<_DateStrip> createState() => _DateStripState();
}

class _DateStripState extends State<_DateStrip> {
  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    return SizedBox(
      height: 72,
      child: ShaderMask(
        shaderCallback: (rect) => const LinearGradient(
          colors: [Colors.transparent, Colors.black, Colors.black, Colors.transparent],
          stops: [0, 0.04, 0.96, 1],
        ).createShader(rect),
        blendMode: BlendMode.dstIn,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x2),
          itemCount: widget.dates.length,
          separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.x2),
          itemBuilder: (context, n) {
            final date = widget.dates[n];
            final at = DateTime.parse(date);
            final selected = date == widget.selected;
            final fg = selected ? AppColors.onSignal : AppColors.ink;
            return Semantics(
              button: true,
              selected: selected,
              child: GestureDetector(
                onTap: () => widget.onSelect(date),
                child: AnimatedContainer(
                  duration: AppMotion.duration(context, BentoTokens.state),
                  curve: BentoTokens.curve,
                  width: 56,
                  decoration: BoxDecoration(
                    color: selected ? AppColors.ink : AppColors.field,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        DateFormat.E(locale).format(at),
                        style: AppTypography.caption.copyWith(color: selected ? AppColors.onSignal : AppColors.inkSecondary),
                      ),
                      Text(
                        '${at.day}',
                        style: AppTypography.title.copyWith(
                          fontSize: 20,
                          height: 24 / 20,
                          color: fg,
                          fontVariations: const [FontVariation('wght', 700)],
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      Text(
                        DateFormat.MMM(locale).format(at),
                        style: AppTypography.caption.copyWith(color: selected ? AppColors.onSignal : AppColors.inkSecondary),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Lesson, «Сервисный сбор» and the total (plan v2 §9.1); the total is the
/// headline. A first lesson says why its fee is higher.
class PriceLines extends StatelessWidget {
  const PriceLines({super.key, required this.quote});

  final BookingQuote quote;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final q = quote;
    TextStyle style(bool strong) => AppTypography.label.copyWith(
          color: strong ? AppColors.ink : AppColors.inkSecondary,
          fontVariations: [FontVariation('wght', strong ? 600 : 500)],
          fontFeatures: const [FontFeature.tabularFigures()],
        );
    Widget line(String label, int cents) => Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.x2),
          child: Row(
            children: [
              Expanded(child: Text(label, style: style(false))),
              Text(formatUsd(cents), style: style(true)),
            ],
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        line(l.translate('booking_lesson_line').replaceAll('{n}', '${q.durationMinutes}'), q.lessonCents),
        line(l.translate('booking_service_fee'), q.platformFeeCents),
        if (q.feeKind == 'first')
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.x2),
            child: Text(
              l.translate('booking_first_note'),
              style: AppTypography.caption.copyWith(color: AppColors.inkSecondary),
            ),
          ),
        const SizedBox(height: AppSpacing.x1),
        Row(
          children: [
            Expanded(
              child: Text(
                l.translate('booking_total'),
                style: AppTypography.body.copyWith(
                  fontSize: 17,
                  color: AppColors.ink,
                  fontVariations: const [FontVariation('wght', 600)],
                ),
              ),
            ),
            Text(
              formatUsd(q.totalCents),
              style: AppTypography.title.copyWith(
                fontSize: 22,
                height: 28 / 22,
                color: AppColors.ink,
                fontVariations: const [FontVariation('wght', 700)],
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
