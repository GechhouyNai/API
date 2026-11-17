import 'package:dart_frog/dart_frog.dart';
import 'package:mongo_dart/mongo_dart.dart';
import '../../../lib/database/mongo.dart';
import '../../../lib/utils/auth.dart';
import '../../../lib/utils/responses.dart';

Future<Response> onRequest(RequestContext context, String id) async {
  if (context.request.method != HttpMethod.delete) {
    return errorResponse('Method not allowed.', statusCode: 405);
  }
  final userId = await userIdFromRequest(context);
  if (userId == null) return errorResponse('Please log in first.', statusCode: 401);
  try {
    final result = await (await MongoDatabase.collection('favorites'))
        .deleteOne(where.eq('_id', id).eq('userId', userId));
    if (result.nRemoved == 0) return errorResponse('Favorite not found.', statusCode: 404);
    return successResponse('Favorite removed.');
  } catch (e) {
    return errorResponse('Could not remove favorite: $e', statusCode: 500);
  }
}
