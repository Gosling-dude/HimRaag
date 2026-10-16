import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:himraag/core/constants/app_constants.dart';
import 'package:himraag/core/widgets/legal_links.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

/// Records launched URLs instead of opening a browser.
class _FakeLauncher extends Fake
    with MockPlatformInterfaceMixin
    implements UrlLauncherPlatform {
  final launched = <String>[];
  bool succeed = true;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launched.add(url);
    return succeed;
  }
}

void main() {
  late _FakeLauncher launcher;

  setUp(() {
    launcher = _FakeLauncher();
    UrlLauncherPlatform.instance = launcher;
  });

  Future<void> pumpCard(WidgetTester tester) => tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: LegalLinksCard())),
      );

  group('legal URLs', () {
    // These must stay identical to what Play Console has on file
    // (App content → Privacy policy, Data safety → account deletion URL).
    test('point at the hosted HimRaag legal pages over https', () {
      expect(AppConstants.privacyPolicyUrl,
          'https://gosling-dude.github.io/himraag-legal/privacy.html');
      expect(AppConstants.accountDeletionUrl,
          'https://gosling-dude.github.io/himraag-legal/delete-account.html');
      expect(AppConstants.termsUrl,
          'https://gosling-dude.github.io/himraag-legal/terms.html');
    });
  });

  group('LegalLinksCard', () {
    testWidgets('shows privacy, terms and account-deletion entries',
        (tester) async {
      await pumpCard(tester);

      expect(find.text('Privacy Policy'), findsOneWidget);
      expect(find.text('Terms of Service'), findsOneWidget);
      expect(find.text('Delete account'), findsOneWidget);
    });

    testWidgets('each entry opens its hosted page', (tester) async {
      await pumpCard(tester);

      await tester.tap(find.text('Privacy Policy'));
      await tester.tap(find.text('Terms of Service'));
      await tester.tap(find.text('Delete account'));
      await tester.pump();

      expect(launcher.launched, [
        AppConstants.privacyPolicyUrl,
        AppConstants.termsUrl,
        AppConstants.accountDeletionUrl,
      ]);
    });

    testWidgets('shows the address when no browser can open it',
        (tester) async {
      launcher.succeed = false;
      await pumpCard(tester);

      await tester.tap(find.text('Delete account'));
      await tester.pump();

      expect(
        find.text('Could not open the page. '
            'Visit ${AppConstants.accountDeletionUrl}'),
        findsOneWidget,
      );
    });
  });
}
