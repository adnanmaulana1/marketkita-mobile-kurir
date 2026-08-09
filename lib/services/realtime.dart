import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../config.dart';
import 'api.dart';

class RealtimeService {
  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  Timer? _retryTimer;
  Timer? _keepAlive;
  bool _disposed = false;
  int _retry = 0;

  final _listeners = <void Function(Map<String, dynamic>)>[];
  final _connListeners = <void Function(bool connected)>[];

  bool get isConnected => _channel != null;

  void addListener(void Function(Map<String, dynamic>) cb) => _listeners.add(cb);
  void removeListener(void Function(Map<String, dynamic>) cb) => _listeners.remove(cb);

  void addConnListener(void Function(bool connected) cb) => _connListeners.add(cb);
  void removeConnListener(void Function(bool connected) cb) => _connListeners.remove(cb);

  static Uri _wsUri() {
    final base = Uri.parse(AppConfig.baseUrl);
    final scheme = base.scheme == 'https' ? 'wss' : 'ws';
    return Uri(
      scheme: scheme,
      host: base.host,
      port: base.hasPort ? base.port : (scheme == 'wss' ? 443 : 80),
      path: '/ws/kurir',
      queryParameters: {'token': Api.token ?? ''},
    );
  }

  void connect() {
    final token = Api.token;
    if (token == null || _disposed) return;
    try {
      _channel = WebSocketChannel.connect(_wsUri());
      _sub = _channel!.stream.listen(
        _onData,
        onError: (_) => _onClose(),
        onDone: _onClose,
        cancelOnError: true,
      );
      _keepAlive?.cancel();
      _keepAlive = Timer.periodic(const Duration(seconds: 25), (_) => send({'type': 'ping'}));
      _retry = 0;
      _notifyConn(true);
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _onData(dynamic raw) {
    try {
      final d = jsonDecode(raw as String) as Map<String, dynamic>;
      if (d['type'] == 'pong') return;
      for (final cb in List.of(_listeners)) {
        cb(d);
      }
    } catch (_) {}
  }

  void _onClose() {
    _closeChannel();
    _notifyConn(false);
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    _retryTimer?.cancel();
    final delay = _retry == 0 ? 1000 : (_retry > 5 ? 15000 : _retry * 2000);
    _retry++;
    _retryTimer = Timer(Duration(milliseconds: delay), connect);
  }

  void _closeChannel() {
    _sub?.cancel();
    _sub = null;
    _keepAlive?.cancel();
    _keepAlive = null;
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
  }

  void send(Map<String, dynamic> data) {
    try {
      _channel?.sink.add(jsonEncode(data));
    } catch (_) {}
  }

  void sendLocation(List<int> orderIds, double lat, double lng) {
    send({'type': 'kurir_location', 'order_ids': orderIds, 'lat': lat, 'lng': lng});
  }

  void _notifyConn(bool connected) {
    for (final cb in List.of(_connListeners)) {
      cb(connected);
    }
  }

  void dispose() {
    _disposed = true;
    _retryTimer?.cancel();
    _keepAlive?.cancel();
    _closeChannel();
    _listeners.clear();
    _connListeners.clear();
  }
}
