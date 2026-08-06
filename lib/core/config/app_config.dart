class AppConfig {
  const AppConfig({required this.apiBaseUrl, this.bootstrapApiKey});

  final String apiBaseUrl;
  final String? bootstrapApiKey;

  factory AppConfig.fromEnvironment() {
    const base = String.fromEnvironment(
      'CURSOR_API_BASE_URL',
      defaultValue: 'https://api.cursor.com',
    );
    const key = String.fromEnvironment('CURSOR_API_KEY');
    return AppConfig(
      apiBaseUrl: base,
      bootstrapApiKey: key.isEmpty ? null : key,
    );
  }
}
