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
    final cart = await MongoDatabase.collection('cart');
    if (context.request.method == HttpMethod.get) {
      final items = await cart.find(where.eq('userId', userId)).toList();
      return successResponse('Cart loaded.', data: items);
    }
    if (context.request.method == HttpMethod.post) {
      final body = await context.request.json() as Map;
      final coffeeId = body['coffeeId']?.toString() ?? '';
      final quantity = int.tryParse(body['quantity']?.toString() ?? '1') ?? 0;
      if (coffeeId.isEmpty || quantity < 1) return errorResponse('coffeeId and quantity >= 1 are required.');
      final coffee = await (await MongoDatabase.collection('coffees'))
          .findOne(where.eq('_id', coffeeId));
      if (coffee == null || coffee['isAvailable'] == false) {
        return errorResponse('Coffee not found or unavailable.', statusCode: 404);
      }
      final existing = await cart.findOne(
        where.eq('userId', userId).eq('coffeeId', coffeeId),
      );
      if (existing != null) {
        final newQuantity = (int.tryParse(existing['quantity'].toString()) ?? 0) + quantity;
        await cart.updateOne(where.eq('_id', existing['_id']), modify.set('quantity', newQuantity));
        final updated = await cart.findOne(where.eq('_id', existing['_id']));
        return successResponse('Cart quantity updated.', data: updated);
      }
      final doc = {
        '_id': const Uuid().v4(),
        'userId': userId,
        'coffeeId': coffeeId,
        'title': coffee['title'],
        'price': coffee['price'],
        'quantity': quantity,
      };
      await cart.insertOne(doc);
      return Response.json(statusCode: 201, body: {
        'success': true, 'message': 'Added to cart.', 'data': doc,
      });
    }
    return errorResponse('Method not allowed.', statusCode: 405);
  } catch (e) {
    return errorResponse('Cart request failed: $e', statusCode: 500);
  }
}
