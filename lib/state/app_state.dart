import 'package:flutter/foundation.dart';

import '../models/user.dart';
import '../services/api.dart';

class AppState extends ChangeNotifier {
  User? _user;
  bool _loading = false;

  User? get user => _user;
  bool get loading => _loading;
  bool get isLoggedIn => _user != null;

  Future<void> load() async {
    await Api.init();
    final token = Api.token;
    if (token == null) {
      notifyListeners();
      return;
    }
    _loading = true;
    notifyListeners();
    try {
      _user = await Api.me();
    } catch (_) {
      await Api.clearToken();
      _user = null;
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    _loading = true;
    notifyListeners();
    try {
      _user = await Api.login(email, password);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> register({
    required String nama,
    required String email,
    required String telepon,
    required String password,
    required String kendaraan,
  }) async {
    _loading = true;
    notifyListeners();
    try {
      _user = await Api.register(
        nama: nama,
        email: email,
        telepon: telepon,
        password: password,
        kendaraan: kendaraan,
      );
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await Api.logout();
    _user = null;
    notifyListeners();
  }

  /// Update profil (nama, telepon, kendaraan) dan opsional ganti kata sandi.
  Future<void> updateProfil({
    required String nama,
    required String telepon,
    required String kendaraan,
    String passwordLama = '',
    String passwordBaru = '',
    String konfirmasi = '',
  }) async {
    final res = await Api.post('/api/auth/me', {
      'nama': nama,
      'telepon': telepon,
      'kendaraan': kendaraan,
      if (passwordBaru.isNotEmpty) 'password_lama': passwordLama,
      if (passwordBaru.isNotEmpty) 'password_baru': passwordBaru,
      if (passwordBaru.isNotEmpty) 'konfirmasi': konfirmasi,
    });
    _user = User.fromJson(res['user'] as Map<String, dynamic>);
    notifyListeners();
  }

  /// Upload foto profil, lalu perbarui user dari respons server.
  Future<void> uploadFoto(String path) async {
    final res = await Api.postMultipart('/api/auth/foto', {}, 'file', path);
    final url = res['url'] as String?;
    if (url != null && _user != null) {
      _user = User(
        id: _user!.id,
        nama: _user!.nama,
        email: _user!.email,
        telepon: _user!.telepon,
        role: _user!.role,
        kendaraan: _user!.kendaraan,
        saldo: _user!.saldo,
        fotoProfil: url,
        isVerified: _user!.isVerified,
      );
      notifyListeners();
    }
  }

  bool isKurir() => _user?.role == 'kurir';
}
