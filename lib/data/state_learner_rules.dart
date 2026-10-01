/// What each released state requires of a new driver before the road test —
/// the "learner" columns of the state research (vault raw/drive_usa/
/// 2026-09-30-State instructor requirements, official DMV / statute sources,
/// checked 2026-09-30). Shown on the Инструкторы tab as «Что требует ваш
/// штат» (instructors plan v2 §14.4). Re-check at every launch: WA, VA and
/// CO change on 2027-01-01.
///
/// Hours are rounded to what the state publishes; where a state counts in
/// "periods" or segments the card says only that a course is required.
sealed class TeenRule {
  const TeenRule();
}

/// Classroom + behind-the-wheel hours with a licensed school.
class TeenBtw extends TeenRule {
  const TeenBtw(this.classHours, this.btwHours, {this.parentHours});
  final int classHours;
  final int btwHours;

  /// A parent-taught alternative to the school hours (GA).
  final int? parentHours;
}

/// Driver education with behind-the-wheel hours, at a school or parent-taught (TX).
class TeenBtwOrParentCourse extends TeenRule {
  const TeenBtwOrParentCourse(this.btwHours);
  final int btwHours;
}

/// A course only; practice with any licensed adult.
class TeenCourseOnly extends TeenRule {
  const TeenCourseOnly(this.classHours);
  final int classHours;
}

/// Behind-the-wheel with a school only at 16 (NJ).
class TeenAge16Btw extends TeenRule {
  const TeenAge16Btw(this.btwHours);
  final int btwHours;
}

/// A school course is required; the state counts it in periods (VA, CO).
class TeenSchoolCourse extends TeenRule {
  const TeenSchoolCourse();
}

class TeenNone extends TeenRule {
  const TeenNone();
}

sealed class AdultRule {
  const AdultRule();
}

/// Every new driver, any age: classes + behind-the-wheel with a school (MD).
class AdultAllAgesBtw extends AdultRule {
  const AdultAllAgesBtw(this.classHours, this.btwHours);
  final int classHours;
  final int btwHours;
}

/// A classroom/online course for an age band, no driving hours (IL, TX).
class AdultCourse extends AdultRule {
  const AdultCourse(this.fromAge, this.toAge, this.classHours);
  final int fromAge;
  final int toAge;
  final int classHours;
}

/// A course for every new adult driver, no driving hours (FL, NY).
class AdultCourseAll extends AdultRule {
  const AdultCourseAll(this.classHours);
  final int classHours;
}

/// The full teen course, driving hours included, up to an age (OH).
class AdultFullCourseUnder extends AdultRule {
  const AdultFullCourseUnder(this.toAge, this.btwHours);
  final int toAge;
  final int btwHours;
}

class AdultNone extends AdultRule {
  const AdultNone();
}

class LearnerRules {
  const LearnerRules(this.teen, this.adult, {this.changes2027 = false});
  final TeenRule teen;
  final AdultRule adult;
  final bool changes2027;
}

const Map<String, LearnerRules> stateLearnerRules = {
  'CA': LearnerRules(TeenBtw(30, 6), AdultNone()),
  'TX': LearnerRules(TeenBtwOrParentCourse(7), AdultCourse(18, 24, 6)),
  'FL': LearnerRules(TeenCourseOnly(6), AdultCourseAll(4)),
  'NJ': LearnerRules(TeenAge16Btw(6), AdultNone()),
  'PA': LearnerRules(TeenNone(), AdultNone()),
  'WA': LearnerRules(TeenBtw(30, 6), AdultNone(), changes2027: true),
  'MI': LearnerRules(TeenBtw(30, 6), AdultNone()),
  'AZ': LearnerRules(TeenNone(), AdultNone()),
  'OH': LearnerRules(TeenBtw(24, 8), AdultFullCourseUnder(20, 8)),
  'NC': LearnerRules(TeenBtw(30, 6), AdultNone()),
  'MA': LearnerRules(TeenBtw(30, 12), AdultNone()),
  'MD': LearnerRules(TeenBtw(30, 6), AdultAllAgesBtw(30, 6)),
  'IL': LearnerRules(TeenBtw(30, 6), AdultCourse(18, 20, 6)),
  'NY': LearnerRules(TeenCourseOnly(5), AdultCourseAll(5)),
  'GA': LearnerRules(TeenBtw(30, 6, parentHours: 40), AdultNone()),
  'VA': LearnerRules(TeenSchoolCourse(), AdultNone(), changes2027: true),
  'CO': LearnerRules(TeenSchoolCourse(), AdultNone(), changes2027: true),
  'NV': LearnerRules(TeenCourseOnly(30), AdultNone()),
  'OR': LearnerRules(TeenNone(), AdultNone()),
  'MN': LearnerRules(TeenBtw(30, 6), AdultNone()),
};
