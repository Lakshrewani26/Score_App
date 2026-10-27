import 'package:flutter/material.dart';
import 'features/partner/catalogue/partner_two_wheeler_catalogue_screen.dart';

void main() {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Score - Partner 2-Wheeler Product Catalogue',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Arial',
      ),
      home: const PartnerTwoWheelerCatalogueScreen(),
    ),
  );
}
