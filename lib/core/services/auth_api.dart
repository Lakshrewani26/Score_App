import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';

class AuthApiException implements Exception {
  const AuthApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'AuthApiException: $message (statusCode: $statusCode)';
}

class UnifiedAuthResponse {
  const UnifiedAuthResponse({
    required this.accessToken,
    this.tokenType = 'bearer',
    this.expiresIn = 0,
    required this.userId,
    required this.name,
    required this.mobile,
    required this.role,
    required this.isActive,
    this.staffId,
    this.customerProfile,
    this.partnerProfile,
    required this.rawUser,
  });

  final String accessToken;
  final String tokenType;
  final int expiresIn;
  final int userId;
  final String name;
  final String mobile;
  final String role;
  final bool isActive;
  final String? staffId;
  final Map<String, dynamic>? customerProfile;
  final Map<String, dynamic>? partnerProfile;
  final Map<String, dynamic> rawUser;

  factory UnifiedAuthResponse.fromJson(Map<String, dynamic> json) {
    final token = json['access_token'];
    if (token is! String || token.isEmpty) {
      throw const FormatException(
          'Missing or invalid access_token in response');
    }

    final rawUser = (json['user'] is Map<String, dynamic>)
        ? json['user'] as Map<String, dynamic>
        : <String, dynamic>{};

    final userId = json['user_id'] as int? ??
        json['id'] as int? ??
        rawUser['id'] as int? ??
        0;

    final role = (json['role'] ?? rawUser['role'] ?? '').toString();
    final name = (json['name'] ?? rawUser['name'] ?? '').toString();
    final mobile = (json['mobile'] ?? rawUser['mobile'] ?? '').toString();
    final isActive =
        json['is_active'] as bool? ?? rawUser['is_active'] as bool? ?? false;
    final staffId =
        json['staff_id'] as String? ?? rawUser['staff_id'] as String?;

    return UnifiedAuthResponse(
      accessToken: token,
      tokenType: (json['token_type'] ?? 'bearer').toString(),
      expiresIn: json['expires_in'] as int? ?? 0,
      userId: userId,
      name: name,
      mobile: mobile,
      role: role,
      isActive: isActive,
      staffId: staffId,
      customerProfile: json['customer_profile'] as Map<String, dynamic>? ??
          rawUser['customer_profile'] as Map<String, dynamic>?,
      partnerProfile: json['partner_profile'] as Map<String, dynamic>? ??
          rawUser['partner_profile'] as Map<String, dynamic>?,
      rawUser: rawUser.isNotEmpty ? rawUser : json,
    );
  }
}

class AuthApi {
  AuthApi({
    http.Client? client,
    String? baseUrl,
  })  : _client = client ?? http.Client(),
        _baseUrl =
            (baseUrl ?? AppConfig.baseUrl).replaceAll(RegExp(r'/+$'), '');

  final http.Client _client;
  final String _baseUrl;

  Future<UnifiedAuthResponse> login({
    required String mobile,
    required String password,
  }) async {
    final cleanMobile = mobile.trim();
    if (cleanMobile.isEmpty || password.isEmpty) {
      throw const AuthApiException(
        'Phone number and password are required',
      );
    }

    http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse('$_baseUrl/api/v1/auth/login'),
            headers: const {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'mobile': cleanMobile,
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw const AuthApiException(
        'Connection timed out. Please check your network.',
      );
    } on http.ClientException catch (error) {
      throw AuthApiException('Network error: ${error.message}');
    } catch (e) {
      if (e is AuthApiException) rethrow;
      throw const AuthApiException(
        'Unable to connect to server. Please try again.',
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      var message = 'Invalid phone number or password';
      try {
        final body = jsonDecode(response.body);
        if (body is Map<String, dynamic>) {
          if (body['detail'] is String) {
            message = body['detail'] as String;
          } else if (body['detail'] is List &&
              (body['detail'] as List).isNotEmpty) {
            final first = (body['detail'] as List).first;
            if (first is Map && first['msg'] != null) {
              message = first['msg'].toString();
            }
          }
        }
      } catch (_) {}
      throw AuthApiException(message, statusCode: response.statusCode);
    }

    try {
      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic>) {
        throw const FormatException('Expected JSON object in response');
      }
      return UnifiedAuthResponse.fromJson(data);
    } on FormatException catch (e) {
      throw AuthApiException('Failed to parse response: ${e.message}');
    }
  }
}
