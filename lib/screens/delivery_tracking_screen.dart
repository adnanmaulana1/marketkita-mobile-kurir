import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../models/order.dart';

/// Peta pelacakan real-time saat kurir mengantar pesanan.
/// Menampilkan rute jalan, posisi GPS kurir yang bergerak live, jarak & ETA.
class DeliveryTrackingScreen extends StatefulWidget {
  final Order order;
  final Future<void> Function()? onDiantar;

  const DeliveryTrackingScreen({super.key, required this.order, this.onDiantar});

  @override
  State<DeliveryTrackingScreen> createState() => _DeliveryTrackingScreenState();
}

class _DeliveryTrackingScreenState extends State<DeliveryTrackingScreen>
    with SingleTickerProviderStateMixin {
  final _mapController = MapController();
  LatLng? _current;
  double? _heading;
  List<LatLng>? _route;
  StreamSubscription<Position>? _posSub;
  Timer? _rerouteTimer;
  Timer? _refreshTimer;
  bool _loadingRoute = true;
  bool _submitting = false;
  bool _fittedOnce = false; // kamera hanya di-fit sekali saat GPS pertama siap
  bool _gpsReady = false;
  bool _follow = false; // mode ikut posisi kurir (dipicu tombol kanan atas)
  LatLng? _lastFiltered;
  // Animasi marker kurir: interpolasi posisi lama -> baru agar tidak meloncat.
  late final AnimationController _markerAnim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  LatLng _animFrom = LatLng(0, 0);
  LatLng _animTo = LatLng(0, 0);
  LatLng? _displayPoint;
  int _checkpoint = 0; // 0=mulai, 1=sampai toko, 2=sampai pembeli
  double _routeDistanceM = 0; // jarak rute (m) dari OSRM
  int _routeDurationSec = 0; // durasi rute (detik) dari OSRM

  static const double _minMoveMeters = 12; // abaikan lompatan GPS di bawah ini
  static const double _maxAccuracyMeters = 40; // abaikan fix dengan akurasi buruk

  LatLng get _customer =>
      LatLng(widget.order.latitude!, widget.order.longitude!);
  LatLng get _store =>
      LatLng(widget.order.storeLatitude!, widget.order.storeLongitude!);

  @override
  void initState() {
    super.initState();
    _markerAnim.addListener(_onMarkerTick);
    _loadRoute();
    _startGps();
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _rerouteTimer?.cancel();
    _refreshTimer?.cancel();
    _markerAnim.dispose();
    _mapController.dispose();
    super.dispose();
  }

  /// Satu tick animasi marker: interpolasi posisi kurir + ikuti kamera bila follow.
  void _onMarkerTick() {
    if (!mounted) return;
    final t = Curves.easeInOut.transform(_markerAnim.value);
    final lat = _animFrom.latitude + (_animTo.latitude - _animFrom.latitude) * t;
    final lng = _animFrom.longitude + (_animTo.longitude - _animFrom.longitude) * t;
    _displayPoint = LatLng(lat, lng);
    setState(() {});
    if (_follow && _current != null) {
      _mapController.move(_displayPoint!, _mapController.camera.zoom.clamp(14.5, 17));
    }
  }

  /// Mulai animasi marker dari posisi lama ke posisi baru.
  void _animateTo(LatLng p) {
    final from = _displayPoint ?? _current ?? p;
    _animFrom = from;
    _animTo = p;
    _markerAnim.forward(from: 0);
  }

  /// Rute dengan 3 titik: posisi kurir sekarang -> toko -> pembeli.
  Future<void> _loadRoute() async {
    final s = _store;
    final c = _customer;
    final start = _current ?? s; // fallback: mulai dari toko bila GPS belum siap
    try {
      final uri = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${start.longitude},${start.latitude};${s.longitude},${s.latitude};${c.longitude},${c.latitude}'
        '?overview=full&geometries=geojson',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 12));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final route = (data['routes'] as List).cast<Map<String, dynamic>>().first;
        final coords = (route['geometry']['coordinates'] as List);
        final points = coords
            .map<LatLng>((e) => LatLng((e[1] as num).toDouble(), (e[0] as num).toDouble()))
            .toList();
        if (points.length >= 2 && mounted) {
          setState(() {
            _route = points;
            _routeDistanceM = (route['distance'] as num?)?.toDouble() ?? 0;
            _routeDurationSec = (route['duration'] as num?)?.toInt() ?? 0;
          });
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingRoute = false);
    // Fit kamera hanya sekali (saat GPS pertama siap), tidak pada reroute berkala.
    if (_gpsReady && mounted && !_fittedOnce) {
      _fittedOnce = true;
      _fitToRoute();
    }
  }

  /// Animasi zoom out agar seluruh rute (posisi kurir saat ini -> pembeli) masuk layar.
  void _fitToRoute() {
    final c = _current;
    if (c == null) return;
    final bounds = LatLngBounds.fromPoints([c, _customer]);
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(70),
        maxZoom: 17,
      ),
    );
  }

  Future<void> _startGps() async {
    if (!await _ensurePermission()) return;
    final stream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
        timeLimit: Duration(minutes: 120),
      ),
    );
    _posSub = stream.listen((pos) {
      if (!mounted) return;
      // Abaikan fix dengan akurasi buruk
      if (pos.accuracy > _maxAccuracyMeters) return;

      final p = LatLng(pos.latitude, pos.longitude);
      // Heading selalu di-update (arah gerak/kompas), terlepas dari ambang gerak.
      if (pos.heading.isFinite && pos.heading != 0) {
        setState(() => _heading = pos.heading);
      } else if (_current != null) {
        final h = _resolveHeading(_current!, p, null);
        setState(() => _heading = h);
      }

      // Smoothing: hanya pindahkan marker jika benar-benar bergerak > ambang (kurangi noise GPS)
      if (_lastFiltered != null) {
        final moved = const Distance().as(LengthUnit.Meter, _lastFiltered!, p);
        if (moved < _minMoveMeters) return;
      }

      _applyPosition(pos, p);
    }, onError: (_) {});
    // Seed posisi awal: stream hanya memancarkan saat kurir bergerak, sehingga
    // marker kurir butuh fix inisial (getLastKnownPosition -> getCurrentPosition).
    await _seedInitialPosition();
    // Refresh posisi kurir tiap 5 detik (hanya marker, tidak menggeser kamera/zoom).
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) => _refreshPosition());
  }

  /// Update posisi marker kurir secara berkala tanpa mengubah posisi/zoom peta.
  Future<void> _refreshPosition() async {
    if (!mounted || !_gpsReady) return;
    try {
      if (!await _ensurePermission()) return;
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 4),
        ),
      );
      if (!mounted) return;
      if (pos.accuracy > _maxAccuracyMeters) return;
      final prev = _current;
      final p = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _current = p;
        _heading = _resolveHeading(prev ?? p, p, pos.heading);
      });
      _animateTo(p);
    } catch (_) {}
  }

  /// Hitung arah (bearing) dari posisi lama ke posisi baru; fallback ke heading
  /// perangkat bila tersedia.
  double _resolveHeading(LatLng from, LatLng to, double? deviceHeading) {
    if (deviceHeading != null && deviceHeading.isFinite && deviceHeading != 0) {
      return deviceHeading;
    }
    if (from == to) return _heading ?? 0;
    try {
      return const Distance().bearing(from, to);
    } catch (_) {
      return _heading ?? 0;
    }
  }

  void _applyPosition(Position pos, LatLng p) {
    final prev = _current;
    setState(() {
      _lastFiltered = p;
      _current = p;
      _heading = _resolveHeading(prev ?? p, p, pos.heading);
    });
    _animateTo(p);
    if (!_gpsReady) {
      // GPS pertama kali diperoleh: mulai rute dari lokasi kurir & jadwalkan re-route
      _gpsReady = true;
      _fittedOnce = true;
      _fitToRoute();
      _loadRoute();
      _rerouteTimer?.cancel();
      _rerouteTimer = Timer.periodic(const Duration(seconds: 20), (_) => _loadRoute());
    }
  }

  Future<void> _seedInitialPosition() async {
    if (!mounted) return;
    try {
      final pos = await Geolocator.getLastKnownPosition() ??
          await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 12),
            ),
          );
      if (!mounted) return;
      // Tampilkan marker segera meski akurasi fix awal belum ideal; stream
      // bergerak tetap menapis akurasi buruk untuk smoothing.
      _applyPosition(pos, LatLng(pos.latitude, pos.longitude));
    } catch (_) {}
  }

  Future<bool> _ensurePermission() async {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    return perm == LocationPermission.whileInUse || perm == LocationPermission.always;
  }

  double _distanceTo(LatLng target) {
    if (_current == null) return 0;
    return const Distance().as(LengthUnit.Meter, _current!, target);
  }

  /// Stop aktif berikutnya berdasarkan checkpoint manual: toko -> pembeli.
  LatLng get _activeStop => _checkpoint < 1 ? _store : _customer;

  String get _activeStopLabel {
    if (_checkpoint >= 2) return 'Pesanan Telah Diantar';
    return _checkpoint < 1 ? 'Menuju Toko' : 'Menuju Penerima';
  }

  String get _checkpointLabel {
    if (_checkpoint >= 2) return 'Selesai';
    return _checkpoint < 1 ? 'Checkpoint: Sampai di Toko' : 'Checkpoint: Sampai di Penerima';
  }

  bool get _checkpointDone => _checkpoint >= 2;

  /// Tombol checkpoint: maju ke stop berikutnya (toko -> pembeli).
  void _checkpointTap() {
    if (_checkpoint >= 2) return;
    setState(() => _checkpoint++);
  }

  double get _activeDistance => _distanceTo(_activeStop);

  int _etaMinutes() {
    if (_routeDurationSec > 0) return (_routeDurationSec / 60).ceil();
    // Fallback garis lurus: asumsi 30 km/jam
    return (_activeDistance / 500).ceil();
  }

  Future<void> _markDiantar() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      await widget.onDiantar?.call();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final center = _current ??
        LatLng(
          (widget.order.storeLatitude! + widget.order.latitude!) / 2,
          (widget.order.storeLongitude! + widget.order.longitude!) / 2,
        );

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.order.nomor, style: const TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            tooltip: _follow ? 'Matikan mode ikut posisi' : 'Aktifkan mode ikut posisi',
            icon: Icon(_follow ? Icons.my_location : Icons.location_searching),
            onPressed: () {
              setState(() => _follow = !_follow);
              if (_follow && _current != null) {
                _mapController.move(_current!, _mapController.camera.zoom.clamp(14.5, 17));
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: 15,
              interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
              onPositionChanged: (pos, hasGesture) {
                if (hasGesture && _follow) {
                  _follow = false;
                  if (mounted) setState(() {});
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'id.marketkita.kurir',
              ),
              if (_route != null)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _route!,
                      color: const Color(0xFF1E88E5),
                      strokeWidth: 4,
                      borderColor: Colors.white,
                      borderStrokeWidth: 2,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _store,
                    width: 42,
                    height: 42,
                    child: _StoreMarker(fotoUrl: widget.order.storeFoto),
                  ),
                  Marker(
                    point: _customer,
                    width: 42,
                    height: 42,
                    child: _PhotoMarker(fotoUrl: widget.order.pembeliFoto, color: Colors.red),
                  ),
                  if (_displayPoint != null)
                    Marker(
                      point: _displayPoint!,
                      width: 44,
                      height: 44,
                      child: _CourierDot(heading: _heading),
                    ),
                ],
              ),
            ],
          ),
          if (_loadingRoute)
            const Positioned(
              top: 12,
              right: 12,
              child: Material(
                color: Colors.white,
                shape: CircleBorder(),
                elevation: 3,
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                ),
              ),
            ),
          Align(
            alignment: Alignment.bottomCenter,
            child: _bottomPanel(),
          ),
        ],
      ),
    );
  }

  Widget _bottomPanel() {
    final dist = _routeDistanceM > 0 ? _routeDistanceM : _activeDistance;
    final eta = _etaMinutes();
    final gpsReady = _current != null && dist > 0;
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.delivery_dining, color: _current == null ? Colors.orange : Colors.green),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _activeStopLabel,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                ),
                if (gpsReady)
                  Text(
                    '$eta min',
                    style: TextStyle(fontWeight: FontWeight.w800, color: Colors.green.shade700, fontSize: 15),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _stat(Icons.straighten, gpsReady ? _fmtDistance(dist) : 'Mencari GPS...'),
                const SizedBox(width: 12),
                _stat(Icons.schedule, gpsReady ? '± $eta menit' : '...'),
              ],
            ),
            const SizedBox(height: 12),
            // Indikator progres 3 titik: Lokasi -> Toko -> Penerima
            _stopProgress(),
            const SizedBox(height: 14),
            if (!_checkpointDone)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _checkpointTap,
                  icon: const Icon(Icons.flag),
                  label: Text(_checkpointLabel),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange.shade800,
                    side: BorderSide(color: Colors.orange.shade800),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                ),
              ),
            if (!_checkpointDone) const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: (_submitting || !_checkpointDone) ? null : _markDiantar,
                icon: const Icon(Icons.check_circle_outline),
                label: Text(
                  _checkpointDone
                      ? (_submitting ? 'Menyimpan...' : 'Tandai Sudah Diantar')
                      : 'Selesaikan Pengantaran',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
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

  Widget _stopProgress() {
    return Row(
      children: [
        _stopChip(1, 'Lokasi', _checkpoint >= 1),
        Expanded(
          child: Container(
            height: 2,
            color: _checkpoint >= 1 ? Colors.green : Colors.grey.shade300,
          ),
        ),
        _stopChip(2, 'Toko', _checkpoint >= 2),
        Expanded(
          child: Container(
            height: 2,
            color: _checkpoint >= 2 ? Colors.green : Colors.grey.shade300,
          ),
        ),
        _stopChip(3, 'Penerima', _checkpoint >= 2),
      ],
    );
  }

  Widget _stopChip(int number, String label, bool done) {
    final color = done ? Colors.green : (_checkpoint == number - 1 ? Colors.orange : Colors.grey);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Center(
            child: done
                ? const Icon(Icons.check, color: Colors.white, size: 14)
                : Text('$number', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }

  Widget _stat(IconData icon, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            Icon(icon, size: 18, color: Colors.grey[700]),
            const SizedBox(width: 6),
            Expanded(
              child: Text(value,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  String _fmtDistance(double meters) {
    if (meters >= 1000) return '${(meters / 1000).toStringAsFixed(1)} km';
    return '${meters.round()} m';
  }
}

/// Marker foto (pembeli): foto profil melingkar, fallback ikon person.
class _PhotoMarker extends StatelessWidget {
  final String? fotoUrl;
  final Color color;
  const _PhotoMarker({this.fotoUrl, required this.color});

  @override
  Widget build(BuildContext context) {
    final hasFoto = fotoUrl != null && fotoUrl!.isNotEmpty;
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: hasFoto ? null : color,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
      ),
      child: hasFoto
          ? ClipOval(
              child: Image.network(
                fotoUrl!,
                width: 40,
                height: 40,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    Icon(Icons.person, color: Colors.white, size: 28),
              ),
            )
          : const Icon(Icons.person, color: Colors.white, size: 28),
    );
  }
}

/// Marker kurir: dot hitam dengan panah arah yang berputar mengikuti heading.
class _CourierDot extends StatelessWidget {
  final double? heading;
  const _CourierDot({this.heading});

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFF171717);
    final h = (heading != null && heading!.isFinite) ? heading! : 0.0;
    final angle = h * 3.141592653589793 / 180;
    return Transform.rotate(
      angle: angle,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: -6,
            child: Icon(Icons.navigation, color: color, size: 24),
          ),
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
            ),
          ),
        ],
      ),
    );
  }
}

/// Marker toko: foto toko melingkar, fallback ikon storefront.
class _StoreMarker extends StatelessWidget {
  final String? fotoUrl;
  const _StoreMarker({this.fotoUrl});

  @override
  Widget build(BuildContext context) {
    final hasFoto = fotoUrl != null && fotoUrl!.isNotEmpty;
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: hasFoto ? null : const Color(0xFF1E88E5),
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
      ),
      child: hasFoto
          ? ClipOval(
              child: Image.network(
                fotoUrl!,
                width: 40,
                height: 40,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    const Icon(Icons.storefront, color: Color(0xFF1E88E5), size: 28),
              ),
            )
          : const Icon(Icons.storefront, color: Colors.white, size: 28),
    );
  }
}
