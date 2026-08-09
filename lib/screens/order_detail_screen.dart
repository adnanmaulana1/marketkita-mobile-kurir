import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../models/order.dart';
import '../utils/format.dart';
import 'delivery_tracking_screen.dart';

class OrderDetailScreen extends StatefulWidget {
  final Order order;
  final bool isMine;
  final Future<Order?> Function(String action, int orderId, {String status})? onAction;

  const OrderDetailScreen({
    super.key,
    required this.order,
    required this.isMine,
    this.onAction,
  });

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  late Order _order;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _order = widget.order;
  }

  /// Jalankan aksi (ambil/status/batal) lalu perbarui order pada layar.
  Future<void> _run(String action, {String status = ''}) async {
    if (_busy || widget.onAction == null) return;
    setState(() => _busy = true);
    try {
      final updated = await widget.onAction!(action, _order.id, status: status);
      if (updated != null && mounted) {
        setState(() => _order = updated);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }


  Color _kurirColor(String s) {
    switch (s) {
      case 'menunggu':
        return Colors.green;
      case 'diambil':
        return Colors.blue;
      case 'perjalanan':
        return Colors.orange;
      case 'diantar':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  Future<void> _call(String phone) async {
    final tel = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (tel.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: tel);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;
    final isMine = widget.isMine;
    final onAction = widget.onAction;
    final kc = _kurirColor(order.statusKurir);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          order.nomor,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: kc.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.circle, color: kc, size: 16),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            order.statusKurirLabel,
                            style: TextStyle(
                              color: kc,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        Text(
                          rupiah(_order.total),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (order.hasRoute) ...[
                    _section(context, 'Peta Rute', _mapCard()),
                    const SizedBox(height: 16),
                  ],
                  _section(context, 'Toko', _storeCard()),
                  const SizedBox(height: 16),
                  _section(context, 'Alamat Penerima', _alamatCard()),
                  const SizedBox(height: 16),
                  _section(context, 'Daftar Pesanan', _itemsCard()),
                  const SizedBox(height: 16),
                  _section(context, 'Ringkasan', _summaryCard()),
                  const SizedBox(height: 20),
                  if (order.statusKurir == 'menunggu' &&
                      !isMine &&
                      onAction != null)
                    ElevatedButton(
                      onPressed: _busy
                          ? null
                          : () async {
                              await _run('ambil');
                              if (mounted &&
                                  _order.statusKurir == 'diambil') {
                                _openTracking(this.context);
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF171717),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Ambil Order',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    )
                  else if (isMine &&
                      order.statusKurir == 'diambil' &&
                      onAction != null)
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _busy
                                ? null
                                : () async {
                                    await _run('status', status: 'perjalanan');
                                    if (mounted &&
                                        _order.statusKurir == 'perjalanan') {
                                      _openTracking(this.context);
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text(
                              'Mulai Perjalanan',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: _busy
                              ? null
                              : () => _run('batal'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 14,
                            ),
                          ),
                          child: const Text('Batal'),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            if (isMine && order.statusKurir == 'perjalanan' && onAction != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Colors.grey.shade200)),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 8,
                      offset: Offset(0, -2),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: () => _openTracking(context),
                  icon: const Icon(Icons.navigation),
                  label: const Text('Lacak di Peta (Realtime)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF171717),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _openTracking(BuildContext context) {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) => DeliveryTrackingScreen(
          order: _order,
          onDiantar: () async =>
              widget.onAction?.call('status', _order.id, status: 'diantar'),
        ),
      ),
    );
  }

  Widget _section(BuildContext context, String title, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: child,
    );
  }

  Widget _mapCard() {
    return _card(
      child: SizedBox(
        height: 220,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: _RouteMap(
            store: LatLng(_order.storeLatitude!, _order.storeLongitude!),
            customer: LatLng(_order.latitude!, _order.longitude!),
            storeFoto: _order.storeFoto,
          ),
        ),
      ),
    );
  }

  Widget _storeCard() {
    return _card(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.storefront, color: Colors.blue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _order.storeNama ?? '-',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if ((_order.storeAlamat ?? '').isNotEmpty)
                  Text(
                    _order.storeAlamat!,
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _alamatCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _order.namaPenerima,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              if (_order.telepon.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.call, color: Colors.green),
                  onPressed: () => _call(_order.telepon),
                ),
            ],
          ),
          if (_order.telepon.isNotEmpty)
            Text(
              _order.telepon,
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 16,
                color: Colors.red,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _order.alamat,
                  style: TextStyle(color: Colors.grey[800], fontSize: 13),
                ),
              ),
            ],
          ),
          if (_order.metodeBayar.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Pembayaran: ${_order.metodeBayar}',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
          if (_order.catatan.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Catatan: ${_order.catatan}',
                style: TextStyle(color: Colors.amber.shade900, fontSize: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _itemsCard() {
    return _card(
      child: Column(
        children: [
          for (final it in _order.items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          it.nama,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        if (it.varian.isNotEmpty)
                          Text(
                            it.varian,
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Text('${it.qty}x', style: TextStyle(color: Colors.grey[600])),
                  const SizedBox(width: 12),
                  Text(
                    rupiah(it.harga * it.qty),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _summaryCard() {
    return _card(
      child: Column(
        children: [
          _row('Subtotal', rupiah(_order.subtotal)),
          const SizedBox(height: 6),
          _row('Ongkir', rupiah(_order.ongkir)),
          if (_order.diskon > 0) ...[
            const SizedBox(height: 6),
            _row('Diskon', '-${rupiah(_order.diskon)}', color: Colors.green),
          ],
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              Text(
                rupiah(_order.total),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[700])),
        Text(
          value,
          style: TextStyle(fontWeight: FontWeight.w600, color: color),
        ),
      ],
    );
  }
}

/// Peta rute dengan jalur jalan sungguhan dari OSRM (fallback garis lurus).
class _RouteMap extends StatefulWidget {
  final LatLng store;
  final LatLng customer;
  final String? storeFoto;
  const _RouteMap({
    required this.store,
    required this.customer,
    this.storeFoto,
  });

  @override
  State<_RouteMap> createState() => _RouteMapState();
}

class _RouteMapState extends State<_RouteMap> {
  List<LatLng>? _route;
  LatLng? _courier;

  @override
  void initState() {
    super.initState();
    _loadRoute();
    _loadCourierPosition();
  }

  Future<void> _loadCourierPosition() async {
    try {
      var pos =
          await Geolocator.getLastKnownPosition() ??
          await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium,
              timeLimit: Duration(seconds: 12),
            ),
          );
      if (mounted) {
        setState(() => _courier = LatLng(pos.latitude, pos.longitude));
      }
    } catch (_) {}
  }

  Future<void> _loadRoute() async {
    final s = widget.store;
    final c = widget.customer;
    try {
      final uri = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${s.longitude},${s.latitude};${c.longitude},${c.latitude}'
        '?overview=full&geometries=geojson',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final coords =
          (data['routes'] as List)
                  .cast<Map<String, dynamic>>()
                  .first['geometry']['coordinates']
              as List;
      final points = coords
          .map<LatLng>(
            (e) => LatLng((e[1] as num).toDouble(), (e[0] as num).toDouble()),
          )
          .toList();
      if (points.length >= 2 && mounted) {
        setState(() => _route = points);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final points = _route ?? [widget.store, widget.customer];
    final center = LatLng(
      (widget.store.latitude + widget.customer.latitude) / 2,
      (widget.store.longitude + widget.customer.longitude) / 2,
    );
    return Stack(
      children: [
        FlutterMap(
          options: MapOptions(
            initialCenter: center,
            initialZoom: 13,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'id.marketkita.kurir',
            ),
            PolylineLayer(
              polylines: [
                Polyline(
                  points: points,
                  color: const Color(0xFF1E88E5),
                  strokeWidth: 4,
                  borderColor: Colors.white,
                  borderStrokeWidth: 2,
                ),
              ],
            ),
            MarkerLayer(
              markers: [
                if (_courier != null)
                  Marker(
                    point: _courier!,
                    width: 40,
                    height: 40,
                    child: const Icon(
                      Icons.two_wheeler,
                      color: Color(0xFF171717),
                      size: 34,
                    ),
                  ),
                Marker(
                  point: widget.store,
                  width: 40,
                  height: 40,
                  child: _StoreFotoMarker(fotoUrl: widget.storeFoto),
                ),
                Marker(
                  point: widget.customer,
                  width: 34,
                  height: 34,
                  child: const Icon(
                    Icons.location_on,
                    color: Colors.red,
                    size: 34,
                  ),
                ),
              ],
            ),
          ],
        ),
        if (_route == null)
          const Positioned(
            right: 8,
            bottom: 8,
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
      ],
    );
  }
}

/// Marker toko: foto toko melingkar, fallback ikon storefront.
class _StoreFotoMarker extends StatelessWidget {
  final String? fotoUrl;
  const _StoreFotoMarker({this.fotoUrl});

  @override
  Widget build(BuildContext context) {
    final hasFoto = fotoUrl != null && fotoUrl!.isNotEmpty;
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: hasFoto ? null : const Color(0xFF1E88E5),
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
      ),
      child: hasFoto
          ? ClipOval(
              child: Image.network(
                AppConfig.resolveUrl(fotoUrl),
                width: 38,
                height: 38,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const Icon(
                  Icons.storefront,
                  color: Color(0xFF1E88E5),
                  size: 26,
                ),
              ),
            )
          : const Icon(Icons.storefront, color: Colors.white, size: 26),
    );
  }
}
