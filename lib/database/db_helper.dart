import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DbHelper {
  static final DbHelper instance = DbHelper._init();
  static Database? _database;

  DbHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('scans_history.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path, 
      version: 1, 
      onCreate: _createDB
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE scans (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        scan_date TEXT NOT NULL,
        detected_items TEXT NOT NULL
      )
    ''');
  }

  Future<int> deleteScan(int id) async {
  final db = await instance.database;
  return await db.delete(
    'scans',
    where: 'id = ?',
    whereArgs: [id],
  );
}

  Future<int> insertScan(Map<String, dynamic> scan) async {
    final db = await instance.database;
    return await db.insert('scans', scan);
  }

  Future<List<Map<String, dynamic>>> fetchAllScans() async {
    final db = await instance.database;
    return await db.query('scans', orderBy: 'id DESC'); // Najnowsze na górze
  }

  Future<int> updateScanTitle(int id, String newTitle) async {
    final db = await instance.database;
    return await db.update('scans', {'title': newTitle}, where: 'id = ?', whereArgs: [id]);
  }
}