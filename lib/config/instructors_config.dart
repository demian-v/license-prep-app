/// The instructors side of the app for students and new sign-ups: «Create
/// Instructor Account» on Sign Up, the Инструкторы tab and its onboarding step.
/// While this is false a release has no way in, so the Didit identity check
/// (a selfie video) and Stripe can't be reached.
///
/// Off for the release without instructors (owner, 2026-10-30). Before turning
/// it on: the privacy policies must cover the identity check (risk #81), and
/// the real Stripe and Didit secrets must be in production.
///
/// To work on instructors: `--dart-define=INSTRUCTORS=true`.
const bool instructorsReleased = bool.fromEnvironment('INSTRUCTORS');

/// Tests only.
bool? debugInstructorsOn;

bool get instructorsOn => debugInstructorsOn ?? instructorsReleased;
