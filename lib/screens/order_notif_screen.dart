import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/format.dart';

class OrderNotifScreen extends StatefulWidget {
  final Map<String, dynamic> data;
  final Future<void> Function(int orderId) onAccept;
  final Future<void> Function() onDecline;
  const OrderNotifScreen({
    super.key,
    required this.data,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  State<OrderNotifScreen> createState() => _OrderNotifScreenState();
}

class _OrderNotifScreenState extends State<OrderNotifScreen> {
  bool _busy = false;

  int get _orderId => (widget.data['order_id'] as num?)?.toInt() ?? 0;

  Future<void> _accept() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onAccept(_orderId);
    } catch (_) {}
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _decline() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onDecline();
    } catch (_) {}
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final nomor = widget.data['nomor'] ?? '-';
    final toko = widget.data['toko'] ?? 'Toko';
    final tokoAlamat = widget.data['toko_alamat'] ?? '';
    final alamat = widget.data['alamat'] ?? '';
    final namaPenerima = widget.data['nama_penerima'] ?? '';
    final ongkir = (widget.data['ongkir'] as num?)?.toInt() ?? 0;
    final total = (widget.data['total'] as num?)?.toInt() ?? 0;
    final ongkirLabel = (widget.data['ongkir_label'] as String?) ?? '';
    final catatan = (widget.data['catatan'] as String?) ?? '';
    final items = (widget.data['items'] as List?) ?? <dynamic>[];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF101010), Color(0xFF1F1F1F)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'PESANAN MASUK',
                      style: TextStyle(
                        color: Color(0xFF171717),
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'No. $nomor',
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              ),
              const Spacer(),
              Expanded(
                flex: 2,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      _buildRouteCard(toko, tokoAlamat, alamat, namaPenerima),
                      const SizedBox(height: 14),
                      _buildOrderCard(items, ongkir, ongkirLabel, total, catatan),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              _buildActions(),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRouteCard(String toko, String tokoAlamat, String alamat, String penerima) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.two_wheeler, color: Color(0xFF171717)),
              const SizedBox(width: 10),
              Text(
                'Rute Pengantaran',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.grey[800]),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _locRow(Icons.storefront, Color(0xFF1E88E5), 'Ambil di Toko', toko, tokoAlamat),
          _routeLine(),
          _locRow(Icons.home_outlined, Colors.amber.shade800, 'Antar ke Penerima', penerima, alamat),
        ],
      ),
    );
  }

  Widget _locRow(IconData icon, Color color, String label, String title, String sub) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              const SizedBox(height: 2),
              Text(
                title.isEmpty ? '-' : title,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              if (sub.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(sub, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _routeLine() {
    return Padding(
      padding: const EdgeInsets.only(left: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 2,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(List items, int ongkir, String ongkirLabel, int total, String catatan) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Rincian Pesanan', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.grey[800])),
          const SizedBox(height: 12),
          if (items.isEmpty)
            Text('Order ${widget.data['nomor']}', style: const TextStyle(fontSize: 14))
          else
            ...items.map(
              (it) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${(it['qty'] as num?)?.toInt() ?? 1}x',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(it['nama'] ?? '', style: const TextStyle(fontSize: 14))),
                  ],
                ),
              ),
            ),
          if (catatan.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.sticky_note_2_outlined, size: 18, color: Colors.amber),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Catatan: $catatan',
                    style: TextStyle(color: Colors.grey[700], fontSize: 13),
                  ),
                ),
              ],
            ),
          ],
          const Divider(height: 24),
          Row(
            children: [
              Text('Ongkir', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
              if (ongkirLabel.isNotEmpty) ...[
                const SizedBox(width: 6),
                Text(ongkirLabel, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
              ],
              const Spacer(),
              Text(rupiah(ongkir), style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('Total', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
              const Spacer(),
              Text(rupiah(total), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _busy ? null : _decline,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.redAccent,
                side: const BorderSide(color: Colors.redAccent),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Tolak', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _busy ? null : _accept,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: const Color(0xFF171717),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF171717)),
                    )
                  : const Text('Ambil', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> showOrderNotif(
  BuildContext context,
  Map<String, dynamic> data, {
  required Future<void> Function(int orderId) onAccept,
  required Future<void> Function() onDecline,
}) {
  HapticFeedback.vibrate();
  return Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder(
      opaque: false,
      transitionDuration: const Duration(milliseconds: 350),
      reverseTransitionDuration: const Duration(milliseconds: 250),
      transitionsBuilder: (_, animation, _, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero).animate(curved),
          child: child,
        );
      },
      pageBuilder: (_, _, _) => OrderNotifScreen(
        data: data,
        onAccept: onAccept,
        onDecline: onDecline,
      ),
    ),
  );
}
