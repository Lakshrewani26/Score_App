import 'package:flutter/material.dart';

import '../../../core/services/catalogue_api.dart';
import 'catalogue_product_list_screen.dart';

class ThreeWheelerPartsScreen extends StatelessWidget {
  const ThreeWheelerPartsScreen({
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
