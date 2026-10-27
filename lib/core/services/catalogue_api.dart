import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/catalogue_models.dart';

class CatalogueApiException implements Exception {
  CatalogueApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'CatalogueApiException: $message';
}

class CatalogueApi {
  CatalogueApi({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = (baseUrl ?? AppConfig.baseUrl).replaceAll(RegExp(r'/+$'), '');

  final http.Client _client;
  final String _baseUrl;

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

  Future<List<CatalogueCategory>> loadCategories() async {
    final response = await _client.get(_uri('/api/v1/categories'));
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

    final response = await _client.get(_uri('/api/v1/products', query));
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
    final response = await _client.get(_uri('/api/v1/products/$productId'));
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
