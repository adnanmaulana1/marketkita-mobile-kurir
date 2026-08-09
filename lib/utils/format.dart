import 'package:intl/intl.dart';

String rupiah(int value) {
  return 'Rp${NumberFormat.decimalPattern('id_ID').format(value)}';
}

String formatTanggal(String? iso) {
  if (iso == null || iso.isEmpty) return '-';
  try {
    final dt = DateTime.parse(iso).toLocal();
    return DateFormat('d MMM yyyy, HH:mm', 'id_ID').format(dt);
  } catch (_) {
    return iso;
  }
}

String kendaraanLabel(String kendaraan) {
  switch (kendaraan) {
    case 'motor':
      return 'Motor';
    case 'mobil':
      return 'Mobil';
    case 'pickup':
      return 'Pickup';
    default:
      return kendaraan.isEmpty ? 'Kurir' : kendaraan;
  }
}
