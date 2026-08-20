import 'package:flutter/material.dart';
import '../db_helper.dart';
import '../models.dart';
import '../theme.dart';
import '../formatters.dart';

class EditLotScreen extends StatefulWidget {
  final int lotId;
  const EditLotScreen({super.key, required this.lotId});

  @override
  State<EditLotScreen> createState() => _EditLotScreenState();
}

class _EditLotScreenState extends State<EditLotScreen> {
  Lot? _lot;
  Position? _position;
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _qtyCtrl;
  late TextEditingController _buyPriceCtrl;
  late TextEditingController _purchaseChargesCtrl;
  late TextEditingController _otherChargesCtrl;
  late TextEditingController _mtfDailyCtrl;
  late TextEditingController _myFundsCtrl;
  late TextEditingController _brokerFundedCtrl;
  late TextEditingController _dividendCtrl;
  DateTime _buyDate = DateTime.now();
  bool _nifty500 = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = DBHelper.instance;
    final lots = await db.getAllLots();
    final lot = lots.firstWhere((l) => l.id == widget.lotId);
    final position = await db.getPosition(lot.positionId);
    setState(() {
      _lot = lot;
      _position = position;
      _qtyCtrl = TextEditingController(text: lot.quantity.toString());
      _buyPriceCtrl = TextEditingController(text: lot.buyPrice.toString());
      _purchaseChargesCtrl = TextEditingController(text: lot.purchaseCharges.toString());
      _otherChargesCtrl = TextEditingController(text: lot.otherCharges.toString());
      _mtfDailyCtrl = TextEditingController(text: lot.mtfDailyCharge.toString());
      _myFundsCtrl = TextEditingController(text: lot.myFunds.toString());
      _brokerFundedCtrl = TextEditingController(text: lot.brokerFunded.toString());
      _dividendCtrl = TextEditingController(text: lot.dividend.toString());
      _buyDate = lot.buyDate;
      _nifty500 = lot.nifty500;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final p = _position!;
    final isMTF = p.assetType == 'MTF';

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Lot')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            _readonlyField('Symbol', p.symbol),
            const SizedBox(height: 12),
            _readonlyField('Account', p.account),
            const SizedBox(height: 12),
            _readonlyField('Asset Type', p.assetType),
            const SizedBox(height: 12),
            TextFormField(
              controller: _qtyCtrl,
              decoration: const InputDecoration(labelText: 'Quantity'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _buyPriceCtrl,
              decoration: const InputDecoration(labelText: 'Buy Price (₹)'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                    context: context, initialDate: _buyDate, firstDate: DateTime(2015), lastDate: DateTime.now());
                if (picked != null) setState(() => _buyDate = picked);
              },
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Buy Date'),
                child: Text(formatDate(_buyDate)),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _purchaseChargesCtrl,
              decoration: const InputDecoration(labelText: 'Purchase Charges (₹)'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _otherChargesCtrl,
              decoration: const InputDecoration(labelText: 'Other Charges (₹)'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _dividendCtrl,
              decoration: const InputDecoration(labelText: 'Dividend Received (₹)'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            if (isMTF) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _mtfDailyCtrl,
                decoration: const InputDecoration(labelText: 'MTF Daily Charge (₹)'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _myFundsCtrl,
                decoration: const InputDecoration(labelText: 'My Funds (₹)'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _brokerFundedCtrl,
                decoration: const InputDecoration(labelText: 'Broker Funded (₹)'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Nifty 500 at Purchase'),
                value: _nifty500,
                onChanged: (v) => setState(() => _nifty500 = v),
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton(onPressed: _save, child: const Text('Save Changes')),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _delete,
              child: const Text('Delete This Lot', style: TextStyle(color: AppColors.red)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _readonlyField(String label, String value) {
    return InputDecorator(
      decoration: InputDecoration(labelText: label),
      child: Text(value),
    );
  }

  Future<void> _save() async {
    final lot = _lot!;
    lot.quantity = double.tryParse(_qtyCtrl.text) ?? lot.quantity;
    lot.buyPrice = double.tryParse(_buyPriceCtrl.text) ?? lot.buyPrice;
    lot.buyDate = _buyDate;
    lot.purchaseCharges = double.tryParse(_purchaseChargesCtrl.text) ?? 0;
    lot.otherCharges = double.tryParse(_otherChargesCtrl.text) ?? 0;
    lot.dividend = double.tryParse(_dividendCtrl.text) ?? 0;
    lot.mtfDailyCharge = double.tryParse(_mtfDailyCtrl.text) ?? 0;
    lot.myFunds = double.tryParse(_myFundsCtrl.text) ?? 0;
    lot.brokerFunded = double.tryParse(_brokerFundedCtrl.text) ?? 0;
    lot.nifty500 = _nifty500;
    await DBHelper.instance.updateLot(lot);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this lot?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: AppColors.red))),
        ],
      ),
    );
    if (confirm == true) {
      await DBHelper.instance.deleteLot(widget.lotId);
      if (mounted) Navigator.pop(context);
    }
  }
}
