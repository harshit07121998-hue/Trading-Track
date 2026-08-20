import 'package:flutter/material.dart';
import '../db_helper.dart';
import '../models.dart';
import '../theme.dart';
import '../xirr.dart';

class XirrScreen extends StatefulWidget {
  const XirrScreen({super.key});

  @override
  State<XirrScreen> createState() => _XirrScreenState();
}

class _XirrScreenState extends State<XirrScreen> {
  bool _loading = true;
  double? _overall;
  double? _stock;
  double? _mtf;
  double? _options;
  double? _crypto;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final positions = await DBHelper.instance.getAllPositions();
    final posMap = {for (final p in positions) p.id!: p};
    final lots = await DBHelper.instance.getAllLots();

    final all = <CashFlow>[];
    final byType = <String, List<CashFlow>>{'Stock': [], 'MTF': [], 'Crypto': [], 'Options': []};

    final now = DateTime.now();
    for (final l in lots) {
      final pos = posMap[l.positionId];
      if (pos == null) continue;
      final outflow = CashFlow(l.buyDate, -(l.quantity * l.buyPrice + l.purchaseCharges + l.otherCharges));
      all.add(outflow);
      byType[pos.assetType]?.add(outflow);

      if (l.status == 'closed') {
        final proceeds = (l.quantity * (l.sellPrice ?? 0)) -
            (l.sellCharges ?? 0) -
            (l.sellOtherCharges ?? 0) -
            (l.mtfInterest ?? 0) +
            l.dividend;
        final inflow = CashFlow(l.sellDate ?? now, proceeds);
        all.add(inflow);
        byType[pos.assetType]?.add(inflow);
      } else {
        final value = l.quantity * pos.currentPrice + l.dividend;
        final inflow = CashFlow(now, value);
        all.add(inflow);
        byType[pos.assetType]?.add(inflow);
      }
    }

    setState(() {
      _overall = XirrCalculator.calculate(all);
      _stock = XirrCalculator.calculate(byType['Stock']!);
      _mtf = XirrCalculator.calculate(byType['MTF']!);
      _crypto = XirrCalculator.calculate(byType['Crypto']!);
      _options = XirrCalculator.calculate(byType['Options']!);
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('XIRR Summary')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  AppCard(
                    child: Column(
                      children: [
                        const Text('Overall Portfolio XIRR', style: TextStyle(color: AppColors.textSecondary)),
                        const SizedBox(height: 8),
                        Text(_fmt(_overall), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.green)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _xirrRow('Stock XIRR', _stock),
                  _xirrRow('MTF XIRR', _mtf),
                  _xirrRow('Options XIRR', _options),
                  _xirrRow('Crypto XIRR', _crypto),
                  const SizedBox(height: 8),
                  const Text(
                    'XIRR accounts for the exact timing and size of every buy and sell, giving a true annualised return — unlike a simple % gain.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
    );
  }

  String _fmt(double? v) => v == null ? '—' : '${v.toStringAsFixed(2)}%';

  Widget _xirrRow(String label, double? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            Text(_fmt(value), style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
