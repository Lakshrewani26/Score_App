import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/catalogue_models.dart';
import 'admin_session_manager.dart';
import 'customer_session_manager.dart';
import 'partner_session_manager.dart';
import 'staff_session_manager.dart';

class CatalogueApiException implements Exception {
  CatalogueApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'CatalogueApiException: $message';
}

class CatalogueApi {
  CatalogueApi({
    http.Client? client,
    String? baseUrl,
    PartnerSessionManager? partnerSessionManager,
    StaffSessionManager? staffSessionManager,
    AdminSessionManager? adminSessionManager,
    CustomerSessionManager? customerSessionManager,
  })  : _client = client ?? http.Client(),
        _baseUrl = (baseUrl ?? AppConfig.baseUrl).replaceAll(RegExp(r'/+$'), ''),
        _partnerSessionManager = partnerSessionManager,
        _staffSessionManager = staffSessionManager,
        _adminSessionManager = adminSessionManager,
        _customerSessionManager = customerSessionManager;

  final http.Client _client;
  final String _baseUrl;
  final PartnerSessionManager? _partnerSessionManager;
  final StaffSessionManager? _staffSessionManager;
  final AdminSessionManager? _adminSessionManager;
  final CustomerSessionManager? _customerSessionManager;

  Uri _uri(String path, [Map<String, dynamic>? queryParameters]) {
    final uri = Uri.parse('$_baseUrl$path');
    if (queryParameters == null || queryParameters.isEmpty) {
      return uri;
    }

    final cleaned = <String, String>{};
    queryParameters.forEach((key, value) {
      if (value == null) {
        return;
      }
      cleaned[key] = value.toString();
    });

    return uri.replace(queryParameters: cleaned.isEmpty ? null : cleaned);
  }

  Future<Map<String, String>> _authHeaders() async {
    final headers = <String, String>{};

    final partnerSession = _partnerSessionManager ?? PartnerSessionManager.instance;
    if (partnerSession.isAuthenticated) {
      final token = await partnerSession.getToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
        return headers;
      }
    }

    final staffSession = _staffSessionManager ?? StaffSessionManager.instance;
    if (staffSession.isAuthenticated) {
      final token = await staffSession.getToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
        return headers;
      }
    }

    final adminSession = _adminSessionManager ?? AdminSessionManager.instance;
    if (adminSession.isAuthenticated) {
      final token = await adminSession.tokenStorage.getToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
        return headers;
      }
    }

    final customerSession = _customerSessionManager ?? CustomerSessionManager.instance;
    if (customerSession.isAuthenticated) {
      final token = await customerSession.getToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
        return headers;
      }
    }

    return headers;
  }

  Future<List<CatalogueCategory>> loadCategories({String? vehicleType}) async {
    final query = <String, dynamic>{};
    if (vehicleType != null && vehicleType.trim().isNotEmpty) {
      query['vehicle_type'] = vehicleType.trim();
    }
    final headers = await _authHeaders();
    final response = await _client.get(
      _uri('/api/v1/categories', query.isEmpty ? null : query),
      headers: headers.isEmpty ? null : headers,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CatalogueApiException(
        'Unable to load categories',
        statusCode: response.statusCode,
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw const FormatException('Categories response is invalid');
    }

    return decoded
        .map((dynamic item) => CatalogueCategory.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<ProductPage> loadProducts({
    int? categoryId,
    String? vehicleType,
    String? search,
    int page = 1,
    int pageSize = 20,
  }) async {
    final query = <String, dynamic>{
      'page': page,
      'page_size': pageSize,
    };

    if (categoryId != null) {
      query['category_id'] = categoryId;
    }
    if (vehicleType != null && vehicleType.trim().isNotEmpty) {
      query['vehicle_type'] = vehicleType;
    }
    if (search != null && search.trim().isNotEmpty) {
      query['search'] = search.trim();
    }

    final headers = await _authHeaders();
    final response = await _client.get(
      _uri('/api/v1/products', query),
      headers: headers.isEmpty ? null : headers,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CatalogueApiException(
        'Unable to load products',
        statusCode: response.statusCode,
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Product list response is invalid');
    }

    return ProductPage.fromJson(decoded);
  }

  Future<CatalogueProduct> getProduct(int productId) async {
    final headers = await _authHeaders();
    final response = await _client.get(
      _uri('/api/v1/products/$productId'),
      headers: headers.isEmpty ? null : headers,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CatalogueApiException(
        'Unable to load product details',
        statusCode: response.statusCode,
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Product detail response is invalid');
    }

    return CatalogueProduct.fromJson(decoded);
  }
}
