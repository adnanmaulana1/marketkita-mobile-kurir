import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../state/kurir_state.dart';
import '../utils/format.dart';

class PenarikanMethod {
  final String kode;
  final String label;
  final bool isBank;
  final IconData icon;
  const PenarikanMethod(this.kode, this.label, this.isBank, this.icon);
}

const kBankMethods = [
  PenarikanMethod('bank_bca', 'BCA', true, Icons.account_balance),
  PenarikanMethod('bank_bri', 'BRI', true, Icons.account_balance),
  PenarikanMethod('bank_bni', 'BNI', true, Icons.account_balance),
  PenarikanMethod('bank_mandiri', 'Mandiri', true, Icons.account_balance),
];

const kEwalletMethods = [
  PenarikanMethod('ewallet_dana', 'DANA', false, Icons.account_balance_wallet),
  PenarikanMethod('ewallet_ovo', 'OVO', false, Icons.account_balance_wallet),
  PenarikanMethod('ewallet_gopay', 'GoPay', false, Icons.account_balance_wallet),
  PenarikanMethod('ewallet_shopee', 'ShopeePay', false, Icons.account_balance_wallet),
];

class PenarikanScreen extends StatefulWidget {
  const PenarikanScreen({super.key});

  @override
  State<PenarikanScreen> createState() => _PenarikanScreenState();
}

class _PenarikanScreenState extends State<PenarikanScreen> {
  static const _quickAmounts = [25000, 50000, 100000];

  final _nominal = TextEditingController();
  final _nomorAkun = TextEditingController();
  final _atasNama = TextEditingController();
  PenarikanMethod? _metode;
  int? _saldo;
  bool _loading = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nominal.dispose();
    _nomorAkun.dispose();
    _atasNama.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final ks = context.read<KurirState>();
      final d = await ks.saldo();
      if (mounted) setState(() => _saldo = d.saldo);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  void _setNominal(int v) {
    _nominal.text = '$v';
    _nominal.selection = TextSelection.collapsed(offset: _nominal.text.length);
  }

  Future<void> _submit() async {
    final nominal = int.tryParse(_nominal.text.replaceAll('.', '')) ?? 0;
    final saldo = _saldo ?? 0;
    if (nominal <= 0 || nominal > saldo) {
      _toast('Nominal tidak valid atau melebihi saldo.');
      return;
    }
    if (_metode == null) {
      _toast('Pilih metode penarikan.');
      return;
    }
    if (_nomorAkun.text.trim().isEmpty) {
      _toast('Nomor akun wajib diisi.');
      return;
    }
    if (_atasNama.text.trim().isEmpty) {
      _toast('Nama pemilik akun wajib diisi.');
      return;
    }
    setState(() => _submitting = true);
    try {
      await context.read<KurirState>().tarik(
            nominal: nominal,
            metode: _metode!.kode,
            nomorAkun: _nomorAkun.text.trim(),
            atasNama: _atasNama.text.trim(),
          );
      if (!mounted) return;
      await _showSuccess(nominal, _metode!.label);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) _toast('$e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _showSuccess(int nominal, String metode) {
    return Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black.withValues(alpha: 0.65),
        barrierDismissible: false,
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (_, _, _) => _SuccessOverlay(nominal: nominal, metode: metode),      ),
    );
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(msg),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF171717),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final saldo = _saldo ?? 0;
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: const Color(0xFF171717),
        foregroundColor: Colors.white,
        title: const Text('Penarikan Saldo'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF171717), Color(0xFF333333)]),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Saldo Tersedia', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text(
                        rupiah(saldo),
                        style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text('Nominal', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ..._quickAmounts.map(
                      (a) => ChoiceChip(
                        label: Text(rupiah(a)),
                        selected: _nominal.text == '$a',
                        onSelected: (_) => _setNominal(a),
                        showCheckmark: false,
                        selectedColor: const Color(0xFF171717),
                        labelStyle: TextStyle(
                          color: _nominal.text == '$a' ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.select_all, size: 18),
                      label: const Text('Semua'),
                      onPressed: () => _setNominal(saldo),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _nominal,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Nominal (Rp)',
                    hintText: 'Masukkan nominal',
                    prefixText: 'Rp ',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),
                const Text('Metode Penarikan', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                const Text('Transfer Bank', style: TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 8),
                _buildMethodGroup(kBankMethods),
                const SizedBox(height: 16),
                const Text('E-Wallet', style: TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 8),
                _buildMethodGroup(kEwalletMethods),
                if (_metode != null) ...[
                  const SizedBox(height: 24),
                  const Text('Detail Akun Tujuan', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _nomorAkun,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: _metode!.isBank ? 'Nomor Rekening' : 'Nomor ID / Nomor HP',
                      hintText: _metode!.isBank ? 'Masukkan nomor rekening' : 'Masukkan nomor akun',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _atasNama,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Nama Pemilik Akun',
                      hintText: 'Sesuai identitas',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: const Color(0xFF171717),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF171717)),
                          )
                        : const Text('Tarik Saldo', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Penarikan diproses secara simulasi dan akan mengurangi saldo Anda.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 16),
              ],
            ),
    );
  }

  Widget _buildMethodGroup(List<PenarikanMethod> methods) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: methods.map((m) {
        final selected = _metode?.kode == m.kode;
        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => _metode = m),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFF171717) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? const Color(0xFF171717) : Colors.grey.shade300,
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(m.icon, size: 18, color: selected ? Colors.white : Colors.grey.shade700),
                const SizedBox(width: 6),
                Text(
                  m.label,
                  style: TextStyle(
                    color: selected ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _SuccessOverlay extends StatefulWidget {
  final int nominal;
  final String metode;
  const _SuccessOverlay({required this.nominal, required this.metode});

  @override
  State<_SuccessOverlay> createState() => _SuccessOverlayState();
}

class _SuccessOverlayState extends State<_SuccessOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _checkScale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..forward();
    _scale = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.35, curve: Curves.elasticOut),
    );
    _checkScale = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.15, 0.5, curve: Curves.easeOutBack),
    );
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.25),
      reverseCurve: const Interval(0.85, 1.0),
    );
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: FadeTransition(
          opacity: fade,
          child: ScaleTransition(
            scale: _scale,
            child: Container(
              margin: const EdgeInsets.all(32),
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ScaleTransition(
                    scale: _checkScale,
                    child: Container(
                      width: 84,
                      height: 84,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [Color(0xFF2E7D32), Color(0xFF66BB6A)],
                        ),
                      ),
                      child: const Icon(Icons.check, color: Colors.white, size: 48),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Penarikan Berhasil!',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${rupiah(widget.nominal)} • ${widget.metode}',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[700], fontSize: 15),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Dana sedang diproses.',
                    style: TextStyle(color: Colors.grey[500], fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
