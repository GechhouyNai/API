import 'package:dart_frog/dart_frog.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:coffee_backend_api/database/mongo.dart';
import 'package:coffee_backend_api/utils/responses.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.get) {
    return errorResponse('Method not allowed.', statusCode: 405);
  }

  try {
    final stores = await (await MongoDatabase.collection('stores'))
        .find(where.eq('active', true))
        .toList();
    return Response.json(body: {'stores': stores});
  } catch (e) {
    return errorResponse('Could not load stores: $e', statusCode: 500);
  }
}
