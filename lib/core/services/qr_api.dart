import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/qr_scan_models.dart';
import 'customer_session_manager.dart';
import 'partner_session_manager.dart';

/// Exception thrown by the QR scan API client.
class QrScanException implements Exception {
  final String message;
  final int? statusCode;
  final String? code;

  const QrScanException(
    this.message, {
    this.statusCode,
    this.code,
  });

  bool get isDuplicate => statusCode == 409;
  bool get isExpired =>
      statusCode == 400 && message.toLowerCase().contains('expired');
  bool get isInvalidType =>
      statusCode == 400 &&
      (message.toLowerCase().contains('inappropriate') ||
          message.toLowerCase().contains('type'));
  bool get isNotFound => statusCode == 404;
  bool get isUnauthorized => statusCode == 401 || statusCode == 403;
  bool get isNetworkError => statusCode == 0;

  @override
  String toString() => 'QrScanException(statusCode: $statusCode): $message';
}

/// Client for communicating with the QR scanning and points awarding endpoints.
class QrScanApi {
  final http.Client _client;
  final String _baseUrl;
  final Future<String?> Function()? _tokenProvider;

  QrScanApi({
    http.Client? client,
    String? baseUrl,
    Future<String?> Function()? tokenProvider,
  })  : _client = client ?? http.Client(),
        _baseUrl = (baseUrl ?? AppConfig.baseUrl).replaceAll(RegExp(r'/+$'), ''),
        _tokenProvider = tokenProvider;

  /// Resolves the bearer token: explicit parameter > custom token provider > CustomerSession > PartnerSession.
  Future<String?> _resolveToken(String? explicitToken) async {
    if (explicitToken != null && explicitToken.isNotEmpty) {
      return explicitToken;
    }
    final provider = _tokenProvider;
    if (provider != null) {
      final t = await provider();
      if (t != null && t.isNotEmpty) return t;
    }
    final custToken = await CustomerSessionManager.instance.getToken();
    if (custToken != null && custToken.isNotEmpty) return custToken;

    final partnerToken = await PartnerSessionManager.instance.getToken();
    if (partnerToken != null && partnerToken.isNotEmpty) return partnerToken;

    return null;
  }

  /// Sends a scanned QR payload to `/api/v1/qr/scan` to award loyalty points.
  Future<QrScanResult> scanQrCode({
    required String codeData,
    String? token,
    String? idempotencyKey,
    String? authToken,
  }) async {
    final cleanCode = codeData.trim();
    if (cleanCode.isEmpty) {
      throw const QrScanException(
        'QR code payload cannot be empty.',
        statusCode: 400,
        code: 'EMPTY_PAYLOAD',
      );
    }

    final bearerToken = await _resolveToken(authToken);
    if (bearerToken == null || bearerToken.isEmpty) {
      throw const QrScanException(
        'Please sign in to scan QR codes for points.',
        statusCode: 401,
        code: 'UNAUTHENTICATED',
      );
    }

    final requestBody = <String, dynamic>{
      'code_data': cleanCode,
    };
    if (token != null && token.trim().isNotEmpty) {
      requestBody['token'] = token.trim();
    }
    if (idempotencyKey != null && idempotencyKey.trim().isNotEmpty) {
      requestBody['idempotency_key'] = idempotencyKey.trim();
    }

    http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse('$_baseUrl/api/v1/qr/scan'),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $bearerToken',
            },
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw const QrScanException(
        'Connection timed out. Please check your internet connection.',
        statusCode: 0,
        code: 'TIMEOUT',
      );
    } on http.ClientException catch (e) {
      throw QrScanException(
        'Network error: ${e.message}',
        statusCode: 0,
        code: 'NETWORK_ERROR',
      );
    } catch (e) {
      if (e is QrScanException) rethrow;
      throw QrScanException(
        'Unexpected connection error: $e',
        statusCode: 0,
        code: 'UNKNOWN_NETWORK_ERROR',
      );
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is! Map<String, dynamic>) {
          throw const FormatException('Expected JSON object in scan response');
        }
        return QrScanResult.fromJson(decoded);
      } on FormatException {
        throw const QrScanException(
          'Invalid response format received from server.',
          statusCode: 500,
          code: 'INVALID_JSON',
        );
      }
    }

    // Handle error statuses
    String detail = 'Scan request failed (${response.statusCode})';
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic> && decoded['detail'] is String) {
        detail = decoded['detail'] as String;
      }
    } catch (_) {
      // Keep default detail message
    }

    String code = 'API_ERROR';
    if (response.statusCode == 409) {
      code = 'ALREADY_REDEEMED';
    } else if (response.statusCode == 404) {
      code = 'NOT_FOUND';
    } else if (response.statusCode == 400) {
      if (detail.toLowerCase().contains('expired')) {
        code = 'EXPIRED';
      } else if (detail.toLowerCase().contains('inappropriate') ||
          detail.toLowerCase().contains('type')) {
        code = 'INVALID_TYPE';
      } else {
        code = 'BAD_REQUEST';
      }
    } else if (response.statusCode == 401 || response.statusCode == 403) {
      code = 'UNAUTHORIZED';
    }

    throw QrScanException(detail, statusCode: response.statusCode, code: code);
  }

  /// Retrieves point transactions for the currently authenticated user.
  Future<List<PointTransactionItem>> getTransactions({String? authToken}) async {
    final bearerToken = await _resolveToken(authToken);
    if (bearerToken == null || bearerToken.isEmpty) {
      throw const QrScanException(
        'Please sign in to view transaction history.',
        statusCode: 401,
        code: 'UNAUTHENTICATED',
      );
    }

    http.Response response;
    try {
      response = await _client.get(
        Uri.parse('$_baseUrl/api/v1/qr/transactions'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $bearerToken',
        },
      ).timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw const QrScanException(
        'Connection timed out. Please check your network.',
        statusCode: 0,
      );
    } on http.ClientException catch (e) {
      throw QrScanException('Network error: ${e.message}', statusCode: 0);
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(response.body);
      if (decoded is List) {
        return decoded
            .map((item) =>
                PointTransactionItem.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      return const [];
    }

    throw QrScanException(
      'Failed to load transactions (${response.statusCode})',
      statusCode: response.statusCode,
    );
  }
}
