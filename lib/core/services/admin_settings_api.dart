import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/admin_settings_models.dart';
import 'admin_api.dart';
import 'admin_session_manager.dart';

/// API client for Admin System Settings and Points System Rules operations.
class AdminSettingsApi {
  AdminSettingsApi({
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
          cleaned[key] = value.toString().trim();
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
        errorMessage.isNotEmpty ? errorMessage : 'Rule not found',
        statusCode: 404,
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
  // System Info
  // ---------------------------------------------------------------------------

  /// Retrieves read-only system metadata from `/api/v1/admin/settings/system-info`.
  Future<AdminSystemInfo> getSystemInfo({String? token}) async {
    final activeToken = await _getAuthToken(token);
    final url = _uri('/api/v1/admin/settings/system-info');

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
        return AdminSystemInfo.fromJson(decoded);
      } catch (e) {
        throw AdminApiException(
          'Invalid system info response received from server',
          statusCode: response.statusCode,
        );
      }
    }

    throw _parseError(response, 'Failed to fetch system information');
  }

  // ---------------------------------------------------------------------------
  // Points System Rules
  // ---------------------------------------------------------------------------

  /// Lists saved points rules with optional category, is_active, and search filters.
  Future<AdminPointsRuleListResponse> getPointsRules({
    String? category,
    bool? isActive,
    String? search,
    String? token,
  }) async {
    final activeToken = await _getAuthToken(token);
    final queryParams = <String, dynamic>{};
    if (category != null && category.trim().isNotEmpty && category.trim().toLowerCase() != 'all') {
      queryParams['category'] = category.trim().toLowerCase();
    }
    if (isActive != null) {
      queryParams['is_active'] = isActive.toString();
    }
    if (search != null && search.trim().isNotEmpty) {
      queryParams['search'] = search.trim();
    }

    final url = _uri('/api/v1/admin/points-rules', queryParams);

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
        return AdminPointsRuleListResponse.fromJson(decoded);
      } catch (e) {
        throw AdminApiException(
          'Invalid points rules response received from server',
          statusCode: response.statusCode,
        );
      }
    }

    throw _parseError(response, 'Failed to fetch points rules');
  }

  /// Creates a new points rule via `POST /api/v1/admin/points-rules`.
  Future<AdminPointsRule> createPointsRule(
    AdminPointsRulePayload payload, {
    String? token,
  }) async {
    final activeToken = await _getAuthToken(token);
    final url = _uri('/api/v1/admin/points-rules');

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
        return AdminPointsRule.fromJson(decoded);
      } catch (e) {
        throw AdminApiException(
          'Invalid rule response received from server',
          statusCode: response.statusCode,
        );
      }
    }

    throw _parseError(response, 'Failed to create points rule');
  }

  /// Retrieves a specific rule's detail via `GET /api/v1/admin/points-rules/{rule_id}`.
  Future<AdminPointsRule> getPointsRuleDetail(
    int ruleId, {
    String? token,
  }) async {
    final activeToken = await _getAuthToken(token);
    final url = _uri('/api/v1/admin/points-rules/$ruleId');

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
        return AdminPointsRule.fromJson(decoded);
      } catch (e) {
        throw AdminApiException(
          'Invalid rule response received from server',
          statusCode: response.statusCode,
        );
      }
    }

    throw _parseError(response, 'Failed to fetch points rule details');
  }

  /// Updates an existing points rule via `PATCH /api/v1/admin/points-rules/{rule_id}`.
  Future<AdminPointsRule> updatePointsRule(
    int ruleId,
    AdminPointsRulePayload payload, {
    String? token,
  }) async {
    final activeToken = await _getAuthToken(token);
    final url = _uri('/api/v1/admin/points-rules/$ruleId');

    final response = await _sendWithTimeout(() => _client.patch(
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
        return AdminPointsRule.fromJson(decoded);
      } catch (e) {
        throw AdminApiException(
          'Invalid rule response received from server',
          statusCode: response.statusCode,
        );
      }
    }

    throw _parseError(response, 'Failed to update points rule');
  }

  /// Toggles active/inactive status of a rule via `POST /api/v1/admin/points-rules/{rule_id}/status`.
  Future<AdminPointsRule> updatePointsRuleStatus(
    int ruleId,
    bool isActive, {
    String? token,
  }) async {
    final activeToken = await _getAuthToken(token);
    final url = _uri('/api/v1/admin/points-rules/$ruleId/status');

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
        return AdminPointsRule.fromJson(decoded);
      } catch (e) {
        throw AdminApiException(
          'Invalid rule response received from server',
          statusCode: response.statusCode,
        );
      }
    }

    throw _parseError(response, 'Failed to update rule status');
  }
}
