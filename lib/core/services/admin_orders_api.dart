import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/admin_order_models.dart';
import 'admin_api.dart';
import 'admin_session_manager.dart';

/// API client for Admin Orders and Stock Requests operations.
class AdminOrdersApi {
  AdminOrdersApi({
    http.Client? client,
    String? baseUrl,
    AdminSessionManager? sessionManager,
  })  : _client = client ?? http.Client(),
        _baseUrl = (baseUrl ?? AppConfig.baseUrl).replaceAll(RegExp(r'/+$'), ''),
        _sessionManager = sessionManager ?? AdminSessionManager.instance;

  final http.Client _client;
  final String _baseUrl;
  final AdminSessionManager _sessionManager;

  Uri _uri(String path, [Map<String, dynamic>? queryParameters]) {
    final baseUri = Uri.parse('$_baseUrl$path');
    if (queryParameters != null && queryParameters.isNotEmpty) {
      final cleaned = <String, String>{};
      queryParameters.forEach((key, value) {
        if (value != null && value.toString().trim().isNotEmpty) {
          cleaned[key] = value.toString();
        }
      });
      if (cleaned.isNotEmpty) {
        return baseUri.replace(queryParameters: cleaned);
      }
    }
    return baseUri;
  }

  Future<String> _getAuthToken(String? token) async {
    final activeToken = token ?? await _sessionManager.getToken();
    if (activeToken == null || activeToken.isEmpty) {
      throw AdminApiException(
        'No authentication token provided',
        statusCode: 401,
      );
    }
    return activeToken;
  }

  Future<http.Response> _sendWithTimeout(Future<http.Response> Function() call) async {
    try {
      return await call();
    } on TimeoutException {
      throw AdminApiException(
        'Connection timed out. Please check your network.',
        statusCode: 0,
      );
    } on http.ClientException catch (e) {
      throw AdminApiException(
        'Network error: ${e.message}',
        statusCode: 0,
      );
    } catch (e) {
      if (e is AdminApiException) rethrow;
      throw AdminApiException(
        'Unable to connect to server. Please try again.',
        statusCode: 0,
      );
    }
  }

  AdminApiException _parseError(http.Response response, String fallbackMessage) {
    String errorMessage = fallbackMessage;
    dynamic detail;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic> && decoded.containsKey('detail')) {
        detail = decoded['detail'];
        if (detail is String) {
          errorMessage = detail;
        } else if (detail is List && detail.isNotEmpty) {
          final first = detail.first;
          if (first is Map && first.containsKey('msg')) {
            errorMessage = first['msg'].toString();
          }
        }
      }
    } catch (_) {}

    return AdminApiException(
      errorMessage.isNotEmpty ? errorMessage : fallbackMessage,
      statusCode: response.statusCode,
      detail: detail,
    );
  }

  // =========================================================================
  // Orders API
  // =========================================================================

  /// Fetch a paginated list of orders with optional search and filters.
  Future<PaginatedOrdersResponse> getOrders({
    String? search,
    String? status,
    String? vehicleType,
    String? dateFrom,
    String? dateTo,
    int page = 1,
    int pageSize = 20,
    String? token,
  }) async {
    final authToken = await _getAuthToken(token);
    final url = _uri('/api/v1/admin/orders', {
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      if (status != null && status.trim().isNotEmpty && status != 'all') 'status': status.trim(),
      if (vehicleType != null && vehicleType.trim().isNotEmpty && vehicleType != 'all')
        'vehicle_type': vehicleType.trim(),
      if (dateFrom != null && dateFrom.trim().isNotEmpty) 'date_from': dateFrom.trim(),
      if (dateTo != null && dateTo.trim().isNotEmpty) 'date_to': dateTo.trim(),
      'page': page,
      'page_size': pageSize,
    });

    final response = await _sendWithTimeout(
      () => _client.get(
        url,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
      ),
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      return PaginatedOrdersResponse.fromJson(decoded);
    }

    throw _parseError(response, 'Failed to load orders');
  }

  /// Fetch full details for a specific order.
  Future<AdminOrderDetail> getOrderDetail(int orderId, {String? token}) async {
    final authToken = await _getAuthToken(token);
    final url = _uri('/api/v1/admin/orders/$orderId');

    final response = await _sendWithTimeout(
      () => _client.get(
        url,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
      ),
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      return AdminOrderDetail.fromJson(decoded);
    }

    throw _parseError(response, 'Failed to load order details');
  }

  /// Update the progression status of an order (e.g. dispatched, delivered).
  Future<AdminOrderDetail> updateOrderStatus(
    int orderId, {
    required String status,
    String? remarks,
    String? token,
  }) async {
    final authToken = await _getAuthToken(token);
    final url = _uri('/api/v1/admin/orders/$orderId/status');

    final body = jsonEncode({
      'status': status,
      if (remarks != null && remarks.trim().isNotEmpty) 'remarks': remarks.trim(),
    });

    final response = await _sendWithTimeout(
      () => _client.patch(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: body,
      ),
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      return AdminOrderDetail.fromJson(decoded);
    }

    throw _parseError(response, 'Failed to update order status');
  }

  // =========================================================================
  // Stock Requests API
  // =========================================================================

  /// Fetch a paginated list of stock requests with optional search and filters.
  Future<PaginatedStockRequestsResponse> getStockRequests({
    String? search,
    String? status,
    String? dateFrom,
    String? dateTo,
    int page = 1,
    int pageSize = 20,
    String? token,
  }) async {
    final authToken = await _getAuthToken(token);
    final url = _uri('/api/v1/admin/stock-requests', {
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      if (status != null && status.trim().isNotEmpty && status != 'all') 'status': status.trim(),
      if (dateFrom != null && dateFrom.trim().isNotEmpty) 'date_from': dateFrom.trim(),
      if (dateTo != null && dateTo.trim().isNotEmpty) 'date_to': dateTo.trim(),
      'page': page,
      'page_size': pageSize,
    });

    final response = await _sendWithTimeout(
      () => _client.get(
        url,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
      ),
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      return PaginatedStockRequestsResponse.fromJson(decoded);
    }

    throw _parseError(response, 'Failed to load stock requests');
  }

  /// Fetch full details for a specific stock request.
  Future<AdminStockRequestDetail> getStockRequestDetail(
    int requestId, {
    String? token,
  }) async {
    final authToken = await _getAuthToken(token);
    final url = _uri('/api/v1/admin/stock-requests/$requestId');

    final response = await _sendWithTimeout(
      () => _client.get(
        url,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
      ),
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      return AdminStockRequestDetail.fromJson(decoded);
    }

    throw _parseError(response, 'Failed to load stock request details');
  }
}
