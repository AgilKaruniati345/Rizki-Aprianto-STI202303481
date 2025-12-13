import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/destination_model.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('destinations.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const realType = 'REAL NOT NULL';
    const textTypeNullable = 'TEXT';

    await db.execute('''
      CREATE TABLE destinations (
        id $idType,
        name $textType,
        description $textType,
        location $textType,
        latitude $realType,
        longitude $realType,
        imagePath $textTypeNullable,
        visitDate $textTypeNullable,
        visitTime $textTypeNullable,
        createdAt $textType
      )
    ''');
  }

  Future<int> createDestination(Destination destination) async {
    final db = await instance.database;
    return await db.insert('destinations', destination.toMap());
  }

  Future<List<Destination>> getAllDestinations() async {
    final db = await instance.database;
    final result = await db.query('destinations', orderBy: 'createdAt DESC');
    return result.map((json) => Destination.fromMap(json)).toList();
  }

  Future<Destination?> getDestination(int id) async {
    final db = await instance.database;
    final maps = await db.query(
      'destinations',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return Destination.fromMap(maps.first);
    }
    return null;
  }

  Future<int> updateDestination(Destination destination) async {
    final db = await instance.database;
    return db.update(
      'destinations',
      destination.toMap(),
      where: 'id = ?',
      whereArgs: [destination.id],
    );
  }

  Future<int> deleteDestination(int id) async {
    final db = await instance.database;
    return await db.delete('destinations', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Destination>> searchDestinations(String query) async {
    final db = await instance.database;
    final result = await db.query(
      'destinations',
      where: 'name LIKE ? OR location LIKE ? OR description LIKE ?',
      whereArgs: ['%$query%', '%$query%', '%$query%'],
      orderBy: 'createdAt DESC',
    );
    return result.map((json) => Destination.fromMap(json)).toList();
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
