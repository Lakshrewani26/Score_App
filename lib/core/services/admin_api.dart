import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/admin_models.dart';
import 'admin_catalogue_api.dart';
import 'admin_orders_api.dart';
import 'admin_reports_api.dart';
import 'admin_qr_api.dart';
import 'admin_settings_api.dart';
import 'admin_session_manager.dart';

class AdminApiException implements Exception {
  AdminApiException(this.message, {this.statusCode, this.detail});

  final String message;
  final int? statusCode;
  final dynamic detail;

  @override
  String toString() => 'AdminApiException: $message (statusCode: $statusCode)';
}

class AdminApi {
  AdminApi({
    http.Client? client,
    String? baseUrl,
    AdminSessionManager? sessionManager,
  })  : _client = client ?? http.Client(),
        _baseUrl =
            (baseUrl ?? AppConfig.baseUrl).replaceAll(RegExp(r'/+$'), ''),
        _sessionManager = sessionManager ?? AdminSessionManager.instance;

  final http.Client _client;
  final String _baseUrl;
  final AdminSessionManager _sessionManager;

  Uri _uri(String path, [Map<String, dynamic>? queryParameters]) {
    final baseUri = Uri.parse('$_baseUrl$path');
    if (queryParameters != null && queryParameters.isNotEmpty) {
      return baseUri.replace(queryParameters: queryParameters);
    }
    return baseUri;
  }

