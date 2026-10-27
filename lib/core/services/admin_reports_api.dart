import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/admin_report_models.dart';
import 'admin_api.dart';
import 'admin_session_manager.dart';

/// API client for Admin Reports and Analytics operations.
class AdminReportsApi {
  AdminReportsApi({
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

    return AdminApiException(
      errorMessage.isNotEmpty ? errorMessage : fallbackMessage,
      statusCode: response.statusCode,
      detail: detail,
    );
  }

  /// Fetch overall report and analytics metrics with optional date and interval filters.
  Future<AdminReportOverview> getReportOverview({
    String? preset,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? interval,
    String? token,
  }) async {
    final authToken = await _getAuthToken(token);

    final queryParams = <String, dynamic>{};
    if (preset != null && preset.isNotEmpty) {
      queryParams['preset'] = preset;
    }
    if (dateFrom != null) {
      queryParams['date_from'] =
          '${dateFrom.year.toString().padLeft(4, '0')}-${dateFrom.month.toString().padLeft(2, '0')}-${dateFrom.day.toString().padLeft(2, '0')}';
    }
    if (dateTo != null) {
      queryParams['date_to'] =
          '${dateTo.year.toString().padLeft(4, '0')}-${dateTo.month.toString().padLeft(2, '0')}-${dateTo.day.toString().padLeft(2, '0')}';
    }
    if (interval != null && interval.isNotEmpty) {
      queryParams['interval'] = interval;
    }

    final url = _uri('/api/v1/admin/reports/overview', queryParams);

    final response = await _sendWithTimeout(
      () => _client.get(
        url,
        headers: {
          'Authorization': 'Bearer $authToken',
          'Accept': 'application/json',
        },
      ),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          return AdminReportOverview.fromJson(decoded);
        }
        throw AdminApiException('Invalid response format received from server.');
      } catch (e) {
        if (e is AdminApiException) rethrow;
        throw AdminApiException('Failed to parse reporting response: $e');
      }
    }

    throw _parseError(response, 'Failed to fetch report overview (${response.statusCode})');
  }
}
