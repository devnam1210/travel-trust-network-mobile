class AppConfig {
  AppConfig._();

  // Android Emulator reaches the development machine through 10.0.2.2.
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8080/api/v1',
  );

  static const googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue:
        '506895478574-shd0aimlfm88l55dcp5c8q4silmfed6p.apps.googleusercontent.com',
  );

  static const testPlaceId = String.fromEnvironment('TEST_PLACE_ID');
}
