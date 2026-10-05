import '../../core/usecases/usecase.dart';
import '../entities/account.dart';

/// Credits, plans, usage and settings of the signed-in account.
abstract interface class AccountRepository {
  Future<Result<BillingInfo>> getBilling();
  Future<Result<List<Plan>>> getPlans();
  Future<Result<UsageDashboard>> getUsageDashboard();
  Future<Result<UserSettings>> getSettings();
  Future<Result<UserSettings>> updateSettings(UserSettings previous, UserSettings next);

  /// Everything the service holds about the account, as JSON text.
  Future<Result<String>> exportData();
}
