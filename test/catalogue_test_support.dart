import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:score_app/core/services/catalogue_api.dart';

List<Map<String, dynamic>> _testCategories() => [
      {'id': 1, 'name': 'Brake Parts', 'description': null},
      {'id': 2, 'name': 'Filters', 'description': null},
    ];

Map<String, dynamic> _testProductPage(Uri uri) {
  final page = int.tryParse(uri.queryParameters['page'] ?? '') ?? 1;
  final vehicleType = uri.queryParameters['vehicle_type'] ?? '2-Wheeler';
  final categoryId =
      int.tryParse(uri.queryParameters['category_id'] ?? '') ?? 1;
  final firstProductId = (page - 1) * 20 + 1;
  final products = List.generate(2, (index) {
    final productId = firstProductId + index;
    return {
      'id': productId,
      'category_id': categoryId,
      'category_name': categoryId == 2 ? 'Filters' : 'Brake Parts',
      'product_code': 'PART-$productId',
      'name': '$vehicleType Part $productId',
      'description': null,
      'vehicle_type': vehicleType,
      'price': '10.00',
      'image_url': null,
    };
  });

  return {
    'items': products,
    'pagination': {
      'total': 45,
      'page': page,
      'page_size': 20,
      'total_pages': 3,
    },
  };
}

/// Runs a widget-test body with scoped, successful responses for the public
/// catalogue endpoints used by home-screen navigation tests.
Future<T> withTestCatalogueHttpResponses<T>(Future<T> Function() body) {
  return HttpOverrides.runZoned(
    body,
    createHttpClient: (_) => _TestCatalogueHttpClient(),
  );
}

void testWidgetsWithCatalogueResponses(
  String description,
  Future<void> Function(WidgetTester tester) callback,
) {
  testWidgets(
    description,
    (tester) => withTestCatalogueHttpResponses(() => callback(tester)),
  );
}

CatalogueApi buildTestCatalogueApi(List<Uri> productRequests) {
  return CatalogueApi(
    client: MockClient((request) async {
      if (request.url.path == '/api/v1/categories') {
        return http.Response(
          jsonEncode(_testCategories()),
          200,
        );
      }

      if (request.url.path == '/api/v1/products') {
        productRequests.add(request.url);
        return http.Response(
          jsonEncode(_testProductPage(request.url)),
          200,
        );
      }

      return http.Response('Not found', 404);
    }),
    baseUrl: 'http://localhost',
  );
}

class _TestCatalogueHttpClient implements HttpClient {
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async =>
      _TestCatalogueHttpRequest(method, url);

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestCatalogueHttpRequest implements HttpClientRequest {
  _TestCatalogueHttpRequest(this.method, this.uri);

  @override
  final String method;

  @override
  final Uri uri;

  @override
  final HttpHeaders headers = _TestCatalogueHttpHeaders();

  @override
  int contentLength = -1;

  @override
  bool followRedirects = true;

  @override
  int maxRedirects = 5;

  @override
  bool persistentConnection = true;

  @override
  Future<void> addStream(Stream<List<int>> stream) async {
    await for (final _ in stream) {
      // Consume the request body; these catalogue GET requests send none.
    }
  }

  @override
  Future<HttpClientResponse> close() async {
    final String body;
    final int statusCode;
    if (uri.path == '/api/v1/categories') {
      body = jsonEncode(_testCategories());
      statusCode = 200;
    } else if (uri.path == '/api/v1/products') {
      body = jsonEncode(_testProductPage(uri));
      statusCode = 200;
    } else {
      body = 'Not found';
      statusCode = 404;
    }
    return _TestCatalogueHttpResponse(body, statusCode);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestCatalogueHttpResponse extends Stream<List<int>>
    implements HttpClientResponse {
  _TestCatalogueHttpResponse(String body, this.statusCode)
      : _body = Stream<List<int>>.value(utf8.encode(body));

  final Stream<List<int>> _body;

  @override
  final int statusCode;

  @override
  final HttpHeaders headers = _TestCatalogueHttpHeaders();

  @override
  int get contentLength => -1;

  @override
  bool get isRedirect => false;

  @override
  List<RedirectInfo> get redirects => const [];

  @override
  bool get persistentConnection => false;

  @override
  String get reasonPhrase => statusCode == 200 ? 'OK' : 'Not Found';

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) =>
      _body.listen(
        onData,
        onError: onError,
        onDone: onDone,
        cancelOnError: cancelOnError,
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestCatalogueHttpHeaders implements HttpHeaders {
  @override
  void forEach(void Function(String name, List<String> values) action) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
