import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../localization/app_localizations.dart';
import '../providers/auth_provider.dart';
import '../services/instructor_service.dart';
import '../theme/app_theme.dart';
import '../theme/bento_tokens.dart';
import '../widgets/bento_auth_parts.dart';
import '../widgets/bento_question_parts.dart';

/// «Календарь» — the instructor's first tab (instructors plan v2 §14.2): the
/// weekly hours students can book inside, as a grid of half hours from 06:00
/// to 22:00, in the instructor's own timezone. Tap opens or closes one half
/// hour; hold, then drag, marks a range (a plain drag scrolls the page).
/// Saved through updateInstructorProfile, which merges the cells into
/// intervals. Upcoming and past lessons come with bookings (P7). A tab page,
/// so no title (owner rule 1).
class InstructorCalendarScreen extends StatefulWidget {
  const InstructorCalendarScreen({super.key, this.service, this.uid});

  final InstructorService? service;

  /// For tests; the signed-in user otherwise.
  final String? uid;

  static const days = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
  static const firstMinute = 6 * 60;
  static const slots = 32; // 06:00–22:00 in half hours

  /// `{mon: [{start, end}]}` → the half-hour cells each day has open.
  static Map<String, Set<int>> cellsFrom(Object? availability) {
    final out = {for (final d in days) d: <int>{}};
    if (availability is! Map) return out;
    for (final d in days) {
      final list = availability[d];
      if (list is! List) continue;
      for (final item in list) {
        if (item is! Map) continue;
        final start = _minutes(item['start']);
        final end = _minutes(item['end']);
        if (start == null || end == null) continue;
        for (var m = start; m < end; m += 30) {
          final i = (m - firstMinute) ~/ 30;
          if (i >= 0 && i < slots) out[d]!.add(i);
        }
      }
    }
    return out;
  }

  /// The cells → merged intervals, empty days left out.
  static Map<String, List<Map<String, String>>> availabilityFrom(Map<String, Set<int>> cells) {
    final out = <String, List<Map<String, String>>>{};
    for (final d in days) {
      final sorted = (cells[d] ?? const <int>{}).toList()..sort();
      final intervals = <Map<String, String>>[];
      for (final i in sorted) {
        if (intervals.isNotEmpty && intervals.last['end'] == time(i)) {
          intervals.last['end'] = time(i + 1);
        } else {
          intervals.add({'start': time(i), 'end': time(i + 1)});
        }
      }
      if (intervals.isNotEmpty) out[d] = intervals;
    }
    return out;
  }

  /// The wall-clock start of cell [i], "HH:MM".
  static String time(int i) {
    final m = firstMinute + i * 30;
    return '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
  }

  static int? _minutes(Object? v) {
    if (v is! String || !RegExp(r'^\d{2}:\d{2}$').hasMatch(v)) return null;
    return int.parse(v.substring(0, 2)) * 60 + int.parse(v.substring(3));
  }

  @override
  State<InstructorCalendarScreen> createState() => _InstructorCalendarScreenState();
}

class _InstructorCalendarScreenState extends State<InstructorCalendarScreen> {
  late final InstructorService _service = widget.service ?? InstructorService();
  Stream<Map<String, dynamic>?>? _profile;

  /// What the server has, and what the instructor is editing.
  Map<String, Set<int>> _saved = InstructorCalendarScreen.cellsFrom(null);
  Map<String, Set<int>> _cells = InstructorCalendarScreen.cellsFrom(null);
  bool _loaded = false;
  bool _busy = false;
  bool _justSaved = false;
  String? _error;

  /// The state a long-press drag paints (open or closed), from its first cell,
  /// and the last cell it painted.
  bool? _paint;
  (int, int)? _lastPaint;

  String get _uid =>
      widget.uid ?? Provider.of<AuthProvider>(context, listen: false).user?.id ?? '';

