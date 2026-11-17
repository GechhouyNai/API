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
    final orders = await MongoDatabase.collection('orders');
    if (context.request.method == HttpMethod.get) {
      final data = await orders.find(where.eq('userId', userId)).toList();
      return successResponse('Order history loaded.', data: data);
    }
    if (context.request.method == HttpMethod.post) {
      final cart = await MongoDatabase.collection('cart');
      final items = await cart.find(where.eq('userId', userId)).toList();
      if (items.isEmpty) return errorResponse('Your cart is empty.');
      final total = items.fold<num>(0, (sum, item) {
        final price = num.tryParse(item['price'].toString()) ?? 0;
        final qty = int.tryParse(item['quantity'].toString()) ?? 0;
        return sum + price * qty;
      });
      final body = await context.request.json() as Map;
      final doc = {
        '_id': const Uuid().v4(),
        'userId': userId,
        'items': items.map((item) => {
          'coffeeId': item['coffeeId'],
          'title': item['title'],
          'price': item['price'],
          'quantity': item['quantity'],
        }).toList(),
        'total': total,
        'deliveryAddress': body['deliveryAddress']?.toString() ?? '',
        'status': 'PENDING',
        'paymentStatus': 'UNPAID',
        'createdAt': DateTime.now().toUtc().toIso8601String(),
      };
      await orders.insertOne(doc);
      await cart.deleteMany(where.eq('userId', userId));
      return Response.json(statusCode: 201, body: {
        'success': true, 'message': 'Order placed. Payment is still pending.', 'data': doc,
      });
    }
    return errorResponse('Method not allowed.', statusCode: 405);
  } catch (e) {
    return errorResponse('Order request failed: $e', statusCode: 500);
  }
}
