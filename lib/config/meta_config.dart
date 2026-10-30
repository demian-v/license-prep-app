/// Meta's App Events (analytics plan E). The ids of the Meta app are in
/// `ios/Runner/Info.plist` and `android/app/src/main/res/values/strings.xml`.
/// While this is false the app shows no tracking prompt, sends Meta nothing
/// and keeps the Facebook SDK asleep.
///
/// True since 2026-10-30: the privacy policy covers Meta and the Meta app is
/// published. It stays true only while both do.
const bool metaConfigured = true;
