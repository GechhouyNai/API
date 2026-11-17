import 'package:dart_frog/dart_frog.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import '../config/env.dart';
import 'responses.dart';

Future<String?> userIdFromRequest(RequestContext context) async {
  final header = context.request.headers['authorization'];
  if (header == null || !header.startsWith('Bearer ')) return null;

  try {
    final secret = await Env.require('JWT_SECRET');
    final token = header.substring(7).trim();
    final jwt = JWT.verify(token, SecretKey(secret));
    final payload = jwt.payload;
    if (payload is Map<String, dynamic>) {
      return payload['userId']?.toString();
    }
    if (payload is Map) return payload['userId']?.toString();
  } catch (_) {
    return null;
  }
  return null;
}

Future<Response?> requireUser(RequestContext context) async {
  final id = await userIdFromRequest(context);
  if (id == null || id.isEmpty) {
    return errorResponse('Please log in first.', statusCode: 401);
  }
  return null;
}

Future<String> createToken(String userId) async {
  final secret = await Env.require('JWT_SECRET');
  final jwt = JWT(
    {'userId': userId},
    issuer: 'coffee-backend',
  );
  return jwt.sign(
    SecretKey(secret),
    expiresIn: const Duration(days: 7),
  );
}
