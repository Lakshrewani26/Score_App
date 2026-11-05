import '../../../../core/models/catalogue_models.dart';

abstract class NewArrivalsDataSource {
  Future<List<CatalogueProduct>> getNewArrivals();
}

/// Isolated data source providing clearly marked placeholder products
/// for the New Arrivals section. Real backend integration can replace
/// this implementation seamlessly without modifying the Home UI.
class PlaceholderNewArrivalsDataSource implements NewArrivalsDataSource {
  const PlaceholderNewArrivalsDataSource({
    this.customProducts,
    this.delay = Duration.zero,
  });

  final List<CatalogueProduct>? customProducts;
  final Duration delay;

  @override
  Future<List<CatalogueProduct>> getNewArrivals() async {
    if (delay > Duration.zero) {
      await Future.delayed(delay);
    }
    if (customProducts != null) {
      return customProducts!;
    }

    return const [
      CatalogueProduct(
        id: -101,
        categoryId: 1,
        categoryName: 'Electrical',
        productCode: 'SAMPLE-NA-01',
        name: 'Sample Starter Motor',
        description: 'Placeholder product description for starter motor',
        vehicleType: '2-Wheeler',
        price: 1450.00,
        imageUrl: null,
      ),
      CatalogueProduct(
        id: -102,
        categoryId: 2,
        categoryName: 'Brakes',
        productCode: 'SAMPLE-NA-02',
        name: 'Sample Disc Brake Pad',
        description: 'Placeholder product description for disc brake pad',
        vehicleType: '2-Wheeler',
        price: 680.00,
        imageUrl: null,
      ),
      CatalogueProduct(
        id: -103,
        categoryId: 3,
        categoryName: 'Engine',
        productCode: 'SAMPLE-NA-03',
        name: 'Sample Piston Kit',
        description: 'Placeholder product description for piston kit',
        vehicleType: '3-Wheeler',
        price: 2100.00,
        imageUrl: null,
      ),
      CatalogueProduct(
        id: -104,
        categoryId: 4,
        categoryName: 'Suspension',
        productCode: 'SAMPLE-NA-04',
        name: 'Sample Shock Absorber',
        description: 'Placeholder product description for shock absorber',
        vehicleType: 'Both',
        price: 1850.00,
        imageUrl: null,
      ),
    ];
  }
}
