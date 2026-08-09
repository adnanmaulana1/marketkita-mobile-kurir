import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../models/order.dart';
import '../models/transaksi.dart';
import '../services/kurir_api.dart';
import '../services/realtime.dart';

class KurirState extends ChangeNotifier {
  final RealtimeService realtime = RealtimeService();

  KurirDashboard? dashboard;
  bool loading = true;
  String? error;
  bool connected = false;

  void Function(String title, String msg)? onNotify;
  void Function(Map<String, dynamic> data)? onOrderBaru;

  Timer? _gpsTimer;
  List<int> _activeOrderIds = [];
  bool _requestedGpsPerm = false;

  Future<void> init() async {
    realtime.addListener(_onRealtime);
    realtime.addConnListener(_onConn);
    realtime.connect();
    await refresh();
  }

  void _onConn(bool c) {
    connected = c;
    notifyListeners();
    _updateGps();
  }

  void _onRealtime(Map<String, dynamic> d) {
    final type = d['type'];
    if (type == 'kurir_order_baru') {
      onOrderBaru?.call(d);
      onNotify?.call(
        'Order Baru!',
        'Order ${d['nomor'] ?? ''} tersedia dari ${d['toko'] ?? 'Toko'}',
      );
      refresh();
    } else if (type == 'kurir_status') {
      final msg = (d['msg'] as String?) ?? 'Status pesanan diperbarui.';
      onNotify?.call('Perbaruan Status', msg);
      refresh();
    }
  }

  Future<void> refresh() async {
    try {
      dashboard = await KurirApi.dashboard();
      error = null;
      _updateGps();
    } catch (e) {
      error = '$e';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void _updateGps() {
    // Hanya lacak GPS saat ada order yang benar-benar dalam perjalanan.
    final traveling = (dashboard?.saya ?? [])
        .where((o) => o.statusKurir == 'perjalanan')
        .toList();
    _activeOrderIds = traveling.map((o) => o.id).toList();
    if (_activeOrderIds.isEmpty || !connected) {
      _gpsTimer?.cancel();
      _gpsTimer = null;
      return;
    }
    _gpsTimer ??= Timer.periodic(const Duration(seconds: 10), (_) => _sendGps());
    _sendGps();
  }

  Future<void> _sendGps() async {
    if (!connected || _activeOrderIds.isEmpty) return;
    try {
      if (!await _ensurePermission()) return;
      final pos = await _currentPosition();
      if (pos == null) return;
      realtime.sendLocation(_activeOrderIds, pos.latitude, pos.longitude);
    } catch (_) {}
  }

  Future<Position?> _currentPosition() async {
    // Pakai fix terakhir yang tersedia dulu (instan, hemat baterai).
    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) return last;
    } catch (_) {}

    // Jika tidak ada, minta fix baru dengan waktu lebih longgar (GPS lambat di dalam ruangan).
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 12),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  Future<bool> _ensurePermission() async {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied && !_requestedGpsPerm) {
      _requestedGpsPerm = true;
      perm = await Geolocator.requestPermission();
    }
    return perm == LocationPermission.whileInUse || perm == LocationPermission.always;
  }

  Future<Order> ambil(int orderId) async {
    final order = await KurirApi.ambil(orderId);
    await refresh();
    return order;
  }

  Future<Order> ubahStatus(int orderId, String status) async {
    final order = await KurirApi.ubahStatus(orderId, status);
    await refresh();
    return order;
  }

  Future<Order> batal(int orderId) async {
    final order = await KurirApi.batal(orderId);
    await refresh();
    return order;
  }

  Future<({int saldo, int pendapatan, List<Transaksi> transaksi})> saldo() async {
    final s = await KurirApi.saldo();
    return (
      saldo: s.saldo,
      pendapatan: s.pendapatan,
      transaksi: s.transaksi,
    );
  }

  Future<int> tarik({
    required int nominal,
    required String metode,
    required String nomorAkun,
    required String atasNama,
  }) async {
    final saldo = await KurirApi.tarik(
      nominal: nominal,
      metode: metode,
      nomorAkun: nomorAkun,
      atasNama: atasNama,
    );
    await refresh();
    return saldo;
  }

  @override
  void dispose() {
    _gpsTimer?.cancel();
    realtime.dispose();
    super.dispose();
  }
}
