// Core data models for the Trading Tracker app.
// A "Position" is a symbol you hold (Stock / MTF / Crypto / Options).
// A "Lot" is a single purchase batch under a Position. Options are stored
// as a Position with a single Lot that is created already "closed"
// (buy + sell entered together), per the app spec.

class Position {
  int? id;
  String symbol;
  String assetType; // Stock, MTF, Crypto, Options
  String account; // broker / demat account name
  double currentPrice; // manually updated LTP (offline app, no live feed)

  Position({
    this.id,
    required this.symbol,
    required this.assetType,
    required this.account,
    this.currentPrice = 0,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'symbol': symbol,
        'assetType': assetType,
        'account': account,
        'currentPrice': currentPrice,
      };

  factory Position.fromMap(Map<String, dynamic> m) => Position(
        id: m['id'] as int?,
        symbol: m['symbol'] as String,
        assetType: m['assetType'] as String,
        account: m['account'] as String,
        currentPrice: (m['currentPrice'] as num).toDouble(),
      );
}

class Lot {
  int? id;
  int positionId;
  double quantity;
  double buyPrice;
  DateTime buyDate;
  double purchaseCharges;
  double otherCharges;
  double mtfDailyCharge;
  double myFunds;
  double brokerFunded;
  bool nifty500;
  String status; // 'open' or 'closed'
  double dividend;

  // Populated only when status == 'closed'
  double? sellPrice;
  DateTime? sellDate;
  double? sellCharges;
  double? sellOtherCharges;
  double? mtfInterest;

  Lot({
    this.id,
    required this.positionId,
    required this.quantity,
    required this.buyPrice,
    required this.buyDate,
    this.purchaseCharges = 0,
    this.otherCharges = 0,
    this.mtfDailyCharge = 0,
    this.myFunds = 0,
    this.brokerFunded = 0,
    this.nifty500 = false,
    this.status = 'open',
    this.dividend = 0,
    this.sellPrice,
    this.sellDate,
    this.sellCharges,
    this.sellOtherCharges,
    this.mtfInterest,
  });

  double get invested => quantity * buyPrice + purchaseCharges + otherCharges;

  double unrealisedPnl(double ltp) => (ltp - buyPrice) * quantity - purchaseCharges - otherCharges + dividend;

  double unrealisedPnlPct(double ltp) {
    final inv = invested;
    if (inv == 0) return 0;
    return (unrealisedPnl(ltp) / inv) * 100;
  }

  double get grossProfit {
    if (sellPrice == null) return 0;
    return (sellPrice! - buyPrice) * quantity;
  }

  double get totalCharges =>
      purchaseCharges + otherCharges + (sellCharges ?? 0) + (sellOtherCharges ?? 0) + (mtfInterest ?? 0);

  double get netProfit => grossProfit - totalCharges + dividend;

  double get netProfitPct {
    final inv = invested;
    if (inv == 0) return 0;
    return (netProfit / inv) * 100;
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'positionId': positionId,
        'quantity': quantity,
        'buyPrice': buyPrice,
        'buyDate': buyDate.toIso8601String(),
        'purchaseCharges': purchaseCharges,
        'otherCharges': otherCharges,
        'mtfDailyCharge': mtfDailyCharge,
        'myFunds': myFunds,
        'brokerFunded': brokerFunded,
        'nifty500': nifty500 ? 1 : 0,
        'status': status,
        'dividend': dividend,
        'sellPrice': sellPrice,
        'sellDate': sellDate?.toIso8601String(),
        'sellCharges': sellCharges,
        'sellOtherCharges': sellOtherCharges,
        'mtfInterest': mtfInterest,
      };

  factory Lot.fromMap(Map<String, dynamic> m) => Lot(
        id: m['id'] as int?,
        positionId: m['positionId'] as int,
        quantity: (m['quantity'] as num).toDouble(),
        buyPrice: (m['buyPrice'] as num).toDouble(),
        buyDate: DateTime.parse(m['buyDate'] as String),
        purchaseCharges: (m['purchaseCharges'] as num?)?.toDouble() ?? 0,
        otherCharges: (m['otherCharges'] as num?)?.toDouble() ?? 0,
        mtfDailyCharge: (m['mtfDailyCharge'] as num?)?.toDouble() ?? 0,
        myFunds: (m['myFunds'] as num?)?.toDouble() ?? 0,
        brokerFunded: (m['brokerFunded'] as num?)?.toDouble() ?? 0,
        nifty500: (m['nifty500'] as int?) == 1,
        status: m['status'] as String,
        dividend: (m['dividend'] as num?)?.toDouble() ?? 0,
        sellPrice: (m['sellPrice'] as num?)?.toDouble(),
        sellDate: m['sellDate'] != null ? DateTime.parse(m['sellDate'] as String) : null,
        sellCharges: (m['sellCharges'] as num?)?.toDouble(),
        sellOtherCharges: (m['sellOtherCharges'] as num?)?.toDouble(),
        mtfInterest: (m['mtfInterest'] as num?)?.toDouble(),
      );
}

// Convenience wrapper joining a Position with all of its lots, used
// throughout the UI layer.
class PositionWithLots {
  final Position position;
  final List<Lot> lots;

  PositionWithLots(this.position, this.lots);

  List<Lot> get openLots => lots.where((l) => l.status == 'open').toList();
  List<Lot> get closedLots => lots.where((l) => l.status == 'closed').toList();

  double get totalQuantity => openLots.fold(0.0, (s, l) => s + l.quantity);
  double get invested => openLots.fold(0.0, (s, l) => s + l.invested);
  double get avgBuyPrice => totalQuantity == 0 ? 0 : openLots.fold(0.0, (s, l) => s + l.buyPrice * l.quantity) / totalQuantity;
  double get unrealisedPnl => openLots.fold(0.0, (s, l) => s + l.unrealisedPnl(position.currentPrice));
  double get unrealisedPnlPct => invested == 0 ? 0 : (unrealisedPnl / invested) * 100;
}
