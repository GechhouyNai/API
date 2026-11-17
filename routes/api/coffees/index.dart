import 'package:dart_frog/dart_frog.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:uuid/uuid.dart';
import '../../../lib/database/mongo.dart';
import '../../../lib/utils/auth.dart';
import '../../../lib/utils/responses.dart';

Future<Response> onRequest(RequestContext context) async {
  try {
    final coffees = await MongoDatabase.collection('coffees');
    if (context.request.method == HttpMethod.get) {
      final params = context.request.uri.queryParameters;
      final type = params['type']?.toUpperCase();
      final search = params['search']?.toLowerCase().trim();
      final all = await coffees.find().toList();
      final filtered = all.where((coffee) {
        final matchesType = type == null || type == 'ALL' ||
            coffee['type']?.toString().toUpperCase() == type;
        final title = coffee['title']?.toString().toLowerCase() ?? '';
        final matchesSearch = search == null || search.isEmpty || title.contains(search);
        return matchesType && matchesSearch;
      }).toList();
      return successResponse('Coffee list loaded.', data: filtered);
    }

    if (context.request.method == HttpMethod.post) {
      final authError = await requireUser(context);
      if (authError != null) return authError;
      final body = await context.request.json() as Map;
      final title = body['title']?.toString().trim() ?? '';
      final price = num.tryParse(body['price']?.toString() ?? '');
      final type = body['type']?.toString().toUpperCase() ?? '';
      if (title.isEmpty || price == null || price < 0 || !['HOT', 'ICED'].contains(type)) {
        return errorResponse('Provide title, a non-negative price, and type HOT or ICED.');
      }
      final id = const Uuid().v4();
      final doc = {
        '_id': id,
        'title': title,
        'desc': body['desc']?.toString() ?? '',
        'image': body['image']?.toString() ?? '',
        'price': price,
        'type': type,
        'isAvailable': body['isAvailable'] != false,
        'createdAt': DateTime.now().toUtc().toIso8601String(),
      };
      await coffees.insertOne(doc);
      return Response.json(statusCode: 201, body: {
        'success': true, 'message': 'Coffee created.', 'data': doc,
      });
    }
    return errorResponse('Method not allowed.', statusCode: 405);
  } catch (e) {
    return errorResponse('Coffee request failed: $e', statusCode: 500);
  }
}
