import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_constants.dart';
import 'core/revenuecat/subscription_service.dart';
import 'core/theme/cognitive_aibot_theme.dart';
import 'presentation/providers/auth_provider.dart';
import 'presentation/screens/main_shell.dart';
import 'presentation/screens/sign_in_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SubscriptionService.initialize();
  runApp(
    const ProviderScope(
      child: CognitiveAIBotApp(),
    ),
  );
}

class CognitiveAIBotApp extends StatelessWidget {
  const CognitiveAIBotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: CognitiveAIBotTheme.theme,
      darkTheme: CognitiveAIBotTheme.theme,
      themeMode: ThemeMode.dark,
      home: const AuthGate(),
    );
  }
}

/// Restores the saved session on launch, then shows the app or sign-in.
/// Any 401 from the server signs out and lands back here.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(authControllerProvider.select((s) => s.status));
    // Popping pushed pages on sign-out keeps them from showing the old account.
    ref.listen(authControllerProvider.select((s) => s.status), (prev, next) {
      if (next != AuthStatus.signedIn) Navigator.of(context).popUntil((r) => r.isFirst);
    });
    return switch (status) {
      AuthStatus.restoring => const Scaffold(
          backgroundColor: CognitiveAIBotTheme.background,
          body: Center(child: CircularProgressIndicator()),
        ),
      AuthStatus.signedOut => const SignInScreen(),
      AuthStatus.signedIn => const MainShell(),
    };
  }
}
