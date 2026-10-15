import 'dart:convert';

/// Model riwayat instalasi aplikasi XAPK
class InstallHistory {
  final String id;
  final String appName;
  final String packageName;
  final String versionName;
  final DateTime installedAt;
  final bool isSuccess;
  final String? errorMessage;

  const InstallHistory({
    required this.id,
    required this.appName,
    required this.packageName,
    required this.versionName,
    required this.installedAt,
    required this.isSuccess,
    this.errorMessage,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'appName': appName,
      'packageName': packageName,
      'versionName': versionName,
      'installedAt': installedAt.toIso8601String(),
      'isSuccess': isSuccess,
      'errorMessage': errorMessage,
    };
  }

  factory InstallHistory.fromMap(Map<String, dynamic> map) {
    return InstallHistory(
      id: map['id'] as String,
      appName: map['appName'] as String,
      packageName: map['packageName'] as String,
      versionName: map['versionName'] as String,
      installedAt: DateTime.parse(map['installedAt'] as String),
      isSuccess: map['isSuccess'] as bool? ?? true,
      errorMessage: map['errorMessage'] as String?,
    );
  }

  String toJson() => json.encode(toMap());

  factory InstallHistory.fromJson(String source) =>
      InstallHistory.fromMap(json.decode(source) as Map<String, dynamic>);
}
