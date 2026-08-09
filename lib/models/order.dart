class OrderItem {
  final int id;
  final int productId;
  final String nama;
  final int harga;
  final int qty;
  final String varian;

  OrderItem({
    required this.id,
    required this.productId,
    required this.nama,
    required this.harga,
    required this.qty,
    this.varian = '',
  });

  factory OrderItem.fromJson(Map<String, dynamic> j) => OrderItem(
        id: (j['id'] as num?)?.toInt() ?? 0,
        productId: (j['product_id'] as num?)?.toInt() ?? 0,
        nama: j['nama'] as String? ?? '',
        harga: (j['harga'] as num?)?.toInt() ?? 0,
        qty: (j['qty'] as num?)?.toInt() ?? 1,
        varian: j['varian'] as String? ?? '',
      );
}

class Order {
  final int id;
  final String nomor;
  final String status;
  final String statusKurir;
  final int subtotal;
  final int ongkir;
  final int diskon;
  final String voucherKode;
  final int total;
  final String metodePengiriman;
  final String metodeBayar;
  final String catatan;
  final String namaPenerima;
  final String telepon;
  final String alamat;
  final double? latitude;
  final double? longitude;
  final String? createdAt;
  final String? kurirAntarAt;
  final List<OrderItem> items;
  final int? storeId;
  final String? storeNama;
  final String? storeSlug;
  final String? storeAlamat;
  final String? storeFoto;
  final double? storeLatitude;
  final double? storeLongitude;
  final String pembeliFoto;

  Order({
    required this.id,
    required this.nomor,
    required this.status,
    this.statusKurir = '',
    required this.subtotal,
    required this.ongkir,
    required this.diskon,
    this.voucherKode = '',
    required this.total,
    this.metodePengiriman = '',
    this.metodeBayar = '',
    this.catatan = '',
    this.namaPenerima = '',
    this.telepon = '',
    this.alamat = '',
    this.latitude,
    this.longitude,
    this.createdAt,
    this.kurirAntarAt,
    this.items = const [],
    this.storeId,
    this.storeNama,
    this.storeSlug,
    this.storeAlamat,
    this.storeFoto,
    this.storeLatitude,
    this.storeLongitude,
    this.pembeliFoto = '',
  });

  factory Order.fromJson(Map<String, dynamic> j) {
    final store = j['store'] as Map<String, dynamic>?;
    return Order(
      id: (j['id'] as num?)?.toInt() ?? 0,
      nomor: j['nomor'] as String? ?? '',
      status: j['status'] as String? ?? '',
      statusKurir: j['status_kurir'] as String? ?? '',
      subtotal: (j['subtotal'] as num?)?.toInt() ?? 0,
      ongkir: (j['ongkir'] as num?)?.toInt() ?? 0,
      diskon: (j['diskon'] as num?)?.toInt() ?? 0,
      voucherKode: j['voucher_kode'] as String? ?? '',
      total: (j['total'] as num?)?.toInt() ?? 0,
      metodePengiriman: j['metode_pengiriman'] as String? ?? '',
      metodeBayar: j['metode_bayar'] as String? ?? '',
      catatan: j['catatan'] as String? ?? '',
      namaPenerima: j['nama_penerima'] as String? ?? '',
      telepon: j['telepon'] as String? ?? '',
      alamat: j['alamat'] as String? ?? '',
      latitude: (j['latitude'] as num?)?.toDouble(),
      longitude: (j['longitude'] as num?)?.toDouble(),
      createdAt: j['created_at'] as String?,
      kurirAntarAt: j['kurir_antar_at'] as String?,
      items: (j['items'] as List?)?.map((e) => OrderItem.fromJson(e)).toList() ?? [],
      storeId: (store?['id'] as num?)?.toInt(),
      storeNama: store?['nama'] as String?,
      storeSlug: store?['slug'] as String?,
      storeAlamat: store?['alamat'] as String?,
      storeFoto: store?['foto_url'] as String?,
      storeLatitude: (store?['latitude'] as num?)?.toDouble(),
      storeLongitude: (store?['longitude'] as num?)?.toDouble(),
      pembeliFoto: j['pembeli_foto'] as String? ?? '',
    );
  }

  String get statusKurirLabel {
    switch (statusKurir) {
      case 'menunggu':
        return 'Menunggu';
      case 'diambil':
        return 'Diambil';
      case 'perjalanan':
        return 'Dalam Perjalanan';
      case 'diantar':
        return 'Telah Diantar';
      default:
        return statusKurir;
    }
  }

  bool get hasRoute =>
      storeLatitude != null &&
      storeLongitude != null &&
      latitude != null &&
      longitude != null;
}
