import 'package:flutter/material.dart';
import '../db_helper.dart';
import '../models.dart';
import '../theme.dart';
import '../formatters.dart';

class ClosedTradesScreen extends StatefulWidget {
  const ClosedTradesScreen({super.key});

  @override
  State<ClosedTradesScreen> createState() => _ClosedTradesScreenState();
}

class _ClosedTradesScreenState extends State<ClosedTradesScreen> {
  String _filter = 'ALL';
  final _filters = const ['ALL', 'STOCK/MTF', 'OPTIONS', 'CRYPTO'];
  List<Lot> _lots = [];
  Map<int, Position> _positions = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final lots = await DBHelper.instance.getClosedLots();
    final positions = await DBHelper.instance.getAllPositions();
    final posMap = {for (final p in positions) p.id!: p};
    setState(() {
      _lots = lots;
      _positions = posMap;
      _loading = false;
    });
  }

  List<Lot> get _filtered {
    if (_filter == 'ALL') return _lots;
    return _lots.where((l) {
      final assetType = _positions[l.positionId]?.assetType.toUpperCase() ?? '';
      if (_filter == 'STOCK/MTF') return assetType == 'STOCK' || assetType == 'MTF';
      return assetType == _filter;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Closed Trades')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _filters.map((f) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(f),
                      selected: f == _filter,
                      onSelected: (_) => setState(() => _filter = f),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? const Center(child: Text('No closed trades yet.', style: TextStyle(color: AppColors.textSecondary)))
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                          itemCount: _filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (_, i) => _tradeCard(_filtered[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _tradeCard(Lot l) {
    final p = _positions[l.positionId];
    return AppCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(p?.symbol ?? '-', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(color: AppColors.cardAlt, borderRadius: BorderRadius.circular(5)),
                    child: Text(p?.assetType ?? '', style: const TextStyle(fontSize: 10)),
                  ),
                ]),
                const SizedBox(height: 2),
                Text('${formatQty(l.quantity)} Shares  •  ${formatDate(l.sellDate ?? l.buyDate)}',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          Text(formatSignedMoney(l.netProfit), style: TextStyle(color: pnlColor(l.netProfit), fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
