import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/order.dart';
import '../models/transaksi.dart';
import '../models/user.dart';
import '../state/app_state.dart';
import '../state/kurir_state.dart';
import '../utils/format.dart';
import '../widgets/order_card.dart';
import 'order_detail_screen.dart';
import 'order_notif_screen.dart';
import 'penarikan_screen.dart';

class KurirHomeScreen extends StatefulWidget {
  const KurirHomeScreen({super.key});

  @override
  State<KurirHomeScreen> createState() => _KurirHomeScreenState();
}

class _KurirHomeScreenState extends State<KurirHomeScreen> {
  int _tab = 0;
  bool _notifOpen = false;
  final _pageController = PageController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ks = context.read<KurirState>();
      ks.onNotify = (title, msg) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(msg),
              behavior: SnackBarBehavior.floating,
              backgroundColor: const Color(0xFF171717),
            ),
          );
      };
      ks.onOrderBaru = (data) => _showOrderNotif(data);
      ks.init();
    });
  }

  Future<void> _showOrderNotif(Map<String, dynamic> data) async {
    if (_notifOpen || !mounted) return;
    _notifOpen = true;
    try {
      await showOrderNotif(
        context,
        data,
        onAccept: (orderId) => _action('ambil', orderId),
        onDecline: () async {},
      );
    } finally {
      _notifOpen = false;
    }
  }

  Future<Order?> _action(String action, int orderId, {String status = ''}) async {
    final ks = context.read<KurirState>();
    try {
      switch (action) {
        case 'ambil':
          return await ks.ambil(orderId);
        case 'status':
          return await ks.ubahStatus(orderId, status);
        case 'batal':
          return await ks.batal(orderId);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
    return null;
  }

  void _openDetail(Order order, bool isMine) {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) => OrderDetailScreen(
          order: order,
          isMine: isMine,
          onAction: (action, id, {status = ''}) async {
            return _action(action, id, status: status);
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: (i) => setState(() => _tab = i),
        children: [
          _DashboardTab(onAction: _action, onOpenDetail: _openDetail),
          _RiwayatTab(onAction: _action, onOpenDetail: _openDetail),
          const _SaldoTab(),
          const _ProfilTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) {
          if (i == _tab) return;
          _pageController.animateToPage(
            i,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.history), label: 'Riwayat'),
          NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet), label: 'Saldo'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profil'),
        ],
      ),
    );
  }
}

class _DashboardTab extends StatelessWidget {
  final Future<void> Function(String action, int orderId, {String status}) onAction;
  final void Function(Order order, bool isMine) onOpenDetail;
  const _DashboardTab({required this.onAction, required this.onOpenDetail});

