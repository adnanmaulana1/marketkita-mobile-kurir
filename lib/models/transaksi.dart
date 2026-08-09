class Transaksi {
  final int id;
  final String tipe;
  final int jumlah;
  final String keterangan;
  final String? createdAt;

  Transaksi({
    required this.id,
    required this.tipe,
    required this.jumlah,
    required this.keterangan,
    this.createdAt,
  });

  factory Transaksi.fromJson(Map<String, dynamic> j) => Transaksi(
        id: (j['id'] as num?)?.toInt() ?? 0,
        tipe: j['tipe'] as String? ?? '',
        jumlah: (j['jumlah'] as num?)?.toInt() ?? 0,
        keterangan: j['keterangan'] as String? ?? '',
        createdAt: j['created_at'] as String?,
      );
}
