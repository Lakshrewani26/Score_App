import '../models/catalogue_models.dart';
import 'catalogue_api.dart';

abstract class NewArrivalsDataSource {
  Future<List<CatalogueProduct>> getNewArrivals({int limit = 5});
}

/// Dynamic, API-backed data source that retrieves latest products
/// from the `/api/v1/products/new-arrivals` endpoint.
class ApiNewArrivalsDataSource implements NewArrivalsDataSource {
  ApiNewArrivalsDataSource({CatalogueApi? catalogueApi})
      : _catalogueApi = catalogueApi ?? CatalogueApi();

  final CatalogueApi _catalogueApi;

  @override
  Future<List<CatalogueProduct>> getNewArrivals({int limit = 5}) {
    return _catalogueApi.getNewArrivals(limit: limit);
  }
}
