import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:khqr_generator/khqr_generator.dart';
import 'package:mongo_dart/mongo_dart.dart';

import '../config/env.dart';
import '../database/mongo.dart';

class BakongException implements Exception {
  BakongException(this.message);
  final String message;
  @override
  String toString() => message;
}

class BakongQrResult {
  const BakongQrResult({required this.qr, required this.md5, required this.amountKhr});
  final String qr;
  final String md5;
  final int amountKhr;
}

class BakongService {
  static const _tokenKey = 'bakong_open_api';

  static Future<int> toKhr(num orderTotal) async {
    final orderCurrency = (await Env.get('BAKONG_ORDER_CURRENCY') ?? 'USD').toUpperCase();
    if (orderCurrency == 'KHR') return orderTotal.round();
    if (orderCurrency != 'USD') throw BakongException('BAKONG_ORDER_CURRENCY must be USD or KHR.');
    final rate = num.tryParse(await Env.get('BAKONG_KHR_PER_USD') ?? '4100');
    if (rate == null || rate <= 0) throw BakongException('BAKONG_KHR_PER_USD must be a positive number.');
    return (orderTotal * rate).round();
  }

  static Future<BakongQrResult> generateMerchantQr({
    required int amountKhr,
    required String billNumber,
    required DateTime expiresAt,
  }) async {
    if (amountKhr <= 0) throw BakongException('Payment amount must be greater than zero.');
    final accountId = await Env.require('BAKONG_ACCOUNT_ID');
    final merchantId = await Env.require('BAKONG_MERCHANT_ID');
    final merchantName = await Env.require('BAKONG_MERCHANT_NAME');
    final acquiringBank = await Env.get('BAKONG_ACQUIRING_BANK') ?? 'ABA';
    final merchantCity = await Env.get('BAKONG_MERCHANT_CITY') ?? 'Phnom Penh';
    if (accountId.contains('your_real_') || merchantId.contains('your_real_') || accountId == 'coffee@bakong') {
      throw BakongException('Replace BAKONG_ACCOUNT_ID and BAKONG_MERCHANT_ID with the real ABA-registered merchant details.');
    }

    final result = KHQRGenerator.generateMerchant(MerchantInfo(
      bakongAccountID: accountId,
      merchantID: merchantId,
      acquiringBank: acquiringBank,
      merchantName: merchantName,
      merchantCity: merchantCity,
      currency: KHQRCurrency.khr.code,
      amount: amountKhr.toDouble(),
      billNumber: billNumber,
      storeLabel: 'Coffee Shop',
      purposeOfTransaction: 'Coffee order',
      expirationTimestamp: expiresAt.millisecondsSinceEpoch,
    ));
    if (result.status.code != 0 || result.data == null) {
      throw BakongException('KHQR generation failed: ${result.status.message}');
    }
    return BakongQrResult(qr: result.data!.qr, md5: result.data!.md5, amountKhr: amountKhr);
  }

  static Future<void> saveToken({required String token, String? email}) async {
    if (token.trim().isEmpty) throw BakongException('Bakong token cannot be empty.');
    final col = await MongoDatabase.collection('api_bakong');
    final tokenEmail = email ?? await Env.get('BAKONG_EMAIL') ?? '';
    await col.updateOne(
      where.eq('key', _tokenKey),
      modify.set('key', _tokenKey)
        .set('token', token.trim())
        .set('email', tokenEmail)
        .set('updatedAt', DateTime.now().toUtc().toIso8601String()),
      upsert: true,
    );
  }

  static Future<String> getAccessToken() async {
    final col = await MongoDatabase.collection('api_bakong');
    final doc = await col.findOne(where.eq('key', _tokenKey));
    final stored = doc?['token']?.toString() ?? '';
    if (stored.isNotEmpty && !_isJwtExpired(stored)) return stored;
    final email = (doc?['email']?.toString().isNotEmpty == true)
        ? doc!['email'].toString()
        : (await Env.get('BAKONG_EMAIL') ?? '');
    if (email.isNotEmpty) return renewAndSaveToken(email: email);
    final envToken = (await Env.get('BAKONG_API_TOKEN') ?? '').trim();
    if (envToken.isNotEmpty) return envToken;
    throw BakongException('Bakong token is missing or expired. Save one using POST /api/payments/bakong/token.');
  }

  static Future<String> renewAndSaveToken({required String email}) async {
    final baseUrl = await _baseUrl();
    final response = await http.post(
      Uri.parse('$baseUrl/v1/renew_token'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    ).timeout(const Duration(seconds: 15));
    final body = _decode(response.body);
    if (response.statusCode != 200 || body['responseCode'] != 0) {
      throw BakongException('Bakong token renewal failed: ${body['responseMessage'] ?? response.body}');
    }
    final token = (body['data'] is Map) ? body['data']['token']?.toString() : null;
    if (token == null || token.isEmpty) throw BakongException('Bakong renewal response did not contain a token.');
    await saveToken(token: token, email: email);
    return token;
  }

  static Future<Map<String, dynamic>> checkTransactionByMd5(String md5) async {
    var token = await getAccessToken();
    var response = await _postCheck(token, md5);
    if (response.statusCode == 401) {
      final tokenDoc = await (await MongoDatabase.collection('api_bakong'))
          .findOne(where.eq('key', _tokenKey));
      final storedEmail = tokenDoc?['email']?.toString() ?? '';
      final email = storedEmail.isNotEmpty
          ? storedEmail
          : (await Env.get('BAKONG_EMAIL') ?? '');
      if (email.isNotEmpty) {
        token = await renewAndSaveToken(email: email);
        response = await _postCheck(token, md5);
      }
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw BakongException('Bakong API returned HTTP ${response.statusCode}. Check your token and environment.');
    }
    return _decode(response.body);
  }

  static Future<http.Response> _postCheck(String token, String md5) async => http.post(
    Uri.parse('${await _baseUrl()}/v1/check_transaction_by_md5'),
    headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
    body: jsonEncode({'md5': md5}),
  ).timeout(const Duration(seconds: 15));

  static Future<String> _baseUrl() async {
    final configured = await Env.get('BAKONG_API_URL') ??
        await Env.get('BAKONG_BASE_URL') ??
        '';
    final value = configured.trim().replaceAll(RegExp(r'/+$'), '');
    if (value.isEmpty) throw BakongException('BAKONG_API_URL (or BAKONG_BASE_URL) is missing in .env.');
    return value;
  }

  static Map<String, dynamic> _decode(String source) {
    final value = jsonDecode(source);
    if (value is! Map) throw BakongException('Unexpected response from Bakong API.');
    return Map<String, dynamic>.from(value);
  }

  static bool _isJwtExpired(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return false;
      final payload = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1])))) as Map;
      final exp = int.tryParse(payload['exp'].toString());
      if (exp == null) return false;
      return DateTime.now().millisecondsSinceEpoch ~/ 1000 >= exp - 60;
    } catch (_) { return false; }
  }
}
