import 'package:flutter/material.dart';

import '../../../core/services/catalogue_api.dart';
import '../../customer/catalogue/catalogue_product_list_screen.dart';

class StaffTwoWheelerCatalogueScreen extends StatelessWidget {
  const StaffTwoWheelerCatalogueScreen({
    super.key,
    this.api,
  });

  final CatalogueApi? api;

  @override
  Widget build(BuildContext context) {
    return CatalogueProductListScreen(
      api: api ?? CatalogueApi(),
      vehicleType: '2-Wheeler',
      title: '2-Wheeler',
      heroCaption: 'Genuine Parts for a Smoother Ride',
      accentColor: const Color(0xFFDCEBFE),
      heroIcon: Icons.two_wheeler_rounded,
    );
  }
}
