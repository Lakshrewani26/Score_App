import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/admin_catalogue_models.dart';
import 'admin_api.dart';
import 'admin_session_manager.dart';

/// API client for Admin Catalogue operations: products, categories,
/// price updates, and activation status management.
class AdminCatalogueApi {
  AdminCatalogueApi({
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
        if (value != null) {
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

    if (response.statusCode == 400) {
      return AdminApiException(
        errorMessage.isNotEmpty ? errorMessage : 'Bad request',
        statusCode: 400,
        detail: detail,
      );
    } else if (response.statusCode == 401) {
      return AdminApiException(
        errorMessage.isNotEmpty ? errorMessage : 'Invalid or expired session',
        statusCode: 401,
        detail: detail,
      );
    } else if (response.statusCode == 403) {
      return AdminApiException(
        errorMessage.isNotEmpty ? errorMessage : 'Access denied: Admin privileges required',
        statusCode: 403,
        detail: detail,
      );
    } else if (response.statusCode == 404) {
      return AdminApiException(
        errorMessage.isNotEmpty ? errorMessage : fallbackMessage,
        statusCode: 404,
        detail: detail,
      );
    } else if (response.statusCode == 409) {
      return AdminApiException(
        errorMessage.isNotEmpty ? errorMessage : 'Conflict: record already exists',
        statusCode: 409,
        detail: detail,
      );
    } else if (response.statusCode == 422) {
      return AdminApiException(
        errorMessage.isNotEmpty ? errorMessage : 'Validation error',
        statusCode: 422,
        detail: detail,
      );
    } else if (response.statusCode >= 500) {
      return AdminApiException(
        'Server error. Please try again later.',
        statusCode: response.statusCode,
        detail: detail,
      );
    } else {
      return AdminApiException(
        errorMessage,
        statusCode: response.statusCode,
        detail: detail,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Products Endpoints
  // ---------------------------------------------------------------------------

  /// List products for Admin with optional category, vehicle type, search, status,
  /// price missing filters, and pagination.
  ///
  /// Sends GET to `/api/v1/admin/catalogue/products`.
  Future<AdminProductListResponse> getAdminProducts({
    int page = 1,
    int pageSize = 20,
    String? search,
    int? categoryId,
    String? vehicleType,
    String? status,
    bool? isActive,
    bool? hasPrice,
    bool? priceMissing,
    String? token,
  }) async {
    final activeToken = await _getAuthToken(token);

    final queryParams = <String, dynamic>{
      'page': page,
      'page_size': pageSize,
    };
    if (search != null && search.trim().isNotEmpty) {
      queryParams['search'] = search.trim();
    }
    if (categoryId != null) {
      queryParams['category_id'] = categoryId;
    }
    if (vehicleType != null && vehicleType.trim().isNotEmpty) {
      queryParams['vehicle_type'] = vehicleType.trim();
    }
    if (status != null && status.trim().isNotEmpty && status.toLowerCase() != 'all') {
      queryParams['status'] = status.toLowerCase().trim();
    }
    if (isActive != null) {
      queryParams['is_active'] = isActive;
    }
    if (hasPrice != null) {
      queryParams['has_price'] = hasPrice;
    }
    if (priceMissing != null) {
      queryParams['price_missing'] = priceMissing;
    }

    final url = _uri('/api/v1/admin/catalogue/products', queryParams);
    final response = await _sendWithTimeout(() => _client.get(
          url,
          headers: {
            'Authorization': 'Bearer $activeToken',
            'Accept': 'application/json',
          },
        ));

    if (response.statusCode >= 200 && response.statusCode < 300) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is! Map<String, dynamic>) {
          throw const FormatException('Expected JSON object');
        }
        return AdminProductListResponse.fromJson(decoded);
      } catch (e) {
        throw AdminApiException(
          'Invalid response received from server',
          statusCode: response.statusCode,
        );
      }
    }

    throw _parseError(response, 'Failed to fetch products');
  }

  /// Retrieve full product details for Admin.
  ///
  /// Sends GET to `/api/v1/admin/catalogue/products/{productId}`.
  Future<AdminProduct> getAdminProductDetail(
    int productId, {
    String? token,
  }) async {
    final activeToken = await _getAuthToken(token);

    final url = _uri('/api/v1/admin/catalogue/products/$productId');
    final response = await _sendWithTimeout(() => _client.get(
          url,
          headers: {
            'Authorization': 'Bearer $activeToken',
            'Accept': 'application/json',
          },
        ));

    if (response.statusCode >= 200 && response.statusCode < 300) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is! Map<String, dynamic>) {
          throw const FormatException('Expected JSON object');
        }
        return AdminProduct.fromJson(decoded);
      } catch (e) {
        throw AdminApiException(
          'Invalid response received from server',
          statusCode: response.statusCode,
        );
      }
    }

