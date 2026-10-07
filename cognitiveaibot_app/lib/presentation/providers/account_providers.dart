import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/error/failures.dart';
import '../../core/usecases/usecase.dart';
import '../../domain/entities/account.dart';
import '../../domain/usecases/account_usecases.dart';
import 'auth_provider.dart';
import 'providers.dart';

T _unwrap<T>(Result<T> result) => switch (result) {
      Success(:final data) => data,
      FailureResult(:final failure) => throw failure,
    };

/// Plan, subscription and credits. Invalidate after a reply or a purchase.
/// Rebuilt when the signed-in user changes.
final billingProvider = FutureProvider<BillingInfo>((ref) async {
  ref.watch(currentUserProvider.select((u) => u?.id));
  return _unwrap(await ref.read(getBillingProvider).call(const NoParams()));
});

/// The plan catalog from the server.
final plansProvider = FutureProvider<List<Plan>>((ref) async {
  return _unwrap(await ref.read(getPlansProvider).call(const NoParams()));
});

final usageDashboardProvider = FutureProvider<UsageDashboard>((ref) async {
  ref.watch(currentUserProvider.select((u) => u?.id));
  return _unwrap(await ref.read(getUsageDashboardProvider).call(const NoParams()));
});

/// The account's settings, saved on the server.
class SettingsController extends AsyncNotifier<UserSettings> {
  @override
  Future<UserSettings> build() async {
    ref.watch(currentUserProvider.select((u) => u?.id));
    return _unwrap(await ref.read(getSettingsProvider).call(const NoParams()));
  }

  /// Applies [change] at once and saves it. On failure the previous value
  /// comes back and the failure's message is returned.
  Future<String?> save(UserSettings Function(UserSettings current) change) async {
    final previous = state.valueOrNull;
    if (previous == null) return 'Settings haven’t loaded yet.';
    final next = change(previous);
    state = AsyncData(next);
    final result = await ref.read(updateSettingsProvider).call(UpdateSettingsParams(previous: previous, next: next));
    switch (result) {
      case Success(:final data):
        state = AsyncData(data);
        return null;
      case FailureResult(:final failure):
        state = AsyncData(previous);
        return failure.message ?? 'Couldn’t save settings.';
    }
  }
}

final settingsProvider = AsyncNotifierProvider<SettingsController, UserSettings>(SettingsController.new);

/// User-facing text for a provider error.
String errorText(Object error) =>
    error is Failure ? (error.message ?? 'Something went wrong.') : 'Something went wrong.';
