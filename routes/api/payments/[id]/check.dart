import 'package:dart_frog/dart_frog.dart';
import 'package:mongo_dart/mongo_dart.dart';

import '../../../../lib/config/env.dart';
import '../../../../lib/database/mongo.dart';
import '../../../../lib/services/bakong_service.dart';
import '../../../../lib/utils/auth.dart';
import '../../../../lib/utils/responses.dart';

Future<Response> onRequest(RequestContext context, String id) async {
  if (context.request.method != HttpMethod.post) {
    return errorResponse('Method not allowed.', statusCode: 405);
  }
  final userId = await userIdFromRequest(context);
  if (userId == null) return errorResponse('Please log in first.', statusCode: 401);

  try {
    final payments = await MongoDatabase.collection('payments');
    final payment = await payments.findOne(where.eq('_id', id).eq('userId', userId));
    if (payment == null) return errorResponse('Payment not found.', statusCode: 404);
    if (payment['status'] == 'PAID') {
      return successResponse('Payment already verified.', data: payment);
    }

    final md5 = payment['md5']?.toString() ?? '';
    if (md5.isEmpty) return errorResponse('Payment has no QR MD5 hash.', statusCode: 409);

    final result = await BakongService.checkTransactionByMd5(md5);
    final responseCode = result['responseCode'];
    final data = result['data'];

    if (responseCode != 0 || data is! Map) {
      final expiresAt = DateTime.tryParse(payment['expiresAt']?.toString() ?? '');
      if (expiresAt != null && DateTime.now().toUtc().isAfter(expiresAt)) {
        await payments.updateOne(where.eq('_id', id), modify.set('status', 'EXPIRED'));
        final expired = await payments.findOne(where.eq('_id', id));
        return successResponse('No payment was found before the QR expired.', data: expired);
      }
      return successResponse('Payment is not confirmed yet. Try checking again shortly.', data: {
        'paymentId': id,
        'status': 'PENDING',
        'bakongMessage': result['responseMessage'],
      });
    }

    final transaction = Map<String, dynamic>.from(data);
    final expectedAccount = await Env.require('BAKONG_ACCOUNT_ID');
    final actualAccount = transaction['toAccountId']?.toString() ?? '';
    final actualCurrency = transaction['currency']?.toString().toUpperCase() ?? '';
    final actualAmount = num.tryParse(transaction['amount']?.toString() ?? '');
    final expectedAmount = num.tryParse(payment['amount']?.toString() ?? '');

    if (actualAccount.toLowerCase() != expectedAccount.toLowerCase()) {
      return errorResponse('Bakong transaction receiving account does not match this merchant.', statusCode: 409);
    }
    if (actualCurrency != 'KHR' || expectedAmount == null || actualAmount == null || actualAmount != expectedAmount) {
      return errorResponse('Bakong transaction amount or currency does not match this payment.', statusCode: 409);
    }

    final transactionHash = transaction['hash']?.toString() ?? '';
    if (transactionHash.isEmpty) return errorResponse('Bakong response did not include a transaction hash.', statusCode: 502);

    final duplicate = await payments.findOne(where.eq('transactionHash', transactionHash));
    if (duplicate != null && duplicate['_id'] != id) {
      return errorResponse('This Bakong transaction has already been used.', statusCode: 409);
    }

    final now = DateTime.now().toUtc().toIso8601String();
    await payments.updateOne(
      where.eq('_id', id).eq('status', 'PENDING'),
      modify
        .set('status', 'PAID')
        .set('transactionHash', transactionHash)
        .set('fromAccountId', transaction['fromAccountId'])
        .set('verifiedAt', now)
        .set('bakongResponseMessage', result['responseMessage']),
    );
    final orderId = payment['orderId'];
    final mongoOrderId =
        orderId is String && RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(orderId)
            ? ObjectId.parse(orderId)
            : orderId;
    await (await MongoDatabase.collection('orders')).updateOne(
      where.eq('_id', mongoOrderId).eq('userId', userId).ne('paymentStatus', 'PAID'),
      modify.set('paymentStatus', 'PAID').set('status', 'CONFIRMED'),
    );

    final updated = await payments.findOne(where.eq('_id', id));
    return successResponse('Bakong payment verified successfully.', data: updated);
  } on BakongException catch (e) {
    return errorResponse(e.message, statusCode: 502);
  } catch (e) {
    return errorResponse('Could not verify Bakong payment: $e', statusCode: 500);
  }
}
