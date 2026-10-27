import 'package:flutter/material.dart';
import 'features/customer/catalogue/customer_catalogue_screen.dart';

void main() {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Score - Product Catalogue',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Arial',
      ),
      home: const CustomerCatalogueScreen(),
    ),
  );
}
