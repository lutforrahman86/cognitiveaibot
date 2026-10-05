# Cognitive AI Bot

A Flutter mobile application with **Clean Architecture** and **Riverpod** for state management. Designed to integrate multiple LLM APIs (OpenAI, Anthropic, Gemini, DeepSeek, Grok, Perplexity).

## Architecture

```
lib/
├── core/                    # Shared utilities, errors, use case base
│   ├── constants/
│   ├── error/
│   └── usecases/
├── data/                    # Data layer - implementations
│   ├── datasources/         # Remote (API) & Local (cache)
│   ├── models/
│   └── repositories/
├── domain/                  # Business logic - no framework deps
│   ├── entities/
│   ├── repositories/       # Abstract interfaces
│   └── usecases/
├── presentation/            # UI layer
│   ├── providers/           # Riverpod providers
│   ├── screens/
│   └── widgets/
└── main.dart
```

## Setup

1. **Install dependencies:**
   ```bash
   flutter pub get
   ```

2. **Run the app:**
   ```bash
   flutter run
   ```

   Purchases are off unless RevenueCat keys for the CognitiveAI Bot project are passed at
   build time (see `lib/core/revenuecat/revenuecat_config.dart`):
   ```bash
   flutter run --dart-define=REVENUECAT_API_KEY=test_xxx --dart-define=REVENUECAT_PRO_ENTITLEMENT=pro
   ```
   Use `REVENUECAT_IOS_API_KEY` / `REVENUECAT_ANDROID_API_KEY` for store builds.

3. **Check it:**
   ```bash
   flutter analyze --no-fatal-infos
   flutter test
   ```

## Next Steps: LLM API Integration

The `ChatRemoteDataSourceImpl` in `lib/data/datasources/` is a placeholder. To integrate LLM APIs:

1. Add SDK packages (e.g. `openai_dart`, `anthropic_dart`, etc.) to `pubspec.yaml`
2. Create provider-specific datasources or a unified adapter
3. Implement `sendMessage()` and `getMessages()` in `ChatRemoteDataSourceImpl`
4. Store API keys securely (e.g. `flutter_dotenv`, `flutter_secure_storage`)

## Tech Stack

- **Flutter** - Cross-platform UI
- **Clean Architecture** - Domain, Data, Presentation layers
- **Riverpod** - State management & dependency injection
