import 'package:flutter/material.dart';
import '../db_helper.dart';
import '../models.dart';
import '../theme.dart';
import '../formatters.dart';
import 'add_position_screen.dart';
import 'edit_lot_screen.dart';
import 'square_off_screen.dart';

class PositionDetailScreen extends StatefulWidget {
  final int positionId;
  const PositionDetailScreen({super.key, required this.positionId});

  @override
  State<PositionDetailScreen> createState() => _PositionDetailScreenState();
}

class _PositionDetailScreenState extends State<PositionDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tab;
  Position? _position;
  List<Lot> _lots = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final p = await DBHelper.instance.getPosition(widget.positionId);
    final lots = await DBHelper.instance.getLotsForPosition(widget.positionId);
    setState(() {
      _position = p;
      _lots = lots;
      _loading = false;
    });
  }

  List<Lot> get _openLots => _lots.where((l) => l.status == 'open').toList();

  @override
  Widget build(BuildContext context) {
    if (_loading || _position == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final p = _position!;
    final totalQty = _openLots.fold(0.0, (s, l) => s + l.quantity);
    final invested = _openLots.fold(0.0, (s, l) => s + l.invested);
    final unrealised = _openLots.fold(0.0, (s, l) => s + l.unrealisedPnl(p.currentPrice));
    final pct = invested == 0 ? 0.0 : (unrealised / invested) * 100;

    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          Text(p.symbol),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: AppColors.cardAlt, borderRadius: BorderRadius.circular(6)),
            child: Text(p.assetType, style: const TextStyle(fontSize: 11)),
          ),
        ]),
        bottom: TabBar(controller: _tab, tabs: const [Tab(text: 'Overview'), Tab(text: 'Lots')]),
        actions: [
          IconButton(icon: const Icon(Icons.price_change_outlined), tooltip: 'Update LTP', onPressed: _updatePrice),
        ],
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AppCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Total Quantity', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                          Text(formatQty(totalQty), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Avg Buy Price', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                          Text(formatMoney(totalQty == 0 ? 0 : _openLots.fold(0.0, (s, l) => s + l.buyPrice * l.quantity) / totalQty),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AppCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Invested', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                          Text(formatMoney(invested), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Unrealised P&L', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                          Text('${formatSignedMoney(unrealised)}\n(${formatPct(pct)})',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: pnlColor(unrealised))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Lots (${_openLots.length})', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                ],
              ),
              const SizedBox(height: 8),
              ..._openLots.map((l) => _lotSummaryCard(l, p.currentPrice)),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        await Navigator.push(context,
                            MaterialPageRoute(builder: (_) => AddPositionScreen(initialAssetType: p.assetType, existingPositionId: p.id)));
                        _load();
                      },
                      child: const Text('+ Add More'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
                      onPressed: _openLots.isEmpty
                          ? null
                          : () async {
                              await Navigator.push(context, MaterialPageRoute(builder: (_) => SquareOffScreen(positionId: p.id!)));
                              _load();
                            },
                      child: const Text('Square Off'),
                    ),
                  ),
                ],
              ),
            ],
          ),
          ListView(
            padding: const EdgeInsets.all(16),
            children: _openLots.isEmpty
                ? [const Padding(padding: EdgeInsets.all(20), child: Text('No open lots.'))]
                : _openLots.map((l) => _lotDetailCard(l, p)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _lotSummaryCard(Lot l, double ltp) {
    final pnl = l.unrealisedPnl(ltp);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${formatQty(l.quantity)} sh @ ${formatMoney(l.buyPrice)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(formatDate(l.buyDate), style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            Text(formatSignedMoney(pnl), style: TextStyle(color: pnlColor(pnl), fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _lotDetailCard(Lot l, Position p) {
    final pnl = l.unrealisedPnl(p.currentPrice);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${formatQty(l.quantity)} Shares', style: const TextStyle(fontWeight: FontWeight.bold)),
                TextButton(
                  onPressed: () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (_) => EditLotScreen(lotId: l.id!)));
                    _load();
                  },
                  child: const Text('Edit'),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Buy Price', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    Text(formatMoney(l.buyPrice)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Buy Date', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    Text(formatDate(l.buyDate)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('P&L', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    Text('${formatSignedMoney(pnl)} (${formatPct(l.unrealisedPnlPct(p.currentPrice))})',
                        style: TextStyle(color: pnlColor(pnl))),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updatePrice() async {
    final ctrl = TextEditingController(text: _position!.currentPrice.toStringAsFixed(2));
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Update Current Price'),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'LTP (₹)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, double.tryParse(ctrl.text)), child: const Text('Save')),
        ],
      ),
    );
    if (result != null) {
      final p = _position!;
      p.currentPrice = result;
      await DBHelper.instance.updatePosition(p);
      _load();
    }
  }
}
