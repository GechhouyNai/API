import 'dart:io';

class Env {
  static Map<String, String>? _values;

  static Future<void> load() async {
    if (_values != null) return;
    final values = <String, String>{};
    final file = File('.env');
    if (await file.exists()) {
      for (final rawLine in await file.readAsLines()) {
        final line = rawLine.trim();
        if (line.isEmpty || line.startsWith('#')) continue;
        final index = line.indexOf('=');
        if (index <= 0) continue;
        final key = line.substring(0, index).trim();
        var value = line.substring(index + 1).trim();
        if (value.length >= 2 &&
            ((value.startsWith('"') && value.endsWith('"')) ||
             (value.startsWith("'") && value.endsWith("'")))) {
          value = value.substring(1, value.length - 1);
        }
        values[key] = value;
      }
    }
    _values = values;
  }

  static Future<String?> get(String key) async {
    await load();
    return Platform.environment[key] ?? _values![key];
  }

  static Future<String> require(String key) async {
    final value = await get(key);
    if (value == null || value.isEmpty) {
      throw StateError('$key is missing. Check your .env file.');
    }
    return value;
  }
}
