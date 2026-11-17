import 'package:dart_frog/dart_frog.dart';
import '../khqr.dart' as khqr_route;

/// Alias route matching the Bakong setup guide:
/// POST /api/payments/bakong/create
Future<Response> onRequest(RequestContext context) => khqr_route.onRequest(context);
