import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/partner_order_models.dart';
import 'staff_session_manager.dart';

class StaffApiException implements Exception {
  const StaffApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'StaffApiException: $message';
}

class StaffAuthResponse {
  const StaffAuthResponse({required this.accessToken, required this.user});

  final String accessToken;
  final StaffUser user;

  factory StaffAuthResponse.fromJson(Map<String, dynamic> json) {
    final token = json['access_token'];
    final rawUser = json['user'];
    if (token is! String || token.isEmpty || rawUser is! Map<String, dynamic>) {
      throw const FormatException('Staff login response is invalid');
    }
    return StaffAuthResponse(
      accessToken: token,
      user: StaffUser.fromJson(rawUser),
    );
  }
}

class StaffAssignedPartner {
  const StaffAssignedPartner({
    required this.id,
    required this.name,
    required this.mobile,
    required this.businessName,
    required this.businessAddress,
    this.partnerCode,
  });

  final int id;
  final String name;
  final String mobile;
  final String businessName;
  final String businessAddress;
  final String? partnerCode;

  factory StaffAssignedPartner.fromJson(Map<String, dynamic> json) {
    if (json['id'] is! int ||
        json['name'] is! String ||
        json['mobile'] is! String ||
        json['business_name'] is! String ||
        json['business_address'] is! String) {
      throw const FormatException('Assigned Partner response is invalid');
    }
    return StaffAssignedPartner(
      id: json['id'] as int,
      name: json['name'] as String,
      mobile: json['mobile'] as String,
      businessName: json['business_name'] as String,
      businessAddress: json['business_address'] as String,
      partnerCode: json['partner_code'] as String?,
    );
  }
}


class StaffDashboardStats {
  const StaffDashboardStats({
    required this.dealersCount,
    required this.pendingOrdersCount,
    required this.pendingPaymentsCount,
  });

  final int dealersCount;
  final int pendingOrdersCount;
  final int pendingPaymentsCount;

  factory StaffDashboardStats.fromJson(Map<String, dynamic> json) {
    return StaffDashboardStats(
      dealersCount: json['dealers_count'] as int? ?? 0,
      pendingOrdersCount: json['pending_orders_count'] as int? ?? 0,
      pendingPaymentsCount: json['pending_payments_count'] as int? ?? 0,
    );
  }
}

class StaffApi {
  StaffApi({
    http.Client? client,
    String? baseUrl,
    StaffSessionManager? sessionManager,
  })  : _client = client ?? http.Client(),
        _baseUrl = (baseUrl ?? AppConfig.baseUrl)
            .trim()
            .replaceAll(RegExp(r'/+$'), ''),
        _sessionManager = sessionManager ?? StaffSessionManager.instance;

  final http.Client _client;
  final String _baseUrl;
  final StaffSessionManager _sessionManager;

  Uri _uri(String path) => Uri.parse('$_baseUrl$path');

  Future<http.Response> _send(
    Future<http.Response> Function() request,
  ) async {
    try {
      return await request().timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw const StaffApiException(
        'Connection timed out. Please check your network.',
        statusCode: 0,
      );
    } on http.ClientException catch (error) {
      throw StaffApiException(
        'Network error: ${error.message}',
        statusCode: 0,
      );
    }
  }

  StaffApiException _httpError(http.Response response, String fallback) {
    var message = fallback;
    try {
      final body = jsonDecode(response.body);
      if (body is Map<String, dynamic> && body['detail'] is String) {
        message = body['detail'] as String;
      }
    } on FormatException {
      // Keep the status-specific fallback when the response is not JSON.
    }
    return StaffApiException(message, statusCode: response.statusCode);
  }

