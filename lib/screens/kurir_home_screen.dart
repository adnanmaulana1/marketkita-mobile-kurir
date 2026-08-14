import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../models/order.dart';
import '../models/transaksi.dart';
import '../models/user.dart';
import '../state/app_state.dart';
import '../state/kurir_state.dart';
import '../utils/format.dart';
import '../widgets/order_card.dart';
import 'order_detail_screen.dart';
import 'edit_profil_screen.dart';
import 'order_notif_screen.dart';
import 'penarikan_screen.dart';

const Color _kDark = Color(0xFF171717);
const Color _kEmerald = Color(0xFF34D399);
const Color _kAmber = Color(0xFFFBBF24);

class KurirHomeScreen extends StatefulWidget {
  const KurirHomeScreen({super.key});

  @override
  State<KurirHomeScreen> createState() => _KurirHomeScreenState();
}

class _KurirHomeScreenState extends State<KurirHomeScreen>
    with SingleTickerProviderStateMixin {
  int _tab = 0;
  bool _notifOpen = false;
  late final AnimationController _tabAnim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
    value: 1,
  );
  late final Animation<double> _tabOpacity =
      CurvedAnimation(parent: _tabAnim, curve: Curves.easeOut);
  late final Animation<Offset> _tabSlide = Tween<Offset>(
    begin: const Offset(0, 0.03),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _tabAnim, curve: Curves.easeOutCubic));

  void _switchTab(int i) {
    if (i == _tab) return;
    setState(() => _tab = i);
    _tabAnim.forward(from: 0);
  }

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
              backgroundColor: _kDark,
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
    _tabAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FadeTransition(
        opacity: _tabOpacity,
        child: SlideTransition(
          position: _tabSlide,
          child: IndexedStack(
            index: _tab,
            children: [
              _DashboardTab(onAction: _action, onOpenDetail: _openDetail),
              _RiwayatTab(onAction: _action, onOpenDetail: _openDetail),
              const _SaldoTab(),
              const _ProfilTab(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _BottomBar(selected: _tab, onSelect: _switchTab),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onSelect;
  const _BottomBar({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, -4)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _BarItem(icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard, label: 'Beranda', selected: selected == 0, onTap: () => onSelect(0)),
              _BarItem(icon: Icons.history, label: 'Riwayat', selected: selected == 1, onTap: () => onSelect(1)),
              _BarItem(icon: Icons.account_balance_wallet_outlined, activeIcon: Icons.account_balance_wallet, label: 'Saldo', selected: selected == 2, onTap: () => onSelect(2)),
              _BarItem(icon: Icons.person_outline, activeIcon: Icons.person, label: 'Profil', selected: selected == 3, onTap: () => onSelect(3)),
            ],
          ),
        ),
      ),
    );
  }
}

