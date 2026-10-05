/// Lenient readers for the backend's JSON: Postgres DECIMAL columns arrive
/// as strings, and optional fields may be missing or null.
double? readDouble(Object? v) => switch (v) {
      num n => n.toDouble(),
      String s => double.tryParse(s),
      _ => null,
    };

int? readInt(Object? v) => switch (v) {
      int n => n,
      num n => n.round(),
      String s => int.tryParse(s) ?? double.tryParse(s)?.round(),
      _ => null,
    };

String? readString(Object? v) => v is String ? v : null;

bool readBool(Object? v, {bool fallback = false}) => v is bool ? v : fallback;

DateTime? readDate(Object? v) => v is String ? DateTime.tryParse(v)?.toLocal() : null;

Map<String, dynamic> readMap(Object? v) => v is Map<String, dynamic> ? v : const {};

List<Map<String, dynamic>> readList(Object? v) =>
    v is List ? v.whereType<Map<String, dynamic>>().toList() : const [];
