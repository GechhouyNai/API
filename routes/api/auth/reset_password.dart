import 'package:bcrypt/bcrypt.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:coffee_backend_api/database/mongo.dart';
import 'package:coffee_backend_api/utils/responses.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return errorResponse('Method not allowed.', statusCode: 405);
  }

  try {
    final body = await context.request.json() as Map;
    final email = body['email']?.toString().trim().toLowerCase() ?? '';
    final code = body['code']?.toString().trim() ?? '';
    final password = body['newPassword']?.toString() ?? '';
    if (email.isEmpty || code.isEmpty || password.length < 6) {
      return errorResponse(
        'Email, code, and newPassword (at least 6 characters) are required.',
      );
    }

    final users = await MongoDatabase.collection('users');
    final user = await users.findOne(
      where.eq('email', email).eq('resetCode', code),
    );
    if (user == null) return errorResponse('Invalid email or reset code.');

    final expiryValue = user['resetCodeExpiresAt'];
    final expiresAt = expiryValue is DateTime
        ? expiryValue
        : DateTime.tryParse(expiryValue?.toString() ?? '');
    if (expiresAt == null || !DateTime.now().toUtc().isBefore(expiresAt)) {
      return errorResponse('Reset code has expired.');
    }

    await users.updateOne(
      where.eq('_id', user['_id']),
      modify
          .set('passwordHash', BCrypt.hashpw(password, BCrypt.gensalt()))
          .unset('resetCode')
          .unset('resetCodeExpiresAt'),
    );
    return successResponse('Password updated successfully.');
  } catch (e) {
    return errorResponse('Could not reset password: $e', statusCode: 500);
  }
}
