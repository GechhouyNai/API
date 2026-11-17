import 'package:dart_frog/dart_frog.dart';
import 'package:bcrypt/bcrypt.dart';
import 'package:mongo_dart/mongo_dart.dart';
import '../../../lib/database/mongo.dart';
import '../../../lib/utils/auth.dart';
import '../../../lib/utils/responses.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return errorResponse('Method not allowed.', statusCode: 405);
  }
  try {
    final body = await context.request.json() as Map;
    final email = body['email']?.toString().trim().toLowerCase() ?? '';
    final password = body['password']?.toString() ?? '';
    if (email.isEmpty || password.isEmpty) {
      return errorResponse('Email and password are required.');
    }

    final users = await MongoDatabase.collection('users');
    final user = await users.findOne(where.eq('email', email));
    if (user == null ||
        !BCrypt.checkpw(password, user['passwordHash']?.toString() ?? '')) {
      return errorResponse('Invalid email or password.', statusCode: 401);
    }

    final token = await createToken(user['_id'].toString());
    return Response.json(body: {
      'success': true,
      'message': 'Login successful.',
      'token': token,
      'data': {
        'id': user['_id'],
        'name': user['name'],
        'email': user['email'],
        'phone': user['phone'],
      },
    });
  } catch (e) {
    return errorResponse('Could not log in: $e', statusCode: 500);
  }
}
