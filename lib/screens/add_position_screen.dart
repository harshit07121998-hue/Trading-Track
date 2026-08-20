import 'package:flutter/material.dart';
import '../db_helper.dart';
import '../models.dart';
import '../theme.dart';
import '../formatters.dart';

// Handles two flows:
// 1. Adding a brand-new position (Stock/MTF/Crypto) with its first lot, or
//    adding another lot to an existing symbol under the same asset type.
// 2. Adding an Option: buy + sell entered together, saved directly as a
//    closed trade (per the app's rule that Options never appear as open
//    positions).
class AddPositionScreen extends StatefulWidget {
  final String initialAssetType;
  final int? existingPositionId; // when adding a lot to an existing position

  const AddPositionScreen({super.key, this.initialAssetType = 'Stock', this.existingPositionId});

  @override
  State<AddPositionScreen> createState() => _AddPositionScreenState();
}

class _AddPositionScreenState extends State<AddPositionScreen> {
  final _formKey = GlobalKey<FormState>();
  late String _assetType;
  final _symbolCtrl = TextEditingController();
  final _accountCtrl = TextEditingController(text: 'Default');
  final _qtyCtrl = TextEditingController();
  final _buyPriceCtrl = TextEditingController();
  final _purchaseChargesCtrl = TextEditingController(text: '0');
  final _otherChargesCtrl = TextEditingController(text: '0');
  final _mtfDailyCtrl = TextEditingController(text: '0');
  final _myFundsCtrl = TextEditingController(text: '0');
  final _brokerFundedCtrl = TextEditingController(text: '0');
  bool _nifty500 = false;
  DateTime _buyDate = DateTime.now();

  // Options-only fields
  final _sellPriceCtrl = TextEditingController();
  final _sellChargesCtrl = TextEditingController(text: '0');
  DateTime _sellDate = DateTime.now();

  bool get _isOptions => _assetType == 'Options';
  bool get _isMTF => _assetType == 'MTF';

  @override
  void initState() {
    super.initState();
    _assetType = widget.initialAssetType;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.existingPositionId != null ? 'Add Lot' : 'Add Position')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            if (widget.existingPositionId == null) ...[
              DropdownButtonFormField<String>(
                value: _assetType,
                decoration: const InputDecoration(labelText: 'Asset Type'),
                items: const ['Stock', 'MTF', 'Crypto', 'Options']
                    .map((a) => DropdownMenuItem(value: a, child: Text(a)))
                    .toList(),
                onChanged: (v) => setState(() => _assetType = v!),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _symbolCtrl,
                decoration: const InputDecoration(labelText: 'Symbol (e.g. HDFC Bank, BTC)'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _accountCtrl,
                decoration: const InputDecoration(labelText: 'Account / Broker'),
              ),
              const SizedBox(height: 12),
            ],
            TextFormField(
              controller: _qtyCtrl,
              decoration: InputDecoration(labelText: _assetType == 'Crypto' ? 'Quantity (units)' : 'Quantity (shares)'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (v) => (v == null || double.tryParse(v) == null) ? 'Enter a valid number' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _buyPriceCtrl,
              decoration: const InputDecoration(labelText: 'Buy Price (₹)'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (v) => (v == null || double.tryParse(v) == null) ? 'Enter a valid number' : null,
            ),
            const SizedBox(height: 12),
            _dateField('Buy Date', _buyDate, (d) => setState(() => _buyDate = d)),
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
            if (_isMTF) ...[
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
            if (_isOptions) ...[
              const Divider(height: 32),
              const Text('Sell Details (Options are recorded as Buy + Sell together)',
                  style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 12),
              TextFormField(
                controller: _sellPriceCtrl,
                decoration: const InputDecoration(labelText: 'Sell Price (₹)'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) => (v == null || double.tryParse(v) == null) ? 'Enter a valid number' : null,
              ),
              const SizedBox(height: 12),
              _dateField('Sell Date', _sellDate, (d) => setState(() => _sellDate = d)),
              const SizedBox(height: 12),
              TextFormField(
                controller: _sellChargesCtrl,
                decoration: const InputDecoration(labelText: 'Sell Charges (₹)'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton(onPressed: _save, child: const Text('Save')),
          ],
        ),
      ),
    );
  }

  Widget _dateField(String label, DateTime value, void Function(DateTime) onPicked) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value,
          firstDate: DateTime(2015),
          lastDate: DateTime.now().add(const Duration(days: 1)),
        );
        if (picked != null) onPicked(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Text(formatDate(value)),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final qty = double.parse(_qtyCtrl.text);
    final buyPrice = double.parse(_buyPriceCtrl.text);
    final purchaseCharges = double.tryParse(_purchaseChargesCtrl.text) ?? 0;
    final otherCharges = double.tryParse(_otherChargesCtrl.text) ?? 0;

    int positionId;
    if (widget.existingPositionId != null) {
      positionId = widget.existingPositionId!;
    } else {
      final position = Position(
        symbol: _symbolCtrl.text.trim(),
        assetType: _assetType,
        account: _accountCtrl.text.trim().isEmpty ? 'Default' : _accountCtrl.text.trim(),
        currentPrice: buyPrice,
      );
      positionId = await DBHelper.instance.insertPosition(position);
      if (_accountCtrl.text.trim().isNotEmpty) {
        await DBHelper.instance.addAccount(_accountCtrl.text.trim());
      }
    }

    if (_isOptions) {
      final lot = Lot(
        positionId: positionId,
        quantity: qty,
        buyPrice: buyPrice,
        buyDate: _buyDate,
        purchaseCharges: purchaseCharges,
        otherCharges: otherCharges,
        status: 'closed',
        sellPrice: double.parse(_sellPriceCtrl.text),
        sellDate: _sellDate,
        sellCharges: double.tryParse(_sellChargesCtrl.text) ?? 0,
        sellOtherCharges: 0,
        mtfInterest: 0,
      );
      await DBHelper.instance.insertLot(lot);
    } else {
      final lot = Lot(
        positionId: positionId,
        quantity: qty,
        buyPrice: buyPrice,
        buyDate: _buyDate,
        purchaseCharges: purchaseCharges,
        otherCharges: otherCharges,
        mtfDailyCharge: _isMTF ? (double.tryParse(_mtfDailyCtrl.text) ?? 0) : 0,
        myFunds: _isMTF ? (double.tryParse(_myFundsCtrl.text) ?? 0) : 0,
        brokerFunded: _isMTF ? (double.tryParse(_brokerFundedCtrl.text) ?? 0) : 0,
        nifty500: _isMTF ? _nifty500 : false,
        status: 'open',
      );
      await DBHelper.instance.insertLot(lot);
    }

    if (mounted) Navigator.pop(context);
  }
}
