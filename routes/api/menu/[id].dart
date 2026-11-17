import 'package:dart_frog/dart_frog.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:coffee_backend_api/database/mongo.dart';
import 'package:coffee_backend_api/utils/responses.dart';

Future<Response> onRequest(RequestContext context, String id) async {
  if (context.request.method != HttpMethod.get) {
    return errorResponse('Method not allowed.', statusCode: 405);
  }

  try {
    for (final collectionName in ['coffees', 'coffee_items']) {
      final collection = await MongoDatabase.collection(collectionName);
      var item = await collection.findOne(where.eq('_id', id));
      if (item == null && RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(id)) {
        item = await collection.findOne(
          where.eq('_id', ObjectId.fromHexString(id)),
        );
      }
      if (item != null) return Response.json(body: item);
    }
    return errorResponse('Coffee item not found.', statusCode: 404);
  } catch (e) {
    return errorResponse('Could not load coffee item: $e', statusCode: 500);
  }
}
