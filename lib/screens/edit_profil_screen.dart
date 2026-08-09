import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../services/api.dart';
import '../state/app_state.dart';

class EditProfilScreen extends StatefulWidget {
  const EditProfilScreen({super.key});

  @override
  State<EditProfilScreen> createState() => _EditProfilScreenState();
}

class _EditProfilScreenState extends State<EditProfilScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nama;
  late final TextEditingController _telepon;
  final _passwordLama = TextEditingController();
  final _passwordBaru = TextEditingController();
  final _konfirmasi = TextEditingController();
  late String _kendaraan;
  File? _fotoBaru;
  bool _obscureLama = true;
  bool _obscureBaru = true;
  bool _obscureKonfirmasi = true;
  bool _submitting = false;
  bool _uploadingFoto = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final u = context.read<AppState>().user;
    _nama = TextEditingController(text: u?.nama ?? '');
    _telepon = TextEditingController(text: u?.telepon ?? '');
    _kendaraan = u?.kendaraan ?? 'motor';
  }

  @override
  void dispose() {
    _nama.dispose();
    _telepon.dispose();
    _passwordLama.dispose();
    _passwordBaru.dispose();
    _konfirmasi.dispose();
    super.dispose();
  }

  Future<void> _pilihFoto(ImageSource source) async {
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (file == null) return;
      if (!mounted) return;
      setState(() => _fotoBaru = File(file.path));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal mengambil gambar.')),
        );
      }
    }
  }

  void _pilihSumberFoto() {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Galeri'),
              onTap: () {
                Navigator.pop(ctx);
                _pilihFoto(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Kamera'),
              onTap: () {
                Navigator.pop(ctx);
                _pilihFoto(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _simpan() async {
    if (!_formKey.currentState!.validate()) return;
    final pwBaru = _passwordBaru.text.trim();
    if (pwBaru.isNotEmpty) {
      if (pwBaru.length < 6) {
        _showError('Kata sandi baru minimal 6 karakter.');
        return;
      }
      if (pwBaru != _konfirmasi.text.trim()) {
        _showError('Konfirmasi kata sandi tidak cocok.');
        return;
      }
    }
    setState(() {
      _error = null;
      _submitting = true;
    });
    final app = context.read<AppState>();
    try {
      if (_fotoBaru != null) {
        setState(() => _uploadingFoto = true);
        await app.uploadFoto(_fotoBaru!.path);
        setState(() => _uploadingFoto = false);
      }
      await app.updateProfil(
        nama: _nama.text.trim(),
        telepon: _telepon.text.trim(),
        kendaraan: _kendaraan,
        passwordLama: _passwordLama.text,
        passwordBaru: pwBaru,
        konfirmasi: _konfirmasi.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil berhasil diperbarui.')),
      );
    } on ApiException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError('Terjadi kesalahan. Periksa koneksi ke server.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    setState(() => _error = msg);
  }

  @override
  Widget build(BuildContext context) {
    final u = context.watch<AppState>().user;
    final fotoUrl = u?.fotoProfil;
    final showFoto = fotoUrl != null && fotoUrl.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profil')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: GestureDetector(
                    onTap: _uploadingFoto ? null : _pilihSumberFoto,
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: 48,
                          backgroundColor: Colors.grey.shade200,
                          backgroundImage: _fotoBaru != null
                              ? FileImage(_fotoBaru!)
                              : (showFoto
                                    ? NetworkImage(AppConfig.resolveUrl(fotoUrl))
                                    : null),
                          child: (_fotoBaru == null && !showFoto)
                              ? const Icon(Icons.person, size: 48, color: Colors.grey)
                              : null,
                        ),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Color(0xFF171717),
                            shape: BoxShape.circle,
                          ),
                          child: _uploadingFoto
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Center(
                  child: Text(
                    'Ketuk untuk ganti foto',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 20),
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Text(_error!, style: TextStyle(color: Colors.red.shade700)),
                  ),
                  const SizedBox(height: 14),
                ],
                TextFormField(
                  controller: _nama,
                  decoration: const InputDecoration(
                    labelText: 'Nama Lengkap',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Nama wajib diisi' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _telepon,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Telepon',
                    prefixIcon: Icon(Icons.phone_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _kendaraan,
                  decoration: const InputDecoration(
                    labelText: 'Kendaraan',
                    prefixIcon: Icon(Icons.two_wheeler_outlined),
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'motor', child: Text('Motor')),
                    DropdownMenuItem(value: 'mobil', child: Text('Mobil')),
                    DropdownMenuItem(value: 'pickup', child: Text('Pickup')),
                  ],
                  onChanged: (v) => _kendaraan = v ?? 'motor',
                ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 8),
                Text(
                  'Ganti Kata Sandi (opsional)',
                  style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordLama,
                  obscureText: _obscureLama,
                  decoration: InputDecoration(
                    labelText: 'Kata Sandi Lama',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureLama ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscureLama = !_obscureLama),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordBaru,
                  obscureText: _obscureBaru,
                  decoration: InputDecoration(
                    labelText: 'Kata Sandi Baru',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureBaru ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscureBaru = !_obscureBaru),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _konfirmasi,
                  obscureText: _obscureKonfirmasi,
                  decoration: InputDecoration(
                    labelText: 'Konfirmasi Kata Sandi Baru',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureKonfirmasi ? Icons.visibility_off : Icons.visibility),
                      onPressed: () =>
                          setState(() => _obscureKonfirmasi = !_obscureKonfirmasi),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _submitting ? null : _simpan,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF171717),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    _submitting ? 'Menyimpan...' : 'Simpan',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
