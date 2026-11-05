import '../../../../core/models/catalogue_models.dart';

abstract class StaffNewArrivalsDataSource {
  Future<List<CatalogueProduct>> getNewArrivals();
}

/// Isolated data source providing clearly marked placeholder products
/// for the Staff New Arrivals section. Real backend integration can replace
/// this implementation seamlessly without modifying the Staff Home UI.
class PlaceholderStaffNewArrivalsDataSource
    implements StaffNewArrivalsDataSource {
  const PlaceholderStaffNewArrivalsDataSource({
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
        id: -201,
        categoryId: 1,
        categoryName: 'Electrical',
        productCode: 'SAMPLE-STAFF-NA-01',
        name: 'Sample Starter Motor Pro',
        description: 'Placeholder product description for starter motor',
        vehicleType: '2-Wheeler',
        price: 1550.00,
        imageUrl: null,
      ),
      CatalogueProduct(
        id: -202,
        categoryId: 2,
        categoryName: 'Brakes',
        productCode: 'SAMPLE-STAFF-NA-02',
        name: 'Sample Disc Brake Assembly',
        description: 'Placeholder product description for disc brake assembly',
        vehicleType: '2-Wheeler',
        price: 890.00,
        imageUrl: null,
      ),
      CatalogueProduct(
        id: -203,
        categoryId: 3,
        categoryName: 'Engine',
        productCode: 'SAMPLE-STAFF-NA-03',
        name: 'Sample Piston Kit Heavy Duty',
        description: 'Placeholder product description for piston kit',
        vehicleType: '3-Wheeler',
        price: 2450.00,
        imageUrl: null,
      ),
      CatalogueProduct(
        id: -204,
        categoryId: 4,
        categoryName: 'Suspension',
        productCode: 'SAMPLE-STAFF-NA-04',
        name: 'Sample Gas Shock Absorber',
        description: 'Placeholder product description for gas shock absorber',
        vehicleType: 'Both',
        price: 2100.00,
        imageUrl: null,
      ),
    ];
  }
}
