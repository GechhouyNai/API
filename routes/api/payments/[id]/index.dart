import 'package:dart_frog/dart_frog.dart';
import 'package:mongo_dart/mongo_dart.dart';
import '../../../../lib/database/mongo.dart';
import '../../../../lib/utils/auth.dart';
import '../../../../lib/utils/responses.dart';

Future<Response> onRequest(RequestContext context, String id) async {
  if (context.request.method != HttpMethod.get) {
    return errorResponse('Method not allowed.', statusCode: 405);
  }
  final userId = await userIdFromRequest(context);
  if (userId == null)
    return errorResponse('Please log in first.', statusCode: 401);
  try {
    final payment = await (await MongoDatabase.collection('payments'))
        .findOne(where.eq('_id', id).eq('userId', userId));
    if (payment == null)
      return errorResponse('Payment not found.', statusCode: 404);
    return successResponse('Payment loaded.', data: payment);
  } catch (e) {
    return errorResponse('Could not load payment: $e', statusCode: 500);
  }
}
