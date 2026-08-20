import 'package:flutter/material.dart';
import '../db_helper.dart';
import '../models.dart';
import '../theme.dart';
import '../formatters.dart';
import 'position_detail_screen.dart';
import 'add_position_screen.dart';

class OpenPositionsScreen extends StatefulWidget {
  const OpenPositionsScreen({super.key});

  @override
  State<OpenPositionsScreen> createState() => _OpenPositionsScreenState();
}

class _OpenPositionsScreenState extends State<OpenPositionsScreen> {
  String _filter = 'ALL';
  List<PositionWithLots> _positions = [];
  bool _loading = true;

  final _filters = const ['ALL', 'STOCK', 'MTF', 'CRYPTO'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await DBHelper.instance.getOpenPositionsWithLots(assetType: _filter);
    setState(() {
      _positions = data;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Open Positions')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: _filters.map((f) {
                final selected = f == _filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(f),
                    selected: selected,
                    onSelected: (_) {
                      setState(() => _filter = f);
                      _load();
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _positions.isEmpty
                    ? const Center(child: Text('No open positions yet.', style: TextStyle(color: AppColors.textSecondary)))
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 90),
                          itemCount: _positions.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (_, i) => _positionCard(_positions[i]),
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddPositionScreen()));
          _load();
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Stock / MTF / Crypto'),
      ),
    );
  }

  Widget _positionCard(PositionWithLots pl) {
    final p = pl.position;
    return InkWell(
      onTap: () async {
        await Navigator.push(context, MaterialPageRoute(builder: (_) => PositionDetailScreen(positionId: p.id!)));
        _load();
      },
      borderRadius: BorderRadius.circular(14),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(p.symbol, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.cardAlt, borderRadius: BorderRadius.circular(6)),
                  child: Text(p.assetType, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                ),
                const Spacer(),
                Text('${formatQty(pl.totalQuantity)} ${p.assetType == "Crypto" ? "Units" : "Shares"}',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Invested', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                      Text(formatMoney(pl.invested)),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('LTP', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                      Text(formatMoney(p.currentPrice)),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('P&L', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                      Text(formatSignedMoney(pl.unrealisedPnl), style: TextStyle(color: pnlColor(pl.unrealisedPnl), fontWeight: FontWeight.w600)),
                      Text('(${formatPct(pl.unrealisedPnlPct)})', style: TextStyle(color: pnlColor(pl.unrealisedPnl), fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
