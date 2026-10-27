import 'package:flutter/material.dart';

import '../../../core/services/catalogue_api.dart';
import '../../customer/catalogue/catalogue_product_list_screen.dart';
import 'partner_catalogue_screen.dart';

class PartnerTwoWheelerCatalogueScreen extends StatelessWidget {
  const PartnerTwoWheelerCatalogueScreen({
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
      fallbackBuilder: (_) => const PartnerProductCatalogueScreen(),
      accentColor: const Color(0xFFDCEBFE),
      heroIcon: Icons.two_wheeler_rounded,
      enablePartnerQuantitySelection: true,
    );
  }
}
