import 'package:dart_frog/dart_frog.dart';
import '../../lib/database/mongo.dart';

Future<Response> onRequest(RequestContext context) async {
  try {
    await MongoDatabase.database;
    return Response.json(body: {
      'success': true,
      'message': 'Coffee API is running.',
      'database': 'connected',
    });
  } catch (e) {
    return Response.json(
      statusCode: 500,
      body: {
        'success': false,
        'message': 'Database connection failed.',
        'error': e.toString(),
      },
    );
  }
}
