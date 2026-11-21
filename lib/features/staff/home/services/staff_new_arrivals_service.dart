import '../../../../core/models/catalogue_models.dart';
import '../../../../core/services/new_arrivals_service.dart';

export '../../../../core/services/new_arrivals_service.dart'
    show NewArrivalsDataSource, ApiNewArrivalsDataSource;

typedef StaffNewArrivalsDataSource = NewArrivalsDataSource;

/// Isolated data source providing clearly marked placeholder products
/// for the Staff New Arrivals section. Used in UI widget tests when mock data is needed.
class PlaceholderStaffNewArrivalsDataSource
    implements NewArrivalsDataSource {
  const PlaceholderStaffNewArrivalsDataSource({
    this.customProducts,
    this.delay = Duration.zero,
  });

  final List<CatalogueProduct>? customProducts;
  final Duration delay;

  @override
  Future<List<CatalogueProduct>> getNewArrivals({int limit = 5}) async {
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
        listPrice: 1250.00,
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
        listPrice: 720.00,
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
        listPrice: 1980.00,
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
        listPrice: 1700.00,
        imageUrl: null,
      ),
    ];
  }
}
