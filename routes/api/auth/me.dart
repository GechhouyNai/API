import 'package:dart_frog/dart_frog.dart';
import 'package:mongo_dart/mongo_dart.dart';
import '../../../lib/database/mongo.dart';
import '../../../lib/utils/auth.dart';
import '../../../lib/utils/responses.dart';

Future<Response> onRequest(RequestContext context) async {
  final userId = await userIdFromRequest(context);
  if (userId == null) return errorResponse('Please log in first.', statusCode: 401);
  try {
    final user = await (await MongoDatabase.collection('users'))
        .findOne(where.eq('_id', userId));
    if (user == null) return errorResponse('User not found.', statusCode: 404);
    user.remove('passwordHash');
    return successResponse('Profile loaded.', data: user);
  } catch (e) {
    return errorResponse('Could not load profile: $e', statusCode: 500);
  }
}
