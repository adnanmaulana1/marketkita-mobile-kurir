class User {
  final int id;
  final String nama;
  final String email;
  final String telepon;
  final String role;
  final String kendaraan;
  final int saldo;
  final String fotoProfil;
  final bool isVerified;

  User({
    required this.id,
    required this.nama,
    required this.email,
    this.telepon = '',
    this.role = 'kurir',
    this.kendaraan = '',
    this.saldo = 0,
    this.fotoProfil = '',
    this.isVerified = false,
  });

  factory User.fromJson(Map<String, dynamic> j) => User(
        id: (j['id'] as num?)?.toInt() ?? 0,
        nama: j['nama'] as String? ?? '',
        email: j['email'] as String? ?? '',
        telepon: j['telepon'] as String? ?? '',
        role: j['role'] as String? ?? 'kurir',
        kendaraan: j['kendaraan'] as String? ?? '',
        saldo: (j['saldo'] as num?)?.toInt() ?? 0,
        fotoProfil: j['foto_profil'] as String? ?? '',
        isVerified: j['is_verified'] as bool? ?? false,
      );
}
