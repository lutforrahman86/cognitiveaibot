import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_constants.dart';
import 'core/revenuecat/subscription_service.dart';
import 'core/theme/cognitive_aibot_theme.dart';
import 'presentation/screens/main_shell.dart';

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
      home: const MainShell(),
    );
  }
}
