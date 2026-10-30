/// The legal pages the app links to, on driveusallc.com (the website in the
/// private repo driveusa-website, live since 2026-10-20). One place, so the
/// sign-up screen and the paywall can't drift apart again; they used to open
/// the old Google Sites pages. The pages are English only (the site's
/// translated folders hold just the welcome page).
class LegalLinks {
  LegalLinks._();

  static final Uri terms = Uri.parse('https://driveusallc.com/terms/');
  static final Uri privacy = Uri.parse('https://driveusallc.com/privacy/');
}
