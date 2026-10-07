import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/cognitive_aibot_theme.dart';
import '../providers/providers.dart';

/// The web app's legal pages.
enum LegalPage {
  terms('Terms', 'Terms of Service', Icons.description_outlined),
  acceptableUse('Acceptable Use Policy', 'Acceptable Use Policy', Icons.rule_outlined),
  privacy('Privacy Policy', 'Privacy Policy', Icons.privacy_tip_outlined);

  const LegalPage(this.shortTitle, this.title, this.icon);

  final String shortTitle;
  final String title;
  final IconData icon;

  Uri get url => switch (this) {
        LegalPage.terms => AppConfig.termsUrl,
        LegalPage.acceptableUse => AppConfig.acceptableUseUrl,
        LegalPage.privacy => AppConfig.privacyUrl,
      };

  Key get key => Key('legal-$name');
}

/// Opens [page] in the browser, or says it couldn't.
Future<void> openLegalPage(BuildContext context, WidgetRef ref, LegalPage page) async {
  final opened = await ref.read(linkOpenerProvider)(page.url);
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Couldn’t open ${page.url}')));
  }
}

/// "By creating an account you agree to the Terms, Acceptable Use Policy
/// and Privacy Policy", each a link. Shown under the sign-up form.
class SignUpAgreement extends ConsumerWidget {
  const SignUpAgreement({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const style = TextStyle(fontSize: 12, color: CognitiveAIBotTheme.textSecondary, height: 1.5);
    Widget link(LegalPage page) => InkWell(
          key: page.key,
          onTap: () => openLegalPage(context, ref, page),
          child: Text(
            page.shortTitle,
            style: style.copyWith(color: CognitiveAIBotTheme.primaryBlue, decoration: TextDecoration.underline),
          ),
        );
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Text('By creating an account you agree to the ', style: style),
        link(LegalPage.terms),
        const Text(', ', style: style),
        link(LegalPage.acceptableUse),
        const Text(' and ', style: style),
        link(LegalPage.privacy),
        const Text('.', style: style),
      ],
    );
  }
}