  Future<http.Response> _sendWithTimeout(
      Future<http.Response> Function() call) async {
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

  AdminApiException _parseError(
      http.Response response, String fallbackMessage) {
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
        errorMessage.isNotEmpty
            ? errorMessage
            : 'Access denied: Admin privileges required',
        statusCode: 403,
        detail: detail,
      );
    } else if (response.statusCode == 404) {
      return AdminApiException(
        errorMessage.isNotEmpty ? errorMessage : 'User not found',
        statusCode: 404,
        detail: detail,
      );
    } else if (response.statusCode == 409) {
      return AdminApiException(
        errorMessage.isNotEmpty
            ? errorMessage
            : 'Conflict: record already exists',
        statusCode: 409,
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

  /// Authenticates an Admin using mobile number and password.
  ///
  /// Sends POST to `/api/v1/auth/admin/login`.
  /// Never logs credentials or returned access tokens.
  Future<AdminAuthResponse> login({
    required String mobile,
    required String password,
  }) async {
    final cleanedMobile = mobile.trim();
    if (cleanedMobile.isEmpty || password.isEmpty) {
      throw AdminApiException(
        'Mobile number and password are required',
        statusCode: 400,
      );
    }

    final url = _uri('/api/v1/auth/admin/login');
    http.Response response;
    try {
      response = await _client.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'mobile': cleanedMobile,
          'password': password,
        }),
      );
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

    if (response.statusCode >= 200 && response.statusCode < 300) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is! Map<String, dynamic>) {
          throw const FormatException('Expected JSON object');
        }
        return AdminAuthResponse.fromJson(decoded);
      } catch (e) {
        throw AdminApiException(
          'Invalid response received from server',
          statusCode: response.statusCode,
        );
      }
    }

    // Attempt to extract detail error message from backend response
    String errorMessage = 'Login failed';
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
    } catch (_) {
      // Body was not JSON
    }

    if (response.statusCode == 401) {
      throw AdminApiException(
        errorMessage.isNotEmpty
            ? errorMessage
            : 'Invalid mobile number or password',
        statusCode: 401,
        detail: detail,
      );
    } else if (response.statusCode == 403) {
      throw AdminApiException(
        errorMessage.isNotEmpty
            ? errorMessage
            : 'Access denied: Admin privileges required',
        statusCode: 403,
        detail: detail,
      );
    } else if (response.statusCode >= 500) {
      throw AdminApiException(
        'Server error. Please try again later.',
        statusCode: response.statusCode,
      );
    } else {
      throw AdminApiException(
        errorMessage,
        statusCode: response.statusCode,
        detail: detail,
      );
    }
  }

  /// Verifies active Admin authentication via `/api/v1/admin/me`.
  ///
  /// Transmits the access token in the `Authorization: Bearer <token>` header.
  Future<AdminUser> getMe({String? token}) async {
    final activeToken = token ?? await _sessionManager.getToken();
    if (activeToken == null || activeToken.isEmpty) {
      throw AdminApiException(
        'No authentication token provided',
        statusCode: 401,
      );
    }

    final url = _uri('/api/v1/admin/me');
    http.Response response;
    try {
      response = await _client.get(
        url,
        headers: {
          'Authorization': 'Bearer $activeToken',
          'Accept': 'application/json',
        },
      );
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

    if (response.statusCode >= 200 && response.statusCode < 300) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is! Map<String, dynamic>) {
          throw const FormatException('Expected JSON object');
        }
        return AdminUser.fromJson(decoded);
      } catch (e) {
        throw AdminApiException(
          'Invalid response received from server',
          statusCode: response.statusCode,
        );
      }
    }

    String errorMessage = 'Admin verification failed';
    dynamic detail;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic> && decoded.containsKey('detail')) {
        detail = decoded['detail'];
        if (detail is String) {
          errorMessage = detail;
        }
      }
    } catch (_) {}

    if (response.statusCode == 401) {
      throw AdminApiException(
        errorMessage.isNotEmpty ? errorMessage : 'Invalid or expired session',
        statusCode: 401,
        detail: detail,
      );
    } else if (response.statusCode == 403) {
      throw AdminApiException(
        errorMessage.isNotEmpty
            ? errorMessage
            : 'Access denied: Admin privileges required',
        statusCode: 403,
        detail: detail,
      );
    } else if (response.statusCode >= 500) {
      throw AdminApiException(
        'Server error. Please try again later.',
        statusCode: response.statusCode,
      );
    } else {
      throw AdminApiException(
        errorMessage,
        statusCode: response.statusCode,
        detail: detail,
      );
    }
  }

  /// List users with optional role, search, is_active, zone_id, page, and page_size filters.
  Future<AdminPaginatedUsers> getUsers({
    String? role,
    String? search,
    bool? isActive,
    int? zoneId,
    int page = 1,
    int pageSize = 20,
    String? token,
  }) async {
    final activeToken = token ?? await _sessionManager.getToken();
    if (activeToken == null || activeToken.isEmpty) {
      throw AdminApiException(
        'No authentication token provided',
        statusCode: 401,
      );
    }

    final queryParams = <String, String>{
      'page': page.toString(),
      'page_size': pageSize.toString(),
    };
    if (role != null && role.isNotEmpty && role.toLowerCase() != 'all') {
      queryParams['role'] = role.toLowerCase();
    }
    if (search != null && search.trim().isNotEmpty) {
      queryParams['search'] = search.trim();
    }
    if (isActive != null) {
      queryParams['is_active'] = isActive.toString();
    }
    if (zoneId != null) {
      queryParams['zone_id'] = zoneId.toString();
    }

    final url = _uri('/api/v1/admin/users', queryParams);
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
        return AdminPaginatedUsers.fromJson(decoded);
      } catch (e) {
        throw AdminApiException(
          'Invalid response received from server',
          statusCode: response.statusCode,
        );
      }
    }

    throw _parseError(response, 'Failed to fetch users');
  }

  Future<List<AdminStaffPartnerAssignment>> getStaffPartnerAssignments({
    bool? isActive,
    String? token,
  }) async {
    final activeToken = token ?? await _sessionManager.getToken();
    if (activeToken == null || activeToken.isEmpty) {
      throw AdminApiException(
        'No authentication token provided',
        statusCode: 401,
      );
    }

    final queryParameters = <String, String>{};
    if (isActive != null) {
      queryParameters['is_active'] = isActive.toString();
    }
    final response = await _sendWithTimeout(
      () => _client.get(
        _uri(
          '/api/v1/admin/staff-partner-assignments',
          queryParameters,
        ),
        headers: {
          'Authorization': 'Bearer $activeToken',
          'Accept': 'application/json',
        },
      ),
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is! List<dynamic>) {
          throw const FormatException('Expected JSON list');
        }
        return decoded.map((item) {
          if (item is! Map<String, dynamic>) {
            throw const FormatException('Invalid assignment item');
          }
          return AdminStaffPartnerAssignment.fromJson(item);
        }).toList(growable: false);
      } on FormatException {
        throw AdminApiException(
          'Invalid response received from server',
          statusCode: response.statusCode,
        );
      }
    }
    throw _parseError(response, 'Failed to fetch Staff-Partner assignments');
  }

  Future<AdminStaffPartnerAssignment> createStaffPartnerAssignment({
    required int staffId,
    required int partnerId,
    String? token,
  }) async {
    final activeToken = token ?? await _sessionManager.getToken();
    if (activeToken == null || activeToken.isEmpty) {
      throw AdminApiException(
        'No authentication token provided',
        statusCode: 401,
      );
    }

    final response = await _sendWithTimeout(
      () => _client.post(
        _uri('/api/v1/admin/staff-partner-assignments'),
        headers: {
          'Authorization': 'Bearer $activeToken',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'staff_id': staffId, 'partner_id': partnerId}),
      ),
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is! Map<String, dynamic>) {
          throw const FormatException('Expected JSON object');
        }
        return AdminStaffPartnerAssignment.fromJson(decoded);
      } on FormatException {
        throw AdminApiException(
          'Invalid response received from server',
          statusCode: response.statusCode,
        );
      }
    }
    throw _parseError(response, 'Failed to assign Partner to Staff');
  }

  /// Retrieve full user details including role-specific profile data.
  Future<AdminUserDetail> getUserDetail({
    required int userId,
    String? token,
  }) async {
    final activeToken = token ?? await _sessionManager.getToken();
    if (activeToken == null || activeToken.isEmpty) {
      throw AdminApiException(
        'No authentication token provided',
        statusCode: 401,
      );
    }

    final url = _uri('/api/v1/admin/users/$userId');
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
        return AdminUserDetail.fromJson(decoded);
      } catch (e) {
        throw AdminApiException(
          'Invalid response received from server',
          statusCode: response.statusCode,
        );
      }
    }

    throw _parseError(response, 'Failed to fetch user details');
  }

  /// Create a Partner account and PartnerProfile atomically.
  Future<AdminUserDetail> createPartner({
    required CreatePartnerPayload payload,
    String? token,
  }) async {
    final activeToken = token ?? await _sessionManager.getToken();
    if (activeToken == null || activeToken.isEmpty) {
      throw AdminApiException(
        'No authentication token provided',
        statusCode: 401,
      );
    }

    final url = _uri('/api/v1/admin/users/partners');
    final response = await _sendWithTimeout(() => _client.post(
          url,
          headers: {
            'Authorization': 'Bearer $activeToken',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode(payload.toJson()),
        ));

    if (response.statusCode >= 200 && response.statusCode < 300) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is! Map<String, dynamic>) {
          throw const FormatException('Expected JSON object');
        }
        return AdminUserDetail.fromJson(decoded);
      } catch (e) {
        throw AdminApiException(
          'Invalid response received from server',
          statusCode: response.statusCode,
        );
      }
    }

    throw _parseError(response, 'Failed to create partner');
  }

  /// Create a Staff account and StaffProfile atomically.
  Future<AdminUserDetail> createStaff({
    required CreateStaffPayload payload,
    String? token,
  }) async {
    final activeToken = token ?? await _sessionManager.getToken();
    if (activeToken == null || activeToken.isEmpty) {
      throw AdminApiException(
        'No authentication token provided',
        statusCode: 401,
      );
    }

    final url = _uri('/api/v1/admin/users/staff');
    final response = await _sendWithTimeout(() => _client.post(
          url,
          headers: {
            'Authorization': 'Bearer $activeToken',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode(payload.toJson()),
        ));

    if (response.statusCode >= 200 && response.statusCode < 300) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is! Map<String, dynamic>) {
          throw const FormatException('Expected JSON object');
        }
        return AdminUserDetail.fromJson(decoded);
      } catch (e) {
        throw AdminApiException(
          'Invalid response received from server',
          statusCode: response.statusCode,
        );
      }
    }

    throw _parseError(response, 'Failed to create staff member');
  }

  /// Activate or deactivate a user account.
  Future<AdminUserSummary> updateUserStatus({
    required int userId,
    required bool isActive,
    String? token,
  }) async {
    final activeToken = token ?? await _sessionManager.getToken();
    if (activeToken == null || activeToken.isEmpty) {
      throw AdminApiException(
        'No authentication token provided',
        statusCode: 401,
      );
    }

    final url = _uri('/api/v1/admin/users/$userId/status');
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
        return AdminUserSummary.fromJson(decoded);
      } catch (e) {
        throw AdminApiException(
          'Invalid response received from server',
          statusCode: response.statusCode,
        );
      }
    }

    throw _parseError(response, 'Failed to update user status');
  }

  /// Create a Customer account atomically from Admin.
  Future<AdminUserDetail> createCustomer({
    required CreateCustomerPayload payload,
    String? token,
  }) async {
    final activeToken = token ?? await _sessionManager.getToken();
    if (activeToken == null || activeToken.isEmpty) {
      throw AdminApiException(
        'No authentication token provided',
        statusCode: 401,
      );
    }

    final url = _uri('/api/v1/admin/users/customers');
    final response = await _sendWithTimeout(() => _client.post(
          url,
          headers: {
            'Authorization': 'Bearer $activeToken',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode(payload.toJson()),
        ));

    if (response.statusCode >= 200 && response.statusCode < 300) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is! Map<String, dynamic>) {
          throw const FormatException('Expected JSON object');
        }
        return AdminUserDetail.fromJson(decoded);
      } catch (e) {
        throw AdminApiException(
          'Invalid response received from server',
          statusCode: response.statusCode,
        );
      }
    }

    throw _parseError(response, 'Failed to create customer');
  }

  /// Update user account details (Customer, Partner, Staff).
  Future<AdminUserDetail> updateUser({
    required int userId,
    required UpdateUserPayload payload,
    String? token,
  }) async {
    final activeToken = token ?? await _sessionManager.getToken();
    if (activeToken == null || activeToken.isEmpty) {
      throw AdminApiException(
        'No authentication token provided',
        statusCode: 401,
      );
    }

    final url = _uri('/api/v1/admin/users/$userId');
    final response = await _sendWithTimeout(() => _client.put(
          url,
          headers: {
            'Authorization': 'Bearer $activeToken',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode(payload.toJson()),
        ));

    if (response.statusCode >= 200 && response.statusCode < 300) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is! Map<String, dynamic>) {
          throw const FormatException('Expected JSON object');
        }
        return AdminUserDetail.fromJson(decoded);
      } catch (e) {
        throw AdminApiException(
          'Invalid response received from server',
          statusCode: response.statusCode,
        );
      }
    }

    throw _parseError(response, 'Failed to update user');
  }

  /// Delete or safely deactivate a user account.
  Future<UserDeleteResult> deleteUser({
    required int userId,
    String? token,
  }) async {
    final activeToken = token ?? await _sessionManager.getToken();
    if (activeToken == null || activeToken.isEmpty) {
      throw AdminApiException(
        'No authentication token provided',
        statusCode: 401,
      );
    }

    final url = _uri('/api/v1/admin/users/$userId');
    final response = await _sendWithTimeout(() => _client.delete(
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
        return UserDeleteResult.fromJson(decoded);
      } catch (e) {
        throw AdminApiException(
          'Invalid response received from server',
          statusCode: response.statusCode,
        );
      }
    }

    throw _parseError(response, 'Failed to delete user');
  }

  // ---------------------------------------------------------------------------
  // Zone Management Endpoints
  // ---------------------------------------------------------------------------

  /// List zones with optional status and search filter.
  Future<List<AdminZone>> getZones({
    bool? isActive,
    String? search,
    String? token,
  }) async {
    final activeToken = token ?? await _sessionManager.getToken();
    if (activeToken == null || activeToken.isEmpty) {
      throw AdminApiException(
        'No authentication token provided',
        statusCode: 401,
      );
    }

    final queryParams = <String, String>{};
    if (isActive != null) {
      queryParams['is_active'] = isActive.toString();
    }
    if (search != null && search.trim().isNotEmpty) {
      queryParams['search'] = search.trim();
    }

    final url = _uri('/api/v1/admin/zones', queryParams);
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
        if (decoded is Map<String, dynamic> && decoded.containsKey('items')) {
          final items = decoded['items'] as List<dynamic>? ?? const [];
          return items
              .whereType<Map<String, dynamic>>()
              .map((e) => AdminZone.fromJson(e))
              .toList();
        }
        throw const FormatException('Expected ZoneListResponse with items');
      } catch (e) {
        throw AdminApiException(
          'Invalid response received from server',
          statusCode: response.statusCode,
        );
      }
    }

    throw _parseError(response, 'Failed to fetch zones');
  }

  /// Create a new Zone.
  Future<AdminZone> createZone({
    required String name,
    String? description,
    bool isActive = true,
    String? token,
  }) async {
    final activeToken = token ?? await _sessionManager.getToken();
    if (activeToken == null || activeToken.isEmpty) {
      throw AdminApiException(
        'No authentication token provided',
        statusCode: 401,
      );
    }

    final url = _uri('/api/v1/admin/zones');
    final response = await _sendWithTimeout(() => _client.post(
          url,
          headers: {
            'Authorization': 'Bearer $activeToken',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({
            'name': name.trim(),
            if (description != null && description.trim().isNotEmpty)
              'description': description.trim(),
            'is_active': isActive,
          }),
        ));

    if (response.statusCode >= 200 && response.statusCode < 300) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is! Map<String, dynamic>) {
          throw const FormatException('Expected JSON object');
        }
        return AdminZone.fromJson(decoded);
      } catch (e) {
        throw AdminApiException(
          'Invalid response received from server',
          statusCode: response.statusCode,
        );
      }
    }

    throw _parseError(response, 'Failed to create zone');
  }

  /// Update an existing Zone.
  Future<AdminZone> updateZone({
    required int zoneId,
    String? name,
    String? description,
    bool? isActive,
    String? token,
  }) async {
    final activeToken = token ?? await _sessionManager.getToken();
    if (activeToken == null || activeToken.isEmpty) {
      throw AdminApiException(
        'No authentication token provided',
        statusCode: 401,
      );
    }

    final body = <String, dynamic>{};
    if (name != null) body['name'] = name.trim();
    if (description != null) body['description'] = description.trim();
    if (isActive != null) body['is_active'] = isActive;

    final url = _uri('/api/v1/admin/zones/$zoneId');
    final response = await _sendWithTimeout(() => _client.patch(
          url,
          headers: {
            'Authorization': 'Bearer $activeToken',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode(body),
        ));

    if (response.statusCode >= 200 && response.statusCode < 300) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is! Map<String, dynamic>) {
          throw const FormatException('Expected JSON object');
        }
        return AdminZone.fromJson(decoded);
      } catch (e) {
        throw AdminApiException(
          'Invalid response received from server',
          statusCode: response.statusCode,
        );
      }
    }

    throw _parseError(response, 'Failed to update zone');
  }

  /// Activate or deactivate a Zone.
  Future<AdminZone> updateZoneStatus({
    required int zoneId,
    required bool isActive,
    String? token,
  }) async {
    final activeToken = token ?? await _sessionManager.getToken();
    if (activeToken == null || activeToken.isEmpty) {
      throw AdminApiException(
        'No authentication token provided',
        statusCode: 401,
      );
    }

    final url = _uri('/api/v1/admin/zones/$zoneId/status');
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
        return AdminZone.fromJson(decoded);
      } catch (e) {
        throw AdminApiException(
          'Invalid response received from server',
          statusCode: response.statusCode,
        );
      }
    }

    throw _parseError(response, 'Failed to update zone status');
  }

  /// Securely update the authenticated Admin's password.
  ///
  /// Sends POST to `/api/v1/admin/me/password` with `current_password` and `new_password`.
  /// Never prints, displays, or logs passwords or tokens.
  Future<AdminPasswordUpdateResponse> updatePassword({
    required String currentPassword,
    required String newPassword,
    String? token,
  }) async {
    if (currentPassword.isEmpty) {
      throw AdminApiException(
        'Current password is required',
        statusCode: 400,
      );
    }
    if (newPassword.isEmpty) {
      throw AdminApiException(
        'New password is required',
        statusCode: 400,
      );
    }
    if (newPassword.length < 8) {
      throw AdminApiException(
        'New password must be at least 8 characters long',
        statusCode: 400,
      );
    }
    if (currentPassword == newPassword) {
      throw AdminApiException(
        'New password must be different from current password',
        statusCode: 400,
      );
    }

    final activeToken = token ?? await _sessionManager.getToken();
    if (activeToken == null || activeToken.isEmpty) {
      throw AdminApiException(
        'No authentication token provided',
        statusCode: 401,
      );
    }

    final url = _uri('/api/v1/admin/me/password');
    final response = await _sendWithTimeout(() => _client.post(
          url,
          headers: {
            'Authorization': 'Bearer $activeToken',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({
            'current_password': currentPassword,
            'new_password': newPassword,
          }),
        ));

    if (response.statusCode >= 200 && response.statusCode < 300) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is! Map<String, dynamic>) {
          throw const FormatException('Expected JSON object');
        }
        return AdminPasswordUpdateResponse.fromJson(decoded);
      } catch (e) {
        throw AdminApiException(
          'Invalid response received from server',
          statusCode: response.statusCode,
        );
      }
    }

    throw _parseError(response, 'Failed to update password');
  }

  // ---------------------------------------------------------------------------
  // Admin Catalogue Integration
  // ---------------------------------------------------------------------------

  AdminCatalogueApi? _catalogueApi;
  AdminCatalogueApi get catalogue => _catalogueApi ??= AdminCatalogueApi(
        client: _client,
        baseUrl: _baseUrl,
        sessionManager: _sessionManager,
      );

  /// List products for Admin.
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
  }) =>
      catalogue.getAdminProducts(
        page: page,
        pageSize: pageSize,
        search: search,
        categoryId: categoryId,
        vehicleType: vehicleType,
        status: status,
        isActive: isActive,
        hasPrice: hasPrice,
        priceMissing: priceMissing,
        token: token,
      );

  /// Retrieve full product details for Admin.
  Future<AdminProduct> getAdminProductDetail(int productId, {String? token}) =>
      catalogue.getAdminProductDetail(productId, token: token);

  /// Create a new product.
  Future<AdminProduct> createProduct(
    AdminProductCreateRequest request, {
    String? token,
  }) =>
      catalogue.createProduct(request, token: token);

  /// Update editable product fields.
  Future<AdminProduct> updateProduct(
    int productId,
    AdminProductUpdateRequest request, {
    String? token,
  }) =>
      catalogue.updateProduct(productId, request, token: token);

  /// Activate or deactivate a product.
  Future<AdminProduct> updateProductStatus(
    int productId,
    bool isActive, {
    String? token,
  }) =>
      catalogue.updateProductStatus(productId, isActive, token: token);

  /// List all categories for Admin (active and inactive) with product count.
  Future<List<AdminCategory>> getAdminCategories({
    String? status,
    bool? isActive,
    String? search,
    String? token,
  }) =>
      catalogue.getAdminCategories(
        status: status,
        isActive: isActive,
        search: search,
        token: token,
      );

  /// Create a new product category.
  Future<AdminCategory> createCategory(
    AdminCategoryCreateRequest request, {
    String? token,
  }) =>
      catalogue.createCategory(request, token: token);

  /// Activate or deactivate a category.
  Future<AdminCategory> updateCategoryStatus(
    int categoryId,
    bool isActive, {
    String? token,
  }) =>
      catalogue.updateCategoryStatus(categoryId, isActive, token: token);

  // ---------------------------------------------------------------------------
  // Admin Orders & Requests Integration
  // ---------------------------------------------------------------------------

  AdminOrdersApi? _ordersApi;
  AdminOrdersApi get orders => _ordersApi ??= AdminOrdersApi(
        client: _client,
        baseUrl: _baseUrl,
        sessionManager: _sessionManager,
      );

  // ---------------------------------------------------------------------------
  // Admin Reports & Analytics Integration
  // ---------------------------------------------------------------------------

  AdminReportsApi? _reportsApi;
  AdminReportsApi get reports => _reportsApi ??= AdminReportsApi(
        client: _client,
        baseUrl: _baseUrl,
        sessionManager: _sessionManager,
      );

  // ---------------------------------------------------------------------------
  // Admin System Settings & Points Rules Integration
  // ---------------------------------------------------------------------------

  AdminSettingsApi? _settingsApi;
  AdminSettingsApi get settings => _settingsApi ??= AdminSettingsApi(
        client: _client,
        baseUrl: _baseUrl,
        sessionManager: _sessionManager,
      );

  // ---------------------------------------------------------------------------
  // Admin QR Code Generation & Batch Management Integration
  // ---------------------------------------------------------------------------

  AdminQrApi? _qrApi;
  AdminQrApi get qr => _qrApi ??= AdminQrApi(
        client: _client,
        baseUrl: _baseUrl,
        sessionManager: _sessionManager,
      );
}
