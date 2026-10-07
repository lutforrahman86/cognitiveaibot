import 'package:cognitiveaibot/core/storage/token_store.dart';
import 'package:cognitiveaibot/presentation/providers/auth_provider.dart';
import 'package:cognitiveaibot/presentation/providers/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'fake_backend.dart';

/// Provider overrides that point the app at [backend], optionally with a
/// saved session token (signed in on start).
List<Override> fakeBackendOverrides(FakeBackend backend, {String? savedToken}) => [
      httpClientProvider.overrideWithValue(backend),
      tokenStoreProvider.overrideWithValue(MemoryTokenStore(savedToken)),
    ];

/// A container that is signed in to [backend].
Future<ProviderContainer> signedInContainer(FakeBackend backend) async {
  final container = ProviderContainer(overrides: fakeBackendOverrides(backend, savedToken: backend.token));
  container.read(authControllerProvider);
  for (var i = 0; i < 50 && container.read(authControllerProvider).status == AuthStatus.restoring; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  return container;
}