  // Named `translate` so localization_coverage_test sees every key literal.
  String translate(String key) => AppLocalizations.of(context).translate(key);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _profile ??= _service.ownProfile(_uid);
  }

  bool get _dirty {
    for (final d in InstructorCalendarScreen.days) {
      final a = _cells[d]!, b = _saved[d]!;
      if (a.length != b.length || !a.containsAll(b)) return true;
    }
    return false;
  }

  void _sync(Map<String, dynamic>? p) {
    final server = InstructorCalendarScreen.cellsFrom(p?['availability']);
    // A change from elsewhere replaces the grid only when nothing is unsaved.
    if (!_loaded || !_dirty) {
      _saved = server;
      _cells = {for (final e in server.entries) e.key: {...e.value}};
      _loaded = true;
    } else {
      _saved = server;
    }
  }

  void _set(String day, int i, bool open) {
    final set = _cells[day]!;
    if (set.contains(i) == open) return;
    setState(() {
      open ? set.add(i) : set.remove(i);
      _justSaved = false;
      _error = null;
    });
  }

  /// A fast finger jumps several cells between two move events; every cell
  /// on the way is painted, not just the ones it landed on.
  void _paintTo(String day, int i) {
    final paint = _paint, last = _lastPaint;
    if (paint == null || last == null) return;
    final c = InstructorCalendarScreen.days.indexOf(day);
    final steps = [(c - last.$1).abs(), (i - last.$2).abs()].reduce((a, b) => a > b ? a : b);
    for (var k = 1; k <= steps; k++) {
      final cc = last.$1 + ((c - last.$1) * k / steps).round();
      final rr = last.$2 + ((i - last.$2) * k / steps).round();
      _set(InstructorCalendarScreen.days[cc], rr, paint);
    }
    _lastPaint = (c, i);
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _service.updateProfile('availability', {
        'availability': InstructorCalendarScreen.availabilityFrom(_cells),
      });
      if (mounted) {
        setState(() {
          _saved = {for (final e in _cells.entries) e.key: {...e.value}};
          _justSaved = true;
        });
      }
    } catch (e) {
      debugPrint('InstructorCalendar: save failed: $e');
      if (mounted) setState(() => _error = translate('iprof_save_error'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  List<String> _dayLabels() => [
        translate('day_short_mon'),
        translate('day_short_tue'),
        translate('day_short_wed'),
        translate('day_short_thu'),
        translate('day_short_fri'),
        translate('day_short_sat'),
        translate('day_short_sun'),
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.field,
      body: SafeArea(
        child: StreamBuilder<Map<String, dynamic>?>(
          stream: _profile,
          builder: (context, snap) {
            if (snap.hasData) _sync(snap.data);
            if (!_loaded) return const Center(child: CircularProgressIndicator());
            final p = snap.data;
            final editable = p?['status'] != 'suspended';
            final timezone = p?['timezone'] as String?;
            return Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.x4 + AppSpacing.x1, AppSpacing.x4, AppSpacing.x4 + AppSpacing.x1, AppSpacing.x4),
                    children: [
                      Text(
                        translate('instructor_calendar_empty_title'),
                        style: AppTypography.title.copyWith(
                          fontSize: 22,
                          height: 28 / 22,
                          color: AppColors.ink,
                          fontVariations: const [FontVariation('wght', 700)],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.x1),
                      Text(
                        editable ? translate('ical_desc') : translate('iprof_suspended'),
                        style: AppTypography.body.copyWith(color: AppColors.inkSecondary),
                      ),
                      if (timezone != null) ...[
                        const SizedBox(height: AppSpacing.x1),
                        Text(
                          translate('ical_timezone').replaceAll('{tz}', timezone.replaceAll('_', ' ')),
                          style: AppTypography.caption.copyWith(color: AppColors.inkSecondary),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.x3),
                      if (_error != null) ...[BentoAuthError(_error!), const SizedBox(height: AppSpacing.x3)],
                      Container(
                        padding: const EdgeInsets.fromLTRB(AppSpacing.x2, AppSpacing.x3, AppSpacing.x3, AppSpacing.x3),
                        decoration: BoxDecoration(
                          color: AppColors.paper,
                          borderRadius: BorderRadius.circular(BentoTokens.card),
                          boxShadow: AppColors.shadowCard,
                        ),
                        child: _Grid(
                          cells: _cells,
                          dayLabels: _dayLabels(),
                          enabled: editable && !_busy,
                          onToggle: (d, i) => _set(d, i, !_cells[d]!.contains(i)),
                          onPaintStart: (d, i) {
                            HapticFeedback.selectionClick();
                            _paint = !_cells[d]!.contains(i);
                            _lastPaint = (InstructorCalendarScreen.days.indexOf(d), i);
                            _set(d, i, _paint!);
                          },
                          onPaint: _paintTo,
                          onPaintEnd: () {
                            _paint = null;
                            _lastPaint = null;
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                if (editable)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.x4 + AppSpacing.x1, AppSpacing.x2, AppSpacing.x4 + AppSpacing.x1, AppSpacing.x3),
                    child: _busy
                        ? const SizedBox(height: 56, child: Center(child: CircularProgressIndicator()))
                        // The page's own action: the dark ink pill (owner rule 16).
                        : BentoActionButton(
                            text: _justSaved && !_dirty ? translate('ical_saved') : translate('save'),
                            ink: true,
                            onTap: _dirty ? _save : null,
                          ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The week: a time column, then one column per day of half-hour cells.
/// Open cells are `signal`.
class _Grid extends StatelessWidget {
  const _Grid({
    required this.cells,
    required this.dayLabels,
    required this.enabled,
    required this.onToggle,
    required this.onPaintStart,
    required this.onPaint,
    required this.onPaintEnd,
  });

  final Map<String, Set<int>> cells;
  final List<String> dayLabels;
  final bool enabled;
  final void Function(String day, int i) onToggle;
  final void Function(String day, int i) onPaintStart;
  final void Function(String day, int i) onPaint;
  final VoidCallback onPaintEnd;

  static const timeColumn = 40.0;
  static const rowHeight = 24.0;
  static const days = InstructorCalendarScreen.days;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final colWidth = (box.maxWidth - timeColumn) / days.length;
      (String, int)? at(Offset p) {
        final c = (p.dx / colWidth).floor();
        final r = (p.dy / rowHeight).floor();
        if (c < 0 || c >= days.length || r < 0 || r >= InstructorCalendarScreen.slots) return null;
        return (days[c], r);
      }

      void call(Offset p, void Function(String, int) f) {
        final hit = at(p);
        if (hit != null) f(hit.$1, hit.$2);
      }

      return Column(
        children: [
          Row(
            children: [
              const SizedBox(width: timeColumn),
              for (final label in dayLabels)
                SizedBox(
                  width: colWidth,
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    style: AppTypography.label.copyWith(
                      color: AppColors.inkSecondary,
                      fontVariations: const [FontVariation('wght', 600)],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.x2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: timeColumn,
                child: Column(
                  children: [
                    for (var i = 0; i < InstructorCalendarScreen.slots; i++)
                      SizedBox(
                        height: rowHeight,
                        child: i.isEven
                            ? Align(
                                alignment: Alignment.topRight,
                                child: Padding(
                                  padding: const EdgeInsets.only(right: AppSpacing.x1),
                                  child: Text(
                                    InstructorCalendarScreen.time(i),
                                    style: AppTypography.caption.copyWith(fontSize: 11, color: AppColors.inkTertiary),
                                  ),
                                ),
                              )
                            : null,
                      ),
                  ],
                ),
              ),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: enabled ? (d) => call(d.localPosition, onToggle) : null,
                  onLongPressStart: enabled ? (d) => call(d.localPosition, onPaintStart) : null,
                  onLongPressMoveUpdate: enabled ? (d) => call(d.localPosition, onPaint) : null,
                  onLongPressEnd: enabled ? (_) => onPaintEnd() : null,
                  child: Row(
                    children: [
                      for (var c = 0; c < days.length; c++)
                        SizedBox(
                          width: colWidth,
                          child: Column(
                            children: [
                              for (var i = 0; i < InstructorCalendarScreen.slots; i++)
                                _Cell(
                                  open: cells[days[c]]!.contains(i),
                                  // One block per open run: rounded at its ends.
                                  openAbove: cells[days[c]]!.contains(i - 1),
                                  openBelow: cells[days[c]]!.contains(i + 1),
                                  hourLine: i.isEven,
                                  label: '${dayLabels[c]} ${InstructorCalendarScreen.time(i)}',
                                  onTap: enabled ? () => onToggle(days[c], i) : null,
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    });
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.open,
    required this.openAbove,
    required this.openBelow,
    required this.hourLine,
    required this.label,
    required this.onTap,
  });

  final bool open;
  final bool openAbove;
  final bool openBelow;
  final bool hourLine;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    const r = Radius.circular(6);
    return Semantics(
      button: true,
      toggled: open,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: SizedBox(
        height: _Grid.rowHeight,
        child: Padding(
          padding: EdgeInsets.only(
            left: 2,
            right: 2,
            top: open && openAbove ? 0 : 1,
            bottom: open && openBelow ? 0 : 1,
          ),
          child: AnimatedContainer(
            duration: AppMotion.duration(context, BentoTokens.state),
            decoration: BoxDecoration(
              color: open ? AppColors.signal : (hourLine ? AppColors.field : AppColors.paper),
              border: open ? null : Border.all(color: AppColors.field),
              borderRadius: BorderRadius.vertical(
                top: open && openAbove ? Radius.zero : r,
                bottom: open && openBelow ? Radius.zero : r,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
