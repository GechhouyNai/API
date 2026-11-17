// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, implicit_dynamic_list_literal

import 'dart:io';

import 'package:dart_frog/dart_frog.dart';


import '../routes/index.dart' as index;
import '../routes/api/index.dart' as api_index;
import '../routes/api/health.dart' as api_health;
import '../routes/api/stores/index.dart' as api_stores_index;
import '../routes/api/payments/khqr.dart' as api_payments_khqr;
import '../routes/api/payments/bakong/verify.dart' as api_payments_bakong_verify;
import '../routes/api/payments/bakong/token.dart' as api_payments_bakong_token;
import '../routes/api/payments/bakong/create.dart' as api_payments_bakong_create;
import '../routes/api/payments/[id]/index.dart' as api_payments_$id_index;
import '../routes/api/payments/[id]/check.dart' as api_payments_$id_check;
import '../routes/api/orders/index.dart' as api_orders_index;
import '../routes/api/orders/[id].dart' as api_orders_$id;
import '../routes/api/menu/index.dart' as api_menu_index;
import '../routes/api/menu/[id].dart' as api_menu_$id;
import '../routes/api/favorites/index.dart' as api_favorites_index;
import '../routes/api/favorites/[id].dart' as api_favorites_$id;
import '../routes/api/coffees/index.dart' as api_coffees_index;
import '../routes/api/coffees/[id].dart' as api_coffees_$id;
import '../routes/api/cart/index.dart' as api_cart_index;
import '../routes/api/cart/[id].dart' as api_cart_$id;
import '../routes/api/auth/signup.dart' as api_auth_signup;
import '../routes/api/auth/reset_password.dart' as api_auth_reset_password;
import '../routes/api/auth/register.dart' as api_auth_register;
import '../routes/api/auth/me.dart' as api_auth_me;
import '../routes/api/auth/logout.dart' as api_auth_logout;
import '../routes/api/auth/login.dart' as api_auth_login;
import '../routes/api/auth/forgot_password.dart' as api_auth_forgot_password;


void main() async {
  final address = InternetAddress.tryParse('') ?? InternetAddress.anyIPv6;
  final port = int.tryParse(Platform.environment['PORT'] ?? '8080') ?? 8080;
  hotReload(() => createServer(address, port));
}

Future<HttpServer> createServer(InternetAddress address, int port) {
  final handler = Cascade().add(buildRootHandler()).handler;
  return serve(handler, address, port);
}

Handler buildRootHandler() {
  final pipeline = const Pipeline();
  final router = Router()
    ..mount('/', (context) => buildHandler()(context))
    ..mount('/api', (context) => buildApiHandler()(context))
    ..mount('/api/stores', (context) => buildApiStoresHandler()(context))
    ..mount('/api/payments', (context) => buildApiPaymentsHandler()(context))
    ..mount('/api/payments/bakong', (context) => buildApiPaymentsBakongHandler()(context))
    ..mount('/api/payments/<id>', (context,id,) => buildApiPayments$idHandler(id,)(context))
    ..mount('/api/orders', (context) => buildApiOrdersHandler()(context))
    ..mount('/api/menu', (context) => buildApiMenuHandler()(context))
    ..mount('/api/favorites', (context) => buildApiFavoritesHandler()(context))
    ..mount('/api/coffees', (context) => buildApiCoffeesHandler()(context))
    ..mount('/api/cart', (context) => buildApiCartHandler()(context))
    ..mount('/api/auth', (context) => buildApiAuthHandler()(context));
  return pipeline.addHandler(router);
}

Handler buildHandler() {
  final pipeline = const Pipeline();
  final router = Router()
    ..all('/', (context) => index.onRequest(context,));
  return pipeline.addHandler(router);
}

Handler buildApiHandler() {
  final pipeline = const Pipeline();
  final router = Router()
    ..all('/health', (context) => api_health.onRequest(context,))..all('/', (context) => api_index.onRequest(context,));
  return pipeline.addHandler(router);
}

Handler buildApiStoresHandler() {
  final pipeline = const Pipeline();
  final router = Router()
    ..all('/', (context) => api_stores_index.onRequest(context,));
  return pipeline.addHandler(router);
}

Handler buildApiPaymentsHandler() {
  final pipeline = const Pipeline();
  final router = Router()
    ..all('/khqr', (context) => api_payments_khqr.onRequest(context,));
  return pipeline.addHandler(router);
}

Handler buildApiPaymentsBakongHandler() {
  final pipeline = const Pipeline();
  final router = Router()
    ..all('/create', (context) => api_payments_bakong_create.onRequest(context,))..all('/token', (context) => api_payments_bakong_token.onRequest(context,))..all('/verify', (context) => api_payments_bakong_verify.onRequest(context,));
  return pipeline.addHandler(router);
}

Handler buildApiPayments$idHandler(String id,) {
  final pipeline = const Pipeline();
  final router = Router()
    ..all('/check', (context) => api_payments_$id_check.onRequest(context,id,))..all('/', (context) => api_payments_$id_index.onRequest(context,id,));
  return pipeline.addHandler(router);
}

Handler buildApiOrdersHandler() {
  final pipeline = const Pipeline();
  final router = Router()
    ..all('/<id>', (context,id,) => api_orders_$id.onRequest(context,id,))..all('/', (context) => api_orders_index.onRequest(context,));
  return pipeline.addHandler(router);
}

Handler buildApiMenuHandler() {
  final pipeline = const Pipeline();
  final router = Router()
    ..all('/<id>', (context,id,) => api_menu_$id.onRequest(context,id,))..all('/', (context) => api_menu_index.onRequest(context,));
  return pipeline.addHandler(router);
}

Handler buildApiFavoritesHandler() {
  final pipeline = const Pipeline();
  final router = Router()
    ..all('/<id>', (context,id,) => api_favorites_$id.onRequest(context,id,))..all('/', (context) => api_favorites_index.onRequest(context,));
  return pipeline.addHandler(router);
}

Handler buildApiCoffeesHandler() {
  final pipeline = const Pipeline();
  final router = Router()
    ..all('/<id>', (context,id,) => api_coffees_$id.onRequest(context,id,))..all('/', (context) => api_coffees_index.onRequest(context,));
  return pipeline.addHandler(router);
}

Handler buildApiCartHandler() {
  final pipeline = const Pipeline();
  final router = Router()
    ..all('/<id>', (context,id,) => api_cart_$id.onRequest(context,id,))..all('/', (context) => api_cart_index.onRequest(context,));
  return pipeline.addHandler(router);
}

Handler buildApiAuthHandler() {
  final pipeline = const Pipeline();
  final router = Router()
    ..all('/forgot_password', (context) => api_auth_forgot_password.onRequest(context,))..all('/login', (context) => api_auth_login.onRequest(context,))..all('/logout', (context) => api_auth_logout.onRequest(context,))..all('/me', (context) => api_auth_me.onRequest(context,))..all('/register', (context) => api_auth_register.onRequest(context,))..all('/reset_password', (context) => api_auth_reset_password.onRequest(context,))..all('/signup', (context) => api_auth_signup.onRequest(context,));
  return pipeline.addHandler(router);
}