    throw _parseError(response, 'Failed to fetch product details');
  }

  /// Create a new product.
  ///
  /// Sends POST to `/api/v1/admin/catalogue/products`.
  Future<AdminProduct> createProduct(
    AdminProductCreateRequest request, {
    String? token,
  }) async {
    final activeToken = await _getAuthToken(token);

    final url = _uri('/api/v1/admin/catalogue/products');
    final response = await _sendWithTimeout(() => _client.post(
          url,
          headers: {
            'Authorization': 'Bearer $activeToken',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode(request.toJson()),
        ));

    if (response.statusCode >= 200 && response.statusCode < 300) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is! Map<String, dynamic>) {
          throw const FormatException('Expected JSON object');
        }
        return AdminProduct.fromJson(decoded);
      } catch (e) {
        throw AdminApiException(
          'Invalid response received from server',
          statusCode: response.statusCode,
        );
      }
    }

    throw _parseError(response, 'Failed to create product');
  }

  /// Update editable product fields.
  ///
  /// Sends POST to `/api/v1/admin/catalogue/products/{productId}/update`.
  Future<AdminProduct> updateProduct(
    int productId,
    AdminProductUpdateRequest request, {
    String? token,
  }) async {
    final activeToken = await _getAuthToken(token);

    final url = _uri('/api/v1/admin/catalogue/products/$productId/update');
    final response = await _sendWithTimeout(() => _client.post(
          url,
          headers: {
            'Authorization': 'Bearer $activeToken',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode(request.toJson()),
        ));

    if (response.statusCode >= 200 && response.statusCode < 300) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is! Map<String, dynamic>) {
          throw const FormatException('Expected JSON object');
        }
        return AdminProduct.fromJson(decoded);
      } catch (e) {
        throw AdminApiException(
          'Invalid response received from server',
          statusCode: response.statusCode,
        );
      }
    }

    throw _parseError(response, 'Failed to update product');
  }

  /// Activate or deactivate a product.
  ///
  /// Sends POST to `/api/v1/admin/catalogue/products/{productId}/status`.
  Future<AdminProduct> updateProductStatus(
    int productId,
    bool isActive, {
    String? token,
  }) async {
    final activeToken = await _getAuthToken(token);

    final url = _uri('/api/v1/admin/catalogue/products/$productId/status');
    final response = await _sendWithTimeout(() => _client.post(
          url,
          headers: {
            'Authorization': 'Bearer $activeToken',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({'is_active': isActive}),
        ));

    if (response.statusCode >= 200 && response.statusCode < 300) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is! Map<String, dynamic>) {
          throw const FormatException('Expected JSON object');
        }
        return AdminProduct.fromJson(decoded);
      } catch (e) {
        throw AdminApiException(
          'Invalid response received from server',
          statusCode: response.statusCode,
        );
      }
    }

    throw _parseError(response, 'Failed to update product status');
  }

  // ---------------------------------------------------------------------------
  // Category Endpoints
  // ---------------------------------------------------------------------------

  /// List all categories for Admin (active and inactive) with product count.
  ///
  /// Sends GET to `/api/v1/admin/catalogue/categories`.
  Future<List<AdminCategory>> getAdminCategories({
    String? status,
    bool? isActive,
    String? search,
    String? token,
  }) async {
    final activeToken = await _getAuthToken(token);

    final queryParams = <String, dynamic>{};
    if (status != null && status.trim().isNotEmpty && status.toLowerCase() != 'all') {
      queryParams['status'] = status.toLowerCase().trim();
    }
    if (isActive != null) {
      queryParams['is_active'] = isActive;
    }
    if (search != null && search.trim().isNotEmpty) {
      queryParams['search'] = search.trim();
    }

    final url = _uri('/api/v1/admin/catalogue/categories', queryParams);
    final response = await _sendWithTimeout(() => _client.get(
          url,
          headers: {
            'Authorization': 'Bearer $activeToken',
            'Accept': 'application/json',
          },
        ));

    if (response.statusCode >= 200 && response.statusCode < 300) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is! List) {
          throw const FormatException('Expected JSON array');
        }
        return decoded
            .map((item) => AdminCategory.fromJson(item as Map<String, dynamic>))
            .toList();
      } catch (e) {
        throw AdminApiException(
          'Invalid response received from server',
          statusCode: response.statusCode,
        );
      }
    }

    throw _parseError(response, 'Failed to fetch categories');
  }

  /// Create a new product category.
  ///
  /// Sends POST to `/api/v1/admin/catalogue/categories`.
  Future<AdminCategory> createCategory(
    AdminCategoryCreateRequest request, {
    String? token,
  }) async {
    final activeToken = await _getAuthToken(token);

    final url = _uri('/api/v1/admin/catalogue/categories');
    final response = await _sendWithTimeout(() => _client.post(
          url,
          headers: {
            'Authorization': 'Bearer $activeToken',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode(request.toJson()),
        ));

    if (response.statusCode >= 200 && response.statusCode < 300) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is! Map<String, dynamic>) {
          throw const FormatException('Expected JSON object');
        }
        return AdminCategory.fromJson(decoded);
      } catch (e) {
        throw AdminApiException(
          'Invalid response received from server',
          statusCode: response.statusCode,
        );
      }
    }

    throw _parseError(response, 'Failed to create category');
  }

  /// Activate or deactivate a category.
  ///
  /// Sends POST to `/api/v1/admin/catalogue/categories/{categoryId}/status`.
  Future<AdminCategory> updateCategoryStatus(
    int categoryId,
    bool isActive, {
    String? token,
  }) async {
    final activeToken = await _getAuthToken(token);

    final url = _uri('/api/v1/admin/catalogue/categories/$categoryId/status');
    final response = await _sendWithTimeout(() => _client.post(
          url,
          headers: {
            'Authorization': 'Bearer $activeToken',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({'is_active': isActive}),
        ));

    if (response.statusCode >= 200 && response.statusCode < 300) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is! Map<String, dynamic>) {
          throw const FormatException('Expected JSON object');
        }
        return AdminCategory.fromJson(decoded);
      } catch (e) {
        throw AdminApiException(
          'Invalid response received from server',
          statusCode: response.statusCode,
        );
      }
    }

    throw _parseError(response, 'Failed to update category status');
  }
}