  @override
  Widget build(BuildContext context) {
    final ks = context.watch<KurirState>();
    final app = context.watch<AppState>();

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: ks.refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _header(context, app, ks),
            const SizedBox(height: 16),
            _SaldoMiniCard(onTarik: () {
              Navigator.push(context, CupertinoPageRoute(builder: (_) => const PenarikanScreen()));
            }),
            const SizedBox(height: 20),
            if (ks.loading && ks.dashboard == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (ks.error != null && ks.dashboard == null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Column(
                  children: [
                    Text(ks.error!, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600])),
                    const SizedBox(height: 12),
                    ElevatedButton(onPressed: ks.refresh, child: const Text('Coba lagi')),
                  ],
                ),
              )
            else ...[
              if (ks.dashboard!.saya.isNotEmpty) ...[
                const Text('Tugas Aktif', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                ...ks.dashboard!.saya.map(
                  (o) => OrderCard(
                    order: o,
                    isMine: true,
                    onAction: onAction,
                    onTap: () => onOpenDetail(o, true),
                  ),
                ),
                const SizedBox(height: 20),
              ],
              const Text('Pesanan Tersedia', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              if (ks.dashboard!.tersedia.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    children: [
                      Icon(Icons.inbox_outlined, size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 8),
                      Text('Tidak ada pesanan tersedia', style: TextStyle(color: Colors.grey[600])),
                    ],
                  ),
                )
              else
                ...ks.dashboard!.tersedia.map(
                  (o) => OrderCard(
                    order: o,
                    isMine: false,
                    onAction: onAction,
                    onTap: () => onOpenDetail(o, false),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context, AppState app, KurirState ks) {
    final u = app.user;
    final data = ks.dashboard;
    return Row(
      children: [
        CircleAvatar(
          radius: 26,
          backgroundColor: Colors.grey[300],
          child: const Icon(Icons.two_wheeler),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(u?.nama ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              Text(
                kendaraanLabel(u?.kendaraan ?? ''),
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
            ],
          ),
        ),
        if (!ks.connected)
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: Icon(Icons.cloud_off, size: 18, color: Colors.orange),
          ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(20)),
          child: Text(
            '${data?.totalDiantar ?? 0} diantar',
            style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.w700, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

class _SaldoMiniCard extends StatelessWidget {
  final VoidCallback onTarik;
  const _SaldoMiniCard({required this.onTarik});

  @override
  Widget build(BuildContext context) {
    final ks = context.watch<KurirState>();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF171717), Color(0xFF333333)]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.account_balance_wallet_outlined, color: Colors.white, size: 32),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Saldo', style: TextStyle(color: Colors.white70, fontSize: 12)),
              Text(
                rupiah(ks.dashboard?.saldo ?? 0),
                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const Spacer(),
          OutlinedButton(
            onPressed: onTarik,
            style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white54)),
            child: const Text('Tarik'),
          ),
        ],
      ),
    );
  }
}

class _RiwayatTab extends StatelessWidget {
  final Future<void> Function(String action, int orderId, {String status}) onAction;
  final void Function(Order order, bool isMine) onOpenDetail;
  const _RiwayatTab({required this.onAction, required this.onOpenDetail});

  @override
  Widget build(BuildContext context) {
    final ks = context.watch<KurirState>();
    final riwayat = ks.dashboard?.riwayat ?? [];
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: ks.refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Riwayat Diantar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(
              'Total diantar: ${ks.dashboard?.totalDiantar ?? 0} pesanan',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
            const SizedBox(height: 16),
            if (ks.loading && ks.dashboard == null)
              const Center(child: Padding(padding: EdgeInsets.all(48), child: CircularProgressIndicator()))
            else if (riwayat.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Column(
                  children: [
                    Icon(Icons.assignment_turned_in_outlined, size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 8),
                    Text('Belum ada pesanan diantar', style: TextStyle(color: Colors.grey[600])),
                  ],
                ),
              )
            else
              ...riwayat.map(
                (o) => OrderCard(
                  order: o,
                  isMine: true,
                  onTap: () => onOpenDetail(o, true),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SaldoTab extends StatefulWidget {
  const _SaldoTab();

  @override
  State<_SaldoTab> createState() => _SaldoTabState();
}

class _SaldoTabState extends State<_SaldoTab> {
  ({int saldo, int pendapatan, List<Transaksi> transaksi})? _data;
  bool _loading = true;
  String? _err;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _err = null;
    });
    try {
      final d = await context.read<KurirState>().saldo();
      if (mounted) setState(() => _data = d);
    } catch (e) {
      if (mounted) setState(() => _err = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ks = context.watch<KurirState>();
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Saldo & Penarikan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF171717), Color(0xFF333333)]),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Saldo', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  Text(
                    rupiah(_data?.saldo ?? ks.dashboard?.saldo ?? 0),
                    style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Total Pendapatan', style: TextStyle(color: Colors.white60, fontSize: 11)),
                              Text(
                                rupiah(_data?.pendapatan ?? 0),
                                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Total Diantar', style: TextStyle(color: Colors.white60, fontSize: 11)),
                              Text(
                                '${ks.dashboard?.totalDiantar ?? 0}',
                                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final done = await Navigator.push<bool>(
                          context,
                          CupertinoPageRoute(builder: (_) => const PenarikanScreen()),
                        );
                        if (done == true) _load();
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: const Color(0xFF171717)),
                      child: const Text('Tarik Saldo', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text('Riwayat Transaksi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            if (_loading)
              const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
            else if (_err != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    Text(_err!, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600])),
                    const SizedBox(height: 8),
                    TextButton(onPressed: _load, child: const Text('Coba lagi')),
                  ],
                ),
              )
            else if (_data!.transaksi.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Column(
                  children: [
                    Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 8),
                    Text('Belum ada transaksi', style: TextStyle(color: Colors.grey[600])),
                  ],
                ),
              )
            else
              ..._data!.transaksi.map((t) => _TransaksiCard(transaksi: t)),
          ],
        ),
      ),
    );
  }
}

