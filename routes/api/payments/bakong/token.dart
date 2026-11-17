import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:mongo_dart/mongo_dart.dart';

import '../../../../lib/config/env.dart';
import '../../../../lib/database/mongo.dart';
import '../../../../lib/services/bakong_service.dart';
import '../../../../lib/utils/responses.dart';

Future<bool> _isAdmin(RequestContext context) async {
  final configured = await Env.get('ADMIN_API_KEY') ?? '';
  final supplied = context.request.headers['x-admin-api-key'] ?? '';
  return configured.isNotEmpty && supplied.isNotEmpty && supplied == configured;
}

/// GET/POST /api/payments/bakong/token
/// Admin only. GET returns token status (never the secret token itself).
/// POST accepts {"token":"...","email":"..."} or {"renew":true,"email":"..."}.
Future<Response> onRequest(RequestContext context) async {
  if (!await _isAdmin(context)) {
    return errorResponse('Admin API key is required.', statusCode: HttpStatus.unauthorized);
  }

  if (context.request.method == HttpMethod.get) {
    try {
      final col = await MongoDatabase.collection('api_bakong');
      final doc = await col.findOne(where.eq('key', 'bakong_open_api'));
      final token = doc?['token']?.toString() ?? '';
      return Response.json(body: {
        'success': true,
        'hasToken': token.isNotEmpty,
        'email': doc?['email'],
        'updatedAt': doc?['updatedAt'],
      });
    } catch (e) {
      return errorResponse('Could not read Bakong token status: $e', statusCode: 500);
    }
  }

  if (context.request.method == HttpMethod.post) {
    try {
      final body = await context.request.json() as Map;
      final email = body['email']?.toString();
      if (body['renew'] == true) {
        final targetEmail = (email ?? await Env.get('BAKONG_EMAIL') ?? '').trim();
        if (targetEmail.isEmpty) return errorResponse('Registered Bakong email is required for token renewal.');
        final token = await BakongService.renewAndSaveToken(email: targetEmail);
        return Response.json(body: {
          'success': true,
          'message': 'Bakong token renewed and saved in MongoDB api_bakong.',
          'tokenPreview': '${token.substring(0, token.length < 10 ? token.length : 10)}...',
        });
      }

      final token = body['token']?.toString() ?? '';
      if (token.trim().isEmpty) return errorResponse('Provide a non-empty token or set renew to true.');
      await BakongService.saveToken(token: token, email: email);
      return Response.json(body: {
        'success': true,
        'message': 'Bakong token saved in MongoDB api_bakong.',
      });
    } on BakongException catch (e) {
      return errorResponse(e.message, statusCode: 502);
    } catch (e) {
      return errorResponse('Could not save Bakong token: $e', statusCode: 500);
    }
  }

  return errorResponse('Method not allowed.', statusCode: 405);
}
