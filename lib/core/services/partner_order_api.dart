import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/partner_order_models.dart';
import 'partner_session_manager.dart';
import 'staff_session_manager.dart';

class PartnerOrderApiException implements Exception {
  const PartnerOrderApiException({
    required this.message,
    this.statusCode,
    this.details,
  });

  final String message;
  final int? statusCode;
  final dynamic details;

  @override
  String toString() =>
      'PartnerOrderApiException: $message (status: $statusCode)';
}

class PartnerOrderApi {
  PartnerOrderApi({
    http.Client? client,
    String? baseUrl,
    PartnerSessionManager? sessionManager,
  })  : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? AppConfig.baseUrl,
        _sessionManager = sessionManager ?? PartnerSessionManager.instance;

  final http.Client _client;
  final String _baseUrl;
  final PartnerSessionManager _sessionManager;
  static const Duration _timeout = Duration(seconds: 15);

  Future<Map<String, String>> _headers({String? idempotencyKey}) async {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
    var token = await _sessionManager.getToken();
    if (token == null || token.isEmpty) {
      token = await StaffSessionManager.instance.getToken();
    }
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    if (idempotencyKey != null && idempotencyKey.isNotEmpty) {
      headers['Idempotency-Key'] = idempotencyKey;
    }
    return headers;
  }

