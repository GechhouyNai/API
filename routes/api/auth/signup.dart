import 'package:dart_frog/dart_frog.dart';
import 'package:bcrypt/bcrypt.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:uuid/uuid.dart';
import '../../../lib/database/mongo.dart';
import '../../../lib/utils/responses.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return errorResponse('Method not allowed.', statusCode: 405);
  }

  try {
    final body = await context.request.json() as Map;
    final name = body['name']?.toString().trim() ?? '';
    final phone = body['phone']?.toString().trim() ?? '';
    final email = body['email']?.toString().trim().toLowerCase() ?? '';
    final password = body['password']?.toString() ?? '';

    if (name.isEmpty || phone.isEmpty || password.length < 8) {
      return errorResponse('name, phone, and password (at least 8 characters) are required.');
    }

    final users = await MongoDatabase.collection('users');
    if (email.isNotEmpty && await users.findOne(where.eq('email', email)) != null) {
      return errorResponse('Email is already registered.', statusCode: 409);
    }

    final id = const Uuid().v4();
    await users.insertOne({
      '_id': id,
      'name': name,
      'phone': phone,
      if (email.isNotEmpty) 'email': email,
      'passwordHash': BCrypt.hashpw(password, BCrypt.gensalt()),
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    });

    return Response.json(
      statusCode: 201,
      body: {
        'success': true,
        'message': 'Account created.',
        'data': {'id': id, 'name': name, 'phone': phone, if (email.isNotEmpty) 'email': email},
      },
    );
  } catch (e) {
    return errorResponse('Could not create account: $e', statusCode: 500);
  }
}
