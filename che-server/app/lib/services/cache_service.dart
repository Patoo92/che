import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class CacheService {
  static Database? _db;

  static Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  static Future<Database> _initDb() async {
    final path = join(await getDatabasesPath(), 'che_cache.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE cache (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            tipo TEXT NOT NULL,
            contenido TEXT NOT NULL,
            timestamp TEXT NOT NULL,
            sincronizado INTEGER DEFAULT 0
          )
        ''');
      },
    );
  }

  static Future<void> guardar(String tipo, String contenido) async {
    final d = await db;
    await d.insert('cache', {
      'tipo': tipo,
      'contenido': contenido,
      'timestamp': DateTime.now().toIso8601String(),
      'sincronizado': 0,
    });
  }

  static Future<List<Map<String, dynamic>>> obtenerNoSincronizados() async {
    final d = await db;
    return d.query('cache', where: 'sincronizado = 0');
  }

  static Future<void> marcarSincronizado(int id) async {
    final d = await db;
    await d.update('cache', {'sincronizado': 1}, where: 'id = ?', whereArgs: [id]);
  }
}
