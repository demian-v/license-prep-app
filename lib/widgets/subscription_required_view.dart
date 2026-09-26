import 'package:flutter/material.dart';
import '../localization/app_localizations.dart';
import '../theme/solar_icons.dart';

/// Shown when content was REFUSED for lack of a subscription, rather than
/// being genuinely absent (risk #3's entitlement gate).
///
/// Before that gate existed a content fetch could only come back empty, so
/// every screen treated "nothing to show" as a content or language problem.
/// A refusal now looks identical from the outside, and telling someone their
/// state has no theory modules when the real answer is "you have no
/// subscription" sends them hunting for a bug that does not exist.
class SubscriptionRequiredView extends StatelessWidget {
  const SubscriptionRequiredView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(SolarIcons.lockKeyholeMinimalisticLinear, size: 64, color: Colors.blue.shade300),
            const SizedBox(height: 24),
            Text(
              localizations.translate('subscription_required_title'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              localizations.translate('subscription_required_message'),
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/subscription'),
              child: Text(localizations.translate('subscribe_now')),
            ),
          ],
        ),
      ),
    );
  }
}
