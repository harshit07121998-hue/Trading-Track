import 'package:flutter/material.dart';
import '../db_helper.dart';
import '../models.dart';
import '../theme.dart';
import '../formatters.dart';

class SquareOffScreen extends StatefulWidget {
  final int positionId;
  const SquareOffScreen({super.key, required this.positionId});

  @override
  State<SquareOffScreen> createState() => _SquareOffScreenState();
}

class _SquareOffScreenState extends State<SquareOffScreen> {
  Position? _position;
  List<Lot> _openLots = [];
  Lot? _selectedLot;
  bool _loading = true;
  bool _done = false;

  final _sellPriceCtrl = TextEditingController();
  final _sellChargesCtrl = TextEditingController(text: '0');
  final _otherChargesCtrl = TextEditingController(text: '0');
  final _mtfInterestCtrl = TextEditingController(text: '0');
  DateTime _sellDate = DateTime.now();

  double? _grossProfit;
  double? _totalCharges;
  double? _netProfit;
  double? _netProfitPct;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await DBHelper.instance.getPosition(widget.positionId);
    final lots = await DBHelper.instance.getLotsForPosition(widget.positionId);
    final open = lots.where((l) => l.status == 'open').toList();
    setState(() {
      _position = p;
      _openLots = open;
      _selectedLot = open.isNotEmpty ? open.first : null;
      if (_selectedLot != null) _sellPriceCtrl.text = p!.currentPrice.toStringAsFixed(2);
      _loading = false;
    });
  }

  void _calculate() {
    final lot = _selectedLot;
    if (lot == null) return;
    final sellPrice = double.tryParse(_sellPriceCtrl.text) ?? 0;
    final sellCharges = double.tryParse(_sellChargesCtrl.text) ?? 0;
    final otherCharges = double.tryParse(_otherChargesCtrl.text) ?? 0;
    final mtfInterest = double.tryParse(_mtfInterestCtrl.text) ?? 0;

    final gross = (sellPrice - lot.buyPrice) * lot.quantity;
    final charges = lot.purchaseCharges + lot.otherCharges + sellCharges + otherCharges + mtfInterest;
    final net = gross - charges;
    final invested = lot.invested;
    final pct = invested == 0 ? 0.0 : (net / invested) * 100;

    setState(() {
      _grossProfit = gross;
      _totalCharges = charges;
      _netProfit = net;
      _netProfitPct = pct;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_openLots.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Square Off')),
        body: const Center(child: Text('No open lots to square off.')),
      );
    }
    if (_done) return _successView();

    final p = _position!;
    return Scaffold(
      appBar: AppBar(title: Text('Square Off - ${p.symbol}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_openLots.length > 1) ...[
            DropdownButtonFormField<Lot>(
              value: _selectedLot,
              decoration: const InputDecoration(labelText: 'Select Lot'),
              items: _openLots
                  .map((l) => DropdownMenuItem(
                        value: l,
                        child: Text('${formatQty(l.quantity)} sh @ ${formatMoney(l.buyPrice)} (${formatDate(l.buyDate)})'),
                      ))
                  .toList(),
              onChanged: (l) => setState(() {
                _selectedLot = l;
                _grossProfit = null;
              }),
            ),
            const SizedBox(height: 12),
          ],
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _rowKV('Available Quantity', formatQty(_selectedLot!.quantity)),
                _rowKV('Buy Price (Avg)', formatMoney(_selectedLot!.buyPrice)),
                _rowKV('Buy Date', formatDate(_selectedLot!.buyDate)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _sellPriceCtrl,
            decoration: const InputDecoration(labelText: 'Sell Price (₹)'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => _calculate(),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () async {
              final picked =
                  await showDatePicker(context: context, initialDate: _sellDate, firstDate: DateTime(2015), lastDate: DateTime.now());
              if (picked != null) setState(() => _sellDate = picked);
            },
            child: InputDecorator(
              decoration: const InputDecoration(labelText: 'Sell Date'),
              child: Text(formatDate(_sellDate)),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _sellChargesCtrl,
            decoration: const InputDecoration(labelText: 'Sell Charges (₹)'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => _calculate(),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _otherChargesCtrl,
            decoration: const InputDecoration(labelText: 'Other Charges (₹)'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => _calculate(),
          ),
          if (p.assetType == 'MTF') ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: _mtfInterestCtrl,
              decoration: const InputDecoration(labelText: 'MTF Interest (₹)'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => _calculate(),
            ),
          ],
          const SizedBox(height: 20),
          if (_grossProfit != null) ...[
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _rowKV('Gross Profit', formatSignedMoney(_grossProfit!), valueColor: pnlColor(_grossProfit!)),
                  _rowKV('Total Charges', formatMoney(_totalCharges!)),
                  const Divider(),
                  _rowKV('Net Profit / Loss', '${formatSignedMoney(_netProfit!)} (${formatPct(_netProfitPct!)})',
                      valueColor: pnlColor(_netProfit!), bold: true),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          ElevatedButton(
            onPressed: () {
              _calculate();
            },
            child: const Text('Calculate P&L'),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.green),
            onPressed: _grossProfit == null ? null : _confirmSquareOff,
            child: const Text('Confirm Square Off'),
          ),
        ],
      ),
    );
  }

  Widget _rowKV(String k, String v, {Color? valueColor, bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k, style: const TextStyle(color: AppColors.textSecondary)),
          Text(v, style: TextStyle(color: valueColor, fontWeight: bold ? FontWeight.bold : FontWeight.w600)),
        ],
      ),
    );
  }

  Future<void> _confirmSquareOff() async {
    final lot = _selectedLot!;
    lot.status = 'closed';
    lot.sellPrice = double.tryParse(_sellPriceCtrl.text) ?? 0;
    lot.sellDate = _sellDate;
    lot.sellCharges = double.tryParse(_sellChargesCtrl.text) ?? 0;
    lot.sellOtherCharges = double.tryParse(_otherChargesCtrl.text) ?? 0;
    lot.mtfInterest = double.tryParse(_mtfInterestCtrl.text) ?? 0;
    await DBHelper.instance.updateLot(lot);
    setState(() => _done = true);
  }

  Widget _successView() {
    return Scaffold(
      appBar: AppBar(title: const Text('Square Off')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: AppColors.green, size: 72),
              const SizedBox(height: 16),
              Text('${_position!.symbol} (Lot) squared off successfully', textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 12),
              Text('Net P&L', style: const TextStyle(color: AppColors.textSecondary)),
              Text(formatSignedMoney(_netProfit ?? 0), style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: pnlColor(_netProfit ?? 0))),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
                child: const Text('Back to Open Positions'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
