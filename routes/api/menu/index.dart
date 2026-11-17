import 'package:dart_frog/dart_frog.dart';
import 'package:coffee_backend_api/database/mongo.dart';
import 'package:coffee_backend_api/utils/responses.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.get) {
    return errorResponse('Method not allowed.', statusCode: 405);
  }

  try {
    final params = context.request.uri.queryParameters;
    final type = params['type']?.trim().toLowerCase();
    final search = params['search']?.trim().toLowerCase();
    final items = <Map<String, dynamic>>[];

    for (final collectionName in ['coffees', 'coffee_items']) {
      final collection = await MongoDatabase.collection(collectionName);
      final records = await collection.find().toList();
      for (final item in records) {
        final itemType = item['type']?.toString().toLowerCase();
        final title = item['title']?.toString().toLowerCase() ?? '';
        final keywords = item['keywords'];
        final matchesSearch = search == null ||
            search.isEmpty ||
            title.contains(search) ||
            (keywords is List &&
                keywords.any(
                  (keyword) =>
                      keyword.toString().toLowerCase().contains(search),
                ));
        if ((type == null ||
                type.isEmpty ||
                type == 'all' ||
                itemType == type) &&
            matchesSearch) {
          items.add(item);
        }
      }
    }

    return Response.json(body: {'items': items});
  } catch (e) {
    return errorResponse('Could not load menu: $e', statusCode: 500);
  }
}
