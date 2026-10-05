/// One instructor as a student sees them: the public projection that
/// `listInstructors` / `getInstructorProfile` send (functions/src/
/// instructors.ts → publicInstructor). Nothing else reaches a student.
class InstructorListing {
  const InstructorListing({
    required this.id,
    required this.kind,
    required this.name,
    required this.city,
    required this.state,
    required this.languages,
    required this.stage,
    required this.ratingAvg,
    required this.ratingCount,
    required this.payoutsEnabled,
    required this.priceHidden,
    required this.lessonDurations,
    this.hourlyRateCents,
    this.photoPath,
    this.schoolName,
    this.schoolLicenseNumber,
    this.schoolAddress,
    this.fleetSize,
    this.instructorCount,
    this.carModel,
    this.carYear,
    this.hasDualControls = false,
    this.bio,
    this.availability = const {},
    this.timezone,
  });

  final String id;

  /// `school` or `schoolInstructor` (a private instructor).
  final String kind;
  final String name;
  final String city;
  final String state;
  final List<String> languages;

  /// 0 not checked, 1 ID checked, 2 bookable (plan v2 §6.4).
  final int stage;
  final double ratingAvg;
  final int ratingCount;
  final bool payoutsEnabled;

  /// A private instructor's price until a licence number is checked (owner,
  /// 2026-09-30): the server drops [hourlyRateCents] then.
  final bool priceHidden;
  final int? hourlyRateCents;
  final List<int> lessonDurations;
  final String? photoPath;
  final String? schoolName;
  final String? schoolLicenseNumber;
  final String? schoolAddress;
  final int? fleetSize;
  final int? instructorCount;
  final String? carModel;
  final int? carYear;
  final bool hasDualControls;
  final String? bio;

  /// Weekly hours, `{mon: [(start, end)]}`, wall clock in [timezone]. Only
  /// the detail call (`getInstructorProfile`) sends these.
  final Map<String, List<(String, String)>> availability;
  final String? timezone;

  bool get isSchool => kind == 'school';

  /// Fewer than 3 reviews says little, so the card shows «Новый» instead of
  /// stars (plan v2 §11).
  bool get isNew => ratingCount < 3;

  /// Only a driving school at stage 2 takes bookings (plan v2 §6.2, §6.4).
  bool get bookable => isSchool && stage >= 2;

  factory InstructorListing.fromMap(Map<dynamic, dynamic> m) {
    String? str(String k) => m[k] is String && (m[k] as String).isNotEmpty ? m[k] as String : null;
    int? integer(String k) => m[k] is num ? (m[k] as num).toInt() : null;
    final availability = <String, List<(String, String)>>{};
    final rawHours = m['availability'];
    if (rawHours is Map) {
      for (final entry in rawHours.entries) {
        final intervals = entry.value;
        if (intervals is! List) continue;
        availability['${entry.key}'] = [
          for (final i in intervals)
            if (i is Map && i['start'] is String && i['end'] is String) (i['start'] as String, i['end'] as String),
        ];
      }
    }
    return InstructorListing(
      id: m['id'] as String,
      kind: str('kind') ?? 'school',
      name: str('name') ?? '',
      city: str('city') ?? '',
      state: str('state') ?? '',
      languages: [for (final l in (m['languages'] as List? ?? const [])) '$l'],
      stage: integer('stage') ?? 0,
      ratingAvg: m['ratingAvg'] is num ? (m['ratingAvg'] as num).toDouble() : 0,
      ratingCount: integer('ratingCount') ?? 0,
      payoutsEnabled: m['payoutsEnabled'] == true,
      priceHidden: m['priceHidden'] == true,
      hourlyRateCents: integer('hourlyRateCents'),
      lessonDurations: [for (final d in (m['lessonDurations'] as List? ?? const [])) if (d is num) d.toInt()],
      photoPath: str('photoPath'),
      schoolName: str('schoolName'),
      schoolLicenseNumber: str('schoolLicenseNumber'),
      schoolAddress: str('schoolAddress'),
      fleetSize: integer('fleetSize'),
      instructorCount: integer('instructorCount'),
      carModel: str('carModel'),
      carYear: integer('carYear'),
      hasDualControls: m['hasDualControls'] == true,
      bio: str('bio'),
      availability: availability,
      timezone: str('timezone'),
    );
  }
}

/// A review as `getInstructorReviews` sends it: no reviewer uid.
class InstructorReview {
  const InstructorReview({required this.name, required this.rating, required this.comment, this.createdAt});

  final String name;
  final int rating;
  final String comment;
  final DateTime? createdAt;

  factory InstructorReview.fromMap(Map<dynamic, dynamic> m) => InstructorReview(
        name: m['name'] is String ? m['name'] as String : '',
        rating: m['rating'] is num ? (m['rating'] as num).toInt() : 0,
        comment: m['comment'] is String ? m['comment'] as String : '',
        createdAt: m['createdAtMs'] is num
            ? DateTime.fromMillisecondsSinceEpoch((m['createdAtMs'] as num).toInt())
            : null,
      );
}

/// The student's filters on Поиск (plan v2 §13), applied in the app to the
/// state's whole listing. Empty = everything.
class InstructorFilters {
  const InstructorFilters({
    this.kind,
    this.city,
    this.languages = const {},
    this.maxPriceUsd,
    this.bookableOnly = false,
    this.rating4 = false,
    this.dualControls = false,
  });

  /// `school` or `schoolInstructor`; null = both.
  final String? kind;
  final String? city;
  final Set<String> languages;

  /// A hidden price can't be compared, so those profiles drop out.
  final int? maxPriceUsd;
  final bool bookableOnly;
  final bool rating4;
  final bool dualControls;

  int get activeCount => [
        kind != null,
        city != null,
        languages.isNotEmpty,
        maxPriceUsd != null,
        bookableOnly,
        rating4,
        dualControls,
      ].where((on) => on).length;

  bool matches(InstructorListing i) =>
      (kind == null || i.kind == kind) &&
      (city == null || i.city == city) &&
      (languages.isEmpty || i.languages.any(languages.contains)) &&
      (maxPriceUsd == null || (i.hourlyRateCents != null && i.hourlyRateCents! <= maxPriceUsd! * 100)) &&
      (!bookableOnly || i.bookable) &&
      (!rating4 || (!i.isNew && i.ratingAvg >= 4)) &&
      (!dualControls || i.hasDualControls);
}

/// Rating that a profile with too few reviews is ranked at, so new ones mix
/// in among the rated instead of sinking to the bottom (plan v2 §13).
const double _newProfileRank = 4.0;

/// The default order (plan v2 §13): stage, then rating, then payouts set
/// up, then a shuffle seeded once per app session — stable while the student
/// scrolls, different next time, so nobody is always last.
List<InstructorListing> orderInstructors(Iterable<InstructorListing> list, int seed) {
  double rank(InstructorListing i) => i.isNew ? _newProfileRank : i.ratingAvg;
  return list.toList()
    ..sort((a, b) {
      if (a.stage != b.stage) return b.stage.compareTo(a.stage);
      if (rank(a) != rank(b)) return rank(b).compareTo(rank(a));
      if (a.payoutsEnabled != b.payoutsEnabled) return a.payoutsEnabled ? -1 : 1;
      return Object.hash(seed, a.id).compareTo(Object.hash(seed, b.id));
    });
}
