import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/partner_transfer_models.dart';
import 'partner_session_manager.dart';

class PartnerApiException implements Exception {
  const PartnerApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'PartnerApiException: $message';
}

class PartnerAuthResponse {
  const PartnerAuthResponse({
    required this.accessToken,
    required this.user,
  });

  final String accessToken;
  final PartnerUser user;

  factory PartnerAuthResponse.fromJson(Map<String, dynamic> json) {
    final rawUser = json['user'];
    if (json['access_token'] is! String || rawUser is! Map<String, dynamic>) {
      throw const FormatException('Partner login response is invalid');
    }

    return PartnerAuthResponse(
      accessToken: json['access_token'] as String,
      user: PartnerUser.fromJson(rawUser),
    );
  }
}

class PartnerApi {
  PartnerApi({
    http.Client? client,
    String? baseUrl,
    PartnerSessionManager? sessionManager,
  })  : _client = client ?? http.Client(),
        _baseUrl =
            (baseUrl ?? AppConfig.baseUrl).replaceAll(RegExp(r'/+$'), ''),
        _sessionManager = sessionManager ?? PartnerSessionManager.instance;

  final http.Client _client;
  final String _baseUrl;
  final PartnerSessionManager _sessionManager;

  Future<String?> _resolveToken(String? explicitToken) async {
    if (explicitToken != null && explicitToken.isNotEmpty) {
      return explicitToken;
    }
    return _sessionManager.getToken();
  }

  String _parseErrorMessage(http.Response response, String fallback) {
    try {
      final body = jsonDecode(response.body);
      if (body is Map<String, dynamic> && body['detail'] != null) {
        final detail = body['detail'];
        if (detail is String) return detail;
        if (detail is List && detail.isNotEmpty) {
          final first = detail.first;
          if (first is Map && first['msg'] != null) {
            return first['msg'].toString();
          }
          return detail.join(', ');
        }
      }
    } catch (_) {}
    return fallback;
  }

  Future<PartnerAuthResponse> login({
    required String mobile,
    required String password,
  }) async {
    final cleanMobile = mobile.trim();
    if (cleanMobile.isEmpty || password.isEmpty) {
      throw const PartnerApiException(
          'Mobile number and password are required');
    }

    http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse('$_baseUrl/api/v1/auth/partner/login'),
            headers: const {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'mobile': cleanMobile, 'password': password}),
          )
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw const PartnerApiException(
        'Connection timed out. Please check your network.',
      );
    } on http.ClientException catch (error) {
      throw PartnerApiException('Network error: ${error.message}');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = _parseErrorMessage(response, 'Login failed');
      throw PartnerApiException(message, statusCode: response.statusCode);
    }

    try {
      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic>) {
        throw const FormatException('Expected JSON object');
      }
      return PartnerAuthResponse.fromJson(body);
    } on FormatException {
      throw PartnerApiException(
        'Invalid response received from server',
        statusCode: response.statusCode,
      );
    }
  }

  /// Resolves a Staff QR token or URL to the assigned Staff recipient.
  Future<StaffQrRecipient> resolveStaffQr({
    required String codeData,
    String? authToken,
  }) async {
    final cleanCode = codeData.trim();
    if (cleanCode.isEmpty) {
      throw const PartnerApiException(
        'A valid QR code token must be provided.',
        statusCode: 400,
      );
    }

    final token = await _resolveToken(authToken);
    if (token == null || token.isEmpty) {
      throw const PartnerApiException(
        'Not authenticated: active Partner session required',
        statusCode: 401,
      );
    }

    http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse('$_baseUrl/api/v1/staff/qr/resolve'),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'token': cleanCode,
              'code_data': cleanCode,
            }),
          )
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw const PartnerApiException(
        'Connection timed out while resolving QR code. Please check your network.',
        statusCode: 408,
      );
    } on http.ClientException catch (error) {
      throw PartnerApiException('Network error: ${error.message}');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message =
          _parseErrorMessage(response, 'Failed to resolve Staff QR code');
      throw PartnerApiException(message, statusCode: response.statusCode);
    }

    try {
      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic>) {
        throw const FormatException('Expected JSON object');
      }
      return StaffQrRecipient.fromJson(body);
    } on FormatException {
      throw PartnerApiException(
        'Invalid response received from server',
        statusCode: response.statusCode,
      );
    }
  }

  /// Executes an atomic points transfer from the authenticated Partner to a Staff recipient.
  Future<PartnerTransferResponse> transferPoints({
    required String codeData,
    required int amount,
    required String idempotencyKey,
    String? authToken,
  }) async {
    final cleanCode = codeData.trim();
    if (cleanCode.isEmpty) {
      throw const PartnerApiException(
        'A valid QR code token must be provided.',
        statusCode: 400,
      );
    }
    if (amount <= 0) {
      throw const PartnerApiException(
        'Transfer amount must be a positive integer greater than zero.',
        statusCode: 400,
      );
    }
    final cleanKey = idempotencyKey.trim();
    if (cleanKey.isEmpty) {
      throw const PartnerApiException(
        'Idempotency key must not be blank.',
        statusCode: 400,
      );
    }

    final token = await _resolveToken(authToken);
    if (token == null || token.isEmpty) {
      throw const PartnerApiException(
        'Not authenticated: active Partner session required',
        statusCode: 401,
      );
    }

    http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse('$_baseUrl/api/v1/partner/transfers'),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
              'Idempotency-Key': cleanKey,
            },
            body: jsonEncode({
              'token': cleanCode,
              'code_data': cleanCode,
              'amount': amount,
              'idempotency_key': cleanKey,
            }),
          )
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw const PartnerApiException(
        'Connection timed out during points transfer. Please check your network.',
        statusCode: 408,
      );
    } on http.ClientException catch (error) {
      throw PartnerApiException('Network error: ${error.message}');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message =
          _parseErrorMessage(response, 'Points transfer failed');
      throw PartnerApiException(message, statusCode: response.statusCode);
    }

    try {
      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic>) {
        throw const FormatException('Expected JSON object');
      }
      return PartnerTransferResponse.fromJson(body);
    } on FormatException {
      throw PartnerApiException(
        'Invalid response received from server',
        statusCode: response.statusCode,
      );
    }
  }

  /// Fetches the authenticated Partner's remaining points balance from the dashboard stats.
  Future<int> getAvailableBalance({String? authToken}) async {
    final token = await _resolveToken(authToken);
    if (token == null || token.isEmpty) {
      throw const PartnerApiException(
        'Not authenticated: active Partner session required',
        statusCode: 401,
      );
    }

    http.Response response;
    try {
      response = await _client
          .get(
            Uri.parse('$_baseUrl/api/v1/orders/dashboard/stats'),
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw const PartnerApiException(
        'Connection timed out while loading balance.',
        statusCode: 408,
      );
    } on http.ClientException catch (error) {
      throw PartnerApiException('Network error: ${error.message}');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message =
          _parseErrorMessage(response, 'Failed to fetch balance');
      throw PartnerApiException(message, statusCode: response.statusCode);
    }

    try {
      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic>) {
        throw const FormatException('Expected JSON object');
      }
      final remaining = body['remaining_balance'];
      if (remaining is num) {
        return remaining.toInt();
      }
      throw const FormatException('remaining_balance missing from response');
    } on FormatException {
      throw PartnerApiException(
        'Invalid response received from server',
        statusCode: response.statusCode,
      );
    }
  }
}
