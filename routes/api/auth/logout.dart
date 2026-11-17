import 'package:dart_frog/dart_frog.dart';
import '../../../lib/utils/responses.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return errorResponse('Method not allowed.', statusCode: 405);
  }
  // JWTs are stateless. The client should discard its token.
  // Add a token denylist/session collection if server-side revocation is required.
  return successResponse('Logged out. Please discard your access token.');
}
