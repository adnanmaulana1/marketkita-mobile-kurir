class AppConfig {
  static const String _defined = String.fromEnvironment('API_BASE_URL');

  static String get baseUrl => _defined.isNotEmpty ? _defined : 'http://toko.adnanmaulana.my.id';

  /// Ubah path relatif server (mis. /static/...) menjadi URL absolut.
  static String resolveUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    if (path.startsWith('/')) return '$baseUrl$path';
    return '$baseUrl/$path';
  }
}