class _TransaksiCard extends StatelessWidget {
  final Transaksi transaksi;
  const _TransaksiCard({required this.transaksi});

  @override
  Widget build(BuildContext context) {
    final isIn = transaksi.tipe == 'masuk';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: (isIn ? Colors.green : Colors.red).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(isIn ? Icons.arrow_downward : Icons.arrow_upward,
                color: isIn ? Colors.green : Colors.red, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(transaksi.keterangan, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                Text(
                  formatTanggal(transaksi.createdAt),
                  style: TextStyle(color: Colors.grey[500], fontSize: 11),
                ),
              ],
            ),
          ),
          Text(
            '${isIn ? '+' : '-'}${rupiah(transaksi.jumlah)}',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: isIn ? Colors.green.shade700 : Colors.red.shade700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfilTab extends StatelessWidget {
  const _ProfilTab();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final ks = context.watch<KurirState>();
    final u = app.user;
    return SafeArea(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _buildHeader(u),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: _statCard(
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'Saldo',
                    value: rupiah(ks.dashboard?.saldo ?? 0),
                    color: const Color(0xFF1E88E5),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _statCard(
                    icon: Icons.assignment_turned_in_outlined,
                    label: 'Total Diantar',
                    value: '${ks.dashboard?.totalDiantar ?? 0}',
                    color: Colors.amber.shade700,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _infoCard(
                  icon: Icons.email_outlined,
                  title: 'Email',
                  value: u?.email ?? '-',
                  color: const Color(0xFF1E88E5),
                ),
                const SizedBox(height: 12),
                _infoCard(
                  icon: Icons.phone_outlined,
                  title: 'Telepon',
                  value: u?.telepon.isEmpty == true ? '-' : u!.telepon,
                  color: Colors.amber.shade700,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton.icon(
              onPressed: () async {
                await app.logout();
                if (context.mounted) {
                  Navigator.pushNamedAndRemoveUntil(context, '/login', (r) => false);
                }
              },
              icon: const Icon(Icons.logout),
              label: const Text('Keluar'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildHeader(User? u) {
    final nama = u?.nama ?? '';
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 32),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xFF171717), Color(0xFF333333)]),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 46,
            backgroundColor: Colors.white,
            child: CircleAvatar(
              radius: 43,
              backgroundColor: const Color(0xFF3A3A3A),
              child: u?.fotoProfil.isNotEmpty == true
                  ? ClipOval(child: Image.network(u!.fotoProfil, width: 86, height: 86, fit: BoxFit.cover))
                  : const Icon(Icons.two_wheeler, size: 44, color: Colors.white),
            ),
          ),
          const SizedBox(height: 16),
          Text(nama, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.delivery_dining, size: 16, color: Colors.amber),
              const SizedBox(width: 6),
              Text(kendaraanLabel(u?.kendaraan ?? ''), style: const TextStyle(color: Colors.white70, fontSize: 14)),
            ],
          ),
          if (u?.isVerified == true) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.verified, color: Colors.lightGreenAccent, size: 16),
                  SizedBox(width: 6),
                  Text('Kurir Terverifikasi', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statCard({required IconData icon, required String label, required String value, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 22, color: color),
          ),
          const SizedBox(height: 12),
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _infoCard({required IconData icon, required String title, required String value, required Color color}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, size: 22, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
