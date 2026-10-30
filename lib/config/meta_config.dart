/// Meta's App Events (analytics plan E). The ids of the Meta app are in
/// `ios/Runner/Info.plist` and `android/app/src/main/res/values/strings.xml`.
/// While this is false the app shows no tracking prompt, sends Meta nothing
/// and keeps the Facebook SDK asleep.
///
/// Set it true only with the privacy policy updated and live.
const bool metaConfigured = false;
