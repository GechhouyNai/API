import 'package:dart_frog/dart_frog.dart';

Response onRequest(RequestContext context) {
  print('Request received at /api');
  return Response.json(
    body: {
      'success': true,
      'message': 'Coffee API is running.',
      'health': '/api/health',
      'register': '/api/auth/register',
      'login': '/api/auth/login',
      'menu': '/api/coffees',
      'favorites': '/api/favorites',
      'orders': '/api/orders',
      'payments': '/api/payments',
    },
  );
}
