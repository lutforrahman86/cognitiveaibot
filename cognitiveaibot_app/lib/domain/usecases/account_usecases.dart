import '../../core/usecases/usecase.dart';
import '../entities/account.dart';
import '../repositories/account_repository.dart';

class GetBilling implements UseCase<BillingInfo, NoParams> {
  GetBilling(this._repository);

  final AccountRepository _repository;

  @override
  Future<Result<BillingInfo>> call(NoParams params) => _repository.getBilling();
}

class GetPlans implements UseCase<List<Plan>, NoParams> {
  GetPlans(this._repository);

  final AccountRepository _repository;

  @override
  Future<Result<List<Plan>>> call(NoParams params) => _repository.getPlans();
}

class GetUsageDashboard implements UseCase<UsageDashboard, NoParams> {
  GetUsageDashboard(this._repository);

  final AccountRepository _repository;

  @override
  Future<Result<UsageDashboard>> call(NoParams params) => _repository.getUsageDashboard();
}

class GetSettings implements UseCase<UserSettings, NoParams> {
  GetSettings(this._repository);

  final AccountRepository _repository;

  @override
  Future<Result<UserSettings>> call(NoParams params) => _repository.getSettings();
}

class UpdateSettings implements UseCase<UserSettings, UpdateSettingsParams> {
  UpdateSettings(this._repository);

  final AccountRepository _repository;

  @override
  Future<Result<UserSettings>> call(UpdateSettingsParams params) =>
      _repository.updateSettings(params.previous, params.next);
}

class UpdateSettingsParams {
  const UpdateSettingsParams({required this.previous, required this.next});

  final UserSettings previous;
  final UserSettings next;
}

/// "Download my data": the account's data as JSON text.
class ExportData implements UseCase<String, NoParams> {
  ExportData(this._repository);

  final AccountRepository _repository;

  @override
  Future<Result<String>> call(NoParams params) => _repository.exportData();
}