  Future<PartnerOrderPreviewResponse> previewOrder(List<CartItem> items) async {
    final url = Uri.parse('$_baseUrl/api/v1/orders/preview');
    final payload = {
      'items': items
          .map((item) => {
                'product_id': item.product.id,
                'quantity': item.quantity,
              })
          .toList(),
    };

    try {
      final headers = await _headers();
      final response = await _client
          .post(url, headers: headers, body: jsonEncode(payload))
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return PartnerOrderPreviewResponse.fromJson(data);
      }

      final errorBody = _parseError(response.body);
      throw PartnerOrderApiException(
        message: errorBody,
        statusCode: response.statusCode,
      );
    } on TimeoutException {
      throw const PartnerOrderApiException(
        message:
            'Order preview request timed out. Please check your connection.',
        statusCode: 408,
      );
    } on http.ClientException catch (e) {
      throw PartnerOrderApiException(
        message: 'Network error: ${e.message}',
      );
    } catch (e) {
      if (e is PartnerOrderApiException) rethrow;
      throw PartnerOrderApiException(message: e.toString());
    }
  }

  Future<PartnerOrderResponse> createOrder({
    required List<CartItem> items,
    String? notes,
    String? idempotencyKey,
  }) async {
    final url = Uri.parse('$_baseUrl/api/v1/orders');
    final payload = {
      'items': items
          .map((item) => {
                'product_id': item.product.id,
                'quantity': item.quantity,
              })
          .toList(),
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      if (idempotencyKey != null && idempotencyKey.isNotEmpty)
        'idempotency_key': idempotencyKey,
    };

    try {
      final headers = await _headers(idempotencyKey: idempotencyKey);
      final response = await _client
          .post(url, headers: headers, body: jsonEncode(payload))
          .timeout(_timeout);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return PartnerOrderResponse.fromJson(data);
      }

      final errorBody = _parseError(response.body);
      throw PartnerOrderApiException(
        message: errorBody,
        statusCode: response.statusCode,
      );
    } on TimeoutException {
      throw const PartnerOrderApiException(
        message:
            'Order creation timed out. Please check if your order was created before retrying.',
        statusCode: 408,
      );
    } on http.ClientException catch (e) {
      throw PartnerOrderApiException(
        message: 'Network error connecting to backend: ${e.message}',
      );
    } catch (e) {
      if (e is PartnerOrderApiException) rethrow;
      throw PartnerOrderApiException(message: e.toString());
    }
  }

  Future<List<PartnerOrderResponse>> listOrders() async {
    final url = Uri.parse('$_baseUrl/api/v1/orders');
    try {
      final response =
          await _client.get(url, headers: await _headers()).timeout(_timeout);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is! List) {
          throw const PartnerOrderApiException(
            message: 'Invalid order list response received from server',
            statusCode: 200,
          );
        }
        return decoded
            .map((item) => PartnerOrderResponse.fromJson(
                  Map<String, dynamic>.from(item as Map),
                ))
            .toList();
      }

      throw PartnerOrderApiException(
        message: _parseError(response.body),
        statusCode: response.statusCode,
      );
    } on TimeoutException {
      throw const PartnerOrderApiException(
        message:
            'Order history request timed out. Please check your connection.',
        statusCode: 408,
      );
    } on http.ClientException catch (error) {
      throw PartnerOrderApiException(
        message: 'Network error: ${error.message}',
      );
    } on FormatException {
      throw const PartnerOrderApiException(
        message: 'Invalid order list response received from server',
      );
    }
  }

  Future<PartnerOrderResponse> getOrder(int orderId) async {
    final url = Uri.parse('$_baseUrl/api/v1/orders/$orderId');
    try {
      final headers = await _headers();
      final response =
          await _client.get(url, headers: headers).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return PartnerOrderResponse.fromJson(data);
      }

      final errorBody = _parseError(response.body);
      throw PartnerOrderApiException(
        message: errorBody,
        statusCode: response.statusCode,
      );
    } on TimeoutException {
      throw const PartnerOrderApiException(
        message: 'Request timed out.',
        statusCode: 408,
      );
    } on http.ClientException catch (e) {
      throw PartnerOrderApiException(message: 'Network error: ${e.message}');
    } catch (e) {
      if (e is PartnerOrderApiException) rethrow;
      throw PartnerOrderApiException(message: e.toString());
    }
  }

  Future<Uint8List> downloadOrderPdf(int orderId) async {
    final url = Uri.parse('$_baseUrl/api/v1/orders/$orderId/pdf');
    try {
      final headers = await _headers();
      final response =
          await _client.get(url, headers: headers).timeout(_timeout);

      if (response.statusCode == 200) {
        return response.bodyBytes;
      }

      final errorBody = _parseError(response.body);
      throw PartnerOrderApiException(
        message: errorBody,
        statusCode: response.statusCode,
      );
    } on TimeoutException {
      throw const PartnerOrderApiException(
        message: 'PDF download timed out.',
        statusCode: 408,
      );
    } on http.ClientException catch (e) {
      throw PartnerOrderApiException(message: 'Network error: ${e.message}');
    } catch (e) {
      if (e is PartnerOrderApiException) rethrow;
      throw PartnerOrderApiException(message: e.toString());
    }
  }

  Future<WhatsAppDeliveryResult> sendOrderWhatsApp(int orderId) async {
    final url = Uri.parse('$_baseUrl/api/v1/orders/$orderId/send-whatsapp');
    try {
      final headers = await _headers();
      final response =
          await _client.post(url, headers: headers).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return WhatsAppDeliveryResult.fromJson(data);
      }

      final errorBody = _parseError(response.body);
      return WhatsAppDeliveryResult(
        success: false,
        status: 'failed',
        message: errorBody,
        provider: 'cloud_api',
      );
    } on TimeoutException {
      return const WhatsAppDeliveryResult(
        success: false,
        status: 'timeout',
        message: 'WhatsApp delivery request timed out.',
        provider: 'cloud_api',
      );
    } catch (e) {
      return WhatsAppDeliveryResult(
        success: false,
        status: 'error',
        message: 'Failed to dispatch WhatsApp message: $e',
        provider: 'cloud_api',
      );
    }
  }

  Future<PartnerOrderResponse> cancelOrder(int orderId, {String? reason}) async {
    final url = Uri.parse('$_baseUrl/api/v1/orders/$orderId/cancel');
    try {
      final headers = await _headers();
      final response = await _client
          .post(
            url,
            headers: headers,
            body: jsonEncode({
              if (reason != null && reason.isNotEmpty) 'reason': reason,
            }),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return PartnerOrderResponse.fromJson(data);
      }

      final errorBody = _parseError(response.body);
      throw PartnerOrderApiException(
        message: errorBody,
        statusCode: response.statusCode,
      );
    } on TimeoutException {
      throw const PartnerOrderApiException(
        message: 'Order cancellation timed out. Please try again.',
        statusCode: 408,
      );
    } on http.ClientException catch (e) {
      throw PartnerOrderApiException(message: 'Network error: ${e.message}');
    } catch (e) {
      if (e is PartnerOrderApiException) rethrow;
      throw PartnerOrderApiException(message: e.toString());
    }
  }

  Future<PartnerDashboardStats> getDashboardStats() async {
    final url = Uri.parse('$_baseUrl/api/v1/orders/dashboard/stats');
    try {
      final headers = await _headers();
      final response =
          await _client.get(url, headers: headers).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return PartnerDashboardStats.fromJson(data);
      }

      final errorBody = _parseError(response.body);
      throw PartnerOrderApiException(
        message: errorBody,
        statusCode: response.statusCode,
      );
    } on TimeoutException {
      throw const PartnerOrderApiException(
        message: 'Dashboard statistics request timed out.',
        statusCode: 408,
      );
    } on http.ClientException catch (e) {
      throw PartnerOrderApiException(message: 'Network error: ${e.message}');
    } catch (e) {
      if (e is PartnerOrderApiException) rethrow;
      throw PartnerOrderApiException(message: e.toString());
    }
  }

  String _parseError(String body) {
    try {
      final json = jsonDecode(body);
      if (json is Map && json.containsKey('detail')) {
        final detail = json['detail'];
        if (detail is String) return detail;
        if (detail is List && detail.isNotEmpty) {
          final first = detail.first;
          if (first is Map && first.containsKey('msg')) {
            return first['msg'].toString();
          }
        }
      }
    } catch (_) {}
    return 'An unexpected error occurred while communicating with the server.';
  }
}
