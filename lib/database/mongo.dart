import 'package:mongo_dart/mongo_dart.dart';
import '../config/env.dart';

class MongoDatabase {
  static Db? _db;
  static Future<Db>? _connecting;

  static Future<Db> get database async {
    final current = _db;
    if (current != null && current.isConnected) return current;
    return _connecting ??= _connect();
  }

  static Future<Db> _connect() async {
    try {
      final uri = await Env.require('MONGO_URI');
      final db = await Db.create(uri);
      await db.open();
      _db = db;
      return db;
    } catch (_) {
      _connecting = null;
      rethrow;
    }
  }

  static Future<DbCollection> collection(String name) async {
    return (await database).collection(name);
  }
}
