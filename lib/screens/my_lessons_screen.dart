import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import '../models/booking.dart';
import '../services/booking_service.dart';
import '../theme/app_theme.dart';
import '../widgets/bento_result_parts.dart' show bentoHeadingAppBar;
import '../widgets/booking_tile.dart';
import 'booking_detail_screen.dart';

/// «Мои уроки» — a student's lessons, upcoming then past (instructors plan
/// v2 §9). Opened from the card at the top of Поиск (owner, 2026-10-05: a
/// card rather than a fourth segment).
class MyLessonsScreen extends StatelessWidget {
  const MyLessonsScreen({super.key, required this.uid, this.service});

  final String uid;
  final BookingService? service;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.field,
      appBar: bentoHeadingAppBar(title: l.translate('my_lessons_title'), onBack: () => Navigator.of(context).pop()),
      body: StreamBuilder<List<Booking>>(
        stream: (service ?? BookingService()).bookings(uid, asInstructor: false),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          return ListView(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.x4 + AppSpacing.x1, AppSpacing.x2, AppSpacing.x4 + AppSpacing.x1, AppSpacing.x6),
            children: bookingSections(
              context,
              snap.data!,
              asInstructor: false,
              onOpen: (b) => Navigator.of(context).push(
                ForwardPageRoute(child: BookingDetailScreen(bookingId: b.id, asInstructor: false)),
              ),
            ),
          );
        },
      ),
    );
  }
}
