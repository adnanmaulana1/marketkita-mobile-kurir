class AppConfig {
  static const String _defined = String.fromEnvironment('API_BASE_URL');

  static String get baseUrl => _defined.isNotEmpty ? _defined : 'http://toko.adnanmaulana.my.id';
}
