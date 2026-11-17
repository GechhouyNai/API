import 'package:dart_frog/dart_frog.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:uuid/uuid.dart';

import '../../../lib/config/env.dart';
import '../../../lib/database/mongo.dart';
import '../../../lib/services/bakong_service.dart';
import '../../../lib/utils/auth.dart';
import '../../../lib/utils/responses.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return errorResponse('Method not allowed.', statusCode: 405);
  }
  final userId = await userIdFromRequest(context);
  if (userId == null)
    return errorResponse('Please log in first.', statusCode: 401);
  try {
    final body = await context.request.json() as Map;
    final orderId = body['orderId']?.toString().trim() ?? '';
    if (orderId.isEmpty) return errorResponse('orderId is required.');

    final orders = await MongoDatabase.collection('orders');
    final mongoOrderId = RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(orderId)
        ? ObjectId.parse(orderId)
        : orderId;
    final order = await orders
        .findOne(where.eq('_id', mongoOrderId).eq('userId', userId));
    if (order == null)
      return errorResponse('Order not found.', statusCode: 404);
    if (order['paymentStatus'] == 'PAID') {
      return errorResponse('This order is already paid.', statusCode: 409);
    }

    final payments = await MongoDatabase.collection('payments');
    final existing = await payments.findOne(
      where.eq('orderId', orderId).eq('userId', userId).eq('status', 'PENDING'),
    );
    if (existing != null) {
      final expiry = DateTime.tryParse(existing['expiresAt']?.toString() ?? '');
      if (expiry != null && expiry.isAfter(DateTime.now().toUtc())) {
        return Response.json(body: {
          'success': true,
          'message': 'An active payment QR already exists for this order.',
          'data': existing,
        });
      }
      await payments.updateOne(
          where.eq('_id', existing['_id']), modify.set('status', 'EXPIRED'));
    }

    final total =
        num.tryParse((order['total'] ?? order['subtotal'])?.toString() ?? '');
    if (total == null || total <= 0)
      return errorResponse('Order total is invalid.');
    final amountKhr = await BakongService.toKhr(total);
    final paymentId = const Uuid().v4();
    final expiryMinutes =
        int.tryParse(await Env.get('BAKONG_QR_EXPIRY_MINUTES') ?? '10') ?? 10;
    final safeExpiryMinutes = expiryMinutes.clamp(1, 10).toInt();
    final now = DateTime.now().toUtc();
    final expiresAt = now.add(Duration(minutes: safeExpiryMinutes));
    final qrResult = await BakongService.generateMerchantQr(
      amountKhr: amountKhr,
      billNumber: paymentId.substring(0, 20),
      expiresAt: expiresAt,
    );
    final payment = {
      '_id': paymentId,
      'orderId': orderId,
      'userId': userId,
      'amount': amountKhr,
      'currency': 'KHR',
      'orderTotal': total,
      'orderCurrency': await Env.get('BAKONG_ORDER_CURRENCY') ?? 'USD',
      'provider': 'BAKONG_KHQR',
      'acquiringBank': await Env.get('BAKONG_ACQUIRING_BANK') ?? 'ABA',
      'qrString': qrResult.qr,
      'md5': qrResult.md5,
      'status': 'PENDING',
      'createdAt': now.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
    };
    await payments.insertOne(payment);

    return Response.json(statusCode: 201, body: {
      'success': true,
      'message':
          'KHQR payment created. Scan the QR and then check payment status.',
      'data': payment,
    });
  } on BakongException catch (e) {
    return errorResponse(e.message, statusCode: 503);
  } catch (e) {
    return errorResponse('Could not create Bakong payment: $e',
        statusCode: 500);
  }
}
