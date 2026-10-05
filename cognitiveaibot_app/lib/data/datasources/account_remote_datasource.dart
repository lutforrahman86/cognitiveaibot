import '../../core/network/api_client.dart';
import '../../domain/entities/account.dart';
import '../models/account_models.dart';
import '../models/json_utils.dart';

abstract interface class AccountRemoteDataSource {
  Future<BillingInfo> getBilling();
  Future<List<Plan>> getPlans();
  Future<UsageDashboard> getUsageDashboard();
  Future<UserSettings> getSettings();
  /// Sends only the fields that differ between [previous] and [next].
  Future<UserSettings> updateSettings(UserSettings previous, UserSettings next);
}

class AccountRemoteDataSourceImpl implements AccountRemoteDataSource {
  AccountRemoteDataSourceImpl(this._api);

  final ApiClient _api;

  @override
  Future<BillingInfo> getBilling() async => billingFromJson(readMap(await _api.get('/api/billing')));

  @override
  Future<List<Plan>> getPlans() async =>
      readList(readMap(await _api.get('/api/plans', auth: false))['plans']).map(planFromJson).toList();

  @override
  Future<UsageDashboard> getUsageDashboard() async =>
      usageDashboardFromJson(readMap(await _api.get('/api/usage/summary', query: {'days': '30'})));

  @override
  Future<UserSettings> getSettings() async =>
      settingsFromJson(readMap(readMap(await _api.get('/api/settings'))['settings']));

  @override
  Future<UserSettings> updateSettings(UserSettings previous, UserSettings next) async {
    final patch = settingsPatch(previous, next);
    if (patch.isEmpty) return next;
    return settingsFromJson(readMap(readMap(await _api.patch('/api/settings', body: patch))['settings']));
  }
}
