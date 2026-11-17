import 'package:dart_frog/dart_frog.dart';

Response errorResponse(String message, {int statusCode = 400}) {
  return Response.json(
    statusCode: statusCode,
    body: {'success': false, 'message': message},
  );
}

Response successResponse(
  String message, {
  Object? data,
  int statusCode = 200,
}) {
  return Response.json(
    statusCode: statusCode,
    body: {
      'success': true,
      'message': message,
      if (data != null) 'data': data,
    },
  );
}
