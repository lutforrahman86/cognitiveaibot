import '../../domain/entities/app_user.dart';
import 'json_utils.dart';

class AppUserModel extends AppUser {
  const AppUserModel({required super.id, required super.email, super.name, super.type});

  factory AppUserModel.fromJson(Map<String, dynamic> json) => AppUserModel(
        id: readString(json['id']) ?? '',
        email: readString(json['email']) ?? '',
        name: readString(json['name']),
        type: readString(json['type']) ?? 'user',
      );
}
