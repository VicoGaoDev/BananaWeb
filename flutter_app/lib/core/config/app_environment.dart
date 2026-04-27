class AppEnvironment {
  const AppEnvironment({
    required this.name,
    required this.apiBaseUrl,
    required this.imageBaseUrl,
    required this.enableDioLog,
  });

  final String name;
  final String apiBaseUrl;
  final String imageBaseUrl;
  final bool enableDioLog;

  factory AppEnvironment.fromEnvironment() {
    const appEnv = String.fromEnvironment('APP_ENV', defaultValue: 'dev');
    const apiBaseUrl = String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://127.0.0.1:8000',
    );
    const imageBaseUrl = String.fromEnvironment(
      'IMAGE_BASE_URL',
      defaultValue: 'http://127.0.0.1:8000',
    );
    const enableDioLog = String.fromEnvironment(
      'ENABLE_DIO_LOG',
      defaultValue: 'true',
    );

    return AppEnvironment(
      name: appEnv,
      apiBaseUrl: apiBaseUrl,
      imageBaseUrl: imageBaseUrl,
      enableDioLog: enableDioLog.toLowerCase() == 'true',
    );
  }

  bool get isProduction => name == 'prod';
}
