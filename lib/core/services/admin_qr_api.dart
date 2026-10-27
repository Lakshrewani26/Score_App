import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/admin_qr_models.dart';
import 'admin_api.dart';
import 'admin_session_manager.dart';

/// API client for Admin QR Code Generation, Batch Management, and Exports.
class AdminQrApi {
  AdminQrApi({
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
      throw AdminApiException('Unexpected network error: $e', statusCode: 0);
    }
  }

  Never _handleError(http.Response response) {
    String detail = 'Request failed (${response.statusCode})';
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        if (decoded['detail'] is String) {
          detail = decoded['detail'] as String;
        } else if (decoded['message'] is String) {
          detail = decoded['message'] as String;
        } else if (decoded['detail'] is List) {
          final first = (decoded['detail'] as List).firstOrNull;
          if (first is Map && first['msg'] is String) {
            detail = first['msg'] as String;
          }
        }
      }
    } catch (_) {}

    throw AdminApiException(detail, statusCode: response.statusCode);
  }

  /// Lists QR batches with optional filters.
  Future<AdminQrBatchListResponse> getBatches({
    String? qrType,
    String? status,
    String? search,
    int page = 1,
    int pageSize = 20,
    String? token,
  }) async {
    final authToken = await _getAuthToken(token);
    final uri = _uri('/api/v1/admin/qr/batches', {
      'qr_type': qrType,
      'status': status,
      'search': search,
      'page': page,
      'page_size': pageSize,
    });

    final res = await _sendWithTimeout(() => _client.get(
          uri,
          headers: {
            'Authorization': 'Bearer $authToken',
            'Accept': 'application/json',
          },
        ));

    if (res.statusCode == 200) {
      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      return AdminQrBatchListResponse.fromJson(decoded);
    }
    _handleError(res);
  }

  /// Creates a new batch and generates unique QR codes.
  Future<AdminQrBatch> createBatch(
    AdminQrBatchPayload payload, {
    String? token,
  }) async {
    final authToken = await _getAuthToken(token);
    final uri = _uri('/api/v1/admin/qr/batches');

    final res = await _sendWithTimeout(() => _client.post(
          uri,
          headers: {
            'Authorization': 'Bearer $authToken',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode(payload.toJson()),
        ));

    if (res.statusCode == 201) {
      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      return AdminQrBatch.fromJson(decoded);
    }
    _handleError(res);
  }

  /// Retrieves single batch details.
  Future<AdminQrBatch> getBatch(
    int batchId, {
    String? token,
  }) async {
    final authToken = await _getAuthToken(token);
    final uri = _uri('/api/v1/admin/qr/batches/$batchId');

    final res = await _sendWithTimeout(() => _client.get(
          uri,
          headers: {
            'Authorization': 'Bearer $authToken',
            'Accept': 'application/json',
          },
        ));

    if (res.statusCode == 200) {
      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      return AdminQrBatch.fromJson(decoded);
    }
    _handleError(res);
  }

  /// Retrieves paginated QR codes belonging to a batch.
  Future<AdminQrCodeListResponse> getBatchCodes(
    int batchId, {
    String? status,
    String? search,
    int page = 1,
    int pageSize = 50,
    String? token,
  }) async {
    final authToken = await _getAuthToken(token);
    final uri = _uri('/api/v1/admin/qr/batches/$batchId/codes', {
      'status': status,
      'search': search,
      'page': page,
      'page_size': pageSize,
    });

    final res = await _sendWithTimeout(() => _client.get(
          uri,
          headers: {
            'Authorization': 'Bearer $authToken',
            'Accept': 'application/json',
          },
        ));

    if (res.statusCode == 200) {
      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      return AdminQrCodeListResponse.fromJson(decoded);
    }
    _handleError(res);
  }

  /// Downloads the Excel file (.xlsx) for a batch.
  Future<Uint8List> downloadBatchExcel(
    int batchId, {
    String? token,
  }) async {
    final authToken = await _getAuthToken(token);
    final uri = _uri('/api/v1/admin/qr/batches/$batchId/export/excel');

    final res = await _sendWithTimeout(() => _client.get(
          uri,
          headers: {
            'Authorization': 'Bearer $authToken',
            'Accept': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          },
        ));

    if (res.statusCode == 200) {
      return res.bodyBytes;
    }
    _handleError(res);
  }

  /// Downloads the CSV export for a batch.
  Future<String> downloadBatchCsv(
    int batchId, {
    String? token,
  }) async {
    final authToken = await _getAuthToken(token);
    final uri = _uri('/api/v1/admin/qr/batches/$batchId/export/csv');

    final res = await _sendWithTimeout(() => _client.get(
          uri,
          headers: {
            'Authorization': 'Bearer $authToken',
            'Accept': 'text/csv',
          },
        ));

    if (res.statusCode == 200) {
      return res.body;
    }
    _handleError(res);
  }

  /// Updates status of an individual QR code (e.g. void or activate).
  Future<AdminQrCode> updateCodeStatus(
    int codeId,
    String newStatus, {
    String? token,
  }) async {
    final authToken = await _getAuthToken(token);
    final uri = _uri('/api/v1/admin/qr/codes/$codeId/status');

    final res = await _sendWithTimeout(() => _client.patch(
          uri,
          headers: {
            'Authorization': 'Bearer $authToken',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({'status': newStatus}),
        ));

    if (res.statusCode == 200) {
      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      return AdminQrCode.fromJson(decoded);
    }
    _handleError(res);
  }
}
