class ApiKeyInfo {
  const ApiKeyInfo({
    required this.apiKeyName,
    required this.createdAt,
    this.userEmail,
    this.userId,
  });

  final String apiKeyName;
  final String? userEmail;
  final int? userId;
  final DateTime createdAt;

  factory ApiKeyInfo.fromJson(Map<String, dynamic> json) {
    return ApiKeyInfo(
      apiKeyName: json['apiKeyName'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      userEmail: json['userEmail'] as String?,
      userId: _readInt(json['userId']),
    );
  }

  static int? _readInt(Object? value) {
    return switch (value) {
      int id => id,
      num id => id.toInt(),
      String id => int.tryParse(id),
      _ => null,
    };
  }
}
