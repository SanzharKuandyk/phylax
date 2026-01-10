import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/blocking_rule.dart';

class RulesDatabase {
  static final RulesDatabase instance = RulesDatabase._init();
  static Database? _database;

  RulesDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('blocking_rules.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 3,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE rules (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        type INTEGER NOT NULL,
        pattern TEXT NOT NULL,
        order_index INTEGER NOT NULL,
        enabled INTEGER NOT NULL DEFAULT 1,
        image_path TEXT,
        overlay_text TEXT DEFAULT 'Stay Focused!',
        text_position_x REAL DEFAULT 0.5,
        text_position_y REAL DEFAULT 0.5,
        image_scale REAL DEFAULT 1.0,
        image_offset_x REAL DEFAULT 0.0,
        image_offset_y REAL DEFAULT 0.0
      )
    ''');
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE rules ADD COLUMN name TEXT');
    }
  }

  Future<BlockingRule> insertRule(BlockingRule rule) async {
    final db = await database;

    // If no order specified, add at the end
    int order = rule.order;
    if (order < 0) {
      final result = await db.rawQuery(
        'SELECT MAX(order_index) as max_order FROM rules',
      );
      final maxOrder = result.first['max_order'] as int? ?? -1;
      order = maxOrder + 1;
    }

    final ruleWithOrder = rule.copyWith(order: order);
    final id = await db.insert('rules', ruleWithOrder.toMap());
    return ruleWithOrder.copyWith(id: id);
  }

  Future<List<BlockingRule>> getAllRules() async {
    final db = await database;
    final result = await db.query('rules', orderBy: 'order_index ASC');
    return result.map((map) => BlockingRule.fromMap(map)).toList();
  }

  Future<List<BlockingRule>> getEnabledRules() async {
    final db = await database;
    final result = await db.query(
      'rules',
      where: 'enabled = ?',
      whereArgs: [1],
      orderBy: 'order_index ASC',
    );
    return result.map((map) => BlockingRule.fromMap(map)).toList();
  }

  Future<int> updateRule(BlockingRule rule) async {
    final db = await database;
    return db.update(
      'rules',
      rule.toMap(),
      where: 'id = ?',
      whereArgs: [rule.id],
    );
  }

  Future<int> deleteRule(int id) async {
    final db = await database;
    return db.delete('rules', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> reorderRules(List<BlockingRule> rules) async {
    final db = await database;
    final batch = db.batch();

    for (int i = 0; i < rules.length; i++) {
      batch.update(
        'rules',
        {'order_index': i},
        where: 'id = ?',
        whereArgs: [rules[i].id],
      );
    }

    await batch.commit(noResult: true);
  }

  Future<void> close() async {
    final db = await database;
    db.close();
  }
}
