import 'package:dart_frog/dart_frog.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:uuid/uuid.dart';
import '../../../lib/database/mongo.dart';
import '../../../lib/utils/auth.dart';
import '../../../lib/utils/responses.dart';

Future<Response> onRequest(RequestContext context) async {
  final userId = await userIdFromRequest(context);
  if (userId == null) return errorResponse('Please log in first.', statusCode: 401);
  try {
    final favorites = await MongoDatabase.collection('favorites');
    if (context.request.method == HttpMethod.get) {
      final data = await favorites.find(where.eq('userId', userId)).toList();
      return successResponse('Favorites loaded.', data: data);
    }
    if (context.request.method == HttpMethod.post) {
      final body = await context.request.json() as Map;
      final coffeeId = body['coffeeId']?.toString() ?? '';
      if (coffeeId.isEmpty) return errorResponse('coffeeId is required.');
      final existing = await favorites.findOne(
        where.eq('userId', userId).eq('coffeeId', coffeeId),
      );
      if (existing != null) return successResponse('Already in favorites.', data: existing);
      final doc = {
        '_id': const Uuid().v4(),
        'userId': userId,
        'coffeeId': coffeeId,
        'createdAt': DateTime.now().toUtc().toIso8601String(),
      };
      await favorites.insertOne(doc);
      return Response.json(statusCode: 201, body: {
        'success': true, 'message': 'Added to favorites.', 'data': doc,
      });
    }
    return errorResponse('Method not allowed.', statusCode: 405);
  } catch (e) {
    return errorResponse('Favorites request failed: $e', statusCode: 500);
  }
}