  Future<StaffAuthResponse> login({
    required String staffId,
    required String password,
  }) async {
    final cleanStaffId = staffId.trim();
    if (cleanStaffId.isEmpty || password.isEmpty) {
      throw const StaffApiException('Staff ID and password are required');
    }

    final response = await _send(
      () => _client.post(
        _uri('/api/v1/auth/staff/login'),
        headers: const {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'staff_id': cleanStaffId, 'password': password}),
      ),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _httpError(response, 'Staff login failed');
    }
    try {
      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic>) {
        throw const FormatException('Expected JSON object');
      }
      return StaffAuthResponse.fromJson(body);
    } on FormatException {
      throw StaffApiException(
        'Invalid response received from server',
        statusCode: response.statusCode,
      );
    }
  }

  Future<StaffUser> getMe({String? token}) async {
    final activeToken = token ?? await _getToken();
    final response = await _send(
      () => _client.get(
        _uri('/api/v1/staff/me'),
        headers: _authHeaders(activeToken),
      ),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _httpError(response, 'Failed to verify Staff session');
    }
    try {
      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic>) {
        throw const FormatException('Expected JSON object');
      }
      return StaffUser.fromJson(body);
    } on FormatException {
      throw StaffApiException(
        'Invalid response received from server',
        statusCode: response.statusCode,
      );
    }
  }

  Future<List<StaffAssignedPartner>> getAssignedPartners() async {
    final token = await _getToken();
    final response = await _send(
      () => _client.get(
        _uri('/api/v1/staff/partners'),
        headers: _authHeaders(token),
      ),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _httpError(response, 'Failed to load assigned Partners');
    }
    try {
      final body = jsonDecode(response.body);
      if (body is! List<dynamic>) {
        throw const FormatException('Expected JSON list');
      }
      return body.map((item) {
        if (item is! Map<String, dynamic>) {
          throw const FormatException('Invalid Partner item');
        }
        return StaffAssignedPartner.fromJson(item);
      }).toList(growable: false);
    } on FormatException {
      throw StaffApiException(
        'Invalid response received from server',
        statusCode: response.statusCode,
      );
    }
  }

  Future<StaffDashboardStats> getDashboardStats() async {
    final token = await _getToken();
    final response = await _send(
      () => _client.get(
        _uri('/api/v1/staff/dashboard'),
        headers: _authHeaders(token),
      ),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _httpError(response, 'Failed to load staff dashboard statistics');
    }
    try {
      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic>) {
        throw const FormatException('Expected JSON object');
      }
      return StaffDashboardStats.fromJson(body);
    } on FormatException {
      throw StaffApiException(
        'Invalid response received from server',
        statusCode: response.statusCode,
      );
    }
  }

  Future<List<PartnerOrderResponse>> getOrders({
    String? status,
    String? search,
  }) async {
    final token = await _getToken();
    final queryParams = <String, String>{};
    if (status != null && status.isNotEmpty) queryParams['status'] = status;
    if (search != null && search.isNotEmpty) queryParams['search'] = search;

    final uri = Uri.parse('$_baseUrl/api/v1/staff/orders').replace(
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    );

    final response = await _send(
      () => _client.get(uri, headers: _authHeaders(token)),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _httpError(response, 'Failed to load staff orders');
    }
    try {
      final body = jsonDecode(response.body);
      if (body is! List<dynamic>) {
        throw const FormatException('Expected JSON list');
      }
      return body.map((item) {
        if (item is! Map<String, dynamic>) {
          throw const FormatException('Invalid Order item');
        }
        return PartnerOrderResponse.fromJson(item);
      }).toList(growable: false);
    } on FormatException {
      throw StaffApiException(
        'Invalid response received from server',
        statusCode: response.statusCode,
      );
    }
  }

  Future<PartnerOrderResponse> getOrder(int orderId) async {
    final token = await _getToken();
    final response = await _send(
      () => _client.get(
        _uri('/api/v1/staff/orders/$orderId'),
        headers: _authHeaders(token),
      ),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _httpError(response, 'Failed to load order detail');
    }
    try {
      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic>) {
        throw const FormatException('Expected JSON object');
      }
      return PartnerOrderResponse.fromJson(body);
    } on FormatException {
      throw StaffApiException(
        'Invalid response received from server',
        statusCode: response.statusCode,
      );
    }
  }

  Future<PartnerOrderResponse> approveOrder(int orderId, {String? remarks}) async {
    final token = await _getToken();
    final response = await _send(
      () => _client.post(
        _uri('/api/v1/staff/orders/$orderId/approve'),
        headers: {
          ..._authHeaders(token),
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          if (remarks != null && remarks.isNotEmpty) 'remarks': remarks,
        }),
      ),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _httpError(response, 'Failed to approve order');
    }
    try {
      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic>) {
        throw const FormatException('Expected JSON object');
      }
      return PartnerOrderResponse.fromJson(body);
    } on FormatException {
      throw StaffApiException(
        'Invalid response received from server',
        statusCode: response.statusCode,
      );
    }
  }

  Future<PartnerOrderResponse> rejectOrder(int orderId, {String? remarks}) async {
    final token = await _getToken();
    final response = await _send(
      () => _client.post(
        _uri('/api/v1/staff/orders/$orderId/reject'),
        headers: {
          ..._authHeaders(token),
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          if (remarks != null && remarks.isNotEmpty) 'remarks': remarks,
        }),
      ),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _httpError(response, 'Failed to reject order');
    }
    try {
      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic>) {
        throw const FormatException('Expected JSON object');
      }
      return PartnerOrderResponse.fromJson(body);
    } on FormatException {
      throw StaffApiException(
        'Invalid response received from server',
        statusCode: response.statusCode,
      );
    }
  }

  Future<PartnerOrderResponse> createOrder({
    required int partnerId,
    required List<CartItem> items,
    String? notes,
    String? idempotencyKey,
  }) async {
    final token = await _getToken();
    final response = await _send(
      () => _client.post(
        _uri('/api/v1/staff/orders'),
        headers: {
          ..._authHeaders(token),
          'Content-Type': 'application/json',
          if (idempotencyKey != null && idempotencyKey.isNotEmpty)
            'Idempotency-Key': idempotencyKey,
        },
        body: jsonEncode({
          'partner_id': partnerId,
          'items': items
              .map((item) => {
                    'product_id': item.product.id,
                    'quantity': item.quantity,
                  })
              .toList(),
          if (notes != null && notes.isNotEmpty) 'notes': notes,
          if (idempotencyKey != null && idempotencyKey.isNotEmpty)
            'idempotency_key': idempotencyKey,
        }),
      ),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _httpError(response, 'Failed to create dealer order');
    }
    try {
      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic>) {
        throw const FormatException('Expected JSON object');
      }
      return PartnerOrderResponse.fromJson(body);
    } on FormatException {
      throw StaffApiException(
        'Invalid response received from server',
        statusCode: response.statusCode,
      );
    }
  }

  Future<String> _getToken() async {
    final token = await _sessionManager.getToken();
    if (token == null || token.isEmpty) {
      throw const StaffApiException(
        'No authentication token provided',
        statusCode: 401,
      );
    }
    return token;
  }

  Map<String, String> _authHeaders(String token) => {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      };
}