class _BarItem extends StatelessWidget {
  final IconData icon;
  final IconData? activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _BarItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.activeIcon,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? _kEmerald.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(selected ? (activeIcon ?? icon) : icon, size: 24, color: selected ? const Color(0xFF059669) : Colors.grey.shade500),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? const Color(0xFF059669) : Colors.grey.shade600,
              ),
            ),
          ],
        ),
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
      bottom: false,
      child: RefreshIndicator(
        onRefresh: ks.refresh,
        color: _kEmerald,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _DashboardHeader(app: app, ks: ks),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!ks.connected) const _OfflineBanner(),
                  _SaldoHeroCard(onTarik: () {
                    Navigator.push(context, CupertinoPageRoute(builder: (_) => const PenarikanScreen()));
                  }),
                  const SizedBox(height: 18),
                  _StatsRow(ks: ks),
                  const SizedBox(height: 22),
                  if (ks.loading && ks.dashboard == null)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: Center(child: CircularProgressIndicator(color: _kEmerald)),
                    )
                  else if (ks.error != null && ks.dashboard == null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Column(
                        children: [
                          Text(ks.error!, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600])),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: ks.refresh,
                            style: ElevatedButton.styleFrom(backgroundColor: _kDark, foregroundColor: Colors.white),
                            child: const Text('Coba lagi'),
                          ),
                        ],
                      ),
                    )
                  else ...[
                    if (ks.dashboard!.saya.isNotEmpty) ...[
                      const _SectionHeader(
                        icon: Icons.bolt,
                        title: 'Tugas Aktif',
                        badge: 'LIVE',
                        badgeColor: _kEmerald,
                      ),
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
                    const _SectionHeader(icon: Icons.storefront_outlined, title: 'Pesanan Tersedia'),
                    const SizedBox(height: 10),
                    if (ks.dashboard!.tersedia.isEmpty)
                      const _EmptyState(
                        icon: Icons.inbox_outlined,
                        message: 'Tidak ada pesanan tersedia\nTerus pantau — order baru akan muncul di sini.',
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
          ],
        ),
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  final AppState app;
  final KurirState ks;
  const _DashboardHeader({required this.app, required this.ks});

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 11) return 'Selamat pagi';
    if (h < 15) return 'Selamat siang';
    if (h < 18) return 'Selamat sore';
    return 'Selamat malam';
  }

  @override
  Widget build(BuildContext context) {
    final u = app.user;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_kDark, Color(0xFF2B2B2B)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: Colors.white.withValues(alpha: 0.12),
                child: u?.fotoProfil.isNotEmpty == true
                    ? ClipOval(child: Image.network(AppConfig.resolveUrl(u!.fotoProfil), width: 52, height: 52, fit: BoxFit.cover))
                    : const Icon(Icons.two_wheeler, color: _kEmerald),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_greeting(), style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
                    Text(u?.nama ?? '', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              _StatusChip(
                connected: ks.connected,
                label: ks.connected ? 'Online' : 'Offline',
                color: ks.connected ? _kEmerald : Colors.redAccent,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.delivery_dining, size: 15, color: _kAmber),
              const SizedBox(width: 6),
              Text(
                kendaraanLabel(u?.kendaraan ?? ''),
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13),
              ),
              const Spacer(),
              Text(
                '${ks.dashboard?.totalDiantar ?? 0} pesanan diantar',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final bool connected;
  final String label;
  final Color color;
  const _StatusChip({required this.connected, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off, size: 18, color: Colors.orange.shade800),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Tidak terhubung ke server — order baru mungkin tidak masuk.',
              style: TextStyle(color: Colors.orange.shade900, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _SaldoHeroCard extends StatelessWidget {
  final VoidCallback onTarik;
  const _SaldoHeroCard({required this.onTarik});

  @override
  Widget build(BuildContext context) {
    final ks = context.watch<KurirState>();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_kEmerald, Color(0xFF0D9488)],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(color: _kEmerald.withValues(alpha: 0.35), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_wallet_outlined, color: Colors.white, size: 26),
              const SizedBox(width: 8),
              Text('Saldo Anda', style: const TextStyle(color: Colors.white70, fontSize: 13)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                child: const Text('Ready', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            rupiah(ks.dashboard?.saldo ?? 0),
            style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: 0.5),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onTarik,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF0D9488),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.arrow_upward, size: 18),
                  SizedBox(width: 8),
                  Text('Tarik Saldo', style: TextStyle(fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final KurirState ks;
  const _StatsRow({required this.ks});

  @override
  Widget build(BuildContext context) {
    final saya = ks.dashboard?.saya.length ?? 0;
    final tersedia = ks.dashboard?.tersedia.length ?? 0;
    final diantar = ks.dashboard?.totalDiantar ?? 0;
    return Row(
      children: [
        Expanded(child: _StatTile(icon: Icons.bolt, label: 'Aktif', value: '$saya', color: _kEmerald)),
        const SizedBox(width: 12),
        Expanded(child: _StatTile(icon: Icons.storefront_outlined, label: 'Tersedia', value: '$tersedia', color: _kAmber)),
        const SizedBox(width: 12),
        Expanded(child: _StatTile(icon: Icons.assignment_turned_in_outlined, label: 'Diantar', value: '$diantar', color: const Color(0xFF7DD3FC))),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _StatTile({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? badge;
  final Color? badgeColor;
  const _SectionHeader({required this.icon, required this.title, this.badge, this.badgeColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: _kDark),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        if (badge != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: (badgeColor ?? _kEmerald).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
            child: Text(
              badge!,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: badgeColor ?? const Color(0xFF059669), letterSpacing: 0.5),
            ),
          ),
        ],
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(icon, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600])),
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
      bottom: false,
      child: RefreshIndicator(
        onRefresh: ks.refresh,
        color: _kEmerald,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const _PageTitle(
              title: 'Riwayat',
              subtitle: 'Daftar pesanan yang telah Anda antar',
            ),
            const SizedBox(height: 16),
            _RiwayatSummary(total: ks.dashboard?.totalDiantar ?? 0),
            const SizedBox(height: 16),
            if (ks.loading && ks.dashboard == null)
              const Center(child: Padding(padding: EdgeInsets.all(48), child: CircularProgressIndicator(color: _kEmerald)))
            else if (ks.error != null && ks.dashboard == null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Column(
                  children: [
                    Text(ks.error!, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600])),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: ks.refresh,
                      style: ElevatedButton.styleFrom(backgroundColor: _kDark, foregroundColor: Colors.white),
                      child: const Text('Coba lagi'),
                    ),
                  ],
                ),
              )
            else if (riwayat.isEmpty)
              const _EmptyState(icon: Icons.assignment_turned_in_outlined, message: 'Belum ada pesanan diantar')
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

class _RiwayatSummary extends StatelessWidget {
  final int total;
  const _RiwayatSummary({required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_kDark, Color(0xFF2B2B2B)]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: _kEmerald.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.emoji_events_outlined, color: _kEmerald),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total pesanan diantar', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
                const SizedBox(height: 2),
                Text('$total pesanan', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PageTitle extends StatelessWidget {
  final String title;
  final String subtitle;
  const _PageTitle({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
      ],
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
      bottom: false,
      child: RefreshIndicator(
        onRefresh: _load,
        color: _kEmerald,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const _PageTitle(title: 'Saldo', subtitle: 'Kelola saldo dan pendapatan Anda'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [_kDark, Color(0xFF2B2B2B)]),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Saldo', style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(
                    rupiah(_data?.saldo ?? ks.dashboard?.saldo ?? 0),
                    style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Total Pendapatan', style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 11)),
                              const SizedBox(height: 2),
                              Text(
                                rupiah(_data?.pendapatan ?? 0),
                                style: const TextStyle(color: _kEmerald, fontSize: 16, fontWeight: FontWeight.w800),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Total Diantar', style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 11)),
                              const SizedBox(height: 2),
                              Text(
                                '${ks.dashboard?.totalDiantar ?? 0}',
                                style: const TextStyle(color: _kAmber, fontSize: 16, fontWeight: FontWeight.w800),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
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
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kEmerald,
                        foregroundColor: _kDark,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Tarik Saldo', style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const _SectionHeader(icon: Icons.receipt_long_outlined, title: 'Riwayat Transaksi'),
            const SizedBox(height: 12),
            if (_loading)
              const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator(color: _kEmerald)))
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
              const _EmptyState(icon: Icons.receipt_long_outlined, message: 'Belum ada transaksi')
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
              color: (isIn ? _kEmerald : Colors.red).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(isIn ? Icons.arrow_downward : Icons.arrow_upward,
                color: isIn ? const Color(0xFF059669) : Colors.red, size: 20),
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
              color: isIn ? const Color(0xFF059669) : Colors.red.shade700,
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
      bottom: false,
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
                    color: _kAmber,
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
                  color: _kAmber,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  CupertinoPageRoute(builder: (_) => const EditProfilScreen()),
                );
              },
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit Profil'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kDark,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 12),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [_kDark, Color(0xFF2B2B2B)]),
      ),
      child: Column(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 46,
                backgroundColor: Colors.white.withValues(alpha: 0.12),
                child: CircleAvatar(
                  radius: 43,
                  backgroundColor: const Color(0xFF3A3A3A),
                  child: u?.fotoProfil.isNotEmpty == true
                      ? ClipOval(child: Image.network(AppConfig.resolveUrl(u!.fotoProfil), width: 86, height: 86, fit: BoxFit.cover))
                      : const Icon(Icons.two_wheeler, size: 44, color: _kEmerald),
                ),
              ),
              if (u?.isVerified == true)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: _kDark, shape: BoxShape.circle, border: Border.all(color: _kEmerald, width: 2)),
                    child: const Icon(Icons.verified, size: 16, color: _kEmerald),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(nama, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.delivery_dining, size: 16, color: _kAmber),
              const SizedBox(width: 6),
              Text(kendaraanLabel(u?.kendaraan ?? ''), style: const TextStyle(color: Colors.white70, fontSize: 14)),
            ],
          ),
          if (u?.isVerified == true) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: _kEmerald.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.verified, color: _kEmerald, size: 16),
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
