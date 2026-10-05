import '../../core/usecases/usecase.dart';
import '../../domain/entities/account.dart';
import '../../domain/repositories/account_repository.dart';
import '../datasources/account_remote_datasource.dart';

class AccountRepositoryImpl implements AccountRepository {
  AccountRepositoryImpl(this._remote);

  final AccountRemoteDataSource _remote;

  @override
  Future<Result<BillingInfo>> getBilling() => Result.guard(_remote.getBilling);

  @override
  Future<Result<List<Plan>>> getPlans() => Result.guard(_remote.getPlans);

  @override
  Future<Result<UsageDashboard>> getUsageDashboard() => Result.guard(_remote.getUsageDashboard);

  @override
  Future<Result<UserSettings>> getSettings() => Result.guard(_remote.getSettings);

  @override
  Future<Result<UserSettings>> updateSettings(UserSettings previous, UserSettings next) =>
      Result.guard(() => _remote.updateSettings(previous, next));
}
