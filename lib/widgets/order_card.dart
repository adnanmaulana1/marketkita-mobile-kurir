import 'package:flutter/material.dart';

import '../models/order.dart';
import '../utils/format.dart';

class OrderCard extends StatelessWidget {
  final Order order;
  final bool isMine;
  final void Function(String action, int orderId, {String status})? onAction;
  final VoidCallback? onTap;

  const OrderCard({
    super.key,
    required this.order,
    required this.isMine,
    this.onAction,
    this.onTap,
  });

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

  @override
  Widget build(BuildContext context) {
    final kc = _kurirColor(order.statusKurir);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(order.nomor, style: const TextStyle(fontWeight: FontWeight.w800)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: kc.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                  child: Text(order.statusKurirLabel.toUpperCase(),
                      style: TextStyle(fontSize: 11, color: kc, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.storefront, size: 16, color: Colors.grey),
                const SizedBox(width: 6),
                Expanded(child: Text(order.storeNama ?? '-', style: const TextStyle(fontWeight: FontWeight.w600))),
              ],
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on_outlined, size: 16, color: Colors.grey),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${order.namaPenerima} — ${order.alamat}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey[700], fontSize: 13),
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            for (final it in order.items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Expanded(child: Text(it.nama, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13))),
                    Text('${it.qty}x', style: TextStyle(color: Colors.grey[500])),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total ${rupiah(order.total)}', style: const TextStyle(fontWeight: FontWeight.w800)),
                Text('Ongkir ${rupiah(order.ongkir)}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
            const SizedBox(height: 12),
            if (order.statusKurir == 'menunggu' && !isMine && onAction != null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => onAction!('ambil', order.id),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF171717),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Ambil Order'),
                ),
              )
            else if (isMine && order.statusKurir == 'diambil' && onAction != null)
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => onAction!('status', order.id, status: 'perjalanan'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                      child: const Text('Mulai Perjalanan'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () => onAction!('batal', order.id),
                    child: const Text('Batal'),
                  ),
                ],
              )
            else if (isMine && order.statusKurir == 'perjalanan' && onAction != null)
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => onAction!('status', order.id, status: 'diantar'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                      child: const Text('Tandai Sudah Diantar'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () => onAction!('batal', order.id),
                    child: const Text('Batal'),
                  ),
                ],
              )
            else if (order.statusKurir == 'diantar')
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(10)),
                child: Text('Selesai diantar',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.teal.shade700, fontWeight: FontWeight.w700)),
              ),
          ],
        ),
      ),
    );
  }
}
