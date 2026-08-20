import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'models.dart';

// Central SQLite access layer. Everything is stored 100% on-device;
// nothing here ever touches the network.
class DBHelper {
  DBHelper._();
  static final DBHelper instance = DBHelper._();

  static Database? _db;
  static const String dbFileName = 'trading_tracker.db';

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<String> dbPath() async {
    final dir = await getApplicationDocumentsDirectory();
    return join(dir.path, dbFileName);
  }

  Future<Database> _initDb() async {
    final path = await dbPath();
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE positions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            symbol TEXT NOT NULL,
            assetType TEXT NOT NULL,
            account TEXT NOT NULL,
            currentPrice REAL NOT NULL DEFAULT 0
          );
        ''');
        await db.execute('''
          CREATE TABLE lots (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            positionId INTEGER NOT NULL,
            quantity REAL NOT NULL,
            buyPrice REAL NOT NULL,
            buyDate TEXT NOT NULL,
            purchaseCharges REAL NOT NULL DEFAULT 0,
            otherCharges REAL NOT NULL DEFAULT 0,
            mtfDailyCharge REAL NOT NULL DEFAULT 0,
            myFunds REAL NOT NULL DEFAULT 0,
            brokerFunded REAL NOT NULL DEFAULT 0,
            nifty500 INTEGER NOT NULL DEFAULT 0,
            status TEXT NOT NULL DEFAULT 'open',
            dividend REAL NOT NULL DEFAULT 0,
            sellPrice REAL,
            sellDate TEXT,
            sellCharges REAL,
            sellOtherCharges REAL,
            mtfInterest REAL,
            FOREIGN KEY (positionId) REFERENCES positions (id) ON DELETE CASCADE
          );
        ''');
        await db.execute('''
          CREATE TABLE accounts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL UNIQUE
          );
        ''');
      },
    );
  }

  // ---------- Positions ----------

  Future<int> insertPosition(Position p) async {
    final db = await database;
    return db.insert('positions', p.toMap()..remove('id'));
  }

  Future<int> updatePosition(Position p) async {
    final db = await database;
    return db.update('positions', p.toMap(), where: 'id = ?', whereArgs: [p.id]);
  }

  Future<List<Position>> getAllPositions() async {
    final db = await database;
    final rows = await db.query('positions', orderBy: 'symbol ASC');
    return rows.map((r) => Position.fromMap(r)).toList();
  }

  Future<Position?> getPosition(int id) async {
    final db = await database;
    final rows = await db.query('positions', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Position.fromMap(rows.first);
  }

  Future<void> deletePosition(int id) async {
    final db = await database;
    await db.delete('lots', where: 'positionId = ?', whereArgs: [id]);
    await db.delete('positions', where: 'id = ?', whereArgs: [id]);
  }

  // ---------- Lots ----------

  Future<int> insertLot(Lot l) async {
    final db = await database;
    return db.insert('lots', l.toMap()..remove('id'));
  }

  Future<int> updateLot(Lot l) async {
    final db = await database;
    return db.update('lots', l.toMap(), where: 'id = ?', whereArgs: [l.id]);
  }

  Future<void> deleteLot(int id) async {
    final db = await database;
    await db.delete('lots', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Lot>> getLotsForPosition(int positionId) async {
    final db = await database;
    final rows = await db.query('lots', where: 'positionId = ?', whereArgs: [positionId], orderBy: 'buyDate ASC');
    return rows.map((r) => Lot.fromMap(r)).toList();
  }

  Future<List<Lot>> getAllLots() async {
    final db = await database;
    final rows = await db.query('lots');
    return rows.map((r) => Lot.fromMap(r)).toList();
  }

  Future<List<Lot>> getClosedLots() async {
    final db = await database;
    final rows = await db.query('lots', where: "status = 'closed'", orderBy: 'sellDate DESC');
    return rows.map((r) => Lot.fromMap(r)).toList();
  }

  Future<List<Lot>> getOpenLots() async {
    final db = await database;
    final rows = await db.query('lots', where: "status = 'open'");
    return rows.map((r) => Lot.fromMap(r)).toList();
  }

  // ---------- Combined helpers ----------

  Future<List<PositionWithLots>> getOpenPositionsWithLots({String? assetType}) async {
    final positions = await getAllPositions();
    final result = <PositionWithLots>[];
    for (final p in positions) {
      if (assetType != null && assetType != 'ALL' && p.assetType.toUpperCase() != assetType.toUpperCase()) {
        continue;
      }
      final lots = await getLotsForPosition(p.id!);
      final openLots = lots.where((l) => l.status == 'open').toList();
      if (openLots.isNotEmpty) {
        result.add(PositionWithLots(p, lots));
      }
    }
    return result;
  }

  // ---------- Accounts ----------

  Future<List<String>> getAccounts() async {
    final db = await database;
    final rows = await db.query('accounts', orderBy: 'name ASC');
    return rows.map((r) => r['name'] as String).toList();
  }

  Future<void> addAccount(String name) async {
    final db = await database;
    await db.insert('accounts', {'name': name}, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  // ---------- Danger zone ----------

  Future<void> wipeAllData() async {
    final db = await database;
    await db.delete('lots');
    await db.delete('positions');
    await db.delete('accounts');
  }

  Future<void> closeAndReopen() async {
    await _db?.close();
    _db = null;
    await database;
  }
}
