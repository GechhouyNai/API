import 'package:dart_frog/dart_frog.dart';
import 'package:mongo_dart/mongo_dart.dart';

import '../../../../lib/config/env.dart';
import '../../../../lib/database/mongo.dart';
import '../../../../lib/services/bakong_service.dart';
import '../../../../lib/utils/auth.dart';
import '../../../../lib/utils/responses.dart';

/// POST /api/payments/bakong/verify
/// Body: {"md5":"..."}
Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return errorResponse('Method not allowed.', statusCode: 405);
  }
  final userId = await userIdFromRequest(context);
  if (userId == null) return errorResponse('Please log in first.', statusCode: 401);

  try {
    final body = await context.request.json() as Map;
    final md5 = body['md5']?.toString().trim() ?? '';
    if (md5.isEmpty) return errorResponse('md5 is required.');

    final payments = await MongoDatabase.collection('payments');
    final payment = await payments.findOne(where.eq('md5', md5).eq('userId', userId));
    if (payment == null) return errorResponse('Payment not found.', statusCode: 404);
    if (payment['status'] == 'PAID') {
      return successResponse('Payment is already verified.', data: payment);
    }

    final result = await BakongService.checkTransactionByMd5(md5);
    final tx = result['data'];
    if (result['responseCode'] != 0 || tx is! Map) {
      final expiry = DateTime.tryParse(payment['expiresAt']?.toString() ?? '');
      if (expiry != null && DateTime.now().toUtc().isAfter(expiry)) {
        await payments.updateOne(where.eq('_id', payment['_id']), modify.set('status', 'EXPIRED'));
        return successResponse('QR expired without a confirmed payment.', data: {
          'paymentId': payment['_id'], 'status': 'EXPIRED',
        });
      }
      return successResponse('Payment is not confirmed yet.', data: {
        'paymentId': payment['_id'], 'status': 'PENDING',
        'bakongMessage': result['responseMessage'],
      });
    }

    final transaction = Map<String, dynamic>.from(tx);
    final expectedAccount = await Env.require('BAKONG_ACCOUNT_ID');
    final receivedAccount = transaction['toAccountId']?.toString() ?? '';
    final receivedCurrency = transaction['currency']?.toString().toUpperCase() ?? '';
    final receivedAmount = num.tryParse(transaction['amount']?.toString() ?? '');
    final expectedAmount = num.tryParse(payment['amount']?.toString() ?? '');
    if (receivedAccount.toLowerCase() != expectedAccount.toLowerCase()) {
      return errorResponse('Transaction receiving account does not match the merchant.', statusCode: 409);
    }
    if (receivedCurrency != 'KHR' || receivedAmount == null || expectedAmount == null || receivedAmount != expectedAmount) {
      return errorResponse('Transaction amount or currency does not match this payment.', statusCode: 409);
    }

    final hash = transaction['hash']?.toString() ?? '';
    if (hash.isEmpty) return errorResponse('Bakong response has no transaction hash.', statusCode: 502);
    final duplicate = await payments.findOne(where.eq('transactionHash', hash));
    if (duplicate != null && duplicate['_id'] != payment['_id']) {
      return errorResponse('This Bakong transaction has already been used.', statusCode: 409);
    }

    final now = DateTime.now().toUtc().toIso8601String();
    await payments.updateOne(
      where.eq('_id', payment['_id']).eq('status', 'PENDING'),
      modify.set('status', 'PAID')
        .set('transactionHash', hash)
        .set('fromAccountId', transaction['fromAccountId'])
        .set('verifiedAt', now),
    );
    final orderId = payment['orderId'];
    final mongoOrderId =
        orderId is String && RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(orderId)
            ? ObjectId.parse(orderId)
            : orderId;
    await (await MongoDatabase.collection('orders')).updateOne(
      where.eq('_id', mongoOrderId).eq('userId', userId).ne('paymentStatus', 'PAID'),
      modify.set('paymentStatus', 'PAID').set('status', 'CONFIRMED').set('paidAt', now),
    );
    final updated = await payments.findOne(where.eq('_id', payment['_id']));
    return successResponse('Bakong payment verified successfully.', data: updated);
  } on BakongException catch (e) {
    return errorResponse(e.message, statusCode: 502);
  } catch (e) {
    return errorResponse('Could not verify Bakong payment: $e', statusCode: 500);
  }
}
