abstract final class AppEnvironment {
  static const configuredApiBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const testUser1Email = String.fromEnvironment('TEST_USER_1_EMAIL');
  static const testUser1Password = String.fromEnvironment(
    'TEST_USER_1_PASSWORD',
  );
  static const testUser2Email = String.fromEnvironment('TEST_USER_2_EMAIL');
  static const testUser2Password = String.fromEnvironment(
    'TEST_USER_2_PASSWORD',
  );

  static String get apiBaseUrl {
    if (configuredApiBaseUrl.isNotEmpty) return configuredApiBaseUrl;
    return 'https://tanidikla.com/api/v1';
  }

  static bool get hasDebugTestAccounts =>
      testUser1Email.isNotEmpty &&
      testUser1Password.isNotEmpty &&
      testUser2Email.isNotEmpty &&
      testUser2Password.isNotEmpty;
}
