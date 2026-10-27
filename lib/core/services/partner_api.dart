import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'partner_session_manager.dart';

class PartnerApiException implements Exception {
  const PartnerApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'PartnerApiException: $message';
}

class PartnerAuthResponse {
  const PartnerAuthResponse({
    required this.accessToken,
    required this.user,
  });

  final String accessToken;
  final PartnerUser user;

  factory PartnerAuthResponse.fromJson(Map<String, dynamic> json) {
    final rawUser = json['user'];
    if (json['access_token'] is! String || rawUser is! Map<String, dynamic>) {
      throw const FormatException('Partner login response is invalid');
    }

    return PartnerAuthResponse(
      accessToken: json['access_token'] as String,
      user: PartnerUser.fromJson(rawUser),
    );
  }
}

class PartnerApi {
  PartnerApi({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl =
            (baseUrl ?? AppConfig.baseUrl).replaceAll(RegExp(r'/+$'), '');

  final http.Client _client;
  final String _baseUrl;

  Future<PartnerAuthResponse> login({
    required String mobile,
    required String password,
  }) async {
    final cleanMobile = mobile.trim();
    if (cleanMobile.isEmpty || password.isEmpty) {
      throw const PartnerApiException(
          'Mobile number and password are required');
    }

    http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse('$_baseUrl/api/v1/auth/partner/login'),
            headers: const {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'mobile': cleanMobile, 'password': password}),
          )
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw const PartnerApiException(
        'Connection timed out. Please check your network.',
      );
    } on http.ClientException catch (error) {
      throw PartnerApiException('Network error: ${error.message}');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      var message = 'Login failed';
      try {
        final body = jsonDecode(response.body);
        if (body is Map<String, dynamic> && body['detail'] is String) {
          message = body['detail'] as String;
        }
      } on FormatException {
        // Keep the status-based message if the server did not return JSON.
      }
      throw PartnerApiException(message, statusCode: response.statusCode);
    }

    try {
      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic>) {
        throw const FormatException('Expected JSON object');
      }
      return PartnerAuthResponse.fromJson(body);
    } on FormatException {
      throw PartnerApiException(
        'Invalid response received from server',
        statusCode: response.statusCode,
      );
    }
  }
}
