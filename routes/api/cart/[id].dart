import 'package:dart_frog/dart_frog.dart';
import 'package:mongo_dart/mongo_dart.dart';
import '../../../lib/database/mongo.dart';
import '../../../lib/utils/auth.dart';
import '../../../lib/utils/responses.dart';

Future<Response> onRequest(RequestContext context, String id) async {
  final userId = await userIdFromRequest(context);
  if (userId == null) return errorResponse('Please log in first.', statusCode: 401);
  try {
    final cart = await MongoDatabase.collection('cart');
    if (context.request.method == HttpMethod.patch) {
      final body = await context.request.json() as Map;
      final quantity = int.tryParse(body['quantity']?.toString() ?? '') ?? 0;
      if (quantity < 1) return errorResponse('quantity must be at least 1.');
      final result = await cart.updateOne(
        where.eq('_id', id).eq('userId', userId),
        modify.set('quantity', quantity),
      );
      if (result.nMatched == 0) return errorResponse('Cart item not found.', statusCode: 404);
      final updated = await cart.findOne(where.eq('_id', id));
      return successResponse('Cart item updated.', data: updated);
    }
    if (context.request.method == HttpMethod.delete) {
      final result = await cart.deleteOne(where.eq('_id', id).eq('userId', userId));
      if (result.nRemoved == 0) return errorResponse('Cart item not found.', statusCode: 404);
      return successResponse('Cart item removed.');
    }
    return errorResponse('Method not allowed.', statusCode: 405);
  } catch (e) {
    return errorResponse('Cart request failed: $e', statusCode: 500);
  }
}
