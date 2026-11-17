import 'dart:math';

import 'package:dart_frog/dart_frog.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:coffee_backend_api/config/env.dart';
import 'package:coffee_backend_api/database/mongo.dart';
import 'package:coffee_backend_api/utils/responses.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return errorResponse('Method not allowed.', statusCode: 405);
  }

  try {
    final body = await context.request.json() as Map;
    final email = body['email']?.toString().trim().toLowerCase() ?? '';
    if (email.isEmpty) return errorResponse('Email is required.');

    final users = await MongoDatabase.collection('users');
    final user = await users.findOne(where.eq('email', email));
    if (user == null) {
      return successResponse(
        'If that email exists, a reset code was generated.',
      );
    }

    final code = (100000 + Random.secure().nextInt(900000)).toString();
    final expiresAt = DateTime.now().toUtc().add(const Duration(minutes: 15));
    await users.updateOne(
      where.eq('_id', user['_id']),
      modify
          .set('resetCode', code)
          .set('resetCodeExpiresAt', expiresAt.toIso8601String()),
    );

    final response = <String, dynamic>{
      'success': true,
      'message': 'Reset code generated.',
    };
    if ((await Env.get('RESET_CODE_IN_RESPONSE'))?.toLowerCase() == 'true') {
      response['devResetCode'] = code;
    }
    return Response.json(body: response);
  } catch (e) {
    return errorResponse('Could not generate reset code: $e', statusCode: 500);
  }
}
