import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants/app_constants.dart';
import '../theme/app_colors.dart';

/// Opens [url] in the user's browser. Falls back to a SnackBar showing the
/// address when no browser can handle it, so the link is never a dead end.
Future<void> openExternalUrl(BuildContext context, String url) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  var opened = false;
  try {
    opened = await launchUrl(Uri.parse(url),
        mode: LaunchMode.externalApplication);
  } catch (_) {/* reported below */}
  if (!opened) {
    messenger?.showSnackBar(
      SnackBar(content: Text('Could not open the page. Visit $url')),
    );
  }
}

/// Privacy Policy, Terms and account-deletion links.
///
/// Google Play requires the privacy policy to be reachable inside the app and
/// an in-app path to request account deletion (a link to the hosted deletion
/// page is an accepted path). Shown on the Profile screen for every user,
/// including signed-out and guest users.
class LegalLinksCard extends StatelessWidget {
  const LegalLinksCard({super.key});

  @override
  Widget build(BuildContext context) {
    // Material (not a decorated Container) so the tappable tiles' ink
    // splashes paint on the card instead of underneath it.
    return Material(
      color: AppColors.cardDark,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: const Column(
        children: [
          _LinkTile(
            icon: Icons.privacy_tip_rounded,
            title: 'Privacy Policy',
            url: AppConstants.privacyPolicyUrl,
          ),
          Divider(height: 1, indent: 52),
          _LinkTile(
            icon: Icons.description_rounded,
            title: 'Terms of Service',
            url: AppConstants.termsUrl,
          ),
          Divider(height: 1, indent: 52),
          _LinkTile(
            icon: Icons.person_remove_rounded,
            title: 'Delete account',
            subtitle: 'Request deletion of your account and data',
            url: AppConstants.accountDeletionUrl,
          ),
        ],
      ),
    );
  }
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({
    required this.icon,
    required this.title,
    required this.url,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String url;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Icon(icon, size: 20, color: AppColors.accent),
      title: Text(title, style: const TextStyle(fontSize: 14)),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondaryDark),
            ),
      trailing: const Icon(Icons.open_in_new_rounded,
          size: 18, color: AppColors.textSecondaryDark),
      onTap: () => openExternalUrl(context, url),
    );
  }
}
