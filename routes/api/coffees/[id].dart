import 'package:dart_frog/dart_frog.dart';
import 'package:mongo_dart/mongo_dart.dart';
import '../../../lib/database/mongo.dart';
import '../../../lib/utils/auth.dart';
import '../../../lib/utils/responses.dart';

Future<Response> onRequest(RequestContext context, String id) async {
  try {
    final coffees = await MongoDatabase.collection('coffees');
    if (context.request.method == HttpMethod.get) {
      final coffee = await coffees.findOne(where.eq('_id', id));
      if (coffee == null)
        return errorResponse('Coffee not found.', statusCode: 404);
      return successResponse('Coffee loaded.', data: coffee);
    }

    final authError = await requireUser(context);
    if (authError != null) return authError;

    if (context.request.method == HttpMethod.patch) {
      final body = await context.request.json() as Map;
      final changes = <String, dynamic>{};
      for (final key in [
        'title',
        'desc',
        'image',
        'price',
        'type',
        'isAvailable'
      ]) {
        if (body.containsKey(key)) changes[key] = body[key];
      }
      if (changes.isEmpty)
        return errorResponse('No supported fields provided.');
      if (changes['type'] != null &&
          !['HOT', 'ICED'].contains(changes['type'].toString().toUpperCase())) {
        return errorResponse('type must be HOT or ICED.');
      }
      if (changes['price'] != null &&
          (num.tryParse(changes['price'].toString()) ?? -1) < 0) {
        return errorResponse('price must be a non-negative number.');
      }
      if (changes['type'] != null)
        changes['type'] = changes['type'].toString().toUpperCase();
      await coffees.updateOne(where.eq('_id', id),
          modify.set('updatedAt', DateTime.now().toUtc().toIso8601String()));
      var update = modify;
      for (final entry in changes.entries) {
        update = update.set(entry.key, entry.value);
      }
      await coffees.updateOne(where.eq('_id', id), update);
      final updated = await coffees.findOne(where.eq('_id', id));
      if (updated == null)
        return errorResponse('Coffee not found.', statusCode: 404);
      return successResponse('Coffee updated.', data: updated);
    }

    if (context.request.method == HttpMethod.delete) {
      final result = await coffees.deleteOne(where.eq('_id', id));
      if (result.nRemoved == 0)
        return errorResponse('Coffee not found.', statusCode: 404);
      return successResponse('Coffee deleted.');
    }
    return errorResponse('Method not allowed.', statusCode: 405);
  } catch (e) {
    return errorResponse('Coffee request failed: $e', statusCode: 500);
  }
}
