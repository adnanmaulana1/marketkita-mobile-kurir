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

  bool isKurir() => _user?.role == 'kurir';
}
