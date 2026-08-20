import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../db_helper.dart';
import '../models.dart';
import '../theme.dart';
import '../formatters.dart';
import 'add_position_screen.dart';

class DashboardScreen extends StatefulWidget {
  final void Function(int) onNavigate;
  const DashboardScreen({super.key, required this.onNavigate});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<PositionWithLots> _positions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await DBHelper.instance.getOpenPositionsWithLots();
    setState(() {
      _positions = all;
      _loading = false;
    });
  }

  Map<String, double> get _assetInvested {
    final map = <String, double>{};
    for (final p in _positions) {
      map[p.position.assetType] = (map[p.position.assetType] ?? 0) + p.invested;
    }
    return map;
  }

  double get _totalInvested => _positions.fold(0.0, (s, p) => s + p.invested);
  double get _totalUnrealised => _positions.fold(0.0, (s, p) => s + p.unrealisedPnl);
  double get _totalCurrentValue => _totalInvested + _totalUnrealised;
  double get _totalPct => _totalInvested == 0 ? 0 : (_totalUnrealised / _totalInvested) * 100;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Total Portfolio Value', style: TextStyle(color: AppColors.textSecondary)),
                        const SizedBox(height: 4),
                        Text(formatMoney(_totalCurrentValue), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Text('Overall P&L  ', style: TextStyle(color: AppColors.textSecondary)),
                            Text('${formatSignedMoney(_totalUnrealised)} (${formatPct(_totalPct)})',
                                style: TextStyle(color: pnlColor(_totalUnrealised), fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _statCard('Invested', formatMoney(_totalInvested, whole: true))),
                      const SizedBox(width: 10),
                      Expanded(
                          child: _statCard('Unrealised P&L', formatMoney(_totalUnrealised, whole: true),
                              color: pnlColor(_totalUnrealised))),
                    ],
                  ),
                  const SizedBox(height: 16),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Asset Summary', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                        const SizedBox(height: 12),
                        if (_totalInvested == 0)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Text('Add a position to see your asset mix here.', style: TextStyle(color: AppColors.textSecondary)),
                          )
                        else
                          _assetSummary(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Quick Actions', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                  const SizedBox(height: 10),
                  GridView.count(
                    crossAxisCount: 4,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    children: [
                      _quickAction(Icons.add_box_outlined, 'Open\nPositions', () => widget.onNavigate(1)),
                      _quickAction(Icons.add, 'Add Stock\n/ MTF', () => _openAdd(context, 'Stock')),
                      _quickAction(Icons.currency_bitcoin, 'Add Crypto', () => _openAdd(context, 'Crypto')),
                      _quickAction(Icons.call_split, 'Add Option\n(Buy+Sell)', () => _openAdd(context, 'Options')),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  void _openAdd(BuildContext context, String assetType) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => AddPositionScreen(initialAssetType: assetType)));
    _load();
  }

  Widget _statCard(String label, String value, {Color? color}) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _quickAction(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AppCard(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.accent),
            const SizedBox(height: 6),
            Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _assetSummary() {
    final data = _assetInvested;
    final colors = {
      'Stock': const Color(0xFF3B82F6),
      'MTF': const Color(0xFF22C55E),
      'Crypto': const Color(0xFFF59E0B),
      'Options': const Color(0xFFA855F7),
    };
    final sections = data.entries.map((e) {
      return PieChartSectionData(
        value: e.value,
        color: colors[e.key] ?? Colors.grey,
        title: '',
        radius: 46,
      );
    }).toList();

    return Row(
      children: [
        SizedBox(
          height: 140,
          width: 140,
          child: PieChart(PieChartData(sections: sections, centerSpaceRadius: 34, sectionsSpace: 2)),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: data.entries.map((e) {
              final pct = _totalInvested == 0 ? 0.0 : (e.value / _totalInvested) * 100;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(width: 10, height: 10, decoration: BoxDecoration(color: colors[e.key] ?? Colors.grey, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Text(e.key),
                    const Spacer(),
                    Text('${pct.toStringAsFixed(1)}%', style: const TextStyle(color: AppColors.textSecondary)),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
