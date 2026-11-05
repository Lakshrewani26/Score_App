import 'package:flutter/material.dart';

import '../../../core/services/catalogue_api.dart';
import '../../customer/catalogue/catalogue_product_list_screen.dart';

class StaffThreeWheelerCatalogueScreen extends StatelessWidget {
  const StaffThreeWheelerCatalogueScreen({
    super.key,
    this.api,
  });

  final CatalogueApi? api;

  @override
  Widget build(BuildContext context) {
    return CatalogueProductListScreen(
      api: api ?? CatalogueApi(),
      vehicleType: '3-Wheeler',
      title: '3-Wheeler',
      heroCaption: 'Genuine Parts for a Smoother Ride',
      accentColor: const Color(0xFFFDE8E8),
      heroIcon: Icons.local_shipping_rounded,
    );
  }
}
