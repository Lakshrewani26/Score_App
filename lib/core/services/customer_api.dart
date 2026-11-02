import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'customer_session_manager.dart';

class CustomerApiException implements Exception {
  const CustomerApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'CustomerApiException: $message';
}

class CustomerAuthResponse {
  const CustomerAuthResponse({
    required this.accessToken,
    required this.user,
  });

  final String accessToken;
  final CustomerUser user;

  factory CustomerAuthResponse.fromJson(Map<String, dynamic> json) {
    final rawUser = json['user'];
    if (json['access_token'] is! String || rawUser is! Map<String, dynamic>) {
      throw const FormatException('Customer auth response is invalid');
    }

    return CustomerAuthResponse(
      accessToken: json['access_token'] as String,
      user: CustomerUser.fromJson(rawUser),
    );
  }
}

class CustomerApi {
  CustomerApi({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl =
            (baseUrl ?? AppConfig.baseUrl).replaceAll(RegExp(r'/+$'), '');

  final http.Client _client;
  final String _baseUrl;

  Future<CustomerAuthResponse> login({
    required String mobile,
    required String password,
  }) async {
    final cleanMobile = mobile.trim();
    if (cleanMobile.isEmpty || password.isEmpty) {
      throw const CustomerApiException(
        'Mobile number and password are required',
      );
    }

    http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse('$_baseUrl/api/v1/auth/customer/login'),
            headers: const {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'mobile': cleanMobile, 'password': password}),
          )
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw const CustomerApiException(
        'Connection timed out. Please check your network.',
      );
    } on http.ClientException catch (error) {
      throw CustomerApiException('Network error: ${error.message}');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      var message = 'Login failed';
      try {
        final body = jsonDecode(response.body);
        if (body is Map<String, dynamic> && body['detail'] is String) {
          message = body['detail'] as String;
        }
      } on FormatException {
        // Keep status-based message
      }
      throw CustomerApiException(message, statusCode: response.statusCode);
    }

    try {
      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic>) {
        throw const FormatException('Expected JSON object');
      }
      return CustomerAuthResponse.fromJson(body);
    } on FormatException {
      throw CustomerApiException(
        'Invalid response received from server',
        statusCode: response.statusCode,
      );
    }
  }

  Future<CustomerAuthResponse> register({
    required String name,
    required String mobile,
    required String password,
    String? state,
    String? city,
    String? segment,
  }) async {
    final cleanName = name.trim();
    final cleanMobile = mobile.trim();

    if (cleanName.isEmpty) {
      throw const CustomerApiException('Full name is required');
    }
    if (cleanMobile.isEmpty) {
      throw const CustomerApiException('Mobile number is required');
    }
    if (password.isEmpty) {
      throw const CustomerApiException('Password is required');
    }
    if (password.length < 6) {
      throw const CustomerApiException(
        'Password must be at least 6 characters long',
      );
    }

    http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse('$_baseUrl/api/v1/auth/customer/register'),
            headers: const {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'name': cleanName,
              'mobile': cleanMobile,
              'password': password,
              'state': state,
              'city': city,
              'segment': segment,
            }),
          )
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw const CustomerApiException(
        'Connection timed out. Please check your network.',
      );
    } on http.ClientException catch (error) {
      throw CustomerApiException('Network error: ${error.message}');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      var message = 'Account creation failed';
      try {
        final body = jsonDecode(response.body);
        if (body is Map<String, dynamic> && body['detail'] is String) {
          message = body['detail'] as String;
        }
      } on FormatException {
        // Keep status-based message
      }
      throw CustomerApiException(message, statusCode: response.statusCode);
    }

    try {
      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic>) {
        throw const FormatException('Expected JSON object');
      }
      return CustomerAuthResponse.fromJson(body);
    } on FormatException {
      throw CustomerApiException(
        'Invalid response received from server',
        statusCode: response.statusCode,
      );
    }
  }

  Future<CustomerUser> getMe({String? token}) async {
    final effectiveToken =
        token ?? await CustomerSessionManager.instance.getToken();
    if (effectiveToken == null || effectiveToken.isEmpty) {
      throw const CustomerApiException(
        'Not authenticated: no bearer token available',
        statusCode: 401,
      );
    }

    http.Response response;
    try {
      response = await _client.get(
        Uri.parse('$_baseUrl/api/v1/auth/customer/me'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $effectiveToken',
        },
      ).timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw const CustomerApiException(
        'Connection timed out. Please check your network.',
      );
    } on http.ClientException catch (error) {
      throw CustomerApiException('Network error: ${error.message}');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      var message = 'Failed to fetch customer profile';
      try {
        final body = jsonDecode(response.body);
        if (body is Map<String, dynamic> && body['detail'] is String) {
          message = body['detail'] as String;
        }
      } on FormatException {
        // fallback
      }
      throw CustomerApiException(message, statusCode: response.statusCode);
    }

    try {
      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic>) {
        throw const FormatException('Expected JSON object');
      }
      return CustomerUser.fromJson(body);
    } on FormatException {
      throw CustomerApiException(
        'Invalid response received from server',
        statusCode: response.statusCode,
      );
    }
  }
}
