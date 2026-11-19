import 'package:flutter/material.dart';

import '../../../core/services/catalogue_api.dart';
import 'catalogue_category_list_screen.dart';
import 'catalogue_product_list_screen.dart';

class ThreeWheelerPartsScreen extends StatelessWidget {
  const ThreeWheelerPartsScreen({
    super.key,
    this.api,
    this.initialCategoryId,
    this.initialCategoryName,
    this.showCategoryList = false,
  });

  final CatalogueApi? api;
  final int? initialCategoryId;
  final String? initialCategoryName;
  final bool showCategoryList;

  @override
  Widget build(BuildContext context) {
    if (showCategoryList && initialCategoryId == null) {
      return CatalogueCategoryListScreen(
        api: api ?? CatalogueApi(),
        vehicleType: '3-Wheeler',
        title: '3-Wheeler',
        heroCaption: 'Genuine Parts for a Smoother Ride',
        accentColor: const Color(0xFFFDE8E8),
        heroIcon: Icons.local_shipping_rounded,
        onCategorySelected: (context, category) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ThreeWheelerPartsScreen(
                api: api,
                initialCategoryId: category.id,
                initialCategoryName: category.name,
                showCategoryList: false,
              ),
            ),
          );
        },
      );
    }

    return CatalogueProductListScreen(
      api: api ?? CatalogueApi(),
      vehicleType: '3-Wheeler',
      title: '3-Wheeler',
      heroCaption: 'Genuine Parts for a Smoother Ride',
      accentColor: const Color(0xFFFDE8E8),
      heroIcon: Icons.local_shipping_rounded,
      initialCategoryId: initialCategoryId,
      initialCategoryName: initialCategoryName,
    );
  }
}
